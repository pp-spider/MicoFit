"""测试流式并行执行功能

验证多路复用机制下，多个任务可以并行执行且流式输出实时可见。
"""
import asyncio
import time
from typing import AsyncGenerator

from app.agents.models import (
    Task, TaskStatus, TaskType, ExecutionPlan, ExecutionMode
)
from app.agents.shared_context import SharedContextPool
from app.agents.task_executor import TaskExecutor


class MockAgent:
    """模拟SubAgent，产生流式输出"""
    def __init__(self, name: str, delay: float = 0.5, chunks_count: int = 5):
        self.name = name
        self.delay = delay
        self.chunks_count = chunks_count

    async def stream(self, state: dict) -> AsyncGenerator[dict, None]:
        """模拟流式输出，每隔一段时间产生一个 chunk"""
        yield {"type": "agent_status", "agent": self.name, "status": "started"}

        for i in range(self.chunks_count):
            # 模拟处理时间
            await asyncio.sleep(self.delay)

            yield {
                "type": "chunk",
                "content": f"[{self.name}] 第{i+1}/{self.chunks_count}个输出 "
            }

        yield {"type": "agent_status", "agent": self.name, "status": "completed"}

        # 设置结果
        state["stream_chunks"] = [f"{self.name} result"]
        state["response"] = f"{self.name} completed"


class MockTaskExecutor(TaskExecutor):
    """扩展 TaskExecutor，使用 MockAgent"""

    async def _execute_task(self, task, context, **kwargs):
        """执行单个任务（流式）"""
        agent_name = task["agent_name"]
        agent = self.agent_registry.get(agent_name)

        if not agent:
            yield {"type": "error", "message": f"Agent {agent_name} not found"}
            return

        task["status"] = TaskStatus.RUNNING

        state = {"stream_chunks": [], "response": None}
        async for chunk in agent.stream(state):
            yield chunk

        task["status"] = TaskStatus.COMPLETED
        task["output_data"] = {
            "content": state.get("response", ""),
            "chunks": state.get("stream_chunks", [])
        }

        yield task


