"""聊天Agent - 使用LangGraph构建"""
import json
import logging
import re
from typing import AsyncGenerator
from datetime import datetime

from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END

from app.agents.state import ChatAgentState
from app.agents.prompts import build_system_prompt
from app.core.config import settings

logger = logging.getLogger(__name__)


class ChatAgent:
    """聊天对话Agent"""

    def __init__(self):
        # 检查配置
        if not settings.OPENAI_API_KEY:
            logger.error("OPENAI_API_KEY 未配置")
            raise ValueError("OPENAI_API_KEY 未配置，请在 .env 文件中设置")

        logger.info(f"初始化 ChatAgent，模型: {settings.OPENAI_MODEL}, base_url: {settings.OPENAI_BASE_URL}")

        try:
            self.llm = ChatOpenAI(
                model=settings.OPENAI_MODEL,
                api_key=settings.OPENAI_API_KEY,
                base_url=settings.OPENAI_BASE_URL if settings.OPENAI_BASE_URL else None,
                temperature=settings.OPENAI_TEMPERATURE,
                max_tokens=settings.OPENAI_MAX_TOKENS,
                streaming=True,
            )
            logger.info("ChatAgent 初始化成功")
        except Exception as e:
            logger.error(f"ChatAgent 初始化失败: {e}")
            raise

    # 最大历史消息数
    MAX_HISTORY_MESSAGES = 20

    def _build_messages(
        self,
        user_message: str,
        user_profile: dict | None = None,
        history: list[dict] | None = None,
        context_summary: str | None = None,
        recent_memories: list[str] | None = None
    ) -> list:
        """
        构建消息列表

        Args:
            user_message: 用户消息
            user_profile: 用户画像
            history: 历史消息列表
            context_summary: 会话上下文摘要
            recent_memories: 近期跨会话记忆
        """
        messages = []

        # 系统提示词（包含上下文摘要和记忆）
        system_prompt = build_system_prompt(
            user_profile=user_profile,
            context_summary=context_summary,
            recent_memories=recent_memories
        )
        messages.append(SystemMessage(content=system_prompt))

        # 历史消息（增加到20条）
        if history:
            # 优先保留最近的消息
            recent_history = history[-self.MAX_HISTORY_MESSAGES:]

            for msg in recent_history:
                role = msg.get("role")
                content = msg.get("content", "")

                # 跳过系统消息和空消息
                if role == "system" or not content.strip():
                    continue

                # 截断过长的历史消息
                if len(content) > 1000:
                    content = content[:1000] + "..."

                if role == "user":
                    messages.append(HumanMessage(content=content))
                elif role == "assistant":
                    messages.append(AIMessage(content=content))

        # 当前用户消息
        messages.append(HumanMessage(content=user_message))

        return messages

    def _estimate_tokens(self, messages: list) -> int:
        """估算消息列表的token数（粗略估算）"""
        total_chars = sum(
            len(msg.content) if hasattr(msg, 'content') else 0
            for msg in messages
        )
        # 中文约1字1token，英文约4字符1token，这里取平均值
        return int(total_chars * 0.8)

    def _extract_workout_plan(self, response: str) -> dict | None:
        """从响应中提取训练计划"""
        # 尝试匹配 ```json ... ``` 代码块
        json_match = re.search(r'```(?:json)?\s*\n?(.*?)\n?```', response, re.DOTALL)
        if json_match:
            json_str = json_match.group(1).strip()
        else:
            # 尝试直接匹配 {...}
            json_match = re.search(r'\{[\s\S]*\}', response)
            if json_match:
                json_str = json_match.group(0)
            else:
                return None

        try:
            data = json.loads(json_str)
            # 验证是否为训练计划结构
            if "modules" in data and "total_duration" in data:
                return data
            return None
        except json.JSONDecodeError:
            return None

    async def chat_stream(
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
        流式聊天

        Args:
            user_id: 用户ID
            session_id: 会话ID
            user_message: 用户消息
            user_profile: 用户画像
            history: 历史消息
            context_summary: 会话上下文摘要
            recent_memories: 近期跨会话记忆

        Yields:
            dict: 包含类型和数据的字典
            - {"type": "chunk", "content": "文本块"}
            - {"type": "plan", "plan": {...}}  # 如果包含训练计划
            - {"type": "done", "content": "完整内容", "has_plan": bool}
        """
        messages = self._build_messages(
            user_message=user_message,
            user_profile=user_profile,
            history=history,
            context_summary=context_summary,
            recent_memories=recent_memories
        )
        estimated_tokens = self._estimate_tokens(messages)
        logger.info(f"开始流式聊天，用户: {user_id}, 消息数: {len(messages)}, 预估token: {estimated_tokens}")

        try:
            full_content = ""
            chunk_count = 0

            async for chunk in self.llm.astream(messages):
                if chunk.content:
                    full_content += chunk.content
                    chunk_count += 1
                    yield {
                        "type": "chunk",
                        "content": chunk.content
                    }

            logger.info(f"流式生成完成，共 {chunk_count} 个块，总长度 {len(full_content)}")

            # 检查是否包含训练计划
            plan = self._extract_workout_plan(full_content)

            if plan:
                plan["generated_at"] = datetime.utcnow().isoformat()
                plan["generated_by"] = "ai"

                yield {
                    "type": "plan",
                    "plan": plan
                }

            yield {
                "type": "done",
                "content": full_content,
                "has_plan": plan is not None
            }

        except Exception as e:
            import traceback
            error_detail = traceback.format_exc()
            logger.error(f"流式聊天出错: {e}\n{error_detail}")
            yield {
                "type": "error",
                "message": f"聊天处理出错: {type(e).__name__}: {str(e)}"
            }

    async def chat_sync(
        self,
        user_id: str,
        session_id: str,
        user_message: str,
        user_profile: dict | None = None,
        history: list[dict] | None = None,
        context_summary: str | None = None,
        recent_memories: list[str] | None = None
    ) -> dict:
        """
        同步聊天（非流式）

        Args:
            user_id: 用户ID
            session_id: 会话ID
            user_message: 用户消息
            user_profile: 用户画像
            history: 历史消息
            context_summary: 会话上下文摘要
            recent_memories: 近期跨会话记忆

        Returns:
            dict: 包含完整响应的字典
        """
        chunks = []
        plan = None
        error = None

        async for item in self.chat_stream(
            user_id=user_id,
            session_id=session_id,
            user_message=user_message,
            user_profile=user_profile,
            history=history,
            context_summary=context_summary,
            recent_memories=recent_memories
        ):
            if item["type"] == "chunk":
                chunks.append(item["content"])
            elif item["type"] == "plan":
                plan = item["plan"]
            elif item["type"] == "error":
                error = item["message"]

        content = "".join(chunks)

        if error:
            return {
                "success": False,
                "error": error
            }

        return {
            "success": True,
            "content": content,
            "plan": plan,
            "has_plan": plan is not None
        }

    async def chat_stream_continue(
        self,
        user_id: str,
        session_id: str,
        existing_content: str,
        user_profile: dict | None = None,
        history: list[dict] | None = None,
        context_summary: str | None = None,
        recent_memories: list[str] | None = None
    ) -> AsyncGenerator[dict, None]:
        """
        继续之前的流式生成

        当应用从后台恢复时，继续生成剩余内容

        Args:
            user_id: 用户ID
            session_id: 会话ID
            existing_content: 已有的内容（前端已接收的部分）
            user_profile: 用户画像
            history: 历史消息
            context_summary: 会话上下文摘要
            recent_memories: 近期跨会话记忆

        Yields:
            dict: 包含类型和数据的字典
        """
        messages = []

        # 系统提示词
        system_prompt = build_system_prompt(
            user_profile=user_profile,
            context_summary=context_summary,
            recent_memories=recent_memories
        )
        messages.append(SystemMessage(content=system_prompt))

        # 历史消息
        if history:
            recent_history = history[-self.MAX_HISTORY_MESSAGES:]
            for msg in recent_history:
                role = msg.get("role")
                content = msg.get("content", "")
                if role == "system" or not content.strip():
                    continue
                if len(content) > 1000:
                    content = content[:1000] + "..."
                if role == "user":
                    messages.append(HumanMessage(content=content))
                elif role == "assistant":
                    messages.append(AIMessage(content=content))

        # 添加一个特殊消息，告诉 LLM 之前已经生成了什么
        continuation_prompt = (
            f"[继续生成]\n"
            f"之前的回复已经生成了以下内容：\n\n"
            f"{existing_content}\n\n"
            f"请继续生成剩余的回复内容。如果之前的回复已经完整，请回复'继续内容已结束'。"
        )
        messages.append(HumanMessage(content=continuation_prompt))

        estimated_tokens = self._estimate_tokens(messages)
        logger.info(f"继续流式聊天，用户: {user_id}, 消息数: {len(messages)}, 预估token: {estimated_tokens}")

        try:
            chunk_count = 0

            async for chunk in self.llm.astream(messages):
                if chunk.content:
                    # 检查是否是"继续内容已结束"的响应
                    if chunk.content.strip() in ["继续内容已结束", "continue", "END"]:
                        logger.info("检测到继续内容已结束")
                        break

                    chunk_count += 1
                    yield {
                        "type": "chunk",
                        "content": chunk.content
                    }

            logger.info(f"继续生成完成，共 {chunk_count} 个块")

            yield {
                "type": "done",
                "has_plan": False
            }

        except Exception as e:
            import traceback
            error_detail = traceback.format_exc()
            logger.error(f"继续生成出错: {e}\n{error_detail}")
            yield {
                "type": "error",
                "message": f"继续生成出错: {type(e).__name__}: {str(e)}"
            }
