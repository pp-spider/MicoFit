"""RouterAgent - 主代理，负责意图识别和路由分发

使用 LangGraph StateGraph 构建工作流：
intent_recognition -> route -> [chat_sub_agent | workout_sub_agent] -> finalize
"""
import json
import logging
import re
from typing import AsyncGenerator
from datetime import datetime

from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END

from app.agents.state import RouterState
from app.agents.prompts import build_intent_recognition_prompt
from app.agents.chat_sub_agent import ChatSubAgent
from app.agents.workout_sub_agent import WorkoutSubAgent
from app.core.config import settings

logger = logging.getLogger(__name__)


def log_agent_flow(title: str, content: str, agent_type: str = "🤖") -> None:
    """美化打印 Agent 执行过程"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    colors = {
        "ROUTER": "\033[94m",    # 蓝色
        "CHAT": "\033[92m",       # 绿色
        "WORKOUT": "\033[93m",   # 黄色
        "INTENT": "\033[96m",     # 青色
        "END": "\033[0m"         # 重置
    }
    color = colors.get(agent_type.upper(), "\033[0m")
    print(f"{color}{agent_type} [{timestamp}] {title}\033[0m")
    for line in content.split('\n'):
        print(f"   {line}")


class RouterAgent:
    """
    RouterAgent - 主代理，负责意图识别和路由分发

    工作流程：
    1. 接收用户消息
    2. 使用 LLM 进行意图识别
    3. 根据意图路由到对应的 SubAgent
    4. 收集 SubAgent 结果并返回

    Attributes:
        llm: 用于意图识别的大语言模型
        chat_sub_agent: 普通对话 SubAgent
        workout_sub_agent: 训练计划生成 SubAgent
        workflow: LangGraph 工作流图
    """

    def __init__(self):
        if not settings.OPENAI_API_KEY:
            raise ValueError("OPENAI_API_KEY 未配置，请在 .env 文件中设置")

        print("\n" + "="*60)
        print("🚀 RouterAgent 初始化成功")
        print(f"   模型: {settings.OPENAI_MODEL}")
        print("="*60 + "\n")

        # 初始化意图识别 LLM（使用较低温度，更确定）
        self.llm = ChatOpenAI(
            model=settings.OPENAI_MODEL,
            api_key=settings.OPENAI_API_KEY,
            base_url=settings.OPENAI_BASE_URL if settings.OPENAI_BASE_URL else None,
            temperature=0.3,  # 意图识别使用较低温度
            max_tokens=500,
        )

        # 初始化 SubAgents
        self.chat_sub_agent = ChatSubAgent()
        self.workout_sub_agent = WorkoutSubAgent()

        # 构建工作流图
        self.workflow = self._build_workflow()
        print("✅ SubAgents 加载完成: ChatSubAgent, WorkoutSubAgent")
        print("="*60 + "\n")

    def _build_workflow(self) -> StateGraph:
        """
        构建 RouterAgent 工作流图

        节点：
        - intent_recognition: 意图识别
        - route: 路由决策
        - chat_sub_agent: 调用 ChatSubAgent
        - workout_sub_agent: 调用 WorkoutSubAgent
        - finalize: 结果整理

        边：
        - 条件边：根据 intent 路由到不同 SubAgent
        """
        workflow = StateGraph(RouterState)

        # ========== 添加节点 ==========
        workflow.add_node("intent_recognition", self._intent_recognition_node)
        workflow.add_node("route", self._route_node)
        workflow.add_node("chat_sub_agent", self._chat_sub_agent_node)
        workflow.add_node("workout_sub_agent", self._workout_sub_agent_node)
        workflow.add_node("finalize", self._finalize_node)

        # ========== 定义边 ==========
        # 入口 → 意图识别
        workflow.set_entry_point("intent_recognition")

        # 意图识别 → 路由决策
        workflow.add_edge("intent_recognition", "route")

        # 路由决策 → 条件边（根据 intent 路由）
        workflow.add_conditional_edges(
            "route",
            self._get_next_node,
            {
                "chat_sub_agent": "chat_sub_agent",
                "workout_sub_agent": "workout_sub_agent",
                "end": END
            }
        )

        # SubAgents → 结果整理
        workflow.add_edge("chat_sub_agent", "finalize")
        workflow.add_edge("workout_sub_agent", "finalize")

        # 结果整理 → 结束
        workflow.add_edge("finalize", END)

        return workflow.compile()

    # ========== 节点实现 ==========

    async def _intent_recognition_node(self, state: RouterState) -> dict:
        """
        意图识别节点 - 使用 LLM 进行智能意图识别

        Args:
            state: 当前状态

        Returns:
            dict: 更新后的状态，包含 intent, confidence, entities
        """
        user_message = state["user_message"]
        user_profile = state.get("user_profile")

        # 构建意图识别提示词
        prompt = build_intent_recognition_prompt(user_message, user_profile)

        messages = [
            SystemMessage(content=prompt),
            HumanMessage(content=user_message)
        ]

        try:
            # 调用 LLM 进行意图识别
            response = await self.llm.ainvoke(messages)
            content = response.content

            # 解析 LLM 响应
            intent_data = self._parse_intent_response(content)

            # 美化输出意图识别结果
            entities = intent_data.get('entities', {})
            print("\n" + "─"*50)
            print("🔍 意图识别完成")
            print(f"   意图: {intent_data['intent']} (置信度: {intent_data['confidence']:.0%})")
            print(f"   推理: {intent_data.get('reasoning', 'N/A')}")
            if entities:
                print("   实体:")
                for k, v in entities.items():
                    if v:
                        print(f"      - {k}: {v}")
            print("─"*50 + "\n")

            return {
                **state,
                "intent": intent_data["intent"],
                "intent_confidence": intent_data["confidence"],
                "intent_reasoning": intent_data.get("reasoning"),
                "entities": intent_data.get("entities", {}),
            }

        except Exception as e:
            logger.error(f"意图识别失败: {e}")
            # 失败时默认使用 chat 意图
            return {
                **state,
                "intent": "chat",
                "intent_confidence": 0.5,
                "intent_reasoning": f"意图识别出错，默认使用 chat: {str(e)}",
                "entities": {},
                "error_message": str(e)
            }

    def _route_node(self, state: RouterState) -> dict:
        """
        路由决策节点 - 基于意图确定路由目标

        Args:
            state: 当前状态

        Returns:
            dict: 更新后的状态，包含 route_to
        """
        intent = state.get("intent")
        confidence = state.get("intent_confidence", 0)

        # 低置信度时记录警告（未来可添加澄清逻辑）
        if confidence < 0.5:
            logger.warning(f"意图置信度较低: {confidence}, intent={intent}")

        # 映射意图到路由目标
        route_map = {
            "workout": "workout_sub_agent",
            "chat": "chat_sub_agent",
            "unknown": "chat_sub_agent"  # 未知意图默认走对话
        }

        route_to = route_map.get(intent, "chat_sub_agent")

        agent_name = "ChatSubAgent" if route_to == "chat_sub_agent" else "WorkoutSubAgent"
        print(f"📤 路由决策: → {agent_name}\n")

        return {
            **state,
            "route_to": route_to
        }

    async def _chat_sub_agent_node(self, state: RouterState) -> dict:
        """
        ChatSubAgent 调用节点

        Args:
            state: 当前状态

        Returns:
            dict: 更新后的状态，包含 sub_agent_result
        """
        from app.agents.state import ChatSubAgentState

        # 构建 ChatSubAgent 状态
        chat_state: ChatSubAgentState = {
            "messages": [],
            "user_id": state["user_id"],
            "session_id": state["session_id"],
            "user_profile": state.get("user_profile"),
            "user_message": state["user_message"],
            "history": state.get("history"),
            "context_summary": state.get("context_summary"),
            "recent_memories": state.get("recent_memories"),
            "response": None,
            "stream_chunks": [],
            "error_message": None
        }

        # 调用 ChatSubAgent（流式收集）
        chunks = []
        async for chunk in self.chat_sub_agent.stream(chat_state):
            chunks.append(chunk)

        # 收集结果
        result = self._collect_sub_agent_result(chunks)

        return {
            **state,
            "sub_agent_result": result,
            "stream_chunks": [c.get("content", "") for c in chunks if c.get("type") == "chunk"],
            "final_response": result.get("content", ""),
            "error_message": result.get("error")
        }

    async def _workout_sub_agent_node(self, state: RouterState) -> dict:
        """
        WorkoutSubAgent 调用节点

        Args:
            state: 当前状态

        Returns:
            dict: 更新后的状态，包含 sub_agent_result
        """
        from app.agents.state import WorkoutSubAgentState

        # 构建 WorkoutSubAgent 状态
        workout_state: WorkoutSubAgentState = {
            "messages": [],
            "user_id": state["user_id"],
            "user_profile": state.get("user_profile"),
            "extracted_preferences": state.get("entities", {}),
            "workout_plan": None,
            "plan_json_str": None,
            "validation_passed": False,
            "stream_chunks": [],
            "error_message": None
        }

        # 调用 WorkoutSubAgent（流式收集）
        chunks = []
        async for chunk in self.workout_sub_agent.stream(workout_state):
            chunks.append(chunk)

        # 收集结果
        result = self._collect_sub_agent_result(chunks)

        return {
            **state,
            "sub_agent_result": result,
            "stream_chunks": [c.get("content", "") for c in chunks if c.get("type") == "chunk"],
            "final_response": result.get("content", ""),
            "error_message": result.get("error")
        }

    def _finalize_node(self, state: RouterState) -> dict:
        """
        结果整理节点 - 统一输出格式

        Args:
            state: 当前状态

        Returns:
            dict: 最终状态
        """
        return {
            **state,
            "final_response": state.get("final_response") or "处理完成"
        }

    # ========== 条件边逻辑 ==========

    def _get_next_node(self, state: RouterState) -> str:
        """
        根据状态决定下一个节点

        Args:
            state: 当前状态

        Returns:
            str: 下一个节点名称
        """
        route_to = state.get("route_to")

        if route_to in ["chat_sub_agent", "workout_sub_agent"]:
            return route_to

        # 默认结束
        return "end"

    # ========== 辅助方法 ==========

    def _parse_intent_response(self, content: str) -> dict:
        """
        解析 LLM 的意图识别响应

        预期格式（JSON）：
        {
            "intent": "chat" | "workout",
            "confidence": 0.95,
            "reasoning": "用户要求生成训练计划...",
            "entities": {
                "focus_body_part": "legs",
                "scene": "office",
                "duration": 15
            }
        }

        Args:
            content: LLM 响应内容

        Returns:
            dict: 解析后的意图数据
        """
        # 尝试提取 JSON
        json_match = re.search(r'\{[\s\S]*\}', content)
        if json_match:
            try:
                data = json.loads(json_match.group(0))
                return {
                    "intent": data.get("intent", "chat"),
                    "confidence": data.get("confidence", 0.5),
                    "reasoning": data.get("reasoning", ""),
                    "entities": data.get("entities", {})
                }
            except json.JSONDecodeError:
                pass

        # 回退到关键词匹配
        content_lower = content.lower()
        if "workout" in content_lower or "计划" in content_lower:
            return {
                "intent": "workout",
                "confidence": 0.7,
                "reasoning": "通过关键词匹配识别",
                "entities": {}
            }

        return {
            "intent": "chat",
            "confidence": 0.5,
            "reasoning": "无法解析响应，默认使用 chat",
            "entities": {}
        }

    def _collect_sub_agent_result(self, chunks: list) -> dict:
        """
        收集 SubAgent 的流式结果

        Args:
            chunks: 流式响应块列表

        Returns:
            dict: 收集后的完整结果
        """
        content_parts = []
        plan = None
        error = None

        for chunk in chunks:
            chunk_type = chunk.get("type")
            if chunk_type == "chunk":
                content_parts.append(chunk.get("content", ""))
            elif chunk_type == "plan":
                plan = chunk.get("plan")
            elif chunk_type == "error":
                error = chunk.get("message")

        if error:
            return {
                "success": False,
                "error": error
            }

        return {
            "success": True,
            "content": "".join(content_parts),
            "plan": plan
        }

    # ========== 公共接口 ==========

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

        这是 RouterAgent 的主要入口，外部调用此方法处理用户消息。

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
            - {"type": "intent", "intent": "...", "confidence": 0.9, "entities": {...}}
            - {"type": "chunk", "content": "..."}
            - {"type": "plan", "plan": {...}}
            - {"type": "done", "has_plan": bool}
            - {"type": "error", "message": "..."}

        Example:
            async for chunk in router_agent.process(
                user_id="123",
                session_id="456",
                user_message="今天练什么"
            ):
                if chunk["type"] == "intent":
                    print(f"意图: {chunk['intent']}")
                elif chunk["type"] == "chunk":
                    print(chunk["content"])
                elif chunk["type"] == "plan":
                    print(f"计划: {chunk['plan']}")
        """
        # 初始化状态
        initial_state: RouterState = {
            "messages": [],
            "user_id": user_id,
            "session_id": session_id,
            "user_profile": user_profile,
            "user_message": user_message,
            "history": history,
            "context_summary": context_summary,
            "recent_memories": recent_memories,
            "intent": None,
            "intent_confidence": 0,
            "intent_reasoning": None,
            "entities": {},
            "route_to": None,
            "sub_agent_result": None,
            "stream_chunks": [],
            "final_response": None,
            "error_message": None,
            "should_retry": False
        }

        try:
            # 步骤1: 意图识别
            state = await self._intent_recognition_node(initial_state)

            yield {
                "type": "intent",
                "intent": state["intent"],
                "confidence": state["intent_confidence"],
                "reasoning": state["intent_reasoning"],
                "entities": state["entities"]
            }

            # 步骤2: 路由决策
            state = self._route_node(state)

            # 步骤3: 根据路由调用 SubAgent（流式）
            if state["route_to"] == "chat_sub_agent":
                async for chunk in self._stream_chat_sub_agent(state):
                    yield chunk
            elif state["route_to"] == "workout_sub_agent":
                async for chunk in self._stream_workout_sub_agent(state):
                    yield chunk
            else:
                yield {
                    "type": "error",
                    "message": "未知的路由目标"
                }

        except Exception as e:
            logger.error(f"RouterAgent 处理失败: {e}")
            yield {
                "type": "error",
                "message": f"处理消息时出错: {str(e)}"
            }

    async def _stream_chat_sub_agent(self, state: RouterState) -> AsyncGenerator[dict, None]:
        """流式调用 ChatSubAgent"""
        from app.agents.state import ChatSubAgentState

        chat_state: ChatSubAgentState = {
            "messages": [],
            "user_id": state["user_id"],
            "session_id": state["session_id"],
            "user_profile": state.get("user_profile"),
            "user_message": state["user_message"],
            "history": state.get("history"),
            "context_summary": state.get("context_summary"),
            "recent_memories": state.get("recent_memories"),
            "response": None,
            "stream_chunks": [],
            "error_message": None
        }

        async for chunk in self.chat_sub_agent.stream(chat_state):
            yield chunk

    async def _stream_workout_sub_agent(self, state: RouterState) -> AsyncGenerator[dict, None]:
        """流式调用 WorkoutSubAgent"""
        from app.agents.state import WorkoutSubAgentState

        workout_state: WorkoutSubAgentState = {
            "messages": [],
            "user_id": state["user_id"],
            "user_profile": state.get("user_profile"),
            "extracted_preferences": state.get("entities", {}),
            "workout_plan": None,
            "plan_json_str": None,
            "validation_passed": False,
            "stream_chunks": [],
            "error_message": None
        }

        async for chunk in self.workout_sub_agent.stream(workout_state):
            yield chunk
