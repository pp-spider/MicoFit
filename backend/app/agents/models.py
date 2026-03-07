"""Planner Agent 数据模型定义

包含 Task, TaskStatus, TaskType, ExecutionPlan, TaskAnalysis 等数据模型。
"""
from typing import TypedDict, Literal, Any
from enum import Enum


class TaskStatus(str, Enum):
    """任务状态"""
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    WAITING_DEPENDENCY = "waiting_dependency"


class TaskType(str, Enum):
    """任务类型"""
    WORKOUT = "workout"
    CHAT = "chat"
    GENERAL_CHAT = "general_chat"  # 通用闲聊（非健身主题）
    FEEDBACK = "feedback"
    EXPLANATION = "explanation"
    ANALYSIS = "analysis"
    SUMMARY = "summary"  # 总结性智能体，用于总结多个子任务的输出


class ExecutionMode(str, Enum):
    """任务执行模式"""
    SERIAL = "serial"          # 纯串行执行
    PARALLEL = "parallel"      # 纯并行执行（按组）
    AUTO = "auto"              # 自动选择（默认）


class Task(TypedDict):
    """任务定义"""
    id: str
    type: TaskType
    description: str
    agent_name: str
    input_data: dict
    depends_on: list[str]
    status: TaskStatus
    output_data: dict | None
    error: str | None


class ExecutionPlan(TypedDict):
    """执行计划"""
    tasks: list[Task]
    execution_order: list[str]
    requires_collaboration: bool
    parallel_groups: list[list[str]]
    execution_mode: ExecutionMode | None  # 执行模式
    estimated_duration_ms: int | None     # 预估执行时间（毫秒）


class TaskAnalysis(TypedDict):
    """任务分析结果"""
    raw_intents: list[str]
    primary_intent: str
    requires_planning: bool
    complexity: Literal["simple", "medium", "complex"]
    extracted_entities: dict
    sub_tasks: list[dict]


class MultiIntentResult(TypedDict):
    """多意图识别结果"""
    intents: list[str]
    primary_intent: str
    complexity: Literal["simple", "medium", "complex"]
    entities: dict
    sub_tasks: list[dict]
    reasoning: str
    confidence: float


class AggregatedResult(TypedDict):
    """聚合后的结果"""
    type: str
    content: str
    plan: dict | None  # 单个计划（向后兼容）
    plans: list[dict] | None  # 多个计划（多计划场景）
    response_format: str
    tasks_output: dict
