"""WorkoutSubAgent - 处理训练计划生成

基于原有 WorkoutAgent 改造，适配 SubAgent 接口，供 RouterAgent 调用。
保持原有的 4 节点工作流：build_prompt → generate → parse → validate
"""
import json
import logging
import re
from typing import AsyncGenerator
from datetime import datetime

from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END

from app.agents.base_sub_agent import BaseSubAgent
from app.agents.state import WorkoutSubAgentState
from app.agents.prompts import build_workout_system_prompt
from app.core.config import settings

logger = logging.getLogger(__name__)


class WorkoutSubAgent(BaseSubAgent):
    """
    WorkoutSubAgent - 处理训练计划生成

    基于原有 WorkoutAgent 改造，适配 SubAgent 接口

    工作流节点：
    1. build_prompt: 构建提示词（包含从意图提取的偏好）
    2. generate: 调用 LLM 流式生成
    3. parse: 从响应中提取 JSON
    4. validate: 验证计划字段完整性

    Attributes:
        llm: 大语言模型
        workflow: LangGraph 工作流图
    """

    def __init__(self):
        print("\n" + "─"*50)
        print("🏋️ WorkoutSubAgent 初始化完成")
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
        logger.info("WorkoutSubAgent 初始化完成")

    def _build_workflow(self) -> StateGraph:
        """
        构建工作流图

        Returns:
            StateGraph: 编译后的工作流图
        """
        workflow = StateGraph(WorkoutSubAgentState)

        workflow.add_node("build_prompt", self._build_prompt_node)
        workflow.add_node("generate", self._generate_node)
        workflow.add_node("parse", self._parse_node)
        workflow.add_node("validate", self._validate_node)
        workflow.add_node("retry", self._retry_node)  # 新增：重试处理节点

        workflow.set_entry_point("build_prompt")
        workflow.add_edge("build_prompt", "generate")
        workflow.add_edge("generate", "parse")
        workflow.add_edge("parse", "validate")

        # 验证失败时进入 retry 节点
        workflow.add_conditional_edges(
            "validate",
            self._should_retry,
            {
                "end": END,
                "retry": "retry"
            }
        )

        # retry 节点处理完后重新生成
        workflow.add_edge("retry", "generate")

        return workflow.compile()

    def _build_prompt_node(self, state: WorkoutSubAgentState) -> dict:
        """
        构建提示词节点

        构建系统提示词和用户消息，用户消息会包含从意图提取的偏好

        Args:
            state: 当前状态

        Returns:
            dict: 更新后的状态，包含 messages
        """
        user_profile = state.get("user_profile")
        preferences = state.get("extracted_preferences", {})

        # 构建系统提示词
        system_prompt = build_workout_system_prompt(user_profile)

        # 构建用户消息（包含提取的偏好）
        user_msg_parts = ["请为我生成今天的训练计划"]

        if preferences:
            if preferences.get("focus_body_part"):
                body_part_map = {
                    "legs": "腿部",
                    "core": "核心",
                    "arms": "手臂",
                    "back": "背部",
                    "chest": "胸部",
                    "glutes": "臀部"
                }
                part = body_part_map.get(
                    preferences["focus_body_part"],
                    preferences["focus_body_part"]
                )
                user_msg_parts.append(f"，重点训练{part}")

            if preferences.get("scene"):
                scene_map = {
                    "office": "办公室",
                    "home": "家中",
                    "outdoor": "户外",
                    "bed": "床上",
                    "hotel": "酒店"
                }
                scene = scene_map.get(preferences["scene"], preferences["scene"])
                user_msg_parts.append(f"，场景是{scene}")

            if preferences.get("duration"):
                user_msg_parts.append(f"，时长约{preferences['duration']}分钟")

            if preferences.get("intensity"):
                intensity_map = {
                    "low": "低强度",
                    "medium": "中等强度",
                    "high": "高强度"
                }
                intensity = intensity_map.get(
                    preferences["intensity"],
                    preferences["intensity"]
                )
                user_msg_parts.append(f"，{intensity}")

        user_message = "".join(user_msg_parts)

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=user_message)
        ]

        logger.info(f"WorkoutSubAgent 构建提示词: {user_message}")

        return {
            **state,
            "messages": messages,
            "stream_chunks": [],
            "validation_passed": False
        }

    async def _generate_node(self, state: WorkoutSubAgentState) -> dict:
        """
        生成节点（流式）

        实际流式生成在外层的 stream() 方法中处理

        Args:
            state: 当前状态

        Returns:
            dict: 状态（保持不变）
        """
        return state

    def _parse_node(self, state: WorkoutSubAgentState) -> dict:
        """
        解析节点 - 从响应中提取 JSON

        Args:
            state: 当前状态

        Returns:
            dict: 更新后的状态，包含 workout_plan
        """
        response = state.get("plan_json_str", "")
        plan = self._extract_json_from_response(response)

        return {
            **state,
            "workout_plan": plan
        }

    def _validate_node(self, state: WorkoutSubAgentState) -> dict:
        """
        验证节点 - 验证计划字段完整性

        验证项：
        - 必要字段存在（id, title, modules, total_duration, scene, rpe）
        - 至少一个模块
        - 时长在有效范围内
        - RPE 在有效范围内

        Args:
            state: 当前状态

        Returns:
            dict: 更新后的状态，包含 validation_passed 和 error_message
        """
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

        # 验证 RPE 范围
        rpe = plan.get("rpe", 0)
        if rpe < 1 or rpe > 10:
            return {
                **state,
                "validation_passed": False,
                "error_message": "RPE 强度必须在1-10之间"
            }

        return {
            **state,
            "validation_passed": True,
            "error_message": None
        }

    def _should_retry(self, state: WorkoutSubAgentState) -> str:
        """
        判断是否需要重试

        Args:
            state: 当前状态

        Returns:
            str: "end" 或 "retry"
        """
        if state.get("validation_passed"):
            return "end"

        # 获取错误信息
        error_message = state.get("error_message", "")
        if not error_message:
            return "end"

        # 获取当前重试次数
        retry_count = state.get("retry_count", 0)
        max_retries = 3  # 最大重试次数

        if retry_count >= max_retries:
            logger.warning(f"已达到最大重试次数 {max_retries}，停止重试")
            return "end"

        return "retry"

    async def _retry_node(self, state: WorkoutSubAgentState) -> dict:
        """
        重试节点 - 使用 AI 修正错误并重新生成

        Args:
            state: 当前状态

        Returns:
            dict: 更新后的状态，包含修正后的 messages
        """
        error_message = state.get("error_message", "")
        retry_count = state.get("retry_count", 0)

        logger.info(f"进入重试节点 (第 {retry_count + 1} 次)，错误: {error_message}")

        # 调用 AI 修正 prompt
        corrected_messages = await self._generate_corrected_prompt(state)

        if corrected_messages:
            return {
                **state,
                "messages": corrected_messages,
                "retry_count": retry_count + 1,
                "validation_passed": False,
                "error_message": None,  # 清除错误，准备重新生成
                "stream_chunks": [],
                "plan_json_str": None,
                "workout_plan": None
            }
        else:
            # 修正失败，结束流程
            return {
                **state,
                "retry_count": retry_count + 1,
                "validation_passed": False,
                "error_message": f"重试 {retry_count + 1} 次后仍失败: {error_message}"
            }

    async def _generate_corrected_prompt(self, state: WorkoutSubAgentState) -> list | None:
        """
        使用 AI 根据错误信息生成修正后的 prompt

        Args:
            state: 当前状态

        Returns:
            list | None: 修正后的 messages
        """
        error_message = state.get("error_message", "")
        user_profile = state.get("user_profile")
        preferences = state.get("extracted_preferences", {})
        retry_count = state.get("retry_count", 0)

        correction_prompt = f"""你是一个训练计划生成助手。刚才生成的训练计划验证失败，错误原因如下：

错误信息：{error_message}

这是第 {retry_count + 1} 次重试。

用户偏好：
- 重点部位：{preferences.get('focus_body_part', '未指定')}
- 场景：{preferences.get('scene', '未指定')}
- 时长：{preferences.get('duration', '未指定')} 分钟
- 强度：{preferences.get('intensity', '未指定')}

请生成一个修正后的用户请求，确保生成的训练计划：
1. 包含所有必要字段：id, title, modules, total_duration, scene, rpe
2. modules 数组至少有一个元素
3. total_duration 在 1-60 分钟之间
4. rpe 在 1-10 之间

直接输出修正后的用户消息（中文），不要输出其他内容。"""

        messages = [
            SystemMessage(content="你是一个专业的健身教练助手，擅长生成有效的训练计划。"),
            HumanMessage(content=correction_prompt)
        ]

        try:
            response = await self.llm.ainvoke(messages)
            corrected_user_message = response.content

            # 重新构建完整的 messages
            system_prompt = build_workout_system_prompt(user_profile)
            new_messages = [
                SystemMessage(content=system_prompt),
                HumanMessage(content=corrected_user_message)
            ]

            logger.info(f"AI 修正后的 prompt (重试 {retry_count + 1}): {corrected_user_message[:100]}...")
            return new_messages

        except Exception as e:
            logger.error(f"生成修正 prompt 失败: {e}")
            return None

    def _extract_json_from_response(self, response: str) -> dict | None:
        """
        从响应中提取 JSON

        Args:
            response: LLM 响应内容

        Returns:
            dict | None: 提取的 JSON 数据
        """
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

    # ========== 公共接口 ==========

    @property
    def name(self) -> str:
        """SubAgent 名称"""
        return "workout_sub_agent"

    @property
    def description(self) -> str:
        """SubAgent 描述"""
        return "生成个性化训练计划"

    async def stream(self, state: WorkoutSubAgentState) -> AsyncGenerator[dict, None]:
        """
        流式处理接口

        Args:
            state: WorkoutSubAgentState

        Yields:
            dict: 流式响应块
            - {"type": "chunk", "content": "..."}
            - {"type": "plan", "plan": {...}}
            - {"type": "done", "has_plan": True}
            - {"type": "error", "message": "..."}
        """
        # 初始化重试计数
        state["retry_count"] = 0

        # 构建提示词
        state = self._build_prompt_node(state)

        # 发送准备消息
        # 美化输出开始
        print("\n" + "─"*50)
        print("🏋️ WorkoutSubAgent 正在生成训练计划...")
        print("─"*50 + "\n")

        yield {
            "type": "chunk",
            "content": "正在为您生成今日训练计划...\n\n"
        }

        try:
            messages = state["messages"]
            full_content = ""

            # 流式生成
            async for chunk in self.llm.astream(messages):
                if chunk.content:
                    full_content += chunk.content
                    yield {
                        "type": "chunk",
                        "content": chunk.content
                    }

            # 解析
            state["plan_json_str"] = full_content
            state = self._parse_node(state)

            # 验证
            state = self._validate_node(state)

            if state.get("validation_passed"):
                plan = state["workout_plan"]
                plan["generated_at"] = datetime.utcnow().isoformat()
                plan["generated_by"] = "ai"

                # 美化输出验证成功
                print("\n" + "─"*50)
                print("✅ 训练计划生成成功!")
                print(f"   计划标题: {plan.get('title')}")
                print(f"   总时长: {plan.get('total_duration')} 分钟")
                print(f"   训练模块: {len(plan.get('modules', []))} 个")
                print("─"*50 + "\n")

                yield {
                    "type": "plan",
                    "plan": plan
                }
                yield {
                    "type": "done",
                    "has_plan": True
                }
            else:
                # 美化输出验证失败
                print("\n" + "─"*50)
                print("❌ 训练计划验证失败")
                print(f"   错误: {state.get('error_message')}")
                print("─"*50 + "\n")

                yield {
                    "type": "error",
                    "message": state.get("error_message", "计划验证失败")
                }

        except Exception as e:
            logger.error(f"WorkoutSubAgent 生成失败: {e}")
            yield {
                "type": "error",
                "message": f"生成计划时出错: {str(e)}"
            }

    async def process(self, state: WorkoutSubAgentState) -> dict:
        """
        同步处理接口

        Args:
            state: WorkoutSubAgentState

        Returns:
            dict: 完整处理结果
            - {"success": True, "content": "...", "plan": {...}}
            - {"success": False, "error": "..."}
        """
        chunks = []
        plan = None
        error = None

        async for chunk in self.stream(state):
            if chunk["type"] == "chunk":
                chunks.append(chunk["content"])
            elif chunk["type"] == "plan":
                plan = chunk["plan"]
            elif chunk["type"] == "error":
                error = chunk["message"]

        if error:
            return {
                "success": False,
                "error": error
            }

        return {
            "success": True,
            "content": "".join(chunks),
            "plan": plan
        }
