"""TaskPlanner - 任务规划器

根据任务分析结果生成执行计划，包括拓扑排序和并行任务识别。
"""
import logging
from typing import Any

from app.agents.models import (
    Task,
    TaskType,
    TaskStatus,
    ExecutionPlan,
    TaskAnalysis
)

logger = logging.getLogger(__name__)


class TaskPlanner:
    """
    任务规划器 - 拆分子任务，确定执行顺序

    职责：
    1. 为每个子任务创建 Task 对象
    2. 拓扑排序确定执行顺序
    3. 识别可并行执行的任务
    """

    def __init__(self, agent_registry: dict[str, Any]):
        """
        初始化任务规划器

        Args:
            agent_registry: Agent 注册表 {agent_name: agent_instance}
        """
        self.agent_registry = agent_registry

    def plan(self, analysis: TaskAnalysis) -> ExecutionPlan:
        """
        生成执行计划

        Args:
            analysis: 任务分析结果

        Returns:
            ExecutionPlan: 执行计划
        """
        sub_tasks = analysis.get("sub_tasks", [])

        if not sub_tasks:
            # 没有子任务，返回空计划
            return ExecutionPlan(
                tasks=[],
                execution_order=[],
                requires_collaboration=False,
                parallel_groups=[]
            )

        # 1. 为每个子任务创建 Task 对象
        tasks = self._create_tasks(sub_tasks)

        # 2. 如果任务数量大于1，添加总结任务作为最后一个任务
        if len(tasks) > 1:
            summary_task = self._create_summary_task(tasks)
            tasks.append(summary_task)

        # 3. 拓扑排序确定执行顺序
        execution_order = self._topological_sort(tasks)

        # 4. 识别可并行执行的任务
        parallel_groups = self._find_parallel_groups(tasks, execution_order)

        # 5. 判断是否需要协作
        requires_collaboration = len(tasks) > 1

        logger.info(f"生成执行计划: {len(tasks)} 个任务, "
                   f"需要协作: {requires_collaboration}, "
                   f"并行组: {parallel_groups}")

        return ExecutionPlan(
            tasks=tasks,
            execution_order=execution_order,
            requires_collaboration=requires_collaboration,
            parallel_groups=parallel_groups
        )

    def _create_tasks(self, sub_tasks: list[dict]) -> list[Task]:
        """
        创建 Task 对象列表

        Args:
            sub_tasks: 子任务列表

        Returns:
            list[Task]: Task 对象列表
        """
        tasks = []
        task_id_counter = 0

        for sub_task in sub_tasks:
            task_type = sub_task.get("type", "chat")

            # 映射任务类型到 Agent
            agent_name = self._map_intent_to_agent(task_type)

            task = Task(
                id=f"task_{task_id_counter}",
                type=TaskType(task_type),
                description=sub_task.get("description", ""),
                agent_name=agent_name,
                input_data=sub_task.get("input_data", {}),
                depends_on=sub_task.get("depends_on", []),
                status=TaskStatus.PENDING,
                output_data=None,
                error=None
            )
            tasks.append(task)
            task_id_counter += 1

        return tasks

    def _create_summary_task(self, existing_tasks: list[Task]) -> Task:
        """
        创建总结任务

        当任务数量大于1时，添加一个总结任务作为最后一个任务，
        依赖所有其他任务。

        Args:
            existing_tasks: 已创建的任务列表

        Returns:
            Task: 总结任务对象
        """
        # 获取所有已有任务的ID作为依赖
        all_task_ids = [task["id"] for task in existing_tasks]

        summary_task = Task(
            id=f"task_{len(existing_tasks)}",
            type=TaskType.SUMMARY,
            description="总结所有子任务输出，生成连贯的整合回复",
            agent_name="summary_sub_agent",
            input_data={
                "depends_on_tasks": all_task_ids,
                "summary_type": "multi_task_aggregation"
            },
            depends_on=all_task_ids,  # 依赖所有其他任务
            status=TaskStatus.PENDING,
            output_data=None,
            error=None
        )

        logger.info(f"创建总结任务: {summary_task['id']}, 依赖: {all_task_ids}")
        return summary_task

    def _map_intent_to_agent(self, intent: str) -> str:
        """
        映射意图类型到 Agent 名称

        Args:
            intent: 意图类型

        Returns:
            str: Agent 名称
        """
        mapping = {
            "workout": "workout_sub_agent",
            "chat": "chat_sub_agent",
            "explanation": "chat_sub_agent",  # 解释使用 ChatSubAgent
            "feedback": "chat_sub_agent",     # 反馈使用 ChatSubAgent
            "analysis": "chat_sub_agent"
        }
        return mapping.get(intent, "chat_sub_agent")

    def _topological_sort(self, tasks: list[Task]) -> list[str]:
        """
        拓扑排序 - 确定任务执行顺序

        使用 Kahn 算法进行拓扑排序

        Args:
            tasks: 任务列表

        Returns:
            list[str]: 任务ID的执行顺序
        """
        # 构建依赖图
        task_map = {task["id"]: task for task in tasks}
        in_degree = {task["id"]: 0 for task in tasks}

        # 计算入度
        for task in tasks:
            for dep_id in task.get("depends_on", []):
                if dep_id in in_degree:
                    in_degree[task["id"]] += 1

        # 从入度为0的任务开始
        queue = [task_id for task_id, degree in in_degree.items() if degree == 0]
        result = []

        while queue:
            # 按优先级排序：workout > explanation > chat
            queue.sort(key=lambda x: self._get_priority(task_map[x]), reverse=True)

            current = queue.pop(0)
            result.append(current)

            # 更新依赖任务的入度
            for task in tasks:
                if current in task.get("depends_on", []):
                    in_degree[task["id"]] -= 1
                    if in_degree[task["id"]] == 0:
                        queue.append(task["id"])

        # 检查是否有环
        if len(result) != len(tasks):
            logger.warning("检测到任务依赖环，使用原始顺序")
            return [task["id"] for task in tasks]

        return result

    def _get_priority(self, task: Task) -> int:
        """获取任务优先级"""
        priority_map = {
            "workout": 3,
            "explanation": 2,
            "feedback": 2,
            "chat": 1,
            "analysis": 1
        }
        return priority_map.get(task.get("type", ""), 0)

    def _find_parallel_groups(
        self,
        tasks: list[Task],
        execution_order: list[str]
    ) -> list[list[str]]:
        """
        识别可并行执行的任务

        Args:
            tasks: 任务列表
            execution_order: 执行顺序

        Returns:
            list[list[str]]: 可并行执行的任务分组
        """
        if not tasks:
            return []

        task_map = {task["id"]: task for task in tasks}
        parallel_groups = []
        current_group = []

        # 维护当前已执行的任务集合
        executed = set()

        for task_id in execution_order:
            task = task_map[task_id]
            deps = task.get("depends_on", [])

            # 检查所有依赖是否已执行
            can_execute = all(dep in executed for dep in deps)

            if can_execute:
                # 检查是否可以与当前组并行
                can_parallel = True
                for other_id in current_group:
                    other_task = task_map[other_id]
                    # 如果有相互依赖，不能并行
                    if task_id in other_task.get("depends_on", []):
                        can_parallel = False
                        break
                    if other_id in task.get("depends_on", []):
                        can_parallel = False
                        break

                if can_parallel and current_group:
                    current_group.append(task_id)
                else:
                    if current_group:
                        parallel_groups.append(current_group)
                    current_group = [task_id]

                executed.add(task_id)
            else:
                # 有依赖未满足，加入等待
                if current_group:
                    parallel_groups.append(current_group)
                current_group = []

        # 添加最后一组
        if current_group:
            parallel_groups.append(current_group)

        return parallel_groups
