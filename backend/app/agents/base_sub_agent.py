"""SubAgent 抽象基类 - 定义所有 SubAgent 的标准接口"""
from abc import ABC, abstractmethod
from typing import AsyncGenerator, TypedDict


class SubAgentResult(TypedDict):
    """SubAgent 标准返回结果"""
    type: str  # "chunk" | "plan" | "error" | "done"
    content: str | None
    plan: dict | None
    error: str | None


class BaseSubAgent(ABC):
    """
    SubAgent 抽象基类

    所有 SubAgent 必须实现此接口，以便 RouterAgent 统一调用

    Example:
        class ChatSubAgent(BaseSubAgent):
            @property
            def name(self) -> str:
                return "chat_sub_agent"

            async def stream(self, state: dict) -> AsyncGenerator[dict, None]:
                # 流式处理逻辑
                yield {"type": "chunk", "content": "..."}

            async def process(self, state: dict) -> dict:
                # 同步处理逻辑
                return {"success": True, "content": "..."}
    """

    @property
    @abstractmethod
    def name(self) -> str:
        """
        SubAgent 名称，用于路由识别

        Returns:
            str: SubAgent 唯一标识名
        """
        pass

    @property
    @abstractmethod
    def description(self) -> str:
        """
        SubAgent 描述，用于日志和调试

        Returns:
            str: SubAgent 功能描述
        """
        pass

    @abstractmethod
    async def stream(self, state: dict) -> AsyncGenerator[dict, None]:
        """
        流式处理接口 - 必须实现

        这是 SubAgent 的主要工作方式，支持实时流式输出，
        让前端能够实时显示生成内容。

        Args:
            state: SubAgent 专用状态字典

        Yields:
            dict: 流式响应块，标准格式如下：
                - {"type": "chunk", "content": "文本内容"} - 普通文本块
                - {"type": "plan", "plan": {...}} - 训练计划（仅 WorkoutSubAgent）
                - {"type": "done", "content": "完整内容", "has_plan": bool} - 完成标记
                - {"type": "error", "message": "错误信息"} - 错误信息

        Example:
            async for chunk in sub_agent.stream(state):
                if chunk["type"] == "chunk":
                    print(chunk["content"])
                elif chunk["type"] == "done":
                    print("处理完成")
        """
        pass

    @abstractmethod
    async def process(self, state: dict) -> dict:
        """
        同步处理接口 - 必须实现

        用于需要完整结果的场景，内部通常调用 stream() 并收集结果。

        Args:
            state: SubAgent 专用状态字典

        Returns:
            dict: 完整处理结果，标准格式如下：
                - {"success": True, "content": "完整响应", "plan": {...}}
                - {"success": False, "error": "错误信息"}

        Example:
            result = await sub_agent.process(state)
            if result["success"]:
                print(result["content"])
            else:
                print(f"错误: {result['error']}")
        """
        pass

    def _collect_stream_result(self, chunks: list[dict]) -> dict:
        """
        辅助方法：收集流式结果

        将 stream() 产生的 chunks 收集为完整结果，
        可在 process() 实现中复用。

        Args:
            chunks: stream() 产生的所有 chunk

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
