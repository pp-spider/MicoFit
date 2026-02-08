"""训练计划服务"""
import uuid
from datetime import date, timedelta
from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc

from app.models.workout_plan import WorkoutPlan, WorkoutRecord


class WorkoutService:
    """训练计划服务"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_plan(
        self,
        user_id: str,
        plan_date: date,
        title: str,
        subtitle: str,
        total_duration: int,
        scene: str,
        rpe: int,
        modules: list,
        ai_note: str | None = None,
        is_applied: bool = False
    ) -> WorkoutPlan:
        """
        创建或更新训练计划

        如果同一天已存在计划，则更新现有计划；否则创建新计划。

        Args:
            user_id: 用户ID
            plan_date: 计划日期
            title: 标题
            subtitle: 副标题
            total_duration: 总时长（分钟）
            scene: 场景
            rpe: 强度（1-10）
            modules: 模块列表
            ai_note: AI备注
            is_applied: 是否已应用

        Returns:
            WorkoutPlan: 创建或更新的计划
        """
        # 检查同一天是否已有计划
        result = await self.db.execute(
            select(WorkoutPlan).where(
                and_(
                    WorkoutPlan.user_id == user_id,
                    WorkoutPlan.plan_date == plan_date
                )
            )
        )
        existing_plan = result.scalar_one_or_none()

        if existing_plan:
            # 更新现有计划
            existing_plan.title = title
            existing_plan.subtitle = subtitle
            existing_plan.total_duration = total_duration
            existing_plan.scene = scene
            existing_plan.rpe = rpe
            existing_plan.modules = modules
            existing_plan.ai_note = ai_note
            existing_plan.is_applied = is_applied
            existing_plan.is_completed = False  # 重置完成状态
            existing_plan.feedback_id = None  # 清除关联的反馈
            await self.db.commit()
            await self.db.refresh(existing_plan)
            return existing_plan

        # 创建新计划
        plan = WorkoutPlan(
            id=str(uuid.uuid4()),
            user_id=user_id,
            plan_date=plan_date,
            title=title,
            subtitle=subtitle,
            total_duration=total_duration,
            scene=scene,
            rpe=rpe,
            modules=modules,
            ai_note=ai_note,
            is_applied=is_applied,
        )

        self.db.add(plan)
        await self.db.commit()
        await self.db.refresh(plan)

        return plan

    async def get_plan_by_id(self, plan_id: str) -> WorkoutPlan | None:
        """根据ID获取计划"""
        result = await self.db.execute(
            select(WorkoutPlan).where(WorkoutPlan.id == plan_id)
        )
        return result.scalar_one_or_none()

    async def get_today_plan(self, user_id: str) -> WorkoutPlan | None:
        """获取今日计划（优先返回已应用的）"""
        # 先查询已应用的今日计划
        result = await self.db.execute(
            select(WorkoutPlan)
            .where(
                and_(
                    WorkoutPlan.user_id == user_id,
                    WorkoutPlan.plan_date == date.today(),
                    WorkoutPlan.is_applied == True
                )
            )
        )
        plan = result.scalar_one_or_none()
        if plan:
            return plan

        # 如果没有，返回最新的今日计划
        result = await self.db.execute(
            select(WorkoutPlan)
            .where(
                and_(
                    WorkoutPlan.user_id == user_id,
                    WorkoutPlan.plan_date == date.today()
                )
            )
            .order_by(desc(WorkoutPlan.created_at))
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def apply_plan(self, user_id: str, plan_id: str) -> WorkoutPlan | None:
        """
        应用计划到今日

        将指定计划标记为已应用，同时取消其他今日计划的已应用状态
        """
        # 获取计划
        result = await self.db.execute(
            select(WorkoutPlan).where(
                and_(
                    WorkoutPlan.id == plan_id,
                    WorkoutPlan.user_id == user_id
                )
            )
        )
        plan = result.scalar_one_or_none()

        if not plan:
            return None

        # 取消其他今日计划的已应用状态
        await self.db.execute(
            select(WorkoutPlan)
            .where(
                and_(
                    WorkoutPlan.user_id == user_id,
                    WorkoutPlan.plan_date == date.today(),
                    WorkoutPlan.id != plan_id,
                    WorkoutPlan.is_applied == True
                )
            )
        )

        # 标记当前计划为已应用
        plan.is_applied = True
        await self.db.commit()
        await self.db.refresh(plan)

        return plan

    async def get_plan_history(
        self,
        user_id: str,
        start_date: date | None = None,
        end_date: date | None = None,
        limit: int = 30
    ) -> List[WorkoutPlan]:
        """获取历史计划"""
        query = select(WorkoutPlan).where(WorkoutPlan.user_id == user_id)

        if start_date:
            query = query.where(WorkoutPlan.plan_date >= start_date)
        if end_date:
            query = query.where(WorkoutPlan.plan_date <= end_date)

        query = query.order_by(desc(WorkoutPlan.plan_date)).limit(limit)

        result = await self.db.execute(query)
        return result.scalars().all()

    async def complete_plan(self, plan_id: str, user_id: str) -> WorkoutPlan | None:
        """标记计划为已完成"""
        result = await self.db.execute(
            select(WorkoutPlan).where(
                and_(
                    WorkoutPlan.id == plan_id,
                    WorkoutPlan.user_id == user_id
                )
            )
        )
        plan = result.scalar_one_or_none()

        if plan:
            plan.is_completed = True
            await self.db.commit()
            await self.db.refresh(plan)

        return plan

    # ========== 训练记录（反馈）相关方法 ==========

    async def create_record(
        self,
        user_id: str,
        plan_id: str | None,
        record_date: date,
        duration: int,
        completion: str,
        feeling: str,
        tomorrow: str,
        pain_locations: list | None = None,
        completed: bool = True
    ) -> WorkoutRecord:
        """
        创建训练记录（反馈）

        Args:
            user_id: 用户ID
            plan_id: 计划ID（可选）
            record_date: 记录日期
            duration: 实际训练时长（分钟）
            completion: 完成度（too_hard/barely/smooth/easy）
            feeling: 感受（uncomfortable/tired/just_right/energized）
            tomorrow: 明天偏好（recovery/maintain/intensify）
            pain_locations: 疼痛部位列表
            completed: 是否已完成

        Returns:
            WorkoutRecord: 创建的记录
        """
        # 检查是否已存在该日期的记录
        result = await self.db.execute(
            select(WorkoutRecord).where(
                and_(
                    WorkoutRecord.user_id == user_id,
                    WorkoutRecord.record_date == record_date
                )
            )
        )
        existing = result.scalar_one_or_none()

        if existing:
            # 更新现有记录
            existing.plan_id = plan_id
            existing.duration = duration
            existing.completion = completion
            existing.feeling = feeling
            existing.tomorrow = tomorrow
            existing.pain_locations = pain_locations or []
            existing.completed = completed
            await self.db.commit()
            await self.db.refresh(existing)
            return existing

        # 创建新记录
        record = WorkoutRecord(
            id=str(uuid.uuid4()),
            user_id=user_id,
            plan_id=plan_id,
            record_date=record_date,
            duration=duration,
            completion=completion,
            feeling=feeling,
            tomorrow=tomorrow,
            pain_locations=pain_locations or [],
            completed=completed,
        )

        self.db.add(record)
        await self.db.commit()
        await self.db.refresh(record)

        # 更新关联计划的反馈ID
        if plan_id:
            result = await self.db.execute(
                select(WorkoutPlan).where(WorkoutPlan.id == plan_id)
            )
            plan = result.scalar_one_or_none()
            if plan:
                plan.feedback_id = record.id
                await self.db.commit()

        return record

    async def get_record_by_date(self, user_id: str, record_date: date) -> WorkoutRecord | None:
        """根据日期获取记录"""
        result = await self.db.execute(
            select(WorkoutRecord).where(
                and_(
                    WorkoutRecord.user_id == user_id,
                    WorkoutRecord.record_date == record_date
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_recent_records(
        self,
        user_id: str,
        days: int = 7
    ) -> List[WorkoutRecord]:
        """获取最近几天的记录"""
        start_date = date.today() - timedelta(days=days)

        result = await self.db.execute(
            select(WorkoutRecord)
            .where(
                and_(
                    WorkoutRecord.user_id == user_id,
                    WorkoutRecord.record_date >= start_date
                )
            )
            .order_by(desc(WorkoutRecord.record_date))
        )
        return result.scalars().all()

    async def get_yesterday_feedback(self, user_id: str) -> WorkoutRecord | None:
        """获取昨天的反馈"""
        yesterday = date.today() - timedelta(days=1)
        return await self.get_record_by_date(user_id, yesterday)
