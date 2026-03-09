"""AI API 端点 - 流式聊天"""
import json
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from sse_starlette.sse import EventSourceResponse

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.chat_session import ChatMessage
from app.services.ai_service import AIService
from app.services.context_service import ContextService
from app.schemas.chat import ChatStreamRequest, ChatStreamChunk, ChatContinueRequest

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

    async def sse_generator():
        """SSE 格式生成器 - 使用 EventSourceResponse 格式"""
        async for chunk in service.stream_chat(
            user_id=str(current_user.id),
            session_id=request.session_id,
            message=request.message
        ):
            # EventSourceResponse 格式：直接返回 dict，包含 event 和 data
            yield {
                "event": chunk.get("type", "chunk"),
                "data": json.dumps(chunk, ensure_ascii=False, default=str)
            }

    return EventSourceResponse(
        sse_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # 禁用 nginx 缓冲
        }
    )


@router.post("/chat/continue")
async def chat_continue(
    request: ChatContinueRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    继续之前的流式生成（SSE）

    当应用从后台恢复时，调用此接口继续生成剩余内容
    """
    service = AIService(db)

    async def event_generator():
        async for chunk in service.continue_stream_chat(
            user_id=str(current_user.id),
            session_id=request.session_id,
            existing_content=request.existing_content
        ):
            yield {
                "event": chunk.get("type", "chunk"),
                "data": json.dumps(chunk, ensure_ascii=False, default=str)
            }

    return EventSourceResponse(
        event_generator(),
        media_type="text/event-stream"
    )


# 注意：/workouts/generate/stream 和 /workouts/generate 接口已移除
# 请统一使用 /chat/stream 接口发送"生成计划"类消息
# 例如：发送 "请为我生成今日训练计划"


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
    await context_service.update_session_summary(session_id, summary)

    return {
        "session_id": session_id,
        "summary": summary,
        "message_count": len(messages)
    }


@router.get("/chat/messages")
async def get_chat_messages(
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取用户的聊天消息（用于数据同步）

    返回所有会话的消息列表
    """
    from app.services.chat_service import ChatService
    from datetime import datetime

    chat_service = ChatService(db)

    # 获取用户的所有会话
    sessions = await chat_service.get_user_sessions(str(current_user.id))

    all_messages = []
    for session in sessions:
        messages = await chat_service.get_session_messages(session.id, limit=limit)
        for msg in messages:
            # 获取消息关联的计划ID列表
            plan_ids = await chat_service.get_message_plan_ids(str(msg.id))
            all_messages.append({
                "id": str(msg.id),
                "session_id": str(msg.session_id),
                "role": msg.role,
                "content": msg.content,
                "data_type": msg.data_type,
                "structured_data": msg.structured_data,
                "tool_calls": msg.tool_calls,
                "tool_call_id": msg.tool_call_id,
                "plan_ids": plan_ids if plan_ids else None,
                "created_at": msg.created_at.isoformat() if msg.created_at else None,
            })

    # 按时间排序
    all_messages.sort(key=lambda x: x["created_at"] or "")

    return {"messages": all_messages}


@router.get("/chat/sessions/{session_id}/memory")
async def get_session_memory(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取会话的完整记忆信息

    包括：
    - 会话元数据（标题、创建时间、消息数）
    - 上下文摘要
    - 最近的消息历史（用于前端恢复对话）
    - 预估的token数
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

    # 获取上下文和消息
    context_service = ContextService(db)
    context = await context_service.get_context_for_chat(session_id=session_id)
    messages = await chat_service.get_session_messages(session_id, limit=50)

    # 构建消息列表（包含角色和内容）
    message_history = []
    for msg in messages:
        # 获取消息关联的计划ID列表
        plan_ids = await chat_service.get_message_plan_ids(str(msg.id))
        message_history.append({
            "id": str(msg.id),
            "role": msg.role,
            "content": msg.content,
            "data_type": msg.data_type,
            "plan_ids": plan_ids if plan_ids else None,
            "created_at": msg.created_at.isoformat() if msg.created_at else None,
        })

    return {
        "session": {
            "id": str(session.id),
            "title": session.title,
            "created_at": session.created_at.isoformat() if session.created_at else None,
            "updated_at": session.updated_at.isoformat() if session.updated_at else None,
            "message_count": session.message_count,
        },
        "memory": {
            "summary": context.get("summary", ""),
            "total_tokens": context.get("total_tokens", 0),
            "recent_topics": context.get("recent_topics", []),
        },
        "history": message_history,
    }


@router.get("/chat/sessions/{session_id}/messages")
async def get_session_messages_api(
    session_id: str,
    limit: int = 100,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取指定会话的消息列表

    用于前端恢复对话上下文
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

    messages = await chat_service.get_session_messages(
        session_id,
        limit=limit,
        offset=offset
    )

    # 构建消息列表，包含关联的计划ID
    messages_with_plan_ids = []
    for msg in messages:
        # 获取消息关联的计划ID列表
        plan_ids = await chat_service.get_message_plan_ids(str(msg.id))
        messages_with_plan_ids.append({
            "id": str(msg.id),
            "role": msg.role,
            "content": msg.content,
            "data_type": msg.data_type,
            "structured_data": msg.structured_data,
            "tool_calls": msg.tool_calls,
            "plan_ids": plan_ids if plan_ids else None,
            "created_at": msg.created_at.isoformat() if msg.created_at else None,
        })

    return {
        "session_id": session_id,
        "messages": messages_with_plan_ids,
        "total": session.message_count,
    }


@router.get("/chat/sessions/{session_id}/search")
async def search_session_messages(
    session_id: str,
    query: str = "",
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    搜索会话中的消息

    用于在历史记录中查找相关内容
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

    # 获取所有消息进行搜索
    messages = await chat_service.get_session_messages(session_id, limit=200)

    if not query:
        return {
            "session_id": session_id,
            "query": query,
            "results": [],
            "total": 0,
        }

    # 简单关键词匹配（可以后续升级为向量搜索）
    query_lower = query.lower()
    results = []
    for msg in messages:
        if msg.role in ["user", "assistant"] and query_lower in msg.content.lower():
            results.append({
                "id": str(msg.id),
                "role": msg.role,
                "content": msg.content,
                "data_type": msg.data_type,
                "created_at": msg.created_at.isoformat() if msg.created_at else None,
                # 返回匹配的部分及其上下文
                "snippet": _get_match_snippet(msg.content, query),
            })

    return {
        "session_id": session_id,
        "query": query,
        "results": results,
        "total": len(results),
    }


def _get_match_snippet(content: str, query: str, context_length: int = 50) -> str:
    """获取匹配的文本片段及其上下文"""
    query_lower = query.lower()
    content_lower = content.lower()
    pos = content_lower.find(query_lower)

    if pos == -1:
        return content[:100] + "..." if len(content) > 100 else content

    start = max(0, pos - context_length)
    end = min(len(content), pos + len(query) + context_length)

    snippet = content[start:end]
    if start > 0:
        snippet = "..." + snippet
    if end < len(content):
        snippet = snippet + "..."

    return snippet


@router.get("/chat/sessions/{session_id}/stats")
async def get_session_stats(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取会话统计信息

    包括消息数量、交互轮数、生成的计划数等
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

    # 获取消息统计
    messages = await chat_service.get_session_messages(session_id, limit=500)

    user_messages = [m for m in messages if m.role == "user"]
    assistant_messages = [m for m in messages if m.role == "assistant"]
    workout_plans = [m for m in messages if m.data_type == "workout_plan"]

    # 计算交互轮数（用户消息数）
    interaction_turns = len(user_messages)

    # 计算总消息长度
    total_chars = sum(len(m.content) for m in messages)

    return {
        "session_id": session_id,
        "stats": {
            "total_messages": len(messages),
            "user_messages": len(user_messages),
            "assistant_messages": len(assistant_messages),
            "interaction_turns": interaction_turns,
            "workout_plans_generated": len(workout_plans),
            "total_characters": total_chars,
            "avg_message_length": total_chars // len(messages) if messages else 0,
        },
        "session": {
            "title": session.title,
            "created_at": session.created_at.isoformat() if session.created_at else None,
            "updated_at": session.updated_at.isoformat() if session.updated_at else None,
            "has_summary": bool(session.context_summary),
        },
    }


@router.get("/chat/sessions/{session_id}/key-info")
async def get_session_key_info(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取会话中提取的关键信息

    包括讨论的主题、目标、生成的计划等
    用于个性化推荐和用户画像构建
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
    key_info = await context_service.extract_key_info_from_session(session_id)

    return {
        "session_id": session_id,
        "key_info": key_info,
    }


@router.get("/chat/sessions-summaries")
async def get_sessions_summaries(
    limit: int = 10,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取用户所有会话的摘要列表

    用于展示会话历史和快速切换
    """
    context_service = ContextService(db)
    summaries = await context_service.get_multi_session_summaries(
        user_id=str(current_user.id),
        limit=limit
    )

    return {
        "user_id": str(current_user.id),
        "sessions": summaries,
        "total": len(summaries),
    }


@router.get("/chat/memory/timeline")
async def get_memory_timeline(
    days: int = 30,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    获取用户记忆时间线

    按时间顺序展示所有会话和关键信息
    用于前端展示用户与AI的交互历史
    """
    from app.services.chat_service import ChatService
    from app.models.chat_session import ChatSession
    from sqlalchemy import and_

    # 获取时间范围内的所有会话
    cutoff_date = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=days)
    result = await db.execute(
        select(ChatSession)
        .where(
            and_(
                ChatSession.user_id == str(current_user.id),
                ChatSession.created_at >= cutoff_date
            )
        )
        .order_by(desc(ChatSession.created_at))
    )
    sessions = result.scalars().all()

    timeline = []
    for session in sessions:
        # 获取该会话的消息
        messages = await db.execute(
            select(ChatMessage)
            .where(ChatMessage.session_id == session.id)
            .order_by(ChatMessage.created_at)
        )
        message_list = messages.scalars().all()

        # 提取关键信息
        user_msgs = [m for m in message_list if m.role == "user"]
        first_message = user_msgs[0].content[:50] if user_msgs else ""
        workout_plans = [m for m in message_list if m.data_type == "workout_plan"]

        timeline.append({
            "session_id": session.id,
            "title": session.title,
            "first_message": first_message,
            "message_count": session.message_count,
            "workout_plans_count": len(workout_plans),
            "has_summary": bool(session.context_summary),
            "created_at": session.created_at.isoformat() if session.created_at else None,
            "updated_at": session.updated_at.isoformat() if session.updated_at else None,
        })

    return {
        "user_id": str(current_user.id),
        "days": days,
        "timeline": timeline,
        "total_sessions": len(timeline),
    }


from datetime import datetime
