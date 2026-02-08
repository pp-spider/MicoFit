"""聊天 Schema"""
from datetime import datetime
from pydantic import BaseModel, Field
from typing import List, Optional


class ChatMessageSchema(BaseModel):
    """聊天消息 Schema"""
    id: str
    role: str = Field(..., description="角色：user/assistant/system/tool")
    content: str
    structured_data: Optional[dict] = None
    data_type: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ChatSessionSchema(BaseModel):
    """聊天会话 Schema"""
    id: str
    title: Optional[str] = None
    message_count: int = 0
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ChatStreamRequest(BaseModel):
    """流式聊天请求"""
    session_id: Optional[str] = Field(default=None, description="会话ID，为空则创建新会话")
    message: str = Field(..., description="用户消息")


class ChatStreamChunk(BaseModel):
    """流式聊天响应块"""
    type: str = Field(..., description="类型：chunk/plan/done/error/session_created/saved")
    content: Optional[str] = None
    plan: Optional[dict] = None
    session_id: Optional[str] = None
    plan_id: Optional[str] = None
    has_plan: Optional[bool] = None
    message: Optional[str] = None


class ChatSessionCreateRequest(BaseModel):
    """创建会话请求"""
    title: Optional[str] = None


class ChatSessionRenameRequest(BaseModel):
    """重命名会话请求"""
    title: str


class ChatHistoryResponse(BaseModel):
    """聊天历史响应"""
    session: ChatSessionSchema
    messages: List[ChatMessageSchema]


class ChatSessionsResponse(BaseModel):
    """会话列表响应"""
    sessions: List[ChatSessionSchema]
    total: int
