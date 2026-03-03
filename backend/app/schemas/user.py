"""用户相关的 Pydantic Schemas"""
from datetime import datetime
from pydantic import BaseModel, EmailStr


class UserResponse(BaseModel):
    """用户响应"""
    id: str
    email: EmailStr
    nickname: str
    avatar_url: str | None = None
    is_active: bool
    is_verified: bool
    created_at: datetime
    last_login_at: datetime | None = None

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    """用户更新请求"""
    nickname: str | None = None
    avatar_url: str | None = None
