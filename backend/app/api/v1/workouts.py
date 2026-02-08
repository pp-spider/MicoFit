"""训练计划 API 端点"""
from datetime import date, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.services.workout_service import WorkoutService
from app.services.ai_service import AIService
from app.schemas.workout import (
    WorkoutPlanSchema,
    WorkoutPlanResponse,
    WorkoutPlanApplyRequest,
)

router = APIRouter(prefix="/workouts", tags=["训练计划"])


@router.get("/today", response_model=Optional[WorkoutPlanSchema])
async def get_today_plan(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取今日训练计划

    优先返回已应用的计划，否则返回最新生成的计划
    """
    service = AIService(db)
    plan = await service.get_today_plan(str(current_user.id))

    if plan:
        return plan

    return None


@router.post("/generate", response_model=WorkoutPlanResponse)
async def generate_plan(
    preferences: Optional[dict] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    生成新的训练计划

    根据用户画像和偏好生成个性化训练计划
    """
    service = AIService(db)
    result = await service.generate_workout_plan(
        user_id=str(current_user.id),
        preferences=preferences
    )

    return WorkoutPlanResponse(**result)


@router.post("/apply")
async def apply_plan(
    request: WorkoutPlanApplyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    应用训练计划到今日

    将指定计划标记为当前使用的计划
    """
    service = WorkoutService(db)
    plan = await service.apply_plan(str(current_user.id), request.plan_id)

    if not plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="计划不存在或无权访问"
        )

    return {
        "success": True,
        "plan_id": str(plan.id),
        "message": "计划已应用到今日"
    }


@router.post("/{plan_id}/complete")
async def complete_plan(
    plan_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    标记训练计划为已完成
    """
    service = WorkoutService(db)
    plan = await service.complete_plan(plan_id, str(current_user.id))

    if not plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="计划不存在或无权访问"
        )

    return {
        "success": True,
        "plan_id": str(plan.id),
        "message": "计划已标记为完成"
    }


@router.get("/history", response_model=list[WorkoutPlanSchema])
async def get_plan_history(
    start_date: Optional[date] = Query(None, description="开始日期"),
    end_date: Optional[date] = Query(None, description="结束日期"),
    limit: int = Query(30, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取历史训练计划

    可按日期范围筛选
    """
    service = WorkoutService(db)
    plans = await service.get_plan_history(
        user_id=str(current_user.id),
        start_date=start_date,
        end_date=end_date,
        limit=limit
    )

    return plans


@router.get("/{plan_id}", response_model=WorkoutPlanSchema)
async def get_plan(
    plan_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取指定训练计划的详情
    """
    service = WorkoutService(db)
    plan = await service.get_plan_by_id(plan_id)

    if not plan or str(plan.user_id) != str(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="计划不存在或无权访问"
        )

    return plan
