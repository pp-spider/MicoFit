"""用户画像 API 端点"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.profile import UserProfileResponse, UserProfileCreate, UserProfileUpdate
from app.services.user_service import UserService
from app.core.deps import get_current_user
from app.models.user import User

router = APIRouter(prefix="/profiles", tags=["用户画像"])


@router.get("/", response_model=UserProfileResponse)
async def get_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取当前用户的画像

    需要在 Header 中提供有效的 Access Token:
    ```
    Authorization: Bearer <access_token>
    ```
    """
    service = UserService(db)
    profile = await service.get_user_profile(current_user.id)

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户画像不存在，请先创建",
        )

    return profile


@router.post("/", response_model=UserProfileResponse, status_code=status.HTTP_201_CREATED)
async def create_profile(
    data: UserProfileCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    创建用户画像

    需要在 Header 中提供有效的 Access Token:
    ```
    Authorization: Bearer <access_token>
    ```
    """
    service = UserService(db)

    try:
        profile = await service.create_user_profile(current_user.id, data)
        return profile
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.put("/", response_model=UserProfileResponse)
async def update_profile(
    data: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    更新用户画像

    需要在 Header 中提供有效的 Access Token:
    ```
    Authorization: Bearer <access_token>
    ```
    """
    service = UserService(db)
    profile = await service.update_user_profile(current_user.id, data)

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户画像不存在",
        )

    return profile


@router.post("/upsert", response_model=UserProfileResponse)
async def upsert_profile(
    data: UserProfileCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    创建或更新用户画像（如果不存在则创建）

    需要在 Header 中提供有效的 Access Token:
    ```
    Authorization: Bearer <access_token>
    ```
    """
    service = UserService(db)
    profile = await service.upsert_user_profile(current_user.id, data)
    return profile
