"""SummarySubAgent - 总结性子智能体

用于总结 planner 规划分解后所有子任务的输出内容。
当多个子任务执行完成后，此智能体将所有子任务输出整合为一份完整、连贯的总结。
"""
import logging
from typing import AsyncGenerator

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_openai import ChatOpenAI

from app.agents.base_sub_agent import BaseSubAgent
from app.core.config import settings

logger = logging.getLogger(__name__)


class SummarySubAgent(BaseSubAgent):
    """
    SummarySubAgent - 总结性子智能体

    职责：
    - 收集所有子任务的输出结果
    - 整合并生成连贯的总结回复
    - 确保输出内容逻辑清晰、结构完整

    Attributes:
        llm: 大语言模型
    """

    def __init__(self):
        print("\n" + "─"*50)
        print("📝 SummarySubAgent 初始化完成")
        print("─"*50 + "\n")

        self.llm = ChatOpenAI(
            model=settings.OPENAI_MODEL,
            api_key=settings.OPENAI_API_KEY,
            base_url=settings.OPENAI_BASE_URL if settings.OPENAI_BASE_URL else None,
            temperature=0.5,  # 稍微低一点的温度，确保总结更稳定
            max_tokens=2000,
            streaming=True,
        )
        logger.info("SummarySubAgent 初始化完成")

    @property
    def name(self) -> str:
        """SubAgent 名称"""
        return "summary_sub_agent"

    @property
    def description(self) -> str:
        """SubAgent 描述"""
        return "总结所有子任务输出，生成连贯的整合回复"

    async def stream(self, state: dict) -> AsyncGenerator[dict, None]:
        """
        流式处理接口 - 总结所有子任务输出

        Args:
            state: 包含以下字段的状态字典
                - user_message: 原始用户消息
                - user_profile: 用户画像
                - task_outputs: 所有子任务的输出列表
                - history: 历史消息
                - context_summary: 会话摘要

        Yields:
            dict: 流式响应块
            - {"type": "chunk", "content": "..."}
            - {"type": "done", "content": "...", "has_plan": False}
            - {"type": "error", "message": "..."}
        """
        user_message = state.get("user_message", "")
        user_profile = state.get("user_profile")
        task_outputs = state.get("task_outputs", [])
        history = state.get("history", [])

        logger.info(f"SummarySubAgent 开始总结 {len(task_outputs)} 个子任务")

        try:
            # 构建总结提示词
            messages = self._build_summary_messages(
                user_message=user_message,
                user_profile=user_profile,
                task_outputs=task_outputs,
                history=history
            )

            # 美化输出开始
            print("\n" + "─"*50)
            print("📝 SummarySubAgent 正在生成总结...")
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
            print("✅ SummarySubAgent 总结完成")
            print(f"   响应长度: {len(full_content)} 字符")
            print("─"*50 + "\n")

        except Exception as e:
            logger.error(f"SummarySubAgent 生成失败: {e}")
            yield {
                "type": "error",
                "message": f"生成总结时出错: {str(e)}"
            }

    async def process(self, state: dict) -> dict:
        """
        同步处理接口

        Args:
            state: 状态字典

        Returns:
            dict: 完整处理结果
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

    def _build_summary_messages(
        self,
        user_message: str,
        user_profile: dict | None,
        task_outputs: list[dict],
        history: list[dict]
    ) -> list:
        """
        构建总结提示词

        Args:
            user_message: 原始用户消息
            user_profile: 用户画像
            task_outputs: 所有子任务的输出列表
            history: 历史消息

        Returns:
            list: LangChain Message 对象列表
        """
        messages = []

        # 系统提示词
        system_prompt = self._build_system_prompt(user_profile)
        messages.append(SystemMessage(content=system_prompt))

        # 构建用户提示词
        user_prompt = self._build_user_prompt(user_message, task_outputs)
        messages.append(HumanMessage(content=user_prompt))

        return messages

    def _build_system_prompt(self, user_profile: dict | None) -> str:
        """
        构建系统提示词

        Args:
            user_profile: 用户画像

        Returns:
            str: 系统提示词
        """
        buffer = []

        # 基础角色定义
        buffer.append("你是微动MicoFit的专属AI健身教练，擅长整合和总结信息。")
        buffer.append("你的职责是将多个子任务的输出整合为一份完整、连贯、有逻辑性的回复。")
        buffer.append("")

        # 用户画像信息
        if user_profile:
            buffer.append("---")
            buffer.append("**用户画像信息**")
            buffer.append(f"- 昵称：{user_profile.get('nickname', '用户')}")
            buffer.append(f"- 健身水平：{self._get_fitness_level_label(user_profile.get('fitness_level', ''))}")
            buffer.append(f"- 健身目标：{self._get_goal_label(user_profile.get('goal', ''))}")
            buffer.append(f"- 常用场景：{self._get_scene_label(user_profile.get('scene', ''))}")
            buffer.append(f"- 时间预算：每次约{user_profile.get('time_budget', 12)}分钟")

            limitations = user_profile.get('limitations', [])
            if limitations and len(limitations) > 0:
                buffer.append(f"- 身体限制：{'、'.join(limitations)}")

            buffer.append("---")
            buffer.append("")

        # 总结要求
        buffer.append("总结要求：")
        buffer.append("1. 综合所有子任务的输出，形成一份连贯的回复")
        buffer.append("2. 保持信息完整，不遗漏重要内容")
        buffer.append("3. 逻辑清晰，结构合理")
        buffer.append("4. 语言自然流畅，避免生硬拼接")
        buffer.append("5. 如果包含训练计划，保留计划的关键信息")
        buffer.append("6. 保持友好鼓励的语气")
        buffer.append("7. 适当使用emoji点缀")
        buffer.append("")
        buffer.append("注意：不要提及'这是总结'或'根据子任务输出'等元信息，直接给出自然的回复。")

        return "\n".join(buffer)

    def _build_user_prompt(self, user_message: str, task_outputs: list[dict]) -> str:
        """
        构建用户提示词

        Args:
            user_message: 原始用户消息
            task_outputs: 所有子任务的输出列表

        Returns:
            str: 用户提示词
        """
        buffer = []

        buffer.append("**原始用户请求：**")
        buffer.append(user_message)
        buffer.append("")
        buffer.append("---")
        buffer.append("")
        buffer.append("**各子任务输出：**")
        buffer.append("")

        for i, output in enumerate(task_outputs, 1):
            task_type = output.get("task_type", "unknown")
            task_id = output.get("task_id", f"task_{i}")
            content = output.get("content", "")

            buffer.append(f"【子任务 {i} | 类型: {task_type} | ID: {task_id}】")
            buffer.append(content)
            buffer.append("")

        buffer.append("---")
        buffer.append("")
        buffer.append("请综合以上内容，生成一份完整、连贯的回复。")

        return "\n".join(buffer)

    def _get_fitness_level_label(self, level: str) -> str:
        """获取健身水平标签"""
        mapping = {
            "beginner": "零基础",
            "occasional": "偶尔运动",
            "regular": "规律运动"
        }
        return mapping.get(level, level)

    def _get_goal_label(self, goal: str) -> str:
        """获取目标标签"""
        mapping = {
            "fat-loss": "减脂塑形",
            "sedentary": "缓解久坐",
            "strength": "增强体能",
            "sleep": "改善睡眠"
        }
        return mapping.get(goal, goal)

    def _get_scene_label(self, scene: str) -> str:
        """获取场景标签"""
        mapping = {
            "bed": "床上",
            "office": "办公室",
            "living": "客厅",
            "outdoor": "户外",
            "hotel": "酒店"
        }
        return mapping.get(scene, scene)
