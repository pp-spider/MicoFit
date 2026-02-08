"""LangGraph Agent状态定义"""
from typing import TypedDict, Annotated, Sequence, Any
from langchain_core.messages import BaseMessage
import operator


class WorkoutAgentState(TypedDict):
    """训练计划生成Agent状态"""
    messages: Annotated[Sequence[BaseMessage], operator.add]
    user_id: str
    user_profile: dict | None
    workout_plan: dict | None
    plan_json_str: str | None
    validation_passed: bool
    error_message: str | None
    stream_chunks: list[str]


class ChatAgentState(TypedDict):
    """聊天Agent状态"""
    messages: Annotated[Sequence[BaseMessage], operator.add]
    user_id: str
    session_id: str
    user_profile: dict | None
    stream_chunks: list[str]
    has_workout_plan: bool
    workout_plan: dict | None
    error_message: str | None


class FeedbackAgentState(TypedDict):
    """反馈处理Agent状态"""
    user_id: str
    user_profile: dict | None
    feedback: dict | None
    last_workout: dict | None
    adjustment_suggestion: str | None
    next_plan_params: dict | None
