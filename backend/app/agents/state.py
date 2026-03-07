"""LangGraph Agent状态定义"""
from typing import TypedDict, Annotated, Sequence, Any
from langchain_core.messages import BaseMessage
import operator


class ChatSubAgentState(TypedDict):
    """
    ChatSubAgent 状态 - 专注于普通对话

    从 RouterState 派生，只包含对话所需的最小状态
    """
    messages: Annotated[Sequence[BaseMessage], operator.add]
    user_id: str
    session_id: str
    user_profile: dict | None
    user_message: str
    history: list[dict] | None
    context_summary: str | None
    recent_memories: list[str] | None

    # 输出
    response: str | None
    stream_chunks: list[str]
    error_message: str | None


class WorkoutSubAgentState(TypedDict):
    """
    WorkoutSubAgent 状态 - 专注于训练计划生成

    从 WorkoutAgentState 继承并扩展
    """
    messages: Annotated[Sequence[BaseMessage], operator.add]
    user_id: str
    session_id: str | None                     # 会话ID，用于关联历史
    user_profile: dict | None

    # 从用户消息中提取的额外偏好
    extracted_preferences: dict | None         # 如用户说"练腿"，提取 focus: "legs"

    # 历史上下文（用于记住用户之前的偏好和调整需求）
    history: list[dict] | None                 # 历史消息
    context_summary: str | None                # 会话摘要
    recent_memories: list[str] | None          # 跨会话记忆

    # 计划生成相关
    workout_plan: dict | None
    plan_json_str: str | None
    validation_passed: bool

    # 输出
    stream_chunks: list[str]
    error_message: str | None

# RouterAgent + SubAgent 架构新状态定义
class RouterState(TypedDict):
    """
    RouterAgent 状态定义 - 作为整个工作流的中央状态

    包含：
    - 原始输入信息
    - 意图识别结果
    - 路由决策
    - SubAgent 执行结果
    - 流式输出缓存
    """
    # ========== 输入信息 ==========
    messages: Annotated[Sequence[BaseMessage], operator.add]
    user_id: str
    session_id: str
    user_profile: dict | None
    user_message: str                          # 当前用户消息
    history: list[dict] | None                 # 历史消息
    context_summary: str | None                # 会话摘要
    recent_memories: list[str] | None          # 跨会话记忆

    # ========== 意图识别结果 ==========
    intent: str | None                         # "chat" | "workout" | "unknown"
    intent_confidence: float                   # 意图置信度 (0-1)
    intent_reasoning: str | None               # LLM 的推理过程
    entities: dict | None                      # 提取的实体（如部位、场景等）

    # ========== 路由决策 ==========
    route_to: str | None                       # "chat_sub_agent" | "workout_sub_agent"

    # ========== SubAgent 执行结果 ==========
    sub_agent_result: dict | None              # SubAgent 返回的完整结果
    stream_chunks: list[str]                   # 流式输出块
    final_response: str | None                 # 最终响应内容

    # ========== 错误处理 ==========
    error_message: str | None
    should_retry: bool


# Planner Agent 状态定义
class PlannerState(TypedDict):
    """
    PlannerAgent 状态 - Planner 架构全局状态

    包含：
    - 用户信息
    - 任务分析结果
    - 执行计划
    - 任务执行结果
    - 共享上下文
    """
    # 用户信息
    user_id: str
    session_id: str
    user_message: str
    user_profile: dict | None
    history: list[dict] | None
    context_summary: str | None
    recent_memories: list[str] | None

    # 任务分析
    task_analysis: dict | None

    # 执行计划
    execution_plan: dict | None

    # 执行结果
    tasks: list[dict]
    shared_context: dict

    # 输出
    final_response: str | None
    error_message: str | None
