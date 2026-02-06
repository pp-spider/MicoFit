"""用户画像相关的 Pydantic Schemas"""
from datetime import datetime
from pydantic import BaseModel, Field
from typing import List


class UserProfileResponse(BaseModel):
    """用户画像响应"""
    id: str
    user_id: str
    nickname: str
    height: float
    weight: float
    bmi: float
    fitness_level: str
    scene: str
    time_budget: int
    limitations: List[str]
    equipment: str
    goal: str
    weekly_days: int
    preferred_time: List[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UserProfileCreate(BaseModel):
    """用户画像创建请求"""
    nickname: str = Field(..., min_length=1, max_length=50)
    height: float = Field(..., gt=0, lt=300)
    weight: float = Field(..., gt=0, lt=500)
    bmi: float = Field(..., gt=0, lt=100)
    fitness_level: str = Field(..., pattern="^(beginner|occasional|regular)$")
    scene: str = Field(..., pattern="^(bed|office|living|outdoor|hotel)$")
    time_budget: int = Field(default=12, ge=3, le=60)
    limitations: List[str] = Field(default_factory=list)
    equipment: str = Field(..., pattern="^(none|mat|chair)$")
    goal: str = Field(..., pattern="^(fat-loss|sedentary|strength|sleep)$")
    weekly_days: int = Field(default=3, ge=1, le=7)
    preferred_time: List[str] = Field(default_factory=lambda: ["morning"])


class UserProfileUpdate(BaseModel):
    """用户画像更新请求"""
    nickname: str | None = None
    height: float | None = None
    weight: float | None = None
    bmi: float | None = None
    fitness_level: str | None = None
    scene: str | None = None
    time_budget: int | None = None
    limitations: List[str] | None = None
    equipment: str | None = None
    goal: str | None = None
    weekly_days: int | None = None
    preferred_time: List[str] | None = None
