"""反馈 API 端点"""
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.services.workout_service import WorkoutService
from app.services.ai_service import AIService
from app.schemas.workout import (
    WorkoutFeedbackRequest,
    WorkoutFeedbackResponse,
    AdjustmentSuggestionResponse,
)

router = APIRouter(prefix="/feedback", tags=["训练反馈"])


@router.post("", response_model=WorkoutFeedbackResponse)
async def submit_feedback(
    request: WorkoutFeedbackRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    提交训练反馈

    记录用户对今日训练的反馈，用于调整明日计划
    """
    service = WorkoutService(db)

    record = await service.create_record(
        user_id=str(current_user.id),
        plan_id=request.plan_id,
        record_date=date.today(),
        duration=request.duration,
        completion=request.completion,
        feeling=request.feeling,
        tomorrow=request.tomorrow,
        pain_locations=request.pain_locations or [],
        completed=request.completed
    )

    return WorkoutFeedbackResponse(
        success=True,
        record_id=str(record.id),
        message="反馈已记录，将用于优化明日计划"
    )


@router.get("/today")
async def get_today_feedback(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取今日反馈（用于检查是否已提交）
    """
    service = WorkoutService(db)
    record = await service.get_record_by_date(
        user_id=str(current_user.id),
        record_date=date.today()
    )

    if record:
        return {
            "exists": True,
            "feedback": {
                "id": str(record.id),
                "completion": record.completion,
                "feeling": record.feeling,
                "tomorrow": record.tomorrow,
                "pain_locations": record.pain_locations,
                "completed": record.completed,
            }
        }

    return {"exists": False}


@router.get("/yesterday")
async def get_yesterday_feedback(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取昨天的训练反馈

    用于生成今日计划时参考
    """
    service = WorkoutService(db)
    record = await service.get_yesterday_feedback(str(current_user.id))

    if record:
        return {
            "exists": True,
            "feedback": {
                "id": str(record.id),
                "completion": record.completion,
                "feeling": record.feeling,
                "tomorrow": record.tomorrow,
                "pain_locations": record.pain_locations,
            }
        }

    return {"exists": False}


@router.get("/recent")
async def get_recent_feedback(
    days: int = 7,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取最近几天的反馈记录
    """
    service = WorkoutService(db)
    records = await service.get_recent_records(
        user_id=str(current_user.id),
        days=days
    )

    return {
        "records": [
            {
                "id": str(r.id),
                "record_date": r.record_date.isoformat(),
                "completion": r.completion,
                "feeling": r.feeling,
                "tomorrow": r.tomorrow,
                "pain_locations": r.pain_locations,
                "completed": r.completed,
            }
            for r in records
        ]
    }


@router.post("/adjust-next", response_model=AdjustmentSuggestionResponse)
async def get_next_day_adjustment(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    基于昨日反馈获取明日计划调整建议

    分析昨日反馈，给出明日训练建议
    """
    # 获取昨日反馈
    workout_service = WorkoutService(db)
    yesterday_feedback = await workout_service.get_yesterday_feedback(
        str(current_user.id)
    )

    if not yesterday_feedback:
        return AdjustmentSuggestionResponse(
            success=False,
            error="没有昨日反馈数据"
        )

    # 根据反馈给出建议
    feedback_data = {
        "completion": yesterday_feedback.completion,
        "feeling": yesterday_feedback.feeling,
        "tomorrow": yesterday_feedback.tomorrow,
        "pain_locations": yesterday_feedback.pain_locations,
    }

    # 生成调整建议
    suggestion = _generate_adjustment_suggestion(feedback_data)

    # 根据"明天偏好"调整参数
    adjusted_params = _get_adjusted_params(feedback_data["tomorrow"])

    return AdjustmentSuggestionResponse(
        success=True,
        suggestion=suggestion,
        adjusted_params=adjusted_params
    )


def _generate_adjustment_suggestion(feedback: dict) -> str:
    """根据反馈生成调整建议文本"""
    tomorrow = feedback.get("tomorrow", "maintain")
    completion = feedback.get("completion", "smooth")
    feeling = feedback.get("feeling", "just_right")
    pain_locations = feedback.get("pain_locations", [])

    suggestions = []

    # 基于完成情况
    if completion == "too_hard":
        suggestions.append("昨天训练难度过高，今日建议降低强度")
    elif completion == "easy":
        suggestions.append("昨天训练较为轻松，今日可以适当提高强度")

    # 基于感受
    if feeling == "uncomfortable":
        suggestions.append("昨天出现不适，今日需要关注恢复")
    elif feeling == "tired":
        suggestions.append("昨天感觉疲劳，今日建议轻松训练")
    elif feeling == "energized":
        suggestions.append("昨天状态很好，今日可以保持")

    # 基于明天偏好
    if tomorrow == "recovery":
        suggestions.append("今日是恢复日，以拉伸和低强度动作为主")
    elif tomorrow == "intensify":
        suggestions.append("今日可以提高训练强度或时长")

    # 基于疼痛部位
    if pain_locations:
        suggestions.append(f"注意避免刺激以下部位：{', '.join(pain_locations)}")

    if not suggestions:
        suggestions.append("昨日训练表现良好，今日保持即可")

    return "；".join(suggestions)


def _get_adjusted_params(tomorrow_preference: str) -> dict:
    """根据明天偏好获取调整后的参数"""
    params = {
        "recovery": {
            "rpe_adjustment": -2,
            "duration_adjustment": -5,
            "focus": "恢复拉伸"
        },
        "maintain": {
            "rpe_adjustment": 0,
            "duration_adjustment": 0,
            "focus": "保持"
        },
        "intensify": {
            "rpe_adjustment": 1,
            "duration_adjustment": 3,
            "focus": "强化"
        }
    }

    return params.get(tomorrow_preference, params["maintain"])
