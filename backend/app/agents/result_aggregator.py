"""ResultAggregator - 结果聚合器

合并多任务结果，根据任务类型选择聚合策略。
"""
import logging
from typing import Any

from app.agents.models import Task, AggregatedResult, TaskStatus
from app.agents.shared_context import SharedContextPool

logger = logging.getLogger(__name__)


class ResultAggregator:
    """
    结果聚合器 - 合并多任务结果

    职责：
    1. 根据任务类型组合选择聚合策略
    2. 合并输出内容
    3. 返回统一格式的结果
    """

    def aggregate(
        self,
        tasks: list[Task],
        context: SharedContextPool
    ) -> AggregatedResult:
        """
        聚合多任务结果

        Args:
            tasks: 执行完成的任务列表
            context: 共享上下文

        Returns:
            AggregatedResult: 聚合后的结果
        """
        # 按执行顺序整理结果
        completed_tasks = [t for t in tasks if t.get("status") == TaskStatus.COMPLETED]
        results_by_type = {}

        for task in completed_tasks:
            task_type = task.get("type")
            output_data = task.get("output_data", {})
            results_by_type[task_type] = output_data

        logger.info(f"聚合结果，任务类型: {list(results_by_type.keys())}")

        # 根据任务组合选择聚合策略
        if "workout" in results_by_type and "explanation" in results_by_type:
            return self._aggregate_workout_with_explanation(results_by_type)
        elif "workout" in results_by_type and "chat" in results_by_type:
            return self._aggregate_workout_with_chat(results_by_type)
        elif "explanation" in results_by_type and "chat" in results_by_type:
            return self._aggregate_chat_with_explanation(results_by_type)
        elif "workout" in results_by_type:
            return self._aggregate_simple_workout(results_by_type)
        elif "explanation" in results_by_type:
            return self._aggregate_simple_explanation(results_by_type)
        else:
            return self._aggregate_simple_chat(results_by_type)

    def _aggregate_workout_with_explanation(self, results: dict) -> AggregatedResult:
        """
        聚合训练计划 + 解释

        格式：解释内容 + 分隔线 + 训练计划
        """
        workout_result = results.get("workout", {})
        explanation_result = results.get("explanation", {})

        workout_content = workout_result.get("content", "")
        explanation_content = explanation_result.get("content", "")
        plan = workout_result.get("plan")

        # 构建内容：解释在前，计划在后
        if explanation_content and plan:
            content = f"{explanation_content}\n\n---\n\n{workout_content}"
        elif explanation_content:
            content = explanation_content
        else:
            content = workout_content

        return AggregatedResult(
            type="workout_with_explanation",
            content=content,
            plan=plan,
            response_format="markdown_with_json",
            tasks_output=results
        )

    def _aggregate_workout_with_chat(self, results: dict) -> AggregatedResult:
        """
        聚合训练计划 + 对话

        格式：对话内容 + 分隔线 + 训练计划
        """
        workout_result = results.get("workout", {})
        chat_result = results.get("chat", {})

        workout_content = workout_result.get("content", "")
        chat_content = chat_result.get("content", "")
        plan = workout_result.get("plan")

        # 构建内容：对话在前，计划在后
        if chat_content and plan:
            content = f"{chat_content}\n\n---\n\n{workout_content}"
        elif chat_content:
            content = chat_content
        else:
            content = workout_content

        return AggregatedResult(
            type="workout_with_chat",
            content=content,
            plan=plan,
            response_format="markdown_with_json",
            tasks_output=results
        )

    def _aggregate_chat_with_explanation(self, results: dict) -> AggregatedResult:
        """
        聚合对话 + 解释

        简单合并内容
        """
        chat_result = results.get("chat", {})
        explanation_result = results.get("explanation", {})

        chat_content = chat_result.get("content", "")
        explanation_content = explanation_result.get("content", "")

        content = f"{chat_content}\n\n{explanation_content}"

        return AggregatedResult(
            type="chat_with_explanation",
            content=content,
            plan=None,
            response_format="markdown",
            tasks_output=results
        )

    def _aggregate_simple_workout(self, results: dict) -> AggregatedResult:
        """聚合单个训练计划任务"""
        workout_result = results.get("workout", {})

        content = workout_result.get("content", "")
        plan = workout_result.get("plan")

        return AggregatedResult(
            type="workout",
            content=content,
            plan=plan,
            response_format="markdown_with_json",
            tasks_output=results
        )

    def _aggregate_simple_explanation(self, results: dict) -> AggregatedResult:
        """聚合单个解释任务"""
        explanation_result = results.get("explanation", {})

        content = explanation_result.get("content", "")

        return AggregatedResult(
            type="explanation",
            content=content,
            plan=None,
            response_format="markdown",
            tasks_output=results
        )

    def _aggregate_simple_chat(self, results: dict) -> AggregatedResult:
        """聚合单个对话任务"""
        # 尝试获取任一任务的结果
        for task_type, task_result in results.items():
            content = task_result.get("content", "")
            if content:
                return AggregatedResult(
                    type="chat",
                    content=content,
                    plan=None,
                    response_format="markdown",
                    tasks_output=results
                )

        # 没有结果
        return AggregatedResult(
            type="empty",
            content="处理完成",
            plan=None,
            response_format="text",
            tasks_output=results
        )
