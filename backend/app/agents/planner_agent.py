"""PlannerAgent - Planner 架构主入口

支持复杂多步骤任务的处理，多 Agent 协作执行。

工作流程：
1. TaskAnalyzer - 分析用户请求，识别任务类型和复杂度
2. TaskPlanner - 拆分子任务，确定执行顺序
3. TaskExecutor - 按计划执行任务
4. ResultAggregator - 合并多任务结果
"""
import logging
from typing import AsyncGenerator

from app.agents.task_analyzer import TaskAnalyzer
from app.agents.task_planner import TaskPlanner
from app.agents.task_executor import TaskExecutor
from app.agents.shared_context import SharedContextPool
from app.agents.result_aggregator import ResultAggregator
from app.agents.chat_sub_agent import ChatSubAgent
from app.agents.workout_sub_agent import WorkoutSubAgent
from app.agents.summary_sub_agent import SummarySubAgent
from app.agents.general_chat_sub_agent import GeneralChatSubAgent
from app.agents.models import ExecutionPlan, TaskAnalysis, ExecutionMode

logger = logging.getLogger(__name__)


class PlannerAgent:
    """
    PlannerAgent - Planner 架构主入口

    支持复杂多步骤任务的处理，实现真正的多 Agent 协作。
    """

    def __init__(self):
        """初始化 PlannerAgent"""
        # 初始化 SubAgents
        self.chat_sub_agent = ChatSubAgent()
        self.workout_sub_agent = WorkoutSubAgent()
        self.summary_sub_agent = SummarySubAgent()
        self.general_chat_sub_agent = GeneralChatSubAgent()

        # Agent 注册表
        self.agent_registry = {
            "chat_sub_agent": self.chat_sub_agent,
            "workout_sub_agent": self.workout_sub_agent,
            "summary_sub_agent": self.summary_sub_agent,
            "general_chat_sub_agent": self.general_chat_sub_agent
        }

        # 初始化核心组件
        self.task_analyzer = TaskAnalyzer()
        self.task_planner = TaskPlanner(self.agent_registry)
        self.task_executor = TaskExecutor(self.agent_registry)
        self.result_aggregator = ResultAggregator()

    async def process(
        self,
        user_id: str,
        session_id: str,
        user_message: str,
        user_profile: dict | None = None,
        history: list[dict] | None = None,
        context_summary: str | None = None,
        recent_memories: list[str] | None = None
    ) -> AsyncGenerator[dict, None]:
        """
        处理用户消息的流式接口

        这是 PlannerAgent 的主要入口。

        Args:
            user_id: 用户ID
            session_id: 会话ID
            user_message: 用户消息
            user_profile: 用户画像
            history: 历史消息
            context_summary: 会话摘要
            recent_memories: 跨会话记忆

        Yields:
            dict: 流式响应块
            - {"type": "analysis", "analysis": {...}}
            - {"type": "plan_info", "execution_order": [...], "parallel_groups": [...]}
            - {"type": "chunk", "content": "..."}
            - {"type": "plan", "plan": {...}}
            - {"type": "done", "has_plan": bool}
            - {"type": "error", "message": "..."}
        """
        # 创建共享上下文
        context = SharedContextPool()

        try:
            task_analysis = await self.task_analyzer.analyze(
                user_message=user_message,
                user_profile=user_profile
            )

            yield {
                "type": "analysis",
                "analysis": {
                    "intents": task_analysis.get("raw_intents"),
                    "primary_intent": task_analysis.get("primary_intent"),
                    "complexity": task_analysis.get("complexity"),
                    "requires_planning": task_analysis.get("requires_planning"),
                    "entities": task_analysis.get("extracted_entities")
                }
            }

            execution_plan = self.task_planner.plan(task_analysis)

            yield {
                "type": "plan_info",
                "execution_order": execution_plan.get("execution_order"),
                "parallel_groups": execution_plan.get("parallel_groups"),
                "requires_collaboration": execution_plan.get("requires_collaboration")
            }

            # 收集流式输出
            all_chunks = []
            final_plan = None

            # 判断执行模式：根据 parallel_groups 是否有实际并行组
            parallel_groups = execution_plan.get("parallel_groups", [])
            execution_mode = execution_plan.get("execution_mode", ExecutionMode.AUTO)

            # 判断是否真的有并行执行的必要（存在长度>1的组）
            has_parallel_groups = any(len(g) > 1 for g in parallel_groups)

            # 强制串行模式开关（可通过环境变量或配置控制）
            force_serial = False  # 未来可从配置读取

            should_use_parallel = (
                not force_serial and
                execution_mode != ExecutionMode.SERIAL and
                has_parallel_groups
            )

            # 并行执行模式
            if should_use_parallel:
                logger.info("使用并行执行模式")
                async for result in self.task_executor.execute_parallel(
                    plan=execution_plan,
                    context=context,
                    user_id=user_id,
                    session_id=session_id,
                    user_message=user_message,
                    user_profile=user_profile,
                    history=history,
                    context_summary=context_summary,
                    recent_memories=recent_memories
                ):
                    result_type = result.get("type")

                    if result_type == "batch_start":
                        yield result

                    elif result_type == "batch_complete":
                        yield result

                    elif result_type == "task_error":
                        logger.error(f"任务 {result.get('task_id')} 失败: {result.get('error')}")
                        yield result

                    elif result_type in ("chunk", "plan", "agent_status", "task_started", "task_completed"):
                        # 收集chunks用于结果聚合
                        if result_type == "chunk":
                            all_chunks.append(result)
                        elif result_type == "plan":
                            final_plan = result.get("plan")
                            all_chunks.append(result)
                            logger.info(f"[PlannerAgent] 收到plan事件: {final_plan.get('title') if final_plan else 'None'}, task_id={result.get('task_id')}")

                        # 跳过子Agent内部的done事件
                        if result_type == "done":
                            continue

                        # 记录任务状态变化
                        if result_type == "task_started":
                            logger.info(f"任务 {result.get('task_id')} 开始执行")
                        elif result_type == "task_completed":
                            logger.info(f"任务 {result.get('task_id')} 完成")

                        # 实时 yield 到前端（带 task_id 标记）
                        yield result

            else:
                # 串行执行模式
                logger.info("使用串行执行模式")
                # 遍历执行任务并实时流式 yield 到前端
                for task_id in execution_plan.get("execution_order", []):
                    # 找到对应的任务
                    task = None
                    for t in execution_plan.get("tasks", []):
                        if t.get("id") == task_id:
                            task = t
                            break

                    if not task:
                        continue

                    logger.info(f"执行任务: {task_id}, 类型: {task.get('type')}, Agent: {task.get('agent_name')}")

                    # 使用 async for 实时获取 chunks 并 yield 到前端
                    async for result in self.task_executor._execute_task(
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
                        # 检查是否是 Task 对象（最后一个 yield）
                        if isinstance(result, dict) and result.get("output_data"):
                            # 这是任务完成后返回的 Task 对象
                            executed_task = result
                            output_data = executed_task.get("output_data", {})
                            task_chunks = output_data.get("chunks", [])
                            all_chunks.extend(task_chunks)
                            logger.info(f"任务 {task_id} 执行完成，共 {len(task_chunks)} 个 chunks")

                            # 提取 plan
                            if output_data.get("plan"):
                                final_plan = output_data.get("plan")
                        else:
                            # 这是一个 chunk，实时 yield 到前端
                            chunk = result

                            # 跳过 SubAgent 内部的 done 事件（不是整个 Planner 的结束）
                            if chunk.get("type") == "done":
                                logger.info(f"跳过 SubAgent 内部 done，任务继续执行...")
                                continue

                            # 记录 AI 返回的内容
                            if chunk.get("type") == "chunk" and chunk.get("content"):
                                logger.info(f"AI 返回内容: {chunk.get('content')[:200]}...")
                            elif chunk.get("type") == "plan":
                                logger.info(f"AI 返回计划: {chunk.get('plan', {}).get('title', '无标题')}")

                            # 实时 yield 到前端
                            yield chunk

            # ========== 结果聚合 ==========
            aggregated = self.result_aggregator.aggregate(execution_plan.get("tasks", []), context)

            # 收集所有计划（支持多计划场景）
            plans = aggregated.get("plans", [])
            if not plans and aggregated.get("plan"):
                plans = [aggregated.get("plan")]

            yield {
                "type": "done",
                "has_plan": len(plans) > 0 or aggregated.get("plan") is not None,
                "has_multiple_plans": len(plans) > 1,
                "plans_count": len(plans),
                "result_type": aggregated.get("type"),
                "content": aggregated.get("content"),
                "plan": aggregated.get("plan"),  # 向后兼容：第一个计划
                "plans": plans  # 所有计划列表
            }

        except Exception as e:
            import traceback
            logger.error(f"PlannerAgent 处理失败: {e}")
            traceback.print_exc()

            yield {
                "type": "error",
                "message": f"处理消息时出错: {str(e)}"
            }

        finally:
            # 清理上下文
            context.clear()
