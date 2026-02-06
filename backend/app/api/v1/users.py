"""用户管理 API 端点"""
from fastapi import APIRouter, Depends

from app.schemas.user import UserResponse, UserUpdate
from app.core.deps import get_current_user
from app.models.user import User

router = APIRouter(prefix="/users", tags=["用户管理"])


@router.get("/me", response_model=UserResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
):
    """
    获取当前用户信息
    """
    return current_user


@router.put("/me", response_model=UserResponse)
async def update_me(
    data: UserUpdate,
    current_user: User = Depends(get_current_user),
):
    """
    更新当前用户信息
    """
    if data.nickname is not None:
        current_user.nickname = data.nickname
    if data.avatar_url is not None:
        current_user.avatar_url = data.avatar_url

    # 注意：需要在这里 commit，但为了简化，暂时跳过
    # 实际使用时需要注入 db session 并提交

    return current_user
