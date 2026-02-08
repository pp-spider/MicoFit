"""AI API 端点 - 流式聊天"""
import json
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sse_starlette.sse import EventSourceResponse

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.services.ai_service import AIService
from app.services.context_service import ContextService
from app.schemas.chat import ChatStreamRequest, ChatStreamChunk

router = APIRouter(prefix="/ai", tags=["AI"])


@router.post("/chat/stream")
async def chat_stream(
    request: ChatStreamRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    流式聊天（SSE）

    支持以下事件类型：
    - chunk: 文本流块
    - plan: 包含生成的训练计划
    - done: 完成
    - error: 错误
    - session_created: 新会话创建
    """
    service = AIService(db)

    async def event_generator():
        async for chunk in service.stream_chat(
            user_id=str(current_user.id),
            session_id=request.session_id,
            message=request.message
        ):
            yield {
                "event": chunk.get("type", "chunk"),
                "data": json.dumps(chunk, ensure_ascii=False, default=str)
            }

    return EventSourceResponse(
        event_generator(),
        media_type="text/event-stream"
    )


@router.post("/workouts/generate/stream")
async def generate_workout_stream(
    preferences: dict | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    流式生成训练计划（SSE）

    支持以下事件类型：
    - chunk: 文本流块
    - plan: 生成的训练计划
    - saved: 计划已保存到数据库
    - error: 错误
    - done: 完成
    """
    service = AIService(db)

    async def event_generator():
        async for chunk in service.stream_generate_workout_plan(
            user_id=str(current_user.id),
            preferences=preferences
        ):
            yield {
                "event": chunk.get("type", "chunk"),
                "data": json.dumps(chunk, ensure_ascii=False, default=str)
            }

    return EventSourceResponse(
        event_generator(),
        media_type="text/event-stream"
    )


@router.post("/workouts/generate")
async def generate_workout(
    preferences: dict | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    生成训练计划（非流式）

    直接返回生成的计划
    """
    service = AIService(db)
    result = await service.generate_workout_plan(
        user_id=str(current_user.id),
        preferences=preferences
    )

    if not result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=result.get("error", "生成计划失败")
        )

    return result


@router.get("/chat/sessions/{session_id}/context")
async def get_session_context(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取会话上下文信息

    包括：
    - 会话摘要
    - 预估token数
    - 近期主题
    """
    from app.services.chat_service import ChatService

    # 验证会话归属
    chat_service = ChatService(db)
    session = await chat_service.get_session(session_id)
    if not session or str(session.user_id) != str(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在或无权访问"
        )

    context_service = ContextService(db)
    context = await context_service.get_context_for_chat(
        session_id=session_id
    )

    return {
        "session_id": session_id,
        "title": context.get("session_title"),
        "summary": context.get("summary"),
        "total_tokens": context.get("total_tokens"),
        "message_count": len(context.get("recent_messages", [])),
    }


@router.get("/chat/user-memory")
async def get_user_memory(
    days: int = 7,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取用户近期记忆（跨会话）

    包括：
    - 近期会话主题
    - 生成的计划数
    - 会话数量统计
    """
    context_service = ContextService(db)
    memory = await context_service.get_user_memory(
        user_id=str(current_user.id),
        days=days
    )

    return {
        "user_id": str(current_user.id),
        "days": days,
        "memory": memory
    }


@router.post("/chat/sessions/{session_id}/regenerate-summary")
async def regenerate_session_summary(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    重新生成会话摘要

    手动触发会话摘要的重新生成
    """
    from app.services.chat_service import ChatService

    # 验证会话归属
    chat_service = ChatService(db)
    session = await chat_service.get_session(session_id)
    if not session or str(session.user_id) != str(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在或无权访问"
        )

    context_service = ContextService(db)

    # 获取所有消息并重新生成摘要
    messages_result = await chat_service.get_session_messages(session_id, limit=100)
    messages = [
        {"role": msg.role, "content": msg.content}
        for msg in messages_result
    ]

    summary = await context_service.summarizer.summarize_messages(messages)
    await context_service._update_session_summary(session_id, summary)

    return {
        "session_id": session_id,
        "summary": summary,
        "message_count": len(messages)
    }
