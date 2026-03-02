"""测试 Planner 并行执行功能"""
import asyncio
import time
from typing import AsyncGenerator

# 模拟测试数据
from app.agents.models import (
    Task, TaskStatus, TaskType, ExecutionPlan, ExecutionMode
)
from app.agents.shared_context import SharedContextPool


class MockAgent:
    """模拟SubAgent，用于测试"""
    def __init__(self, name: str, delay: float = 1.0):
        self.name = name
        self.delay = delay

    async def stream(self, state: dict) -> AsyncGenerator[dict, None]:
        """模拟流式输出"""
        start = time.time()

        yield {"type": "agent_status", "agent": self.name, "status": "started"}

        # 模拟处理时间
        await asyncio.sleep(self.delay)

        # 生成一些输出
        for i in range(3):
            yield {
                "type": "chunk",
                "content": f"[{self.name}] 输出片段 {i+1} "
            }
            await asyncio.sleep(0.1)

        yield {"type": "agent_status", "agent": self.name, "status": "completed"}

        # 设置结果
        state["stream_chunks"] = [f"{self.name} result"]


class MockTaskExecutor:
    """简化版TaskExecutor用于测试"""
    def __init__(self, agent_registry: dict):
        self.agent_registry = agent_registry

    async def _execute_task(
        self, task: Task, context: SharedContextPool, **kwargs
    ) -> AsyncGenerator[dict, None]:
        """执行单个任务（流式）"""
        agent_name = task["agent_name"]
        agent = self.agent_registry.get(agent_name)

        if not agent:
            yield {"type": "error", "message": f"Agent {agent_name} not found"}
            return

        task["status"] = TaskStatus.RUNNING

        state = {"stream_chunks": []}
        async for chunk in agent.stream(state):
            yield chunk

        task["status"] = TaskStatus.COMPLETED
        task["output_data"] = {
            "content": f"Result from {agent_name}",
            "chunks": state["stream_chunks"]
        }

        yield task

    async def _execute_single_task(
        self, task: Task, context: SharedContextPool, **kwargs
    ) -> dict:
        """执行单个任务并收集结果"""
        chunks = []

        async for item in self._execute_task(task, context, **kwargs):
            if isinstance(item, dict) and not isinstance(item.get("output_data"), dict):
                chunks.append(item)

        return {
            "task_id": task["id"],
            "status": task["status"],
            "chunks": chunks,
            "output_data": task.get("output_data", {})
        }

    async def execute_parallel(
        self, plan: ExecutionPlan, context: SharedContextPool, **kwargs
    ) -> AsyncGenerator[dict, None]:
        """并行执行"""
        parallel_groups = plan.get("parallel_groups", [])
        task_map = {task["id"]: task for task in plan.get("tasks", [])}

        for batch_idx, batch_task_ids in enumerate(parallel_groups):
            yield {
                "type": "batch_start",
                "batch_index": batch_idx,
                "total_batches": len(parallel_groups),
                "tasks": batch_task_ids
            }

            tasks_in_batch = [
                task_map[tid] for tid in batch_task_ids if tid in task_map
            ]

            # 并行执行
            coroutines = [
                self._execute_single_task(task, context, **kwargs)
                for task in tasks_in_batch
            ]

            batch_results = await asyncio.gather(*coroutines, return_exceptions=True)

            for task, result in zip(tasks_in_batch, batch_results):
                if isinstance(result, Exception):
                    yield {"type": "task_error", "task_id": task["id"], "error": str(result)}
                else:
                    for chunk in result.get("chunks", []):
                        chunk_with_id = chunk.copy()
                        chunk_with_id["task_id"] = task["id"]
                        yield chunk_with_id

            yield {
                "type": "batch_complete",
                "batch_index": batch_idx,
                "completed_tasks": batch_task_ids
            }


async def test_serial_execution():
    """测试串行执行"""
    print("\n" + "="*60)
    print("测试串行执行")
    print("="*60)

    # 创建模拟Agent（每个耗时1秒）
    agent_registry = {
        "agent_a": MockAgent("agent_a", delay=1.0),
        "agent_b": MockAgent("agent_b", delay=1.0),
    }

    executor = MockTaskExecutor(agent_registry)
    context = SharedContextPool()

    # 创建任务
    tasks = [
        Task(
            id="task_0", type=TaskType.CHAT, description="任务A",
            agent_name="agent_a", input_data={}, depends_on=[],
            status=TaskStatus.PENDING, output_data=None, error=None
        ),
        Task(
            id="task_1", type=TaskType.CHAT, description="任务B",
            agent_name="agent_b", input_data={}, depends_on=[],
            status=TaskStatus.PENDING, output_data=None, error=None
        ),
    ]

    plan = ExecutionPlan(
        tasks=tasks,
        execution_order=["task_0", "task_1"],
        requires_collaboration=False,
        parallel_groups=[["task_0"], ["task_1"]],  # 串行分组
        execution_mode=ExecutionMode.SERIAL,
        estimated_duration_ms=None
    )

    start = time.time()
    batch_count = 0

    async for result in executor.execute_parallel(plan, context):
        if result.get("type") == "batch_start":
            batch_count += 1
            print(f"\n批次 {result['batch_index'] + 1} 开始: {result['tasks']}")
        elif result.get("type") == "batch_complete":
            print(f"批次 {result['batch_index'] + 1} 完成")
        elif result.get("type") == "chunk":
            print(f"  [{result.get('task_id')}] {result.get('content', '')[:30]}...")

    elapsed = time.time() - start
    print(f"\n串行执行耗时: {elapsed:.2f}秒")
    print(f"预期耗时: ~2秒 (1+1)")

    return elapsed


