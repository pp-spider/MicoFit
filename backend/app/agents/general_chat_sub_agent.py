"""GeneralChatSubAgent - 处理通用闲聊

专注于非健身主题的日常生活闲聊、情感交流。
实现 BaseSubAgent 接口，供 PlannerAgent 调用。
"""
import logging
from typing import AsyncGenerator

from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END

from app.agents.base_sub_agent import BaseSubAgent
from app.agents.state import ChatSubAgentState
from app.agents.prompts import build_general_chat_prompt
from app.core.config import settings

logger = logging.getLogger(__name__)


class GeneralChatSubAgent(BaseSubAgent):
    """
    GeneralChatSubAgent - 处理通用闲聊

    职责：
    - 日常生活话题闲聊（天气、电影、音乐等）
    - 情感交流与倾听
    - 轻松幽默的对话
    - 当话题涉及健身时，友好地引导用户使用健身咨询功能

    Attributes:
        llm: 大语言模型
        workflow: LangGraph 工作流图
    """

    def __init__(self):
        print("\n" + "─"*50)
        print("🌟 GeneralChatSubAgent 初始化完成")
        print("─"*50 + "\n")

        self.llm = ChatOpenAI(
            model=settings.OPENAI_MODEL,
            api_key=settings.OPENAI_API_KEY,
            base_url=settings.OPENAI_BASE_URL if settings.OPENAI_BASE_URL else None,
            temperature=settings.OPENAI_TEMPERATURE,
            max_tokens=settings.OPENAI_MAX_TOKENS,
            streaming=True,
        )

        self.workflow = self._build_workflow()
        logger.info("GeneralChatSubAgent 初始化完成")

    def _build_workflow(self) -> StateGraph:
        """
        构建工作流图

        节点：
        - build_prompt: 构建提示词
        - generate: 生成响应
        - post_process: 后处理

        Returns:
            StateGraph: 编译后的工作流图
        """
        workflow = StateGraph(ChatSubAgentState)

        workflow.add_node("build_prompt", self._build_prompt_node)
        workflow.add_node("generate", self._generate_node)
        workflow.add_node("post_process", self._post_process_node)

        workflow.set_entry_point("build_prompt")
        workflow.add_edge("build_prompt", "generate")
        workflow.add_edge("generate", "post_process")
        workflow.add_edge("post_process", END)

        return workflow.compile()

    def _build_prompt_node(self, state: ChatSubAgentState) -> dict:
        """
        构建提示词节点

        Args:
            state: 当前状态

        Returns:
            dict: 更新后的状态，包含 messages
        """
        messages = []

        # 1. 系统提示词（必须是第一条消息）
        system_prompt = build_general_chat_prompt(
            user_profile=state.get("user_profile"),
            context_summary=state.get("context_summary"),
            recent_memories=state.get("recent_memories")
        )
        messages.append(SystemMessage(content=system_prompt))

        # 2. 历史消息（最多20条）
        history = state.get("history", [])
        if history:
            # 确保按时间顺序排列，取最近20条
            recent_history = history[-20:] if len(history) > 20 else history
            for msg in recent_history:
                role = msg.get("role")
                content = msg.get("content", "")
                if role == "user":
                    messages.append(HumanMessage(content=content))
                elif role == "assistant":
                    messages.append(AIMessage(content=content))

        # 3. 当前用户消息
        messages.append(HumanMessage(content=state["user_message"]))

        return {
            **state,
            "messages": messages
        }

    async def _generate_node(self, state: ChatSubAgentState) -> dict:
        """
        生成响应节点

        注意：实际流式生成在外层的 stream() 方法中处理

        Args:
            state: 当前状态

        Returns:
            dict: 状态（保持不变，实际生成在外层）
        """
        return state

    def _post_process_node(self, state: ChatSubAgentState) -> dict:
        """
        后处理节点

        Args:
            state: 当前状态

        Returns:
            dict: 更新后的状态
        """
        return state

    # ========== 公共接口 ==========

    @property
    def name(self) -> str:
        """SubAgent 名称"""
        return "general_chat_sub_agent"

    @property
    def description(self) -> str:
        """SubAgent 描述"""
        return "处理日常生活闲聊、情感交流、非健身主题对话"

    async def stream(self, state: ChatSubAgentState) -> AsyncGenerator[dict, None]:
        """
        流式处理接口

        Args:
            state: ChatSubAgentState

        Yields:
            dict: 流式响应块
            - {"type": "chunk", "content": "..."}
            - {"type": "done", "content": "...", "has_plan": False}
            - {"type": "error", "message": "..."}

        Example:
            async for chunk in general_chat_sub_agent.stream(state):
                if chunk["type"] == "chunk":
                    print(chunk["content"])
        """
        # 构建提示词
        state = self._build_prompt_node(state)
        messages = state["messages"]

        try:
            # 美化输出开始
            print("\n" + "─"*50)
            print("🌟 GeneralChatSubAgent 正在处理对话...")
            print("─"*50 + "\n")

            full_content = ""

            async for chunk in self.llm.astream(messages):
                if chunk.content:
                    full_content += chunk.content
                    yield {
                        "type": "chunk",
                        "content": chunk.content
                    }

            yield {
                "type": "done",
                "content": full_content,
                "has_plan": False
            }

            # 美化输出完成
            print("\n" + "─"*50)
            print("✅ GeneralChatSubAgent 对话完成")
            print(f"   响应长度: {len(full_content)} 字符")
            print("─"*50 + "\n")

        except Exception as e:
            logger.error(f"GeneralChatSubAgent 生成失败: {e}")
            yield {
                "type": "error",
                "message": f"生成响应时出错: {str(e)}"
            }

    async def process(self, state: ChatSubAgentState) -> dict:
        """
        同步处理接口

        Args:
            state: ChatSubAgentState

        Returns:
            dict: 完整处理结果
            - {"success": True, "content": "..."}
            - {"success": False, "error": "..."}
        """
        chunks = []
        async for chunk in self.stream(state):
            if chunk["type"] == "chunk":
                chunks.append(chunk["content"])
            elif chunk["type"] == "error":
                return {
                    "success": False,
                    "error": chunk.get("message")
                }

        return {
            "success": True,
            "content": "".join(chunks)
        }
