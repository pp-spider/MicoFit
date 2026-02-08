"""用户 ORM 模型"""
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Text
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.orm import relationship

from app.db.base import Base


class User(Base):
    """用户表"""

    __tablename__ = "users"

    # 使用 CHAR(36) 存储 UUID
    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    nickname = Column(String(50), nullable=False)
    avatar_url = Column(String(512), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    is_verified = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    last_login_at = Column(DateTime, nullable=True)

    # 关联用户画像
    profile = relationship("UserProfile", back_populates="user", uselist=False, cascade="all, delete-orphan")

    # 关联训练计划
    workout_plans = relationship("WorkoutPlan", back_populates="user", cascade="all, delete-orphan")

    # 关联训练记录
    workout_records = relationship("WorkoutRecord", back_populates="user", cascade="all, delete-orphan")

    # 关联聊天会话
    chat_sessions = relationship("ChatSession", back_populates="user", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<User(id={self.id}, email={self.email}, nickname={self.nickname})>"
