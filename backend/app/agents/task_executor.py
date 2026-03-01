"""TaskExecutor - 任务执行器

按计划执行任务，协调 SubAgent，处理任务依赖。
"""
import logging
from typing import Any, AsyncGenerator

from app.agents.models import (
    Task,
    TaskStatus,
    ExecutionPlan
)
from app.agents.shared_context import SharedContextPool

logger = logging.getLogger(__name__)


class TaskExecutor:
    """
    任务执行器 - 按计划执行任务

    职责：
    1. 按执行顺序执行任务
    2. 处理任务依赖
    3. 调用对应的 SubAgent
    4. 管理共享上下文
    """

    def __init__(self, agent_registry: dict[str, Any]):
        """
        初始化任务执行器

        Args:
            agent_registry: Agent 注册表 {agent_name: agent_instance}
        """
        self.agent_registry = agent_registry

    async def execute(
        self,
        plan: ExecutionPlan,
        context: SharedContextPool,
        user_id: str,
        session_id: str,
        user_message: str,
        user_profile: dict | None = None,
        history: list[dict] | None = None,
        context_summary: str | None = None,
        recent_memories: list[str] | None = None
    ) -> list[Task]:
        """
        执行计划

        Args:
            plan: 执行计划
            context: 共享上下文
            user_id: 用户ID
            session_id: 会话ID
            user_message: 用户消息
            user_profile: 用户画像
            history: 历史消息
            context_summary: 会话摘要
            recent_memories: 跨会话记忆

        Returns:
            list[Task]: 执行完成的任务列表
        """
        tasks = plan.get("tasks", [])
        execution_order = plan.get("execution_order", [])

        if not execution_order:
            logger.warning("执行计划为空")
            return tasks

        # 维护任务映射
        task_map = {task["id"]: task for task in tasks}

        # 遍历执行顺序
        for task_id in execution_order:
            task = task_map.get(task_id)
            if not task:
                continue

            # 检查依赖是否完成
            deps = task.get("depends_on", [])
            for dep_id in deps:
                if dep_id in task_map:
                    dep_task = task_map[dep_id]
                    if dep_task.get("status") != TaskStatus.COMPLETED:
                        # 等待依赖完成
                        logger.info(f"任务 {task_id} 等待依赖 {dep_id}")

                        # 从上下文获取依赖结果
                        try:
                            await context.wait_task_complete(dep_id, timeout=30.0)
                        except TimeoutError:
                            logger.warning(f"等待依赖 {dep_id} 超时")

            # 执行任务
            updated_task = await self._execute_task(
                task=task,
                context=context,
                user_id=user_id,
                session_id=session_id,
                original_message=user_message,
                user_profile=user_profile,
                history=history,
                context_summary=context_summary,
                recent_memories=recent_memories
            )

            # 更新任务状态
            task_map[task_id] = updated_task

        # 返回所有任务
        return list(task_map.values())

    async def _execute_task(
        self,
        task: Task,
        context: SharedContextPool,
        user_id: str,
        session_id: str,
        original_message: str,
        user_profile: dict | None = None,
        history: list[dict] | None = None,
        context_summary: str | None = None,
        recent_memories: list[str] | None = None
    ) -> AsyncGenerator[dict, Task]:
        """
        执行单个任务，实时 yield chunks

        Args:
            task: 任务对象
            context: 共享上下文
            user_id: 用户ID
            session_id: 会话ID
            original_message: 原始用户消息
            user_profile: 用户画像
            history: 历史消息
            context_summary: 会话摘要
            recent_memories: 跨会话记忆

        Yields:
            dict: chunk 数据 (实时流式输出)
            Task: 任务完成后的最终 Task 对象（作为最后一个 yield）
        """
        task_id = task["id"]
        agent_name = task["agent_name"]
        task_type = task["type"]

        logger.info(f"开始执行任务: {task_id}, 类型: {task_type}, Agent: {agent_name}")

        # 更新状态为运行中
        task["status"] = TaskStatus.RUNNING

        try:
            # 获取对应的 Agent
            agent = self.agent_registry.get(agent_name)
            if not agent:
                raise ValueError(f"未找到 Agent: {agent_name}")

            # 准备输入数据
            input_data = task.get("input_data", {}).copy()

            # 根据任务类型准备状态
            # **workout_agent中未加入usermessage，只根据提前设置好的用户画像和训练部位进行推荐决策，个人感觉有失准确性
            if task_type == "workout":
                # 获取从意图提取的偏好
                extracted_preferences = input_data.get("extracted_preferences", {})

                state = {
                    "messages": [],
                    "user_id": user_id,
                    "user_profile": user_profile,
                    "extracted_preferences": extracted_preferences,
                    "workout_plan": None,
                    "plan_json_str": None,
                    "validation_passed": False,
                    "stream_chunks": [],
                    "error_message": None
                }

                # 执行并实时 yield 结果
                chunks = []
                plan = None

                async for chunk in agent.stream(state):
                    # 立即 yield 到前端，实现真正的实时流式输出
                    yield chunk

                    # 同时收集到本地用于最终返回
                    chunks.append(chunk)

                    if chunk.get("type") == "plan":
                        plan = chunk.get("plan")

                # 收集结果
                content_parts = [c.get("content", "") for c in chunks if c.get("type") == "chunk"]
                content = "".join(content_parts)

                task["output_data"] = {
                    "content": content,
                    "plan": plan,
                    "chunks": chunks
                }

                # 写入共享上下文
                if plan:
                    context.set_workout_plan(plan)

                context.set_task_result(task_id, task["output_data"])

                # 任务完成后 yield Task 对象
                yield task

            elif task_type == "explanation":
                # 解释任务需要依赖计划
                plan = context.get_workout_plan()

                state = {
                    "messages": [],
                    "user_id": user_id,
                    "session_id": session_id,
                    "user_profile": user_profile,
                    "user_message": self._build_explanation_message(original_message, plan),
                    "history": history,
                    "context_summary": context_summary,
                    "recent_memories": recent_memories,
                    "response": None,
                    "stream_chunks": [],
                    "error_message": None
                }

                # 执行并实时 yield 结果
                chunks = []
                explanation_content = ""

                async for chunk in agent.stream(state):
                    # 立即 yield 到前端
                    yield chunk

                    # 同时收集到本地
                    chunks.append(chunk)

                    if chunk.get("type") == "chunk":
                        explanation_content += chunk.get("content", "")

                task["output_data"] = {
                    "content": explanation_content,
                    "chunks": chunks
                }

                context.set_task_result(task_id, task["output_data"])

                # 任务完成后 yield Task 对象
                yield task

            elif task_type == "chat":
                # 普通对话
                state = {
                    "messages": [],
                    "user_id": user_id,
                    "session_id": session_id,
                    "user_profile": user_profile,
                    "user_message": original_message,
                    "history": history,
                    "context_summary": context_summary,
                    "recent_memories": recent_memories,
                    "response": None,
                    "stream_chunks": [],
                    "error_message": None
                }

                # 执行并实时 yield 结果
                chunks = []
                chat_content = ""

                async for chunk in agent.stream(state):
                    # 立即 yield 到前端
                    yield chunk

                    # 同时收集到本地
                    chunks.append(chunk)

                    if chunk.get("type") == "chunk":
                        chat_content += chunk.get("content", "")

                task["output_data"] = {
                    "content": chat_content,
                    "chunks": chunks
                }

                context.set_task_result(task_id, task["output_data"])

                # 任务完成后 yield Task 对象
                yield task

            else:
                # 其他类型任务，默认使用 chat
                logger.warning(f"未知任务类型: {task_type}")

            # 标记完成
            task["status"] = TaskStatus.COMPLETED
            logger.info(f"任务完成: {task_id}")

            # 任务完成后 yield Task 对象
            yield task

        except Exception as e:
            import traceback
            logger.error(f"任务执行失败: {task_id}, 错误: {e}")
            print(f"\n❌ 任务 {task_id} 执行出错:")
            traceback.print_exc()
            task["status"] = TaskStatus.FAILED
            task["error"] = str(e)

            # 异常时也 yield Task 对象
            yield task

    def _build_explanation_message(self, original_message: str, plan: dict | None) -> str:
        """
        构建解释任务的消息

        Args:
            original_message: 原始用户消息
            plan: 训练计划

        Returns:
            str: 解释请求消息
        """
        if not plan:
            return original_message + "（无计划可解释）"

        plan_summary = f"""
以下是训练计划：

**{plan.get('title', '训练计划')}**
- 总时长：{plan.get('total_duration', 0)} 分钟
- 场景：{plan.get('scene', '')}

动作列表：
"""

        modules = plan.get("modules", [])
        for module in modules:
            plan_summary += f"\n### {module.get('name', '模块')}\n"
            for ex in module.get("exercises", []):
                plan_summary += f"- {ex.get('name', '动作')}: {ex.get('description', '')}\n"

        plan_summary += "\n请解释这个计划中每个动作的要领和注意事项。"

        return plan_summary
