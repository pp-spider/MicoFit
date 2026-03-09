"""TaskAnalyzer - 任务分析器

分析用户请求，识别任务类型、复杂度和子任务。
"""
import json
import re
import logging
from typing import AsyncGenerator

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_openai import ChatOpenAI

from app.agents.models import TaskAnalysis, MultiIntentResult
from app.agents.prompts import build_multi_intent_prompt
from app.core.config import settings

logger = logging.getLogger(__name__)


class TaskAnalyzer:
    """
    任务分析器 - 分析用户请求，识别任务类型和复杂度

    职责：
    1. 多意图识别
    2. 复杂度评估
    3. 实体提取
    4. 子任务拆分
    """

    def __init__(self):
        self.llm = ChatOpenAI(
            model=settings.OPENAI_MODEL,
            api_key=settings.OPENAI_API_KEY,
            base_url=settings.OPENAI_BASE_URL if settings.OPENAI_BASE_URL else None,
            temperature=0.3,
            max_tokens=1000,
        )

    async def analyze(
        self,
        user_message: str,
        user_profile: dict | None = None,
        history: list[dict] | None = None
    ) -> TaskAnalysis:
        """
        分析用户请求

        Args:
            user_message: 用户消息
            user_profile: 用户画像
            history: 历史对话消息列表，格式为 [{"role": "user"/"assistant", "content": "..."}]

        Returns:
            TaskAnalysis: 任务分析结果
        """
        # 1. 调用 LLM 进行多意图识别
        multi_intent_result = await self._multi_intent_recognition(user_message, user_profile, history)

        # 2. 判断是否需要规划
        requires_planning = self._check_requires_planning(multi_intent_result)

        # 3. 构建任务分析结果
        return TaskAnalysis(
            raw_intents=multi_intent_result.get("intents", []),
            primary_intent=multi_intent_result.get("primary_intent", "chat"),
            requires_planning=requires_planning,
            complexity=multi_intent_result.get("complexity", "simple"),
            extracted_entities=multi_intent_result.get("entities", {}),
            sub_tasks=multi_intent_result.get("sub_tasks", [])
        )

    async def _multi_intent_recognition(
        self,
        message: str,
        user_profile: dict | None = None,
        history: list[dict] | None = None
    ) -> MultiIntentResult:
        """
        多意图识别 - 使用 LLM 识别所有意图

        Args:
            message: 用户消息
            user_profile: 用户画像
            history: 历史对话消息列表

        Returns:
            MultiIntentResult: 多意图识别结果
        """
        # 构建提示词
        prompt = build_multi_intent_prompt(message, user_profile, history)

        messages = [
            SystemMessage(content=prompt)
        ]

        try:
            # 调用 LLM
            response = await self.llm.ainvoke(messages)
            content = response.content

            # 解析 JSON 响应
            result = self._parse_json_response(content)

            if result:
                sub_tasks = result.get("sub_tasks", [])
                workout_count = sum(1 for st in sub_tasks if st.get("type") == "workout")
                logger.info(f"[TaskAnalyzer] 多意图识别成功: {result.get('intents')}, 复杂度: {result.get('complexity')}")
                logger.info(f"[TaskAnalyzer] 子任务数: {len(sub_tasks)}, workout任务数: {workout_count}")
                for i, st in enumerate(sub_tasks):
                    logger.info(f"[TaskAnalyzer] 子任务 {i}: type={st.get('type')}, desc={st.get('description')}")
                return MultiIntentResult(
                    intents=result.get("intents", ["chat"]),
                    primary_intent=result.get("primary_intent", "chat"),
                    complexity=result.get("complexity", "simple"),
                    entities=result.get("entities", {}),
                    sub_tasks=result.get("sub_tasks", []),
                    reasoning=result.get("reasoning", ""),
                    confidence=result.get("confidence", 0.5)
                )

        except Exception as e:
            logger.error(f"多意图识别失败: {e}")

        # 失败时返回默认值（简单场景）
        return self._fallback_analysis(message)

    def _parse_json_response(self, content: str) -> dict | None:
        """解析 LLM 返回的 JSON"""
        # 尝试匹配 ```json ... ``` 代码块
        json_match = re.search(r'```(?:json)?\s*\n?(.*?)\n?```', content, re.DOTALL)
        if json_match:
            json_str = json_match.group(1).strip()
        else:
            # 尝试直接匹配 {...}
            json_match = re.search(r'\{[\s\S]*\}', content)
            if json_match:
                json_str = json_match.group(0)
            else:
                return None

        try:
            return json.loads(json_str)
        except json.JSONDecodeError:
            logger.error(f"JSON 解析失败: {json_str[:100]}")
            return None

    def _check_requires_planning(self, result: dict) -> bool:
        """
        判断是否需要规划

        多意图或复杂任务需要 Planner 介入
        """
        intents = result.get("intents", [])
        complexity = result.get("complexity", "simple")

        # 多意图或复杂任务需要规划
        return len(intents) > 1 or complexity in ["medium", "complex"]

    async def analyze_stream(
        self,
        user_message: str,
        user_profile: dict | None = None,
        history: list[dict] | None = None
    ) -> AsyncGenerator[dict, None]:
        """
        流式任务分析 - 实时返回分析进度

        采用流式文本输出方式，像其他 Agent 一样直接输出分析过程描述

        Args:
            user_message: 用户消息
            user_profile: 用户画像
            history: 历史对话消息列表，格式为 [{"role": "user"/"assistant", "content": "..."}]

        Yields:
            dict: 流式分析进度事件
            - {"type": "analysis_progress", "stage": "started", "message": "..."}
            - {"type": "analysis_progress", "stage": "chunk", "content": "..."}  # 流式文本
            - {"type": "analysis_progress", "stage": "completed", "analysis": {...}}
        """
        # 1. 发送开始分析事件
        yield {
            "type": "analysis_progress",
            "stage": "started",
            "message": "开始分析任务..."
        }

        try:
            # 2. 构建提示词
            prompt = build_multi_intent_prompt(user_message, user_profile, history)
            messages = [SystemMessage(content=prompt)]

            # 3. 调用 LLM 进行流式分析 - 实时 yield 每个 chunk
            full_content = ""
            async for chunk in self.llm.astream(messages):
                if chunk.content:
                    full_content += chunk.content
                    # 【关键修复】实时 yield 每个 chunk，让前端立即显示
                    yield {
                        "type": "analysis_progress",
                        "stage": "streaming",
                        "content": chunk.content
                    }

            # 4. 解析 JSON 响应
            result = self._parse_json_response(full_content)

            if result:
                # 5. 流式输出分析结果描述
                intents = result.get("intents", [])
                primary_intent = result.get("primary_intent", "chat")
                complexity = result.get("complexity", "simple")
                entities = result.get("entities", {})
                sub_tasks = result.get("sub_tasks", [])
                reasoning = result.get("reasoning", "")

                # 构建分析描述文本并流式输出
                analysis_texts = []

                # 意图识别结果
                if intents:
                    analysis_texts.append(f"识别到用户意图：{', '.join(intents)}。")

                # 复杂度评估
                if complexity:
                    complexity_desc = {
                        "simple": "简单任务",
                        "medium": "中等复杂度任务",
                        "complex": "复杂多步骤任务"
                    }.get(complexity, "任务")
                    analysis_texts.append(f"评估为{complexity_desc}。")

                # 实体信息
                if entities:
                    entity_desc = ", ".join([f"{k}={v}" for k, v in list(entities.items())[:3]])
                    analysis_texts.append(f"提取关键信息：{entity_desc}。")

                # 任务拆分
                if sub_tasks:
                    task_count = len(sub_tasks)
                    task_types = [st.get("type", "未知") for st in sub_tasks]
                    analysis_texts.append(f"将任务拆分为 {task_count} 个子任务：{', '.join(task_types)}。")

                # 推理说明
                if reasoning:
                    analysis_texts.append(f"分析依据：{reasoning}")

                # 输出结构化分析结果
                full_text = "\n".join(analysis_texts)
                if full_text:
                    # 分段输出，每段作为一个 chunk（移除人工延迟，实现真正的实时输出）
                    for text in analysis_texts:
                        yield {
                            "type": "analysis_progress",
                            "stage": "chunk",
                            "content": text + "\n"
                        }

                # 6. 构建完整的分析结果
                requires_planning = self._check_requires_planning(result)
                task_analysis = TaskAnalysis(
                    raw_intents=intents,
                    primary_intent=primary_intent,
                    requires_planning=requires_planning,
                    complexity=complexity,
                    extracted_entities=entities,
                    sub_tasks=sub_tasks
                )

                # 7. 发送完成事件
                yield {
                    "type": "analysis_progress",
                    "stage": "completed",
                    "message": "分析完成",
                    "analysis": task_analysis
                }
            else:
                # JSON 解析失败，使用降级分析
                yield {
                    "type": "analysis_progress",
                    "stage": "chunk",
                    "content": "使用备用分析方案...\n"
                }

                fallback_result = self._fallback_analysis(user_message)
                requires_planning = self._check_requires_planning(fallback_result)
                task_analysis = TaskAnalysis(
                    raw_intents=fallback_result.get("intents", []),
                    primary_intent=fallback_result.get("primary_intent", "chat"),
                    requires_planning=requires_planning,
                    complexity=fallback_result.get("complexity", "simple"),
                    extracted_entities=fallback_result.get("entities", {}),
                    sub_tasks=fallback_result.get("sub_tasks", [])
                )

                yield {
                    "type": "analysis_progress",
                    "stage": "completed",
                    "message": "分析完成",
                    "analysis": task_analysis
                }

        except Exception as e:
            logger.error(f"流式分析失败: {e}")
            # 发生错误时返回降级分析结果
            yield {
                "type": "analysis_progress",
                "stage": "error",
                "message": f"分析出错: {str(e)}"
            }

            fallback_result = self._fallback_analysis(user_message)
            requires_planning = self._check_requires_planning(fallback_result)
            task_analysis = TaskAnalysis(
                raw_intents=fallback_result.get("intents", []),
                primary_intent=fallback_result.get("primary_intent", "chat"),
                requires_planning=requires_planning,
                complexity=fallback_result.get("complexity", "simple"),
                extracted_entities=fallback_result.get("entities", {}),
                sub_tasks=fallback_result.get("sub_tasks", [])
            )

            yield {
                "type": "analysis_progress",
                "stage": "completed",
                "message": "✅ 分析完成（降级模式）",
                "analysis": task_analysis
            }

    def _fallback_analysis(self, message: str) -> MultiIntentResult:
        """
        降级分析 - 当 LLM 调用失败时使用

        基于关键词的简单判断
        """
        message_lower = message.lower()

        # 检测是否需要训练计划
        workout_keywords = ["训练", "练", "计划", "动", "运动", "健身"]
        has_workout = any(kw in message_lower for kw in workout_keywords)

        # 检测是否需要解释
        explain_keywords = ["解释", "说明", "为什么", "什么意思", "讲讲"]
        has_explain = any(kw in message_lower for kw in explain_keywords)

        # 构建意图列表
        intents = []
        if has_workout:
            intents.append("workout")
        if has_explain:
            intents.append("explanation")
        if not intents:
            intents.append("chat")

        # 构建子任务
        sub_tasks = []
        task_id = 0
        for intent in intents:
            sub_tasks.append({
                "type": intent,
                "description": f"{intent}任务",
                "input_data": {},
                "depends_on": []
            })
            task_id += 1

        # 设置依赖关系
        if has_workout and has_explain:
            # 解释依赖于计划
            sub_tasks[1]["depends_on"] = ["task_0"]
            sub_tasks[1]["input_data"] = {"plan_reference": "task_0"}

        # 复杂度判断
        if len(intents) > 1:
            complexity = "complex" if has_workout and has_explain else "medium"
        else:
            complexity = "simple"

        return MultiIntentResult(
            intents=intents,
            primary_intent=intents[0],
            complexity=complexity,
            entities={},
            sub_tasks=sub_tasks,
            reasoning="基于关键词降级分析",
            confidence=0.6
        )
