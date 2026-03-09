"""AI服务层 - 封装LangGraph Agent调用"""
import asyncio
import logging
import uuid
import json
from typing import AsyncGenerator

logger = logging.getLogger(__name__)
from datetime import date, datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

# 优先使用 PlannerAgent，支持复杂多任务处理
# 如果需要降级到简单模式，可以使用 RouterAgent
from app.agents.planner_agent import PlannerAgent
from app.agents.router_agent import RouterAgent
from app.agents.chat_sub_agent import ChatSubAgent
from app.agents.workout_sub_agent import WorkoutSubAgent
from app.services.workout_service import WorkoutService
from app.services.chat_service import ChatService
from app.services.user_service import UserService
from app.services.context_service import ContextService
from app.models.workout_plan import WorkoutPlan as WorkoutPlanModel
from app.schemas.chat import ChatGeneratedPlanCreate


class AIService:
    """AI服务"""

    def __init__(self, db: AsyncSession):
        self.db = db
        # 使用 PlannerAgent 作为主入口，支持复杂多任务处理
        self.planner_agent = PlannerAgent()
        # 保留 RouterAgent 作为降级备用
        self.router_agent = RouterAgent()
        self.chat_sub_agent = ChatSubAgent()  # 用于 continue 功能
        self.workout_sub_agent = WorkoutSubAgent()  # 用于直接生成训练计划
        self.workout_service = WorkoutService(db)
        self.chat_service = ChatService(db)
        self.user_service = UserService(db)
        self.context_service = ContextService(db)

    async def stream_chat(
        self,
        user_id: str,
        session_id: str | None,
        message: str
    ) -> AsyncGenerator[dict, None]:
        """
        流式聊天

        Yields:
            dict: SSE事件数据
        """
        # 获取或创建会话
        is_new_session = False
        if not session_id:
            session = await self.chat_service.create_session(user_id, title=None)
            session_id = session.id
            is_new_session = True
            yield {
                "type": "session_created",
                "session_id": session_id
            }
        else:
            # 验证会话存在
            session = await self.chat_service.get_session(session_id)
            if not session or str(session.user_id) != user_id:
                yield {
                    "type": "error",
                    "message": "会话不存在或无权访问"
                }
                return

        # 获取用户画像
        user_profile = await self.user_service.get_user_profile(user_id)
        profile_dict = None
        if user_profile:
            profile_dict = {
                "user_id": str(user_profile.user_id),
                "nickname": user_profile.nickname,
                "fitness_level": user_profile.fitness_level,
                "goal": user_profile.goal,
                "scene": user_profile.scene,
                "time_budget": user_profile.time_budget,
                "limitations": user_profile.limitations,
                "equipment": user_profile.equipment,
                "weekly_days": user_profile.weekly_days,
            }

        print(f"用户画像profile_dict：{json.dumps(profile_dict, ensure_ascii=False, indent=4)}")

        # 获取会话上下文（包含摘要和近期消息）
        context = await self.context_service.get_context_for_chat(
            session_id=session_id,
            user_profile=profile_dict
        )

        print(f"会话上下文：{json.dumps(context, ensure_ascii=False, indent=4)}")

        # 获取历史消息（按时间排序，保留最近30条，但只使用20条）
        history = await self.chat_service.get_session_messages(session_id, limit=30)
        # 确保按时间顺序排列
        history = sorted(history, key=lambda m: (m.created_at or datetime.min, m.id or ''))
        history_dicts = [
            {"role": msg.role, "content": msg.content, "created_at": msg.created_at.isoformat() if msg.created_at else None}
            for msg in history
        ]

        print(f"会话历史消息：{json.dumps(history_dicts, ensure_ascii=False, indent=4)}")

        # 获取用户跨会话记忆
        user_memory = await self.context_service.get_user_memory(user_id, days=7)
        recent_memories = user_memory.get("recent_topics", [])[:3]  # 取最近3个主题

        print(f"跨会话记忆：{json.dumps(user_memory, ensure_ascii=False, indent=4)}")

        # 保存用户消息
        await self.chat_service.add_message(
            session_id=session_id,
            role="user",
            content=message
        )

        # 如果是新会话，自动生成标题
        if is_new_session:
            await self.context_service.update_session_title_from_first_message(
                session_id=session_id,
                first_message=message
            )

        # 流式生成回复 - 使用 PlannerAgent
        full_content = ""
        workout_plans = []  # 改为列表，支持多个训练计划

        # 预先创建AI助手消息（占位），以便在plan事件中可以带上message_id
        assistant_message = await self.chat_service.add_message(
            session_id=session_id,
            role="assistant",
            content="",  # 占位，后续会更新
            data_type="text"
        )
        message_id = str(assistant_message.id)

        async for chunk in self.planner_agent.process(
            user_id=user_id,
            session_id=session_id,
            user_message=message,
            user_profile=profile_dict,
            history=history_dicts,
            context_summary=context.get("summary"),
            recent_memories=recent_memories
        ):
            # PlannerAgent 新增的事件类型
            if chunk["type"] == "analysis_progress":
                # 任务分析进度（流式）
                logger.info(
                    f"任务分析进度: {chunk.get('stage')} - {chunk.get('message')}"
                )
                yield {
                    "type": "analysis_progress",
                    "stage": chunk.get("stage"),
                    "message": chunk.get("message"),
                    "partial_data": chunk.get("partial_data")
                }
            elif chunk["type"] == "analysis":
                # 任务分析结果
                logger.info(
                    f"任务分析: {chunk.get('analysis', {}).get('intents')} "
                    f"复杂度: {chunk.get('analysis', {}).get('complexity')}"
                )
                yield {
                    "type": "analysis",
                    "analysis": chunk.get("analysis", {})
                }
            elif chunk["type"] == "plan_info":
                # 执行计划信息
                logger.info(
                    f"执行计划: {chunk.get('execution_order')} "
                    f"并行组: {chunk.get('parallel_groups')}"
                )
                yield {
                    "type": "plan_info",
                    "execution_order": chunk.get("execution_order"),
                    "parallel_groups": chunk.get("parallel_groups"),
                    "requires_collaboration": chunk.get("requires_collaboration")
                }
            elif chunk["type"] == "intent":
                # 意图识别结果，可以记录日志
                logger.info(
                    f"意图识别: {chunk.get('intent')} "
                    f"(置信度: {chunk.get('confidence', 0):.2f})"
                )
                # 将意图信息传递给前端（可选）
                yield {
                    "type": "metadata",
                    "intent": chunk.get("intent"),
                    "confidence": chunk.get("confidence"),
                    "entities": chunk.get("entities", {})
                }
            elif chunk["type"] == "chunk":
                full_content += chunk["content"]
                yield chunk
            elif chunk["type"] == "plan":
                plan_data = chunk["plan"]
                # 保存计划到 chat_generated_plans 表（用户确认后再转移到 workout_plans）
                try:
                    plan_create = ChatGeneratedPlanCreate(
                        session_id=session_id,
                        message_id=message_id,
                        title=plan_data["title"],
                        subtitle=plan_data.get("subtitle", ""),
                        total_duration=plan_data["total_duration"],
                        scene=plan_data["scene"],
                        rpe=plan_data["rpe"],
                        ai_note=plan_data.get("ai_note"),
                        modules=plan_data["modules"],
                    )
                    plan_record = await self.chat_service.create_generated_plan(
                        user_id=user_id,
                        data=plan_create
                    )
                    # 将数据库ID添加到计划数据中
                    plan_data["id"] = str(plan_record.id)
                    # 添加到计划列表
                    workout_plans.append(plan_data)
                    logger.info(f"[AIService] 保存计划到 chat_generated_plans {len(workout_plans)}: {plan_data['title']}, id={plan_record.id}")
                    yield {
                        "type": "plan",
                        "plan": plan_data,
                        "plan_id": str(plan_record.id),  # 这是 chat_generated_plans 的 ID
                        "plan_index": len(workout_plans) - 1,  # 计划索引
                        "total_plans": len(workout_plans),  # 总计划数
                        "message_id": message_id  # 关联的消息ID
                    }
                except Exception as e:
                    logger.error(f"保存计划失败: {e}")
                    # 保存失败时仍然返回原始计划，但不返回plan_id
                    yield chunk
            elif chunk["type"] == "done":
                # 多 agent 时使用 summary_sub_agent 的输出，而不是简单拼接的 full_content
                final_content = chunk.get("content") or full_content

                # 获取所有计划（从 chunk 中的 plans 字段，或本地收集的 workout_plans）
                all_plans = chunk.get("plans", []) or workout_plans

                # 保存AI回复并获取消息对象
                # 多个计划时，保存所有计划到 structured_data 中
                structured_data = None
                if len(all_plans) == 1:
                    structured_data = all_plans[0]
                elif len(all_plans) > 1:
                    # 多个计划时，保存为包含 plans 数组的对象
                    structured_data = {
                        "plans": all_plans,
                        "primary_plan": all_plans[0]  # 保留主计划用于兼容
                    }

                # 更新之前创建的占位消息
                await self.chat_service.update_message(
                    message_id=message_id,
                    content=final_content,
                    structured_data=structured_data,
                    data_type="workout_plan" if all_plans else "text"
                )
                # 异步更新会话摘要（不阻塞响应）
                # 使用对话历史生成真正的摘要，而不是直接保存回复内容
                try:
                    # 获取完整对话历史（包括当前这条）用于摘要生成
                    all_messages = history_dicts + [
                        {"role": "user", "content": message},
                        {"role": "assistant", "content": final_content}
                    ]
                    # 异步生成并更新摘要，不等待结果
                    asyncio.create_task(
                        self._update_session_summary_async(session_id, all_messages)
                    )
                except Exception as e:
                    logger.warning(f"触发摘要更新失败: {e}")
                yield {
                    "type": "done",
                    "session_id": session_id,
                    "has_plan": len(all_plans) > 0,
                    "has_multiple_plans": len(all_plans) > 1,
                    "plans_count": len(all_plans),
                    "message_id": message_id,  # 返回消息ID
                    "content": final_content  # 返回最终内容给前端
                }
            elif chunk["type"] == "agent_status":
                # Agent 状态事件，透传到前端
                logger.info(f"Agent 状态: {chunk.get('agent')} - {chunk.get('status')}")
                yield chunk
            elif chunk["type"] == "error":
                logger.error(f"PlannerAgent 错误: {chunk.get('message')}")
                yield chunk

    async def continue_stream_chat(
        self,
        user_id: str,
        session_id: str,
        existing_content: str
    ) -> AsyncGenerator[dict, None]:
        """
        继续之前的流式生成

        当应用从后台恢复时，调用此接口继续生成剩余内容

        Args:
            user_id: 用户ID
            session_id: 会话ID
            existing_content: 已有的内容（前端已接收的部分）

        Yields:
            dict: SSE事件数据
        """
        # 验证会话存在
        session = await self.chat_service.get_session(session_id)
        if not session or str(session.user_id) != user_id:
            yield {
                "type": "error",
                "message": "会话不存在或无权访问"
            }
            return

        # 获取用户画像
        user_profile = await self.user_service.get_user_profile(user_id)
        profile_dict = None
        if user_profile:
            profile_dict = {
                "user_id": str(user_profile.user_id),
                "nickname": user_profile.nickname,
                "fitness_level": user_profile.fitness_level,
                "goal": user_profile.goal,
                "scene": user_profile.scene,
                "time_budget": user_profile.time_budget,
                "limitations": user_profile.limitations,
                "equipment": user_profile.equipment,
                "weekly_days": user_profile.weekly_days,
            }

        # 获取会话上下文
        context = await self.context_service.get_context_for_chat(
            session_id=session_id,
            user_profile=profile_dict
        )

        # 获取历史消息
        history = await self.chat_service.get_session_messages(session_id, limit=30)
        history_dicts = [
            {"role": msg.role, "content": msg.content}
            for msg in history
        ]

        # 获取用户跨会话记忆
        user_memory = await self.context_service.get_user_memory(user_id, days=7)
        recent_memories = user_memory.get("recent_topics", [])[:3]

        # 流式继续生成回复（传入 existing_content 作为已生成的内容）
        full_content = existing_content
        workout_plans = []  # 改为列表，支持多个训练计划

        # 使用 ChatSubAgent 继续生成
        from app.agents.state import ChatSubAgentState

        chat_state: ChatSubAgentState = {
            "messages": [],
            "user_id": user_id,
            "session_id": session_id,
            "user_profile": profile_dict,
            "user_message": f"[继续生成] 之前的回复已经生成了以下内容：{existing_content}。请继续生成剩余的回复内容。如果之前的回复已经完整，请回复'继续内容已结束'。",
            "history": history_dicts,
            "context_summary": context.get("summary"),
            "recent_memories": recent_memories,
            "response": None,
            "stream_chunks": [],
            "error_message": None
        }

        async for chunk in self.chat_sub_agent.stream(chat_state):
            if chunk["type"] == "chunk":
                full_content += chunk["content"]
                yield chunk
            elif chunk["type"] == "plan":
                plan_data = chunk["plan"]
                # 保存计划到 chat_generated_plans 表（用户确认后再转移到 workout_plans）
                try:
                    plan_create = ChatGeneratedPlanCreate(
                        session_id=session_id,
                        message_id=None,  # continue 模式下没有预先创建的消息
                        title=plan_data["title"],
                        subtitle=plan_data.get("subtitle", ""),
                        total_duration=plan_data["total_duration"],
                        scene=plan_data["scene"],
                        rpe=plan_data["rpe"],
                        ai_note=plan_data.get("ai_note"),
                        modules=plan_data["modules"],
                    )
                    plan_record = await self.chat_service.create_generated_plan(
                        user_id=user_id,
                        data=plan_create
                    )
                    plan_data["id"] = str(plan_record.id)
                    # 添加到计划列表
                    workout_plans.append(plan_data)
                    yield {
                        "type": "plan",
                        "plan": plan_data,
                        "plan_id": str(plan_record.id),  # 这是 chat_generated_plans 的 ID
                        "plan_index": len(workout_plans) - 1,
                        "total_plans": len(workout_plans)
                    }
                except Exception as e:
                    logger.error(f"保存计划失败: {e}")
                    yield chunk
            elif chunk["type"] == "done":
                # 更新已有消息或添加新消息
                # 多个计划时，保存所有计划到 structured_data 中
                structured_data = None
                if len(workout_plans) == 1:
                    structured_data = workout_plans[0]
                elif len(workout_plans) > 1:
                    structured_data = {
                        "plans": workout_plans,
                        "primary_plan": workout_plans[0]
                    }

                message = await self.context_service.add_message_and_update_summary(
                    session_id=session_id,
                    role="assistant",
                    content=full_content,
                    structured_data=structured_data,
                    data_type="workout_plan" if workout_plans else "text"
                )
                yield {
                    "type": "done",
                    "session_id": session_id,
                    "has_plan": len(workout_plans) > 0,
                    "has_multiple_plans": len(workout_plans) > 1,
                    "plans_count": len(workout_plans),
                    "message_id": str(message.id)  # 返回后端生成的消息ID
                }
            elif chunk["type"] == "error":
                yield chunk

    async def generate_workout_plan(
        self,
        user_id: str,
        preferences: dict | None = None
    ) -> dict:
        """
        生成训练计划（非流式）

        **DEPRECATED**: 请使用 stream_chat 发送"生成计划"类消息

        Args:
            user_id: 用户ID
            preferences: 额外偏好设置

        Returns:
            dict: 包含生成的计划
        """
        # 获取用户画像
        user_profile = await self.user_service.get_user_profile(user_id)
        profile_dict = None
        if user_profile:
            profile_dict = {
                "user_id": str(user_profile.user_id),
                "nickname": user_profile.nickname,
                "fitness_level": user_profile.fitness_level,
                "goal": user_profile.goal,
                "scene": user_profile.scene,
                "time_budget": user_profile.time_budget,
                "limitations": user_profile.limitations,
                "equipment": user_profile.equipment,
                "weekly_days": user_profile.weekly_days,
            }

        # 应用额外偏好
        if preferences:
            if "scene" in preferences:
                profile_dict["scene"] = preferences["scene"]
            if "time_budget" in preferences:
                profile_dict["time_budget"] = preferences["time_budget"]
            if "focus" in preferences:
                # 可以在这里添加更多偏好处理
                pass

        # 生成计划（通过 WorkoutSubAgent）
        from app.agents.state import WorkoutSubAgentState

        workout_state: WorkoutSubAgentState = {
            "messages": [],
            "user_id": user_id,
            "user_profile": profile_dict,
            "extracted_preferences": preferences or {},
            "workout_plan": None,
            "plan_json_str": None,
            "validation_passed": False,
            "stream_chunks": [],
            "error_message": None
        }

        result = await self.workout_sub_agent.process(workout_state)

        if result.get("success") and result.get("plan"):
            # 保存到数据库
            plan_data = result["plan"]
            plan = await self.workout_service.create_plan(
                user_id=user_id,
                plan_date=date.today(),
                title=plan_data["title"],
                subtitle=plan_data.get("subtitle", ""),
                total_duration=plan_data["total_duration"],
                scene=plan_data["scene"],
                rpe=plan_data["rpe"],
                modules=plan_data["modules"],
                ai_note=plan_data.get("ai_note"),
                is_applied=False
            )

            return {
                "success": True,
                "plan": plan_data,
                "plan_id": str(plan.id)
            }

        return {
            "success": False,
            "error": result.get("error", "生成计划失败")
        }

    async def stream_generate_workout_plan(
        self,
        user_id: str,
        preferences: dict | None = None
    ) -> AsyncGenerator[dict, None]:
        """
        流式生成训练计划

        **DEPRECATED**: 请使用 stream_chat 发送"生成计划"类消息

        Yields:
            dict: 包含流式数据和最终计划
        """
        # 获取用户画像
        user_profile = await self.user_service.get_user_profile(user_id)
        profile_dict = None
        if user_profile:
            profile_dict = {
                "user_id": str(user_profile.user_id),
                "nickname": user_profile.nickname,
                "fitness_level": user_profile.fitness_level,
                "goal": user_profile.goal,
                "scene": user_profile.scene,
                "time_budget": user_profile.time_budget,
                "limitations": user_profile.limitations,
                "equipment": user_profile.equipment,
                "weekly_days": user_profile.weekly_days,
            }

        # 应用额外偏好
        if preferences:
            if "scene" in preferences:
                profile_dict["scene"] = preferences["scene"]
            if "time_budget" in preferences:
                profile_dict["time_budget"] = preferences["time_budget"]

        workout_plan = None

        # 使用 WorkoutSubAgent 流式生成
        from app.agents.state import WorkoutSubAgentState

        workout_state: WorkoutSubAgentState = {
            "messages": [],
            "user_id": user_id,
            "user_profile": profile_dict,
            "extracted_preferences": preferences or {},
            "workout_plan": None,
            "plan_json_str": None,
            "validation_passed": False,
            "stream_chunks": [],
            "error_message": None
        }

        async for chunk in self.workout_sub_agent.stream(workout_state):
            if chunk["type"] == "plan":
                workout_plan = chunk["plan"]
            yield chunk

        # 保存计划到数据库
        if workout_plan:
            try:
                plan = await self.workout_service.create_plan(
                    user_id=user_id,
                    plan_date=date.today(),
                    title=workout_plan["title"],
                    subtitle=workout_plan.get("subtitle", ""),
                    total_duration=workout_plan["total_duration"],
                    scene=workout_plan["scene"],
                    rpe=workout_plan["rpe"],
                    modules=workout_plan["modules"],
                    ai_note=workout_plan.get("ai_note"),
                    is_applied=False
                )

                yield {
                    "type": "saved",
                    "plan_id": str(plan.id)
                }
            except Exception as e:
                yield {
                    "type": "error",
                    "message": f"保存计划失败: {str(e)}"
                }

    async def get_today_plan(
        self,
        user_id: str,
        plan_date: date | None = None,
    ) -> dict | None:
        """
        获取今日计划（优先返回已应用的计划 is_applied=true）

        Args:
            user_id: 用户ID
            plan_date: 指定日期，默认为今日（支持不同时区）

        Returns:
            dict | None: 计划数据
        """
        from sqlalchemy import and_

        target_date = plan_date if plan_date else date.today()

        # 1. 优先查询指定日期已应用的计划
        result = await self.db.execute(
            select(WorkoutPlanModel)
            .where(
                and_(
                    WorkoutPlanModel.user_id == user_id,
                    WorkoutPlanModel.plan_date == target_date,
                    WorkoutPlanModel.is_applied == True
                )
            )
            .limit(1)
        )
        plan = result.scalar_one_or_none()

        # 2. 如果没有已应用的计划，查询指定日期最新的计划
        if not plan:
            result = await self.db.execute(
                select(WorkoutPlanModel)
                .where(
                    and_(
                        WorkoutPlanModel.user_id == user_id,
                        WorkoutPlanModel.plan_date == target_date
                    )
                )
                .order_by(desc(WorkoutPlanModel.created_at))
                .limit(1)
            )
            plan = result.scalar_one_or_none()

        # 3. 如果没有找到指定日期的计划，查询用户最新的任意一天的计划
        if not plan:
            result = await self.db.execute(
                select(WorkoutPlanModel)
                .where(WorkoutPlanModel.user_id == user_id)
                .order_by(desc(WorkoutPlanModel.created_at))
                .limit(1)
            )
            plan = result.scalar_one_or_none()

        if plan:
            return {
                "id": str(plan.id),
                "title": plan.title,
                "subtitle": plan.subtitle,
                "total_duration": plan.total_duration,
                "scene": plan.scene,
                "rpe": plan.rpe,
                "modules": plan.modules,
                "ai_note": plan.ai_note,
                "is_completed": plan.is_completed,
                "is_applied": plan.is_applied,
                "plan_date": plan.plan_date.isoformat(),
            }

        return None

    async def _update_session_summary_async(
        self,
        session_id: str,
        messages: list[dict]
    ):
        """
        异步更新会话摘要

        Args:
            session_id: 会话ID
            messages: 消息列表，包含 role 和 content
        """
        try:
            # 使用 ContextService 的 summarizer 生成摘要
            summary = await self.context_service.summarizer.summarize_messages(messages)
            if summary:
                await self.context_service.update_session_summary(session_id, summary)
                logger.info(f"会话 {session_id} 摘要已更新: {summary[:50]}...")
        except Exception as e:
            logger.error(f"生成会话摘要失败: {e}")
