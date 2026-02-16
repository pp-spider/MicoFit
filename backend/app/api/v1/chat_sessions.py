"""聊天会话 API 端点"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.services.chat_service import ChatService
from app.schemas.chat import (
    ChatSessionSchema,
    ChatMessageSchema,
    ChatSessionCreateRequest,
    ChatSessionRenameRequest,
)
from pydantic import BaseModel


class GenerateTitleRequest(BaseModel):
    """生成标题请求"""
    first_message: str

router = APIRouter(prefix="/chat-sessions", tags=["聊天会话"])


@router.get("", response_model=List[ChatSessionSchema])
async def get_sessions(
    limit: int = Query(default=50, ge=1, le=100, description="限制返回数量"),
    offset: int = Query(default=0, ge=0, description="偏移量"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取用户的会话列表（按更新时间倒序）

    Returns:
        List[ChatSessionSchema]: 会话列表
    """
    service = ChatService(db)
    sessions = await service.get_user_sessions(
        user_id=str(current_user.id),
        limit=limit,
        offset=offset,
    )

    # 转换为 Schema 格式
    return [
        ChatSessionSchema(
            id=str(s.id),
            title=s.title,
            message_count=s.message_count,
            created_at=s.created_at,
            updated_at=s.updated_at,
        )
        for s in sessions
    ]


@router.get("/{session_id}", response_model=ChatSessionSchema)
async def get_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取单个会话详情

    Args:
        session_id: 会话ID

    Returns:
        ChatSessionSchema: 会话详情
    """
    service = ChatService(db)
    session = await service.get_session(session_id)

    # 验证会话属于当前用户
    if not session or str(session.user_id) != str(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在或无权访问"
        )

    return ChatSessionSchema(
        id=str(session.id),
        title=session.title,
        message_count=session.message_count,
        created_at=session.created_at,
        updated_at=session.updated_at,
    )


@router.get("/{session_id}/messages", response_model=List[ChatMessageSchema])
async def get_session_messages(
    session_id: str,
    limit: int = Query(default=100, ge=1, le=200, description="限制返回数量"),
    offset: int = Query(default=0, ge=0, description="偏移量"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取会话的消息历史

    Args:
        session_id: 会话ID
        limit: 限制返回数量
        offset: 偏移量

    Returns:
        List[ChatMessageSchema]: 消息列表
    """
    service = ChatService(db)

    # 验证会话归属
    session = await service.get_session(session_id)
    if not session or str(session.user_id) != str(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在或无权访问"
        )

    messages = await service.get_session_messages(
        session_id=session_id,
        limit=limit,
        offset=offset,
    )

    return [
        ChatMessageSchema(
            id=str(m.id),
            role=m.role,
            content=m.content,
            structured_data=m.structured_data,
            data_type=m.data_type,
            created_at=m.created_at,
        )
        for m in messages
    ]


@router.post("", response_model=ChatSessionSchema, status_code=status.HTTP_201_CREATED)
async def create_session(
    request: ChatSessionCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    创建新会话

    Args:
        request: 创建请求，包含可选的标题

    Returns:
        ChatSessionSchema: 创建的会话
    """
    service = ChatService(db)
    session = await service.create_session(
        user_id=str(current_user.id),
        title=request.title or "新对话",
    )

    return ChatSessionSchema(
        id=str(session.id),
        title=session.title,
        message_count=session.message_count,
        created_at=session.created_at,
        updated_at=session.updated_at,
    )


@router.patch("/{session_id}", response_model=ChatSessionSchema)
async def rename_session(
    session_id: str,
    request: ChatSessionRenameRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    重命名会话

    Args:
        session_id: 会话ID
        request: 重命名请求

    Returns:
        ChatSessionSchema: 更新后的会话
    """
    service = ChatService(db)

    # 验证会话归属
    session = await service.get_session(session_id)
    if not session or str(session.user_id) != str(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在或无权访问"
        )

    updated_session = await service.update_session_title(
        session_id=session_id,
        title=request.title,
    )

    return ChatSessionSchema(
        id=str(updated_session.id),
        title=updated_session.title,
        message_count=updated_session.message_count,
        created_at=updated_session.created_at,
        updated_at=updated_session.updated_at,
    )


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    删除会话

    Args:
        session_id: 会话ID

    Returns:
        204 No Content
    """
    service = ChatService(db)

    # 验证会话归属
    session = await service.get_session(session_id)
    if not session or str(session.user_id) != str(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在或无权访问"
        )

    success = await service.delete_session(session_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="删除会话失败"
        )

    return None


@router.post("/{session_id}/generate-title", response_model=ChatSessionSchema)
async def generate_session_title(
    session_id: str,
    request: GenerateTitleRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    基于用户首条消息自动生成会话标题

    Args:
        session_id: 会话ID
        request: 生成标题请求，包含用户的第一条消息

    Returns:
        ChatSessionSchema: 更新后的会话
    """
    from app.services.context_service import ContextService

    # 初始化 ChatService
    service = ChatService(db)

    first_message = request.first_message

    # 验证会话归属
    session = await service.get_session(session_id)
    if not session or str(session.user_id) != str(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在或无权访问"
        )

    # 如果已有标题且不是默认标题，则不覆盖
    if session.title and session.title != "新对话":
        return ChatSessionSchema(
            id=str(session.id),
            title=session.title,
            message_count=session.message_count,
            created_at=session.created_at,
            updated_at=session.updated_at,
        )

    # 生成新标题
    context_service = ContextService(db)
    new_title = await context_service.generate_session_title(session_id, first_message)

    # 更新会话标题
    session.title = new_title
    await db.commit()
    await db.refresh(session)

    return ChatSessionSchema(
        id=str(session.id),
        title=session.title,
        message_count=session.message_count,
        created_at=session.created_at,
        updated_at=session.updated_at,
    )
