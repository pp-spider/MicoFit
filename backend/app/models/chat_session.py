"""聊天会话 ORM 模型"""
import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey, Text, Integer
from sqlalchemy.dialects.mysql import CHAR, JSON
from sqlalchemy.orm import relationship

from app.db.base import Base


class ChatSession(Base):
    """聊天会话表"""

    __tablename__ = "chat_sessions"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # 会话标题（自动生成或用户设置）
    title = Column(String(100), nullable=True)

    # 会话上下文摘要（用于快速了解会话内容）
    context_summary = Column(Text, nullable=True)

    # 消息数量
    message_count = Column(Integer, default=0)

    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # 关联
    user = relationship("User", back_populates="chat_sessions")
    messages = relationship("ChatMessage", back_populates="session", cascade="all, delete-orphan", order_by="ChatMessage.created_at")
    generated_plans = relationship("ChatGeneratedPlan", back_populates="session", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<ChatSession(id={self.id}, user_id={self.user_id}, title={self.title})>"


class ChatMessage(Base):
    """聊天消息表"""

    __tablename__ = "chat_messages"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = Column(CHAR(36), ForeignKey("chat_sessions.id", ondelete="CASCADE"), nullable=False, index=True)

    # 角色：user/assistant/system/tool
    role = Column(String(20), nullable=False)

    # 消息内容
    content = Column(Text, nullable=False)

    # 结构化数据（如健身计划JSON）
    structured_data = Column(JSON, nullable=True)

    # 数据类型：workout_plan/text/tool_call/tool_result
    data_type = Column(String(50), nullable=True)

    # 工具调用信息
    tool_calls = Column(JSON, nullable=True)

    # 工具调用ID（用于关联工具调用和结果）
    tool_call_id = Column(String(100), nullable=True)

    # Agent 执行输出（用于多 Agent 场景）
    agent_outputs = Column(JSON, nullable=True)

    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # 关联
    session = relationship("ChatSession", back_populates="messages")
    generated_plans = relationship("ChatGeneratedPlan", back_populates="message", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<ChatMessage(id={self.id}, session_id={self.session_id}, role={self.role})>"


class ChatGeneratedPlan(Base):
    """聊天会话中生成的训练计划表"""

    __tablename__ = "chat_generated_plans"

    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    session_id = Column(CHAR(36), ForeignKey("chat_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    message_id = Column(CHAR(36), ForeignKey("chat_messages.id", ondelete="SET NULL"), nullable=True)

    plan_id = Column(String(50), nullable=False)  # 前端生成的计划ID
    title = Column(String(100), nullable=False)
    subtitle = Column(String(200), nullable=True)
    total_duration = Column(Integer, nullable=False)
    scene = Column(String(20), nullable=False)
    rpe = Column(Integer, nullable=False)
    ai_note = Column(Text, nullable=True)
    modules = Column(JSON, nullable=False)

    response_status = Column(String(20), default="pending")  # pending/confirmed/rejected
    applied_plan_id = Column(CHAR(36), ForeignKey("workout_plans.id", ondelete="SET NULL"), nullable=True)

    generated_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    responded_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # 关联
    user = relationship("User", back_populates="generated_plans")
    session = relationship("ChatSession", back_populates="generated_plans")
    message = relationship("ChatMessage", back_populates="generated_plans")
    applied_plan = relationship("WorkoutPlan")

    def __repr__(self):
        return f"<ChatGeneratedPlan(id={self.id}, plan_id={self.plan_id}, session_id={self.session_id}, status={self.response_status})>"
