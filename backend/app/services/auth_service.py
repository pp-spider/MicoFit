"""认证服务"""
from datetime import datetime
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.models.user import User
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse
from app.core.config import settings


class AuthService:
    """认证服务"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def register(self, data: RegisterRequest) -> User:
        """
        注册新用户

        Args:
            data: 注册请求

        Returns:
            创建的用户

        Raises:
            ValueError: 邮箱已被注册
        """
        # 检查邮箱是否已存在
        result = await self.db.execute(
            select(User).where(User.email == data.email)
        )
        if result.scalar_one_or_none():
            raise ValueError("邮箱已被注册")

        # 创建新用户
        user = User(
            email=data.email,
            hashed_password=get_password_hash(data.password),
            nickname=data.nickname,
            is_active=True,
            is_verified=False,
        )

        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)

        return user

    async def login(self, data: LoginRequest) -> User:
        """
        用户登录

        Args:
            data: 登录请求

        Returns:
            登录的用户

        Raises:
            ValueError: 邮箱或密码错误
        """
        # 查找用户
        result = await self.db.execute(
            select(User).where(User.email == data.email)
        )
        user = result.scalar_one_or_none()

        if not user or not verify_password(data.password, user.hashed_password):
            raise ValueError("邮箱或密码错误")

        if not user.is_active:
            raise ValueError("用户已被禁用")

        # 更新最后登录时间
        user.last_login_at = datetime.utcnow()
        await self.db.commit()

        return user

    def create_tokens(self, user: User) -> TokenResponse:
        """
        创建访问令牌和刷新令牌

        Args:
            user: 用户对象

        Returns:
            Token 响应
        """
        # 创建 access token
        access_token = create_access_token(
            data={"sub": user.id, "email": user.email}
        )

        # 创建 refresh token
        refresh_token = create_refresh_token(
            data={"sub": user.id, "jti": user.id}
        )

        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            refresh_token_expires_in=settings.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60,
        )

    async def refresh_tokens(self, refresh_token: str) -> TokenResponse:
        """
        刷新令牌

        Args:
            refresh_token: 刷新令牌

        Returns:
            新的 Token 响应

        Raises:
            ValueError: 无效的刷新令牌
        """
        payload = decode_token(refresh_token)

        if payload is None:
            raise ValueError("无效的刷新令牌")

        if payload.get("type") != "refresh":
            raise ValueError("令牌类型错误")

        user_id = payload.get("sub")

        # 验证用户是否存在
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()

        if not user or not user.is_active:
            raise ValueError("用户不存在或已被禁用")

        return self.create_tokens(user)
