"""认证 API 端点"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse, RefreshTokenRequest
from app.services.auth_service import AuthService
from app.core.deps import get_current_user
from app.models.user import User

router = APIRouter(prefix="/auth", tags=["认证"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    data: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    用户注册

    - **email**: 邮箱地址
    - **password**: 密码（至少 6 位）
    - **nickname**: 昵称
    """
    service = AuthService(db)

    try:
        user = await service.register(data)
        return service.create_tokens(user)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post("/login", response_model=TokenResponse)
async def login(
    data: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    用户登录

    - **email**: 邮箱地址
    - **password**: 密码
    """
    service = AuthService(db)

    try:
        user = await service.login(data)
        return service.create_tokens(user)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    刷新访问令牌

    - **refresh_token**: 刷新令牌
    """
    service = AuthService(db)

    try:
        return await service.refresh_tokens(data.refresh_token)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )


@router.post("/logout")
async def logout(current_user: User = Depends(get_current_user)):
    """
    用户登出

    注意：当前实现为无状态登出，前端需删除本地存储的 Token。
    生产环境可考虑将 Refresh Token 加入黑名单。
    """
    return {"message": "登出成功"}


@router.get("/me")
async def get_current_user_info(
    current_user: User = Depends(get_current_user),
):
    """
    获取当前用户信息

    需要在 Header 中提供有效的 Access Token:
    ```
    Authorization: Bearer <access_token>
    ```
    """
    return {
        "id": current_user.id,
        "email": current_user.email,
        "nickname": current_user.nickname,
        "avatar_url": current_user.avatar_url,
        "is_active": current_user.is_active,
        "is_verified": current_user.is_verified,
        "created_at": current_user.created_at,
        "last_login_at": current_user.last_login_at,
    }
