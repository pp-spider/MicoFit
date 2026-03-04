"""TaskExecutor - 任务执行器

按计划执行任务，协调 SubAgent，处理任务依赖。
支持串行和并行两种执行模式。
"""
import asyncio
import logging
from typing import Any, AsyncGenerator

from app.agents.models import (
    Task,
    TaskStatus,
    ExecutionPlan,
    ExecutionMode
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

    async def execute_parallel(
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
    ) -> AsyncGenerator[dict, None]:
        """
        并行执行任务（支持实时流式输出）

        按照 parallel_groups 分批执行，同批次内并行执行，批次间串行执行。
        使用多路复用机制实现并行任务的实时流式输出。

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

        Yields:
            dict: 流式响应块
            - {"type": "batch_start", "batch_index": int, "tasks": [...]}
            - {"type": "batch_complete", "batch_index": int}
            - {"type": "task_started", "task_id": str}
            - {"type": "task_completed", "task_id": str}
            - {"type": "task_error", "task_id": str, "error": str}
            - 各任务产生的 chunks（带 task_id 标记）
        """
        tasks = plan.get("tasks", [])
        parallel_groups = plan.get("parallel_groups", [])

        if not parallel_groups:
            logger.warning("没有并行组信息，回退到串行执行")
            completed_tasks = await self.execute(
                plan=plan,
                context=context,
                user_id=user_id,
                session_id=session_id,
                user_message=user_message,
                user_profile=user_profile,
                history=history,
                context_summary=context_summary,
                recent_memories=recent_memories
            )
            # 串行执行后，yield 所有任务的 chunks
            for task in completed_tasks:
                output_data = task.get("output_data", {})
                for chunk in output_data.get("chunks", []):
                    yield chunk
            return

        task_map = {task["id"]: task for task in tasks}

        # 按批次执行
        for batch_idx, batch_task_ids in enumerate(parallel_groups):
            # 通知批次开始
            yield {
                "type": "batch_start",
                "batch_index": batch_idx,
                "total_batches": len(parallel_groups),
                "tasks": batch_task_ids
            }

            # 获取本批次需要执行的任务
            tasks_in_batch = [
                task_map[tid] for tid in batch_task_ids
                if tid in task_map
            ]

            if not tasks_in_batch:
                logger.warning(f"批次 {batch_idx} 没有有效任务")
                continue

            batch_task_ids_set = {t["id"] for t in tasks_in_batch}
            logger.info(f"批次 {batch_idx}: 并行流式执行 {len(tasks_in_batch)} 个任务: {list(batch_task_ids_set)}")

            # 使用队列进行多路复用
            output_queue: asyncio.Queue[dict] = asyncio.Queue()
            completed_events = {t["id"]: asyncio.Event() for t in tasks_in_batch}

            async def task_wrapper(task: Task):
                """包装任务执行，将输出放入队列"""
                task_id = task["id"]
                agent_name = task.get("agent_name")

                # 通知任务开始
                await output_queue.put({
                    "type": "task_started",
                    "task_id": task_id,
                    "task_type": task.get("type"),
                    "agent_name": agent_name
                })

                try:
                    async for chunk in self._execute_task(
                        task=task,
                        context=context,
                        user_id=user_id,
                        session_id=session_id,
                        original_message=user_message,
                        user_profile=user_profile,
                        history=history,
                        context_summary=context_summary,
                        recent_memories=recent_memories
                    ):
                        # 过滤掉 Task 对象，只收集 dict chunks
                        if isinstance(chunk, dict):
                            if isinstance(chunk.get("output_data"), dict):
                                # 这是最终的 Task 对象
                                continue
                            # 添加任务ID和agent信息并放入队列
                            chunk_with_id = chunk.copy()
                            chunk_with_id["task_id"] = task_id
                            chunk_with_id["agent"] = agent_name
                            await output_queue.put(chunk_with_id)

                    # 通知任务完成
                    await output_queue.put({
                        "type": "task_completed",
                        "task_id": task_id
                    })
                    task["status"] = TaskStatus.COMPLETED

                except Exception as e:
                    logger.error(f"任务 {task_id} 执行失败: {e}")
                    task["status"] = TaskStatus.FAILED
                    task["error"] = str(e)
                    await output_queue.put({
                        "type": "task_error",
                        "task_id": task_id,
                        "error": str(e)
                    })
                finally:
                    completed_events[task_id].set()

            # 启动所有任务
            bg_tasks = [asyncio.create_task(task_wrapper(t)) for t in tasks_in_batch]

            # 等待所有任务完成，同时转发队列中的输出
            remaining_tasks = set(batch_task_ids_set)
            timeout_per_task = 60.0
            total_timeout = len(tasks_in_batch) * timeout_per_task
            start_time = asyncio.get_event_loop().time()

            while remaining_tasks:
                # 检查总超时
                elapsed = asyncio.get_event_loop().time() - start_time
                if elapsed > total_timeout:
                    logger.error(f"批次 {batch_idx} 执行超时")
                    break

                # 检查哪些任务已完成
                done_tasks = {tid for tid in remaining_tasks if completed_events[tid].is_set()}
                remaining_tasks -= done_tasks

                if remaining_tasks:
                    # 还有任务在运行，尝试获取输出（带短超时）
                    try:
                        chunk = await asyncio.wait_for(output_queue.get(), timeout=0.05)
                        yield chunk
                    except asyncio.TimeoutError:
                        continue
                else:
                    # 所有任务已完成，清空队列
                    while not output_queue.empty():
                        chunk = output_queue.get_nowait()
                        yield chunk

            # 取消任何可能还在运行的任务
            for bg_task in bg_tasks:
                if not bg_task.done():
                    bg_task.cancel()
                    try:
                        await bg_task
                    except asyncio.CancelledError:
                        pass

            # 通知批次完成
            yield {
                "type": "batch_complete",
                "batch_index": batch_idx,
                "completed_tasks": batch_task_ids
            }

            logger.info(f"批次 {batch_idx} 执行完成")

    async def _execute_single_task(
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
    ) -> dict:
        """
        执行单个任务并收集所有输出

        与 _execute_task 的区别：此方法收集所有流式输出后返回完整结果，
        而不是实时 yield。适用于并行执行场景。

        Returns:
            dict: 包含 chunks 和 output_data 的结果字典
        """
        chunks = []

        async for item in self._execute_task(
            task=task,
            context=context,
            user_id=user_id,
            session_id=session_id,
            original_message=original_message,
            user_profile=user_profile,
            history=history,
            context_summary=context_summary,
            recent_memories=recent_memories
        ):
            # 过滤掉 Task 对象，只收集 dict chunks
            if isinstance(item, dict) and not isinstance(item.get("output_data"), dict):
                chunks.append(item)

        return {
            "task_id": task["id"],
            "status": task["status"],
            "chunks": chunks,
            "output_data": task.get("output_data", {})
        }

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
        intention_message = task['description']


        logger.info(f"开始执行任务: {task_id}, 类型: {task_type}, Agent: {agent_name}")

        # 更新状态为运行中
        task["status"] = TaskStatus.RUNNING

        # yield agent 开始状态事件
        yield {
            "type": "agent_status",
            "agent": agent_name,
            "status": "started",
            "task_type": task_type,
            "task_id": task_id
        }

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
                    "messages": [intention_message],
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
                    # 添加 agent 信息到 chunk，让前端能正确路由
                    chunk_with_agent = chunk.copy()
                    chunk_with_agent["agent"] = agent_name
                    chunk_with_agent["task_id"] = task_id
                    # 立即 yield 到前端，实现真正的实时流式输出
                    yield chunk_with_agent

                    # 同时收集到本地用于最终返回
                    chunks.append(chunk_with_agent)

                    if chunk.get("type") == "plan":
                        plan = chunk.get("plan")
                        logger.info(f"[TaskExecutor] Workout任务 {task_id} 生成计划: {plan.get('title') if plan else 'None'}")

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
                    # 添加 agent 信息到 chunk，让前端能正确路由
                    chunk_with_agent = chunk.copy()
                    chunk_with_agent["agent"] = agent_name
                    chunk_with_agent["task_id"] = task_id
                    # 立即 yield 到前端
                    yield chunk_with_agent

                    # 同时收集到本地
                    chunks.append(chunk_with_agent)

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
                    # 添加 agent 信息到 chunk，让前端能正确路由
                    chunk_with_agent = chunk.copy()
                    chunk_with_agent["agent"] = agent_name
                    chunk_with_agent["task_id"] = task_id
                    # 立即 yield 到前端
                    yield chunk_with_agent

                    # 同时收集到本地
                    chunks.append(chunk_with_agent)

                    if chunk.get("type") == "chunk":
                        chat_content += chunk.get("content", "")

                task["output_data"] = {
                    "content": chat_content,
                    "chunks": chunks
                }

                context.set_task_result(task_id, task["output_data"])

                # 任务完成后 yield Task 对象
                yield task

            elif task_type == "summary":
                # 总结任务 - 收集所有前置任务的输出并生成总结
                task_outputs = self._collect_task_outputs(context, task.get("depends_on", []))

                state = {
                    "user_id": user_id,
                    "session_id": session_id,
                    "user_profile": user_profile,
                    "user_message": original_message,
                    "task_outputs": task_outputs,
                    "history": history,
                    "context_summary": context_summary,
                    "recent_memories": recent_memories
                }

                # 执行并实时 yield 结果
                chunks = []
                summary_content = ""

                async for chunk in agent.stream(state):
                    # 添加 agent 信息到 chunk，让前端能正确路由
                    chunk_with_agent = chunk.copy()
                    chunk_with_agent["agent"] = agent_name
                    chunk_with_agent["task_id"] = task_id
                    # 立即 yield 到前端
                    yield chunk_with_agent

                    # 同时收集到本地
                    chunks.append(chunk_with_agent)

                    if chunk.get("type") == "chunk":
                        summary_content += chunk.get("content", "")

                task["output_data"] = {
                    "content": summary_content,
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

            # yield agent 完成状态事件
            yield {
                "type": "agent_status",
                "agent": agent_name,
                "status": "completed",
                "task_type": task_type,
                "task_id": task_id
            }

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

    def _collect_task_outputs(
        self,
        context: SharedContextPool,
        task_ids: list[str]
    ) -> list[dict]:
        """
        收集指定任务的输出结果

        Args:
            context: 共享上下文
            task_ids: 任务ID列表

        Returns:
            list[dict]: 任务输出列表，每个包含 task_id, task_type, content
        """
        outputs = []

        for task_id in task_ids:
            result = context.get_task_result(task_id)
            if result:
                outputs.append({
                    "task_id": task_id,
                    "task_type": result.get("task_type", "unknown"),
                    "content": result.get("content", "")
                })

        return outputs

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
