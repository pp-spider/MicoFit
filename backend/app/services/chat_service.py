"""聊天服务"""
import uuid
from datetime import datetime
from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func

from app.models.chat_session import ChatSession, ChatMessage


class ChatService:
    """聊天服务"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_session(self, user_id: str, title: str | None = None) -> ChatSession:
        """
        创建聊天会话

        Args:
            user_id: 用户ID
            title: 会话标题（可选，可由AI自动生成）

        Returns:
            ChatSession: 创建的会话
        """
        session = ChatSession(
            id=str(uuid.uuid4()),
            user_id=user_id,
            title=title or "新对话",
            message_count=0,
        )

        self.db.add(session)
        await self.db.commit()
        await self.db.refresh(session)

        return session

    async def get_session(self, session_id: str) -> ChatSession | None:
        """根据ID获取会话"""
        result = await self.db.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )
        return result.scalar_one_or_none()

    async def get_user_sessions(
        self,
        user_id: str,
        limit: int = 20,
        offset: int = 0
    ) -> List[ChatSession]:
        """获取用户的会话列表"""
        result = await self.db.execute(
            select(ChatSession)
            .where(ChatSession.user_id == user_id)
            .order_by(desc(ChatSession.updated_at))
            .offset(offset)
            .limit(limit)
        )
        return result.scalars().all()

    async def update_session_title(
        self,
        session_id: str,
        title: str
    ) -> ChatSession | None:
        """更新会话标题"""
        result = await self.db.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )
        session = result.scalar_one_or_none()

        if session:
            session.title = title
            await self.db.commit()
            await self.db.refresh(session)

        return session

    async def delete_session(self, session_id: str) -> bool:
        """删除会话（级联删除消息）"""
        result = await self.db.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )
        session = result.scalar_one_or_none()

        if session:
            await self.db.delete(session)
            await self.db.commit()
            return True

        return False

    async def add_message(
        self,
        session_id: str,
        role: str,
        content: str,
        structured_data: dict | None = None,
        data_type: str | None = None,
        tool_calls: list | None = None,
        tool_call_id: str | None = None,
        agent_outputs: list | None = None
    ) -> ChatMessage:
        """
        添加消息

        Args:
            session_id: 会话ID
            role: 角色（user/assistant/system/tool）
            content: 内容
            structured_data: 结构化数据
            data_type: 数据类型
            tool_calls: 工具调用信息
            tool_call_id: 工具调用ID
            agent_outputs: Agent 执行输出

        Returns:
            ChatMessage: 创建的消息
        """
        message = ChatMessage(
            id=str(uuid.uuid4()),
            session_id=session_id,
            role=role,
            content=content,
            structured_data=structured_data,
            data_type=data_type,
            tool_calls=tool_calls,
            tool_call_id=tool_call_id,
            agent_outputs=agent_outputs,
        )

        self.db.add(message)

        # 更新会话消息计数和时间
        result = await self.db.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )
        session = result.scalar_one_or_none()
        if session:
            session.message_count = await self._count_messages(session_id)
            session.updated_at = datetime.utcnow()

        await self.db.commit()
        await self.db.refresh(message)

        return message

    async def _count_messages(self, session_id: str) -> int:
        """统计会话消息数"""
        result = await self.db.execute(
            select(func.count(ChatMessage.id))
            .where(ChatMessage.session_id == session_id)
        )
        return result.scalar()

    async def get_session_messages(
        self,
        session_id: str,
        limit: int = 100,
        offset: int = 0
    ) -> List[ChatMessage]:
        """获取会话的消息列表"""
        result = await self.db.execute(
            select(ChatMessage)
            .where(ChatMessage.session_id == session_id)
            .order_by(ChatMessage.created_at)
            .offset(offset)
            .limit(limit)
        )
        return result.scalars().all()

    async def get_message(self, message_id: str) -> ChatMessage | None:
        """根据ID获取消息"""
        result = await self.db.execute(
            select(ChatMessage).where(ChatMessage.id == message_id)
        )
        return result.scalar_one_or_none()

    async def update_message_structured_data(
        self,
        message_id: str,
        structured_data: dict,
        data_type: str
    ) -> ChatMessage | None:
        """更新消息的结构化数据"""
        result = await self.db.execute(
            select(ChatMessage).where(ChatMessage.id == message_id)
        )
        message = result.scalar_one_or_none()

        if message:
            message.structured_data = structured_data
            message.data_type = data_type
            await self.db.commit()
            await self.db.refresh(message)

        return message
