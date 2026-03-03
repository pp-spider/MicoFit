"""用户服务"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.user_profile import UserProfile
from app.schemas.profile import UserProfileCreate, UserProfileUpdate


class UserService:
    """用户服务"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_user_profile(self, user_id: str) -> UserProfile | None:
        """
        获取用户画像

        Args:
            user_id: 用户 ID

        Returns:
            用户画像对象，如果不存在返回 None
        """
        result = await self.db.execute(
            select(UserProfile).where(UserProfile.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def create_user_profile(
        self,
        user_id: str,
        data: UserProfileCreate,
    ) -> UserProfile:
        """
        创建用户画像

        Args:
            user_id: 用户 ID
            data: 画像创建请求

        Returns:
            创建的用户画像

        Raises:
            ValueError: 用户画像已存在
        """
        # 检查是否已存在画像
        existing = await self.get_user_profile(user_id)
        if existing:
            raise ValueError("用户画像已存在")

        profile = UserProfile(
            user_id=user_id,
            **data.model_dump(),
        )

        self.db.add(profile)
        await self.db.commit()
        await self.db.refresh(profile)

        return profile

    async def update_user_profile(
        self,
        user_id: str,
        data: UserProfileUpdate,
    ) -> UserProfile | None:
        """
        更新用户画像

        Args:
            user_id: 用户 ID
            data: 画像更新请求

        Returns:
            更新后的用户画像，如果不存在返回 None
        """
        profile = await self.get_user_profile(user_id)
        if not profile:
            return None

        # 更新非空字段
        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(profile, field, value)

        await self.db.commit()
        await self.db.refresh(profile)

        return profile

    async def upsert_user_profile(
        self,
        user_id: str,
        data: UserProfileCreate,
    ) -> UserProfile:
        """
        创建或更新用户画像

        Args:
            user_id: 用户 ID
            data: 画像数据

        Returns:
            用户画像对象
        """
        profile = await self.get_user_profile(user_id)

        if profile:
            # 更新现有画像
            update_data = data.model_dump()
            for field, value in update_data.items():
                setattr(profile, field, value)
            await self.db.commit()
            await self.db.refresh(profile)
            return profile
        else:
            # 创建新画像
            return await self.create_user_profile(user_id, data)