async def test_streaming_parallel():
    """测试流式并行执行"""
    print("\n" + "="*70)
    print("测试流式并行执行 - 多路复用")
    print("="*70)
    print("\n场景: 两个任务并行执行，观察它们的流式输出是否实时交错")
    print("预期: 看到 task_0 和 task_1 的输出交错出现，而不是先完成一个再输出另一个\n")

    # 创建模拟Agent（每个任务产生5个chunk，间隔0.5秒）
    agent_registry = {
        "agent_a": MockAgent("agent_a", delay=0.5, chunks_count=5),
        "agent_b": MockAgent("agent_b", delay=0.5, chunks_count=5),
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
    output_timeline = []  # 记录输出时间线

    print("开始执行...\n")

    async for result in executor.execute_parallel(
        plan=plan, context=context, user_id="test_user", session_id="test_session", user_message="test"
    ):
        result_type = result.get("type")
        task_id = result.get("task_id", "N/A")
        current_time = time.time() - start

        if result_type == "batch_start":
            print(f"[t={current_time:.2f}s] 批次开始: {result['tasks']}")

        elif result_type == "task_started":
            print(f"[t={current_time:.2f}s] 任务 {task_id} 开始")

        elif result_type == "chunk":
            content = result.get("content", "")[:30]
            print(f"[t={current_time:.2f}s] [{task_id}] {content}...")
            output_timeline.append((current_time, task_id, content))

        elif result_type == "task_completed":
            print(f"[t={current_time:.2f}s] 任务 {task_id} 完成")

        elif result_type == "batch_complete":
            print(f"[t={current_time:.2f}s] 批次完成")

        elif result_type == "task_error":
            print(f"[t={current_time:.2f}s] 任务 {task_id} 错误: {result.get('error')}")

    elapsed = time.time() - start
    print(f"\n总耗时: {elapsed:.2f}秒")

    # 分析输出时间线
    print("\n" + "="*70)
    print("输出时间线分析")
    print("="*70)

    task_0_chunks = [t for t in output_timeline if t[1] == "task_0"]
    task_1_chunks = [t for t in output_timeline if t[1] == "task_1"]

    print(f"\ntask_0 输出次数: {len(task_0_chunks)}")
    print(f"task_1 输出次数: {len(task_1_chunks)}")

    # 检查是否交错
    is_interleaved = False
    prev_task = None
    switch_count = 0

    for _, task_id, _ in output_timeline:
        if prev_task and prev_task != task_id:
            switch_count += 1
        prev_task = task_id

    print(f"\n任务切换次数: {switch_count}")

    if switch_count > 0:
        print("[OK] 输出是交错的，两个任务在并行执行！")
    else:
        print("[WARN] 输出没有交错，任务可能是串行执行的")

    # 验证时间
    expected_serial_time = 0.5 * 5 * 2  # 0.5s * 5 chunks * 2 tasks = 5s
    expected_parallel_time = 0.5 * 5     # 0.5s * 5 chunks = 2.5s

    print(f"\n预期串行时间: ~{expected_serial_time}s")
    print(f"预期并行时间: ~{expected_parallel_time}s")
    print(f"实际耗时: {elapsed:.2f}s")

    if elapsed < expected_serial_time * 0.7:
        print("[OK] 时间验证通过，任务确实是并行执行的！")
    else:
        print("[WARN] 耗时接近串行时间，并行效果不明显")


async def test_basic_queue():
    """测试基本的队列多路复用"""
    print("\n" + "="*70)
    print("测试 队列多路复用")
    print("="*70)

    queue: asyncio.Queue[dict] = asyncio.Queue()
    completed_events = {"task_a": asyncio.Event(), "task_b": asyncio.Event()}

    async def producer(task_id: str, count: int):
        """模拟任务产生输出"""
        for i in range(count):
            await queue.put({
                "type": "chunk",
                "task_id": task_id,
                "content": f"{task_id} message {i}"
            })
            await asyncio.sleep(0.1)
        completed_events[task_id].set()

    # 启动两个生产者
    asyncio.create_task(producer("task_a", 3))
    asyncio.create_task(producer("task_b", 3))

    # 消费输出
    received = []
    expected_tasks = {"task_a", "task_b"}
    remaining_tasks = set(expected_tasks)

    while remaining_tasks:
        # 检查已完成的任务
        done_tasks = {tid for tid in remaining_tasks if completed_events[tid].is_set()}
        remaining_tasks -= done_tasks

        if remaining_tasks:
            try:
                chunk = await asyncio.wait_for(queue.get(), timeout=0.05)
                received.append(chunk)
                print(f"  收到: [{chunk.get('task_id')}] {chunk.get('content')}")
            except asyncio.TimeoutError:
                continue
        else:
            # 所有任务已完成，清空队列
            while not queue.empty():
                chunk = queue.get_nowait()
                received.append(chunk)
                print(f"  收到: [{chunk.get('task_id')}] {chunk.get('content')}")

    print(f"\n共收到 {len(received)} 条消息")

    task_a_count = len([r for r in received if r.get("task_id") == "task_a"])
    task_b_count = len([r for r in received if r.get("task_id") == "task_b"])

    print(f"task_a: {task_a_count} 条")
    print(f"task_b: {task_b_count} 条")

    if task_a_count == 3 and task_b_count == 3:
        print("[OK] 队列多路复用工作正常！")
    else:
        print("[WARN] 消息数量不匹配")


async def main():
    """主测试函数"""
    print("\n" + "="*70)
    print("流式并行执行架构测试")
    print("="*70)

    # 测试队列多路复用
    await test_basic_queue()

    # 测试流式并行执行
    await test_streaming_parallel()

    print("\n" + "="*70)
    print("测试完成")
    print("="*70)


if __name__ == "__main__":
    asyncio.run(main())
