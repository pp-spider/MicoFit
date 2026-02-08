"""训练计划 ORM 模型"""
import uuid
from datetime import datetime, date
from sqlalchemy import Column, String, Integer, DateTime, Date, Boolean, ForeignKey, Text
from sqlalchemy.dialects.mysql import CHAR, JSON
from sqlalchemy.orm import relationship

from app.db.base import Base


class WorkoutPlan(Base):
    """训练计划表"""

    __tablename__ = "workout_plans"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # 计划日期（每天一个计划）
    plan_date = Column(Date, nullable=False)

    # 计划基本信息
    title = Column(String(100), nullable=False)
    subtitle = Column(String(200), nullable=True)
    total_duration = Column(Integer, nullable=False)  # 总时长（分钟）
    scene = Column(String(20), nullable=False)  # 场景：bed/office/living/outdoor/hotel
    rpe = Column(Integer, nullable=False)  # 运动强度 1-10
    ai_note = Column(Text, nullable=True)  # AI备注

    # 模块详情（包含动作）
    modules = Column(JSON, nullable=False)

    # 完成状态
    is_completed = Column(Boolean, default=False)
    is_applied = Column(Boolean, default=False)  # 是否已应用到今日

    # 关联反馈
    feedback_id = Column(CHAR(36), ForeignKey("workout_records.id", ondelete="SET NULL"), nullable=True)

    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # 关联
    user = relationship("User", back_populates="workout_plans")
    feedback = relationship("WorkoutRecord", back_populates="plan", foreign_keys="WorkoutRecord.plan_id")

    def __repr__(self):
        return f"<WorkoutPlan(id={self.id}, user_id={self.user_id}, date={self.plan_date}, title={self.title})>"


class WorkoutRecord(Base):
    """训练记录表（用户反馈）"""

    __tablename__ = "workout_records"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    plan_id = Column(CHAR(36), ForeignKey("workout_plans.id", ondelete="SET NULL"), nullable=True)

    # 记录日期
    record_date = Column(Date, nullable=False)

    # 实际训练时长（分钟）
    duration = Column(Integer, nullable=False, default=0)

    # 完成度：too_hard/barely/smooth/easy
    completion = Column(String(20), nullable=False)

    # 感受：uncomfortable/tired/just_right/energized
    feeling = Column(String(20), nullable=False)

    # 明天偏好：recovery/maintain/intensify
    tomorrow = Column(String(20), nullable=False)

    # 疼痛部位 ["knee", "waist", ...]
    pain_locations = Column(JSON, nullable=True, default=list)

    # 是否已完成训练
    completed = Column(Boolean, default=True)

    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # 关联
    user = relationship("User", back_populates="workout_records")
    plan = relationship("WorkoutPlan", back_populates="feedback", foreign_keys=[plan_id])

    def __repr__(self):
        return f"<WorkoutRecord(id={self.id}, user_id={self.user_id}, date={self.record_date}, completion={self.completion})>"
