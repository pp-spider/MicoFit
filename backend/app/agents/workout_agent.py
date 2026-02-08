"""训练计划生成Agent - 使用LangGraph构建"""
import json
import logging
import re
from typing import AsyncGenerator, Any
from datetime import datetime

from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END

from app.agents.state import WorkoutAgentState
from app.agents.prompts import build_workout_system_prompt
from app.core.config import settings

logger = logging.getLogger(__name__)


class WorkoutAgent:
    """训练计划生成Agent"""

    def __init__(self):
        if not settings.OPENAI_API_KEY:
            logger.error("OPENAI_API_KEY 未配置")
            raise ValueError("OPENAI_API_KEY 未配置，请在 .env 文件中设置")

        logger.info(f"初始化 WorkoutAgent，模型: {settings.OPENAI_MODEL}")

        try:
            self.llm = ChatOpenAI(
                model=settings.OPENAI_MODEL,
                api_key=settings.OPENAI_API_KEY,
                base_url=settings.OPENAI_BASE_URL if settings.OPENAI_BASE_URL else None,
                temperature=settings.OPENAI_TEMPERATURE,
                max_tokens=settings.OPENAI_MAX_TOKENS,
                streaming=True,
            )
            logger.info("WorkoutAgent 初始化成功")
        except Exception as e:
            logger.error(f"WorkoutAgent 初始化失败: {e}")
            raise

        self.workflow = self._build_workflow()

    def _build_workflow(self) -> StateGraph:
        """构建工作流图"""
        workflow = StateGraph(WorkoutAgentState)

        # 添加节点
        workflow.add_node("build_prompt", self._build_prompt_node)
        workflow.add_node("generate", self._generate_node)
        workflow.add_node("parse", self._parse_node)
        workflow.add_node("validate", self._validate_node)

        # 定义边
        workflow.set_entry_point("build_prompt")
        workflow.add_edge("build_prompt", "generate")
        workflow.add_edge("generate", "parse")
        workflow.add_edge("parse", "validate")

        # 条件边：验证失败则结束（返回错误）
        workflow.add_conditional_edges(
            "validate",
            self._should_retry,
            {
                "end": END,
                "retry": "build_prompt"
            }
        )

        return workflow.compile()

    def _build_prompt_node(self, state: WorkoutAgentState) -> dict:
        """构建提示词节点"""
        user_profile = state.get("user_profile")
        system_prompt = build_workout_system_prompt(user_profile)

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content="请为我生成今天的训练计划")
        ]

        return {
            **state,
            "messages": messages,
            "stream_chunks": [],
            "validation_passed": False,
            "error_message": None
        }

    async def _generate_node(self, state: WorkoutAgentState) -> dict:
        """生成节点（流式）"""
        messages = state["messages"]

        # 收集流式输出
        chunks = []
        async for chunk in self.llm.astream(messages):
            if chunk.content:
                chunks.append(chunk.content)

        full_response = "".join(chunks)

        return {
            **state,
            "messages": messages + [AIMessage(content=full_response)],
            "stream_chunks": chunks,
            "plan_json_str": full_response
        }

    def _parse_node(self, state: WorkoutAgentState) -> dict:
        """解析节点 - 从响应中提取JSON"""
        response = state.get("plan_json_str", "")

        # 尝试提取JSON代码块
        json_data = self._extract_json_from_response(response)

        return {
            **state,
            "workout_plan": json_data
        }

    def _validate_node(self, state: WorkoutAgentState) -> dict:
        """验证节点"""
        plan = state.get("workout_plan")

        if not plan:
            return {
                **state,
                "validation_passed": False,
                "error_message": "未能从响应中解析出训练计划"
            }

        # 验证必要字段
        required_fields = ["id", "title", "modules", "total_duration", "scene", "rpe"]
        for field in required_fields:
            if field not in plan:
                return {
                    **state,
                    "validation_passed": False,
                    "error_message": f"训练计划缺少必要字段: {field}"
                }

        # 验证模块
        modules = plan.get("modules", [])
        if not modules or len(modules) == 0:
            return {
                **state,
                "validation_passed": False,
                "error_message": "训练计划必须包含至少一个模块"
            }

        # 验证时长范围
        duration = plan.get("total_duration", 0)
        if duration <= 0 or duration > 60:
            return {
                **state,
                "validation_passed": False,
                "error_message": "训练时长必须在1-60分钟之间"
            }

        # 验证RPE范围
        rpe = plan.get("rpe", 0)
        if rpe < 1 or rpe > 10:
            return {
                **state,
                "validation_passed": False,
                "error_message": "RPE强度必须在1-10之间"
            }

        return {
            **state,
            "validation_passed": True,
            "error_message": None
        }

    def _should_retry(self, state: WorkoutAgentState) -> str:
        """判断是否需要重试"""
        if state.get("validation_passed"):
            return "end"

        # 可以在这里添加重试逻辑
        return "end"

    def _extract_json_from_response(self, response: str) -> dict | None:
        """从响应中提取JSON"""
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
            return json.loads(json_str)
        except json.JSONDecodeError:
            return None

    async def generate(
        self,
        user_id: str,
        user_profile: dict | None = None
    ) -> AsyncGenerator[dict, None]:
        """
        生成训练计划（流式）

        Yields:
            dict: 包含类型和数据的字典
            - {"type": "chunk", "content": "文本块"}
            - {"type": "plan", "plan": {...}}
            - {"type": "error", "message": "错误信息"}
            - {"type": "done"}
        """
        # 初始化状态
        initial_state: WorkoutAgentState = {
            "messages": [],
            "user_id": user_id,
            "user_profile": user_profile,
            "workout_plan": None,
            "plan_json_str": None,
            "validation_passed": False,
            "error_message": None,
            "stream_chunks": []
        }

        # 构建提示词
        state = self._build_prompt_node(initial_state)

        # 流式生成
        try:
            messages = state["messages"]
            full_content = ""

            async for chunk in self.llm.astream(messages):
                if chunk.content:
                    full_content += chunk.content
                    yield {
                        "type": "chunk",
                        "content": chunk.content
                    }

            # 更新状态
            state["plan_json_str"] = full_content
            state["messages"] = messages + [AIMessage(content=full_content)]

            # 解析
            state = self._parse_node(state)

            # 验证
            state = self._validate_node(state)

            if state.get("validation_passed"):
                # 添加生成的元数据
                plan = state["workout_plan"]
                plan["generated_at"] = datetime.utcnow().isoformat()
                plan["generated_by"] = "ai"

                yield {
                    "type": "plan",
                    "plan": plan
                }
            else:
                yield {
                    "type": "error",
                    "message": state.get("error_message", "计划验证失败")
                }

        except Exception as e:
            import traceback
            error_detail = traceback.format_exc()
            logger.error(f"生成计划出错: {e}\n{error_detail}")
            yield {
                "type": "error",
                "message": f"生成计划时出错: {type(e).__name__}: {str(e)}"
            }

        yield {"type": "done"}

    async def generate_sync(
        self,
        user_id: str,
        user_profile: dict | None = None
    ) -> dict:
        """
        同步生成训练计划（非流式，用于直接返回）

        Returns:
            dict: 包含计划或错误信息的字典
        """
        chunks = []
        plan = None
        error = None

        async for item in self.generate(user_id, user_profile):
            if item["type"] == "chunk":
                chunks.append(item["content"])
            elif item["type"] == "plan":
                plan = item["plan"]
            elif item["type"] == "error":
                error = item["message"]

        if plan:
            return {
                "success": True,
                "plan": plan,
                "content": "".join(chunks)
            }
        else:
            return {
                "success": False,
                "error": error or "生成计划失败",
                "content": "".join(chunks)
            }
