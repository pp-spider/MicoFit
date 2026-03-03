"""训练进度 ORM 模型"""
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, JSON
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.orm import relationship

from app.db.base import Base


class WorkoutProgress(Base):
    """训练进度表 - 存储用户训练过程中的实时进度"""

    __tablename__ = "workout_progress"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # 日期标识（格式: YYYY-MM-DD）
    date_key = Column(String(10), nullable=False, index=True)

    # 训练计划ID（关联 WorkoutPlan.id）
    plan_id = Column(CHAR(36), nullable=False)

    # 状态: not_started / in_progress / completed
    status = Column(String(20), nullable=False, default="not_started")

    # 当前模块索引
    current_module_index = Column(Integer, default=0, nullable=False)

    # 当前动作索引
    current_exercise_index = Column(Integer, default=0, nullable=False)

    # 总动作数
    total_exercises = Column(Integer, nullable=False)

    # 已完成的动作ID列表
    completed_exercise_ids = Column(JSON, nullable=False, default=list)

    # 开始时间
    start_time = Column(DateTime, nullable=False)

    # 最后更新时间
    last_update_time = Column(DateTime, nullable=False)

    # 实际训练时长（秒）
    actual_duration = Column(Integer, default=0, nullable=False)

    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # 关联
    user = relationship("User", back_populates="workout_progress")

    def __repr__(self):
        return f"<WorkoutProgress(id={self.id}, user_id={self.user_id}, date_key={self.date_key}, status={self.status})>"
