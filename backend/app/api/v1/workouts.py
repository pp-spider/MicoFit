"""训练计划 API 端点"""
from datetime import date, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import select, desc
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
    WorkoutProgressSchema,
    WorkoutProgressCreateRequest,
    WorkoutProgressUpdateRequest,
    WorkoutProgressResponse,
)
from app.models.workout_progress import WorkoutProgress
from datetime import datetime

router = APIRouter(prefix="/workouts", tags=["训练计划"])


@router.get("/today", response_model=Optional[WorkoutPlanSchema])
async def get_today_plan(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    plan_date: Optional[date] = Query(None, description="指定日期，格式如 2024-01-01，默认为今日"),
):
    """
    获取今日训练计划

    优先返回已应用的计划，否则返回最新生成的计划
    支持通过 plan_date 参数指定日期，以支持不同时区的用户
    """
    service = AIService(db)
    plan = await service.get_today_plan(str(current_user.id), plan_date=plan_date)

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


@router.get("/latest", response_model=Optional[WorkoutPlanSchema])
async def get_latest_plan(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取最新的训练计划（按创建时间排序）

    返回用户最近一次创建的训练计划
    """
    from app.models.workout_plan import WorkoutPlan

    result = await db.execute(
        select(WorkoutPlan)
        .where(WorkoutPlan.user_id == str(current_user.id))
        .order_by(desc(WorkoutPlan.created_at))
        .limit(1)
    )
    plan = result.scalar_one_or_none()

    if plan:
        return plan

    return None


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


@router.get("/records")
async def get_workout_records(
    start_date: Optional[date] = Query(None, description="开始日期 (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="结束日期 (YYYY-MM-DD)"),
    limit: int = Query(100, ge=1, le=500),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取训练记录列表

    用于同步本地数据到后端后的数据拉取
    """
    service = WorkoutService(db)
    records = await service.get_user_records_for_sync(
        user_id=str(current_user.id),
        start_date=start_date,
        end_date=end_date,
    )

    return {"records": records}


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


@router.get("/stats/monthly")
async def get_monthly_stats(
    year: int = Query(..., description="年份"),
    month: int = Query(..., ge=1, le=12, description="月份 (1-12)"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取月度统计数据

    返回指定月份的训练统计数据，包括总时长、完成天数、每日记录等
    """
    service = WorkoutService(db)
    stats = await service.get_monthly_stats(
        user_id=str(current_user.id),
        year=year,
        month=month
    )

    return stats


# ========== 训练进度 API ==========

@router.get("/progress/today", response_model=Optional[WorkoutProgressSchema])
async def get_today_progress(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取今日训练进度

    返回今天的训练进度（如果有），没有则返回 null
    """
    from sqlalchemy import select
    from datetime import date

    today = date.today().strftime("%Y-%m-%d")

    result = await db.execute(
        select(WorkoutProgress)
        .where(WorkoutProgress.user_id == str(current_user.id))
        .where(WorkoutProgress.date_key == today)
    )
    progress = result.scalar_one_or_none()

    return progress


@router.post("/progress", response_model=WorkoutProgressResponse)
async def create_progress(
    request: WorkoutProgressCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    创建新的训练进度

    开始一个新训练时调用，会覆盖当天的现有进度
    """
    from datetime import date
    from sqlalchemy import select, delete

    today = date.today().strftime("%Y-%m-%d")
    now = datetime.utcnow()

    # 先删除当天的现有进度
    await db.execute(
        delete(WorkoutProgress)
        .where(WorkoutProgress.user_id == str(current_user.id))
        .where(WorkoutProgress.date_key == today)
    )

    # 创建新进度
    progress = WorkoutProgress(
        user_id=str(current_user.id),
        date_key=today,
        plan_id=request.plan_id,
        status="not_started",
        current_module_index=0,
        current_exercise_index=0,
        total_exercises=request.total_exercises,
        completed_exercise_ids=[],
        start_time=now,
        last_update_time=now,
        actual_duration=0,
    )
    db.add(progress)
    await db.commit()
    await db.refresh(progress)

    return WorkoutProgressResponse(success=True, progress=progress)


@router.put("/progress", response_model=WorkoutProgressResponse)
async def update_progress(
    request: WorkoutProgressUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    更新训练进度

    在训练过程中实时更新进度
    支持通过 plan_id 定位进度（用于离线同步）
    """
    from datetime import date
    from sqlalchemy import select

    today = date.today().strftime("%Y-%m-%d")

    # 支持通过 plan_id 定位进度（同时限制 date_key 为今天，避免返回多条记录）
    if request.plan_id:
        result = await db.execute(
            select(WorkoutProgress)
            .where(WorkoutProgress.user_id == str(current_user.id))
            .where(WorkoutProgress.plan_id == request.plan_id)
            .where(WorkoutProgress.date_key == today)
        )
    else:
        # 默认查找今天的进度
        result = await db.execute(
            select(WorkoutProgress)
            .where(WorkoutProgress.user_id == str(current_user.id))
            .where(WorkoutProgress.date_key == today)
        )
    progress = result.scalar_one_or_none()

    if not progress:
        # 如果指定了 plan_id 但没找到，返回 404 错误
        if request.plan_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"未找到计划 {request.plan_id} 的训练进度"
            )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="未找到今日训练进度"
        )

    # 更新字段
    if request.status is not None:
        progress.status = request.status
    if request.current_module_index is not None:
        progress.current_module_index = request.current_module_index
    if request.current_exercise_index is not None:
        progress.current_exercise_index = request.current_exercise_index
    if request.completed_exercise_ids is not None:
        progress.completed_exercise_ids = request.completed_exercise_ids
    if request.actual_duration is not None:
        progress.actual_duration = request.actual_duration

    progress.last_update_time = datetime.utcnow()

    await db.commit()
    await db.refresh(progress)

    return WorkoutProgressResponse(success=True, progress=progress)


@router.delete("/progress")
async def clear_progress(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    清除今日训练进度

    重置今天的训练进度
    """
    from datetime import date
    from sqlalchemy import delete

    today = date.today().strftime("%Y-%m-%d")

    await db.execute(
        delete(WorkoutProgress)
        .where(WorkoutProgress.user_id == str(current_user.id))
        .where(WorkoutProgress.date_key == today)
    )
    await db.commit()

    return {"success": True, "message": "进度已清除"}
