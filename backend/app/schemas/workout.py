"""训练计划 Schema"""
from datetime import date
from pydantic import BaseModel, Field
from typing import List, Optional


class ExerciseSchema(BaseModel):
    """动作 Schema"""
    id: str
    name: str
    duration: int = Field(..., description="时长（秒）")
    description: Optional[str] = ""
    steps: List[str]
    tips: str
    breathing: Optional[str] = ""
    image: Optional[str] = ""
    target_muscles: Optional[List[str]] = []

    model_config = {"from_attributes": True}


class WorkoutModuleSchema(BaseModel):
    """训练模块 Schema"""
    id: str
    name: str
    duration: int = Field(..., description="时长（分钟）")
    exercises: List[ExerciseSchema]

    model_config = {"from_attributes": True}


class WorkoutPlanSchema(BaseModel):
    """训练计划 Schema"""
    id: str
    title: str
    subtitle: Optional[str] = None
    total_duration: int = Field(..., description="总时长（分钟）")
    scene: str
    rpe: int = Field(..., description="运动强度 1-10")
    ai_note: Optional[str] = None
    modules: List[WorkoutModuleSchema]
    is_completed: bool = False
    is_applied: bool = False
    plan_date: date

    model_config = {"from_attributes": True}


class WorkoutPlanCreateRequest(BaseModel):
    """创建训练计划请求"""
    preferences: Optional[dict] = Field(default=None, description="额外偏好设置")


class WorkoutPlanApplyRequest(BaseModel):
    """应用训练计划请求"""
    plan_id: str


class WorkoutPlanResponse(BaseModel):
    """训练计划响应"""
    success: bool
    plan: Optional[WorkoutPlanSchema] = None
    plan_id: Optional[str] = None
    error: Optional[str] = None


# ========== 反馈相关 Schema ==========

class WorkoutFeedbackRequest(BaseModel):
    """训练反馈请求"""
    plan_id: Optional[str] = Field(default=None, description="关联的计划ID")
    duration: int = Field(default=0, description="实际训练时长（分钟）")
    completion: str = Field(..., description="完成度：too_hard/barely/smooth/easy")
    feeling: str = Field(..., description="感受：uncomfortable/tired/just_right/energized")
    tomorrow: str = Field(..., description="明天偏好：recovery/maintain/intensify")
    pain_locations: Optional[List[str]] = Field(default=[], description="疼痛部位")
    completed: bool = Field(default=True, description="是否已完成训练")


class WorkoutFeedbackResponse(BaseModel):
    """训练反馈响应"""
    success: bool
    record_id: Optional[str] = None
    message: Optional[str] = None


class AdjustmentSuggestionResponse(BaseModel):
    """调整建议响应"""
    success: bool
    suggestion: Optional[str] = None
    adjusted_params: Optional[dict] = None
    error: Optional[str] = None
