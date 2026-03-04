"""聊天服务"""
import uuid
from datetime import datetime
from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func

from app.models.chat_session import ChatSession, ChatMessage, ChatGeneratedPlan
from app.schemas.chat import ChatGeneratedPlanCreate
from fastapi import HTTPException


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
        from sqlalchemy import asc
        result = await self.db.execute(
            select(ChatMessage)
            .where(ChatMessage.session_id == session_id)
            .order_by(asc(ChatMessage.created_at), asc(ChatMessage.id))  # 先按时间，再按ID确保稳定顺序
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

    async def update_message(
        self,
        message_id: str,
        content: str,
        structured_data: dict | None = None,
        data_type: str | None = None,
        update_timestamp: bool = True
    ) -> ChatMessage | None:
        """更新消息内容和结构化数据

        Args:
            message_id: 消息ID
            content: 消息内容
            structured_data: 结构化数据
            data_type: 数据类型
            update_timestamp: 是否更新时间戳（流式响应结束时设置为True）
        """
        result = await self.db.execute(
            select(ChatMessage).where(ChatMessage.id == message_id)
        )
        message = result.scalar_one_or_none()

        if message:
            message.content = content
            if structured_data is not None:
                message.structured_data = structured_data
            if data_type is not None:
                message.data_type = data_type
            # 流式响应结束时更新时间戳，确保created_at反映消息完成时间
            if update_timestamp:
                message.created_at = datetime.utcnow()
            await self.db.commit()
            await self.db.refresh(message)

        return message

    async def create_generated_plan(self, user_id: str, data: ChatGeneratedPlanCreate) -> ChatGeneratedPlan:
        """
        创建生成的训练计划

        Args:
            user_id: 用户ID
            data: 计划数据

        Returns:
            ChatGeneratedPlan: 创建的计划
        """
        plan = ChatGeneratedPlan(
            id=str(uuid.uuid4()),
            user_id=user_id,
            session_id=data.session_id,
            message_id=data.message_id,
            title=data.title,
            subtitle=data.subtitle,
            total_duration=data.total_duration,
            scene=data.scene,
            rpe=data.rpe,
            ai_note=data.ai_note,
            modules=data.modules,
            response_status="pending",
            generated_at=data.generated_at or datetime.utcnow(),
        )
        self.db.add(plan)
        await self.db.commit()
        await self.db.refresh(plan)
        return plan

    async def get_session_generated_plans(self, user_id: str, session_id: str) -> List[ChatGeneratedPlan]:
        """
        获取会话中生成的所有计划

        Args:
            user_id: 用户ID
            session_id: 会话ID

        Returns:
            List[ChatGeneratedPlan]: 计划列表
        """
        from sqlalchemy import and_
        result = await self.db.execute(
            select(ChatGeneratedPlan)
            .where(
                and_(
                    ChatGeneratedPlan.user_id == user_id,
                    ChatGeneratedPlan.session_id == session_id,
                )
            )
            .order_by(desc(ChatGeneratedPlan.generated_at))
        )
        return result.scalars().all()

    async def update_generated_plan_response(
        self, user_id: str, plan_db_id: str, response_status: str
    ) -> ChatGeneratedPlan:
        """
        更新计划响应状态

        Args:
            user_id: 用户ID
            plan_db_id: 计划在数据库中的ID
            response_status: 响应状态 (confirmed/rejected)

        Returns:
            ChatGeneratedPlan: 更新后的计划

        Raises:
            HTTPException: 计划不存在时抛出404错误
        """
        from sqlalchemy import and_
        result = await self.db.execute(
            select(ChatGeneratedPlan).where(
                and_(
                    ChatGeneratedPlan.id == plan_db_id,
                    ChatGeneratedPlan.user_id == user_id,
                )
            )
        )
        plan = result.scalar_one_or_none()
        if not plan:
            raise HTTPException(status_code=404, detail="计划不存在")

        plan.response_status = response_status
        plan.responded_at = datetime.utcnow()
        await self.db.commit()
        await self.db.refresh(plan)
        return plan

    async def get_message_plan_ids(self, message_id: str) -> List[str]:
        """
        获取消息关联的训练计划数据库ID列表

        Args:
            message_id: 消息ID

        Returns:
            List[str]: 计划数据库ID列表（id 字段）
        """
        result = await self.db.execute(
            select(ChatGeneratedPlan.id)
            .where(ChatGeneratedPlan.message_id == message_id)
            .order_by(ChatGeneratedPlan.generated_at)
        )
        return [row[0] for row in result.all()]
