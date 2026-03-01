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
from app.agents.models import ExecutionPlan, TaskAnalysis

logger = logging.getLogger(__name__)


class PlannerAgent:
    """
    PlannerAgent - Planner 架构主入口

    支持复杂多步骤任务的处理，实现真正的多 Agent 协作。
    """

    def __init__(self):
        """初始化 PlannerAgent"""
        print("\n" + "="*60)
        print("🚀 PlannerAgent 初始化成功")
        print("="*60 + "\n")

        # 初始化 SubAgents
        self.chat_sub_agent = ChatSubAgent()
        self.workout_sub_agent = WorkoutSubAgent()

        # Agent 注册表
        self.agent_registry = {
            "chat_sub_agent": self.chat_sub_agent,
            "workout_sub_agent": self.workout_sub_agent
        }

        # 初始化核心组件
        self.task_analyzer = TaskAnalyzer()
        self.task_planner = TaskPlanner(self.agent_registry)
        self.task_executor = TaskExecutor(self.agent_registry)
        self.result_aggregator = ResultAggregator()

        print("✅ PlannerAgent 组件加载完成")
        print(f"   - TaskAnalyzer: 任务分析")
        print(f"   - TaskPlanner: 任务规划")
        print(f"   - TaskExecutor: 任务执行")
        print(f"   - ResultAggregator: 结果聚合")
        print("="*60 + "\n")

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
            # ========== 步骤1: 任务分析 ==========
            logger.info(f"PlannerAgent 开始处理: {user_message[:50]}...")
            print("\n" + "─"*50)
            print("📊 PlannerAgent - 任务分析中...")
            print("─"*50 + "\n")

            task_analysis = await self.task_analyzer.analyze(
                user_message=user_message,
                user_profile=user_profile
            )

            # 输出分析结果
            print("\n" + "─"*50)
            print("📊 任务分析完成")
            print(f"   识别意图: {task_analysis.get('raw_intents')}")
            print(f"   复杂度: {task_analysis.get('complexity')}")
            print(f"   需要规划: {task_analysis.get('requires_planning')}")
            print(f"   子任务数: {len(task_analysis.get('sub_tasks', []))}")
            print("─"*50 + "\n")

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

            # ========== 步骤2: 任务规划 ==========
            print("─"*50)
            print("📋 PlannerAgent - 任务规划中...")
            print("─"*50 + "\n")

            execution_plan = self.task_planner.plan(task_analysis)

            # 输出规划结果
            print("\n" + "─"*50)
            print("📋 任务规划完成")
            print(f"   任务数: {len(execution_plan.get('tasks', []))}")
            print(f"   执行顺序: {execution_plan.get('execution_order')}")
            print(f"   并行组: {execution_plan.get('parallel_groups')}")
            print(f"   需要协作: {execution_plan.get('requires_collaboration')}")
            print("─"*50 + "\n")

            yield {
                "type": "plan_info",
                "execution_order": execution_plan.get("execution_order"),
                "parallel_groups": execution_plan.get("parallel_groups"),
                "requires_collaboration": execution_plan.get("requires_collaboration")
            }

            # ========== 步骤3: 任务执行 ==========
            print("─"*50)
            print("⚡ PlannerAgent - 任务执行中...")
            print("─"*50 + "\n")

            # 收集流式输出
            all_chunks = []
            final_plan = None

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

            # ========== 步骤4: 结果聚合 ==========
            print("─"*50)
            print("🔄 PlannerAgent - 结果聚合中...")
            print("─"*50 + "\n")

            aggregated = self.result_aggregator.aggregate(execution_plan.get("tasks", []), context)

            print("\n" + "─"*50)
            print("✅ PlannerAgent 处理完成")
            print(f"   结果类型: {aggregated.get('type')}")
            print(f"   响应格式: {aggregated.get('response_format')}")
            print(f"   包含计划: {aggregated.get('plan') is not None}")
            print("─"*50 + "\n")

            yield {
                "type": "done",
                "has_plan": aggregated.get("plan") is not None,
                "result_type": aggregated.get("type"),
                "content": aggregated.get("content"),
                "plan": aggregated.get("plan")
            }

        except Exception as e:
            import traceback
            logger.error(f"PlannerAgent 处理失败: {e}")
            print("\n" + "─"*50)
            print(f"❌ PlannerAgent 错误: {str(e)}")
            print("─"*50)
            print("堆栈跟踪:")
            traceback.print_exc()
            print("─"*50 + "\n")

            yield {
                "type": "error",
                "message": f"处理消息时出错: {str(e)}"
            }

        finally:
            # 清理上下文
            context.clear()
