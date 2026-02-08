"""上下文管理服务 - 实现AI记忆功能"""
import json
from typing import List, Dict, Any
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, and_

from langchain_core.messages import SystemMessage, HumanMessage, AIMessage
from langchain_openai import ChatOpenAI

from app.models.chat_session import ChatSession, ChatMessage
from app.core.config import settings


class ContextSummarizer:
    """消息摘要器 - 对长对话进行智能摘要"""

    def __init__(self):
        self.llm = ChatOpenAI(
            model=settings.OPENAI_API_KEY and "gpt-3.5-turbo" or None,
            api_key=settings.OPENAI_API_KEY,
            base_url=settings.OPENAI_BASE_URL if settings.OPENAI_BASE_URL else None,
            temperature=0.3,
            max_tokens=500,
        )

    async def summarize_messages(
        self,
        messages: List[Dict[str, Any]],
        max_summary_length: int = 800
    ) -> str:
        """
        对消息列表进行摘要

        Args:
            messages: 消息列表，格式为 [{"role": str, "content": str, ...}]
            max_summary_length: 摘要最大长度

        Returns:
            str: 生成的摘要文本
        """
        if not messages:
            return ""

        # 构建摘要提示
        summary_prompt = self._build_summary_prompt(messages)

        try:
            response = await self.llm.ainvoke([
                SystemMessage(content="你是一个对话摘要助手，请对以下健身相关的对话进行简洁摘要。"),
                HumanMessage(content=summary_prompt)
            ])

            summary = response.content.strip()
            return summary[:max_summary_length]
        except Exception as e:
            # 如果摘要失败，返回简单的文本截断
            return self._fallback_summary(messages, max_summary_length)

    def _build_summary_prompt(self, messages: List[Dict[str, Any]]) -> str:
        """构建摘要提示"""
        # 只保留用户和助手的关键消息
        key_messages = []
        for msg in messages:
            role = msg.get("role", "")
            content = msg.get("content", "")

            # 跳过系统消息和空消息
            if role in ["system", "tool"] or not content.strip():
                continue

            # 截断过长的消息
            if len(content) > 500:
                content = content[:500] + "..."

            key_messages.append(f"{role}: {content}")

        conversation_text = "\n".join(key_messages[-20:])  # 最多取最近20条

        prompt = f"""请对以下健身对话进行摘要，重点关注：
1. 用户的健身目标、偏好和限制
2. 已生成的训练计划类型和效果
3. 用户的反馈和调整需求
4. 重要的个人信息（如伤病、可用器材等）

对话内容：
{conversation_text}

请生成一个简洁的摘要（不超过300字），用于帮助AI助手记住对话上下文："""

        return prompt

    def _fallback_summary(
        self,
        messages: List[Dict[str, Any]],
        max_length: int
    ) -> str:
        """备用摘要方法（简单截断）"""
        user_messages = [
            msg.get("content", "") for msg in messages
            if msg.get("role") == "user" and msg.get("content")
        ]

        if not user_messages:
            return ""

        # 取最近几条用户消息的关键信息
        recent = " | ".join(user_messages[-5:])
        return recent[:max_length] if len(recent) > max_length else recent


