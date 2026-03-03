"""用户画像 ORM 模型"""
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Numeric, Integer, DateTime, JSON, ForeignKey
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.orm import relationship

from app.db.base import Base


class UserProfile(Base):
    """用户画像表"""

    __tablename__ = "user_profiles"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False, index=True)

    # 基本信息
    nickname = Column(String(50), nullable=False)
    height = Column(Numeric(5, 2), nullable=False)  # cm
    weight = Column(Numeric(5, 2), nullable=False)  # kg
    bmi = Column(Numeric(4, 1), nullable=False)

    # 健身信息
    fitness_level = Column(String(20), nullable=False)  # beginner/occasional/regular
    scene = Column(String(20), nullable=False)  # bed/office/living/outdoor/hotel
    time_budget = Column(Integer, default=12, nullable=False)  # 分钟

    # 限制和装备
    limitations = Column(JSON, nullable=False, default=list)  # ["waist", "knee", ...]
    equipment = Column(String(20), nullable=False)  # none/mat/chair

    # 目标
    goal = Column(String(20), nullable=False)  # fat-loss/sedentary/strength/sleep
    weekly_days = Column(Integer, default=3, nullable=False)  # 2-7
    preferred_time = Column(JSON, nullable=False, default=list)  # ["morning", "noon", "evening"]

    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # 关联用户
    user = relationship("User", back_populates="profile")

    def __repr__(self):
        return f"<UserProfile(id={self.id}, user_id={self.user_id}, nickname={self.nickname})>"
