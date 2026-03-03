"""同步 API 端点 - 用于同步离线数据"""
from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.services.workout_service import WorkoutService
from app.services.user_service import UserService
from app.schemas.profile import UserProfileCreate, UserProfileUpdate
from pydantic import BaseModel

router = APIRouter(prefix="/sync", tags=["同步"])


class WorkoutRecordSyncRequest(BaseModel):
    """训练记录同步请求"""
    plan_id: Optional[str] = None
    completed_at: str  # ISO 8601 格式的时间戳
    duration: int  # 训练时长（秒）
    completed_exercises: List[str]  # 完成的动作ID列表


class FeedbackSyncRequest(BaseModel):
    """反馈同步请求"""
    plan_id: Optional[str] = None
    record_date: str  # 日期格式 YYYY-MM-DD
    duration: int  # 训练时长（分钟）
    completion: str  # 完成度
    feeling: str  # 感受
    tomorrow: str  # 明天偏好
    pain_locations: List[str] = []
    completed: bool = True


class ProfileSyncRequest(BaseModel):
    """用户画像同步请求"""
    nickname: Optional[str] = None
    fitness_level: Optional[str] = None
    goal: Optional[str] = None
    scene: Optional[str] = None
    time_budget: Optional[int] = None
    limitations: List[str] = []
    equipment: Optional[str] = None
    weekly_days: Optional[int] = None


class SyncResponse(BaseModel):
    """同步响应"""
    success: bool
    synced_count: int = 0
    failed_count: int = 0
    errors: List[str] = []


@router.post("/workout-records", response_model=SyncResponse)
async def sync_workout_records(
    records: List[WorkoutRecordSyncRequest],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    同步训练记录

    批量上传离线保存的训练记录
    """
    service = WorkoutService(db)
    synced_count = 0
    failed_count = 0
    errors = []

    for record in records:
        try:
            # 将 completed_at 转换为 date
            from datetime import datetime
            completed_at = datetime.fromisoformat(record.completed_at.replace('Z', '+00:00'))
            record_date = completed_at.date()

            # 创建记录（如果已存在则更新）
            await service.create_record(
                user_id=str(current_user.id),
                plan_id=record.plan_id,
                record_date=record_date,
                duration=record.duration // 60,  # 转换为分钟
                completion="smooth",  # 离线记录默认为顺利完成
                feeling="just_right",
                tomorrow="maintain",
                pain_locations=[],
                completed=record.completed,
            )
            synced_count += 1
        except Exception as e:
            failed_count += 1
            errors.append(f"记录同步失败: {str(e)}")

    return SyncResponse(
        success=failed_count == 0,
        synced_count=synced_count,
        failed_count=failed_count,
        errors=errors,
    )


@router.post("/feedback", response_model=SyncResponse)
async def sync_feedback(
    feedback: FeedbackSyncRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    同步训练反馈

    上传离线保存的训练反馈
    """
    service = WorkoutService(db)

    try:
        record = await service.create_record(
            user_id=str(current_user.id),
            plan_id=feedback.plan_id,
            record_date=date.fromisoformat(feedback.record_date),
            duration=feedback.duration,
            completion=feedback.completion,
            feeling=feedback.feeling,
            tomorrow=feedback.tomorrow,
            pain_locations=feedback.pain_locations,
            completed=feedback.completed,
        )

        return SyncResponse(
            success=True,
            synced_count=1,
            failed_count=0,
        )
    except Exception as e:
        return SyncResponse(
            success=False,
            synced_count=0,
            failed_count=1,
            errors=[str(e)],
        )


@router.post("/profile", response_model=SyncResponse)
async def sync_profile(
    profile: ProfileSyncRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    同步用户画像

    上传离线修改的用户画像信息
    """
    user_service = UserService(db)

    try:
        # 只更新提供的字段
        update_data = {k: v for k, v in profile.model_dump().items() if v is not None}

        if not update_data:
            return SyncResponse(success=True, synced_count=0)

        # 先检查是否存在
        existing = await user_service.get_user_profile(str(current_user.id))

        if existing:
            # 更新
            await user_service.update_user_profile(
                str(current_user.id),
                UserProfileUpdate(**update_data)
            )
        else:
            # 创建（需要提供必要字段）
            required_fields = ['nickname', 'fitness_level', 'goal', 'scene', 'time_budget']
            for field in required_fields:
                if field not in update_data:
                    update_data[field] = None

            await user_service.create_user_profile(
                str(current_user.id),
                UserProfileCreate(**update_data)
            )

        return SyncResponse(success=True, synced_count=1)
    except Exception as e:
        return SyncResponse(
            success=False,
            synced_count=0,
            failed_count=1,
            errors=[str(e)],
        )


@router.post("/complete-plan/{plan_id}")
async def sync_complete_plan(
    plan_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    同步计划完成状态

    标记离线完成的训练计划
    """
    service = WorkoutService(db)

    try:
        plan = await service.complete_plan(plan_id, str(current_user.id))

        if not plan:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="计划不存在或无权访问"
            )

        return {
            "success": True,
            "plan_id": plan_id,
            "message": "计划完成状态已同步"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
