"""SharedContextPool - 共享上下文池

用于跨任务共享数据和管理任务依赖。
"""
import asyncio
from typing import Any


class SharedContextPool:
    """
    共享上下文池 - 跨任务共享数据

    特性：
    - 数据存储：存储任务执行过程中的共享数据
    - 事件通知：任务完成后通知依赖任务
    - 超时控制：依赖等待超时处理
    """

    def __init__(self):
        self._data: dict[str, Any] = {}
        self._events: dict[str, asyncio.Event] = {}

    def write(self, key: str, value: Any) -> None:
        """
        写入数据并触发事件

        Args:
            key: 数据键名
            value: 数据值
        """
        self._data[key] = value
        # 触发等待该数据的任务
        if key in self._events:
            self._events[key].set()

    def read(self, key: str) -> Any:
        """
        读取数据

        Args:
            key: 数据键名

        Returns:
            数据值，如果不存在返回 None
        """
        return self._data.get(key)

    async def wait_for(self, key: str, timeout: float = 30.0) -> Any:
        """
        等待数据准备好（用于依赖处理）

        Args:
            key: 数据键名
            timeout: 超时时间（秒）

        Returns:
            数据值

        Raises:
            TimeoutError: 等待超时
        """
        # 如果数据已存在，直接返回
        if key in self._data:
            return self._data[key]

        # 创建事件并等待
        if key not in self._events:
            self._events[key] = asyncio.Event()

        try:
            await asyncio.wait_for(self._events[key].wait(), timeout)
            return self._data.get(key)
        except asyncio.TimeoutError:
            raise TimeoutError(f"等待数据 {key} 超时 ({timeout}s)")

    def has(self, key: str) -> bool:
        """检查数据是否存在"""
        return key in self._data

    # ==================== 快捷方法 ====================

    def get_workout_plan(self) -> dict | None:
        """获取训练计划"""
        return self._data.get("workout_plan")

    def set_workout_plan(self, plan: dict) -> None:
        """设置训练计划"""
        self._data["workout_plan"] = plan

    def get_task_result(self, task_id: str) -> dict | None:
        """获取任务结果"""
        return self._data.get(f"task_result_{task_id}")

    def set_task_result(self, task_id: str, result: dict) -> None:
        """设置任务结果"""
        self._data[f"task_result_{task_id}"] = result
        # 同时触发任务完成事件
        if f"{task_id}_done" not in self._events:
            self._events[f"{task_id}_done"] = asyncio.Event()
        self._events[f"{task_id}_done"].set()

    async def wait_task_complete(self, task_id: str, timeout: float = 30.0) -> dict | None:
        """等待任务完成"""
        event_key = f"{task_id}_done"
        if event_key not in self._events:
            self._events[event_key] = asyncio.Event()

        try:
            await asyncio.wait_for(self._events[event_key].wait(), timeout)
            return self.get_task_result(task_id)
        except asyncio.TimeoutError:
            return None

    def clear(self) -> None:
        """清空上下文"""
        self._data.clear()
        self._events.clear()

    def get_all_data(self) -> dict[str, Any]:
        """获取所有数据（用于调试）"""
        return self._data.copy()