class ContextService:
    """上下文管理服务 - 管理AI记忆功能"""

    # 上下文窗口配置
    MAX_RECENT_MESSAGES = 20  # 保留最近的消息数量
    MAX_CONTEXT_TOKENS = 4000  # 最大上下文token数（预留空间给系统提示和回复）
    SUMMARY_THRESHOLD = 10  # 超过此消息数时触发摘要

    def __init__(self, db: AsyncSession):
        self.db = db
        self.summarizer = ContextSummarizer()

    async def get_context_for_chat(
        self,
        session_id: str,
        user_profile: Dict[str, Any] | None = None
    ) -> Dict[str, Any]:
        """
        获取聊天所需的完整上下文

        Returns:
            Dict 包含:
            - summary: 会话摘要（如果有）
            - recent_messages: 最近的消息列表
            - total_tokens: 预估的token数
        """
        # 获取会话信息
        session_result = await self.db.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )
        session = session_result.scalar_one_or_none()

        if not session:
            return {"summary": "", "recent_messages": [], "total_tokens": 0}

        # 获取最近的消息
        messages = await self._get_recent_messages(session_id)

        # 计算是否需要摘要
        needs_summary = (
            len(messages) > self.SUMMARY_THRESHOLD and
            not session.context_summary
        )

        # 如果需要，生成摘要
        summary = session.context_summary or ""
        if needs_summary:
            summary = await self.summarizer.summarize_messages(messages)
            await self._update_session_summary(session_id, summary)

        # 构建返回的上下文
        recent_for_context = messages[-self.MAX_RECENT_MESSAGES:]

        # 估算token数（简单估算：每字约0.5个token）
        total_text = summary + json.dumps(recent_for_context, ensure_ascii=False)
        estimated_tokens = int(len(total_text) * 0.5)

        return {
            "summary": summary,
            "recent_messages": recent_for_context,
            "total_tokens": estimated_tokens,
            "session_title": session.title,
        }

    async def add_message_and_update_summary(
        self,
        session_id: str,
        role: str,
        content: str,
        structured_data: Dict[str, Any] | None = None,
        data_type: str | None = None
    ) -> ChatMessage:
        """
        添加消息并智能更新摘要
        """
        from app.services.chat_service import ChatService

        chat_service = ChatService(self.db)

        # 添加消息
        message = await chat_service.add_message(
            session_id=session_id,
            role=role,
            content=content,
            structured_data=structured_data,
            data_type=data_type
        )

        # 检查是否需要更新摘要
        await self._maybe_update_summary(session_id)

        return message

    async def _get_recent_messages(
        self,
        session_id: str,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """获取最近的消息"""
        result = await self.db.execute(
            select(ChatMessage)
            .where(ChatMessage.session_id == session_id)
            .where(ChatMessage.role.in_(["user", "assistant"]))
            .order_by(ChatMessage.created_at)
            .limit(limit)
        )
        messages = result.scalars().all()

        return [
            {
                "role": msg.role,
                "content": msg.content,
                "data_type": msg.data_type,
                "created_at": msg.created_at.isoformat() if msg.created_at else None,
            }
            for msg in messages
        ]

    async def _update_session_summary(self, session_id: str, summary: str):
        """更新会话摘要"""
        result = await self.db.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )
        session = result.scalar_one_or_none()

        if session:
            session.context_summary = summary
            await self.db.commit()

    async def _maybe_update_summary(self, session_id: str):
        """根据需要更新摘要"""
        result = await self.db.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )
        session = result.scalar_one_or_none()

        if not session:
            return

        # 每20条消息更新一次摘要
        if session.message_count > 0 and session.message_count % 20 == 0:
            messages = await self._get_recent_messages(session_id)
            summary = await self.summarizer.summarize_messages(messages)
            await self._update_session_summary(session_id, summary)

    async def generate_session_title(
        self,
        session_id: str,
        first_message: str
    ) -> str:
        """
        基于第一条消息自动生成会话标题
        """
        # 如果消息很短，直接使用
        if len(first_message) <= 15:
            return first_message

        # 提取关键词生成标题
        keywords = self._extract_keywords(first_message)
        if keywords:
            title = f"关于{'、'.join(keywords[:3])}的对话"
            if len(title) > 30:
                title = title[:27] + "..."
            return title

        # 默认标题
        return first_message[:20] + "..." if len(first_message) > 20 else first_message

    def _extract_keywords(self, text: str) -> List[str]:
        """从文本中提取关键词"""
        # 健身相关关键词库
        fitness_keywords = [
            "训练", "健身", "运动", "锻炼", "计划", "肌肉", "减脂", "增肌",
            "有氧", "力量", "瑜伽", "拉伸", "跑步", "深蹲", "俯卧撑",
            "腹部", "腿部", "背部", "胸部", "手臂", "核心", "体能",
            "膝盖", "腰部", "肩膀", "恢复", "休息", "饮食", "营养"
        ]

        found = []
        for keyword in fitness_keywords:
            if keyword in text:
                found.append(keyword)

        return found

    async def get_user_memory(
        self,
        user_id: str,
        days: int = 7
    ) -> Dict[str, Any]:
        """
        获取用户近期记忆（跨会话）

        Args:
            user_id: 用户ID
            days: 查询最近几天的会话

        Returns:
            Dict 包含用户的近期重要信息
        """
        cutoff_date = datetime.utcnow() - timedelta(days=days)

        # 获取近期会话
        result = await self.db.execute(
            select(ChatSession)
            .where(
                and_(
                    ChatSession.user_id == user_id,
                    ChatSession.updated_at >= cutoff_date
                )
            )
            .order_by(desc(ChatSession.updated_at))
            .limit(5)
        )
        sessions = result.scalars().all()

        # 汇总重要信息
        memory = {
            "recent_topics": [],
            "plans_generated": 0,
            "preferences_mentioned": [],
            "sessions_count": len(sessions),
        }

        for session in sessions:
            if session.context_summary:
                memory["recent_topics"].append(session.context_summary)

            # 统计生成的计划数
            messages_result = await self.db.execute(
                select(ChatMessage)
                .where(
                    and_(
                        ChatMessage.session_id == session.id,
                        ChatMessage.data_type == "workout_plan"
                    )
                )
            )
            plans = messages_result.scalars().all()
            memory["plans_generated"] += len(plans)

        return memory

    async def update_session_title_from_first_message(
        self,
        session_id: str,
        first_message: str
    ):
        """基于第一条消息更新会话标题"""
        result = await self.db.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )
        session = result.scalar_one_or_none()

        if session and session.title in ["新对话", None, ""]:
            new_title = await self.generate_session_title(session_id, first_message)
            session.title = new_title
            await self.db.commit()