async def test_parallel_execution():
    """测试并行执行"""
    print("\n" + "="*60)
    print("测试并行执行")
    print("="*60)

    # 创建模拟Agent（每个耗时1秒）
    agent_registry = {
        "agent_a": MockAgent("agent_a", delay=1.0),
        "agent_b": MockAgent("agent_b", delay=1.0),
    }

    executor = MockTaskExecutor(agent_registry)
    context = SharedContextPool()

    # 创建任务
    tasks = [
        Task(
            id="task_0", type=TaskType.CHAT, description="任务A",
            agent_name="agent_a", input_data={}, depends_on=[],
            status=TaskStatus.PENDING, output_data=None, error=None
        ),
        Task(
            id="task_1", type=TaskType.CHAT, description="任务B",
            agent_name="agent_b", input_data={}, depends_on=[],
            status=TaskStatus.PENDING, output_data=None, error=None
        ),
    ]

    plan = ExecutionPlan(
        tasks=tasks,
        execution_order=["task_0", "task_1"],
        requires_collaboration=True,
        parallel_groups=[["task_0", "task_1"]],  # 同一批次，并行执行
        execution_mode=ExecutionMode.PARALLEL,
        estimated_duration_ms=None
    )

    start = time.time()
    batch_count = 0

    async for result in executor.execute_parallel(plan, context):
        if result.get("type") == "batch_start":
            batch_count += 1
            print(f"\n批次 {result['batch_index'] + 1} 开始: {result['tasks']}")
        elif result.get("type") == "batch_complete":
            print(f"批次 {result['batch_index'] + 1} 完成")
        elif result.get("type") == "chunk":
            print(f"  [{result.get('task_id')}] {result.get('content', '')[:30]}...")

    elapsed = time.time() - start
    print(f"\n并行执行耗时: {elapsed:.2f}秒")
    print(f"预期耗时: ~1秒 (max(1,1))")

    return elapsed


async def test_hybrid_execution():
    """测试混合执行（串行+并行）"""
    print("\n" + "="*60)
    print("测试混合执行（串行+并行）")
    print("="*60)

    # 创建模拟Agent
    agent_registry = {
        "agent_a": MockAgent("agent_a", delay=1.0),
        "agent_b": MockAgent("agent_b", delay=1.0),
        "agent_c": MockAgent("agent_c", delay=1.0),
    }

    executor = MockTaskExecutor(agent_registry)
    context = SharedContextPool()

    # 创建任务: task_0 和 task_1 并行，然后 task_2 串行
    tasks = [
        Task(
            id="task_0", type=TaskType.CHAT, description="任务A",
            agent_name="agent_a", input_data={}, depends_on=[],
            status=TaskStatus.PENDING, output_data=None, error=None
        ),
        Task(
            id="task_1", type=TaskType.CHAT, description="任务B",
            agent_name="agent_b", input_data={}, depends_on=[],
            status=TaskStatus.PENDING, output_data=None, error=None
        ),
        Task(
            id="task_2", type=TaskType.CHAT, description="任务C",
            agent_name="agent_c", input_data={}, depends_on=["task_0", "task_1"],
            status=TaskStatus.PENDING, output_data=None, error=None
        ),
    ]

    plan = ExecutionPlan(
        tasks=tasks,
        execution_order=["task_0", "task_1", "task_2"],
        requires_collaboration=True,
        parallel_groups=[["task_0", "task_1"], ["task_2"]],  # 第一批2个并行，第二批1个串行
        execution_mode=ExecutionMode.AUTO,
        estimated_duration_ms=None
    )

    start = time.time()

    async for result in executor.execute_parallel(plan, context):
        if result.get("type") == "batch_start":
            print(f"\n批次 {result['batch_index'] + 1} 开始: {result['tasks']}")
        elif result.get("type") == "batch_complete":
            print(f"批次 {result['batch_index'] + 1} 完成")
        elif result.get("type") == "chunk":
            print(f"  [{result.get('task_id')}] {result.get('content', '')[:30]}...")

    elapsed = time.time() - start
    print(f"\n混合执行耗时: {elapsed:.2f}秒")
    print(f"预期耗时: ~2秒 (max(1,1) + 1)")

    return elapsed


async def main():
    """主测试函数"""
    print("\n" + "="*60)
    print("Planner 并行执行架构测试")
    print("="*60)

    # 测试串行
    serial_time = await test_serial_execution()

    # 测试并行
    parallel_time = await test_parallel_execution()

    # 测试混合
    hybrid_time = await test_hybrid_execution()

    # 汇总
    print("\n" + "="*60)
    print("测试结果汇总")
    print("="*60)
    print(f"串行执行: {serial_time:.2f}秒 (预期 ~2秒)")
    print(f"并行执行: {parallel_time:.2f}秒 (预期 ~1秒)")
    print(f"混合执行: {hybrid_time:.2f}秒 (预期 ~2秒)")
    print(f"\n并行效率提升: {(serial_time - parallel_time) / serial_time * 100:.1f}%")

    if parallel_time < serial_time * 0.7:
        print("[OK] 并行执行显著提升了性能！")
    else:
        print("[WARN] 并行执行性能提升不明显，可能受限于测试环境")


if __name__ == "__main__":
    asyncio.run(main())
