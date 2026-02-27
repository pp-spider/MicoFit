# Planner 架构升级方案

## 一、背景与目标

### 当前架构问题

现有 `RouterAgent` 架构只能处理**单一意图**请求，无法处理复杂多步骤任务：

```
用户: "制定训练计划并解释每个动作"
当前: Router → 识别 "workout" → WorkoutSubAgent → 结束
问题: ChatSubAgent 根本没被调用，用户得不到解释
```

### 目标

升级为 **Planner 架构**，支持：
- 复杂任务自动拆分
- 多 Agent 协作执行
- 任务依赖管理
- 结果合并输出

---

## 二、架构设计

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        PlannerAgent                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ TaskAnalyzer│  │ TaskPlanner │  │    TaskExecutor         │ │
│  │  (任务分析)  │→│ (任务规划)   │→│    (任务执行引擎)        │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
│         ↓                ↓                      ↓              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              SharedContextPool (共享上下文池)               ││
│  │   - task_results: Dict[任务ID, 结果]                        ││
│  │   - execution_state: Dict[任务ID, 状态]                     ││
│  │   - artifacts: Dict[任务ID, 产物]                           ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
         ↑                              ↓
         │              ┌──────────────┴──────────────┐
         │              │         SubAgents           │
         │              │  ┌─────────┐  ┌──────────┐  │
         │              │  │  Chat   │  │ Workout  │  │
         │              │  │ SubAgent│  │ SubAgent │  │
         │              │  └────┬────┘  └────┬─────┘  │
         │              │       │            │        │
         │              │       └─────┬──────┘        │
         │              │             ↓               │
         │              │  ┌─────────────────────┐    │
         │              │  │  ResultAggregator   │    │
         │              │  │    (结果聚合器)      │    │
         │              │  └─────────────────────┘    │
         │              └─────────────────────────────┘
         │
         ↓
    ┌─────────────────────────────────────────┐
    │              用户请求                   │
    │  "制定训练计划并解释每个动作"          │
    └─────────────────────────────────────────┘
```

### 2.2 核心组件

| 组件 | 职责 | 输入 | 输出 |
|-----|-----|-----|-----|
| **TaskAnalyzer** | 分析用户请求，识别任务类型和复杂度 | user_message | TaskAnalysis |
| **TaskPlanner** | 拆分子任务，确定执行顺序和依赖 | TaskAnalysis | ExecutionPlan |
| **TaskExecutor** | 按计划执行任务，协调SubAgent | ExecutionPlan | AggregatedResult |
| **SharedContextPool** | 跨任务共享数据和状态 | - | - |
| **ResultAggregator** | 合并多任务结果 | 多任务输出 | 最终响应 |

---

## 三、详细设计

### 3.1 数据结构设计

#### 任务定义 (Task)

```python
# 新增文件: app/agents/models.py
from typing import TypedDict, Literal
from enum import Enum

class TaskStatus(str, Enum):
    """任务状态"""
    PENDING = "pending"          # 等待执行
    RUNNING = "running"          # 执行中
    COMPLETED = "completed"      # 已完成
    FAILED = "failed"            # 执行失败
    WAITING_DEPENDENCY = "waiting_dependency"  # 等待依赖

class TaskType(str, Enum):
    """任务类型"""
    WORKOUT = "workout"          # 训练计划生成
    CHAT = "chat"                # 对话
    FEEDBACK = "feedback"        # 训练反馈
    EXPLANATION = "explanation"  # 解释说明
    ANALYSIS = "analysis"        # 数据分析

class Task(TypedDict):
    """任务定义"""
    id: str                      # 任务唯一ID
    type: TaskType               # 任务类型
    description: str             # 任务描述
    agent_name: str              # 执行的Agent名称
    input_data: dict             # 输入数据
    depends_on: list[str]        # 依赖的任务ID列表
    status: TaskStatus           # 任务状态
    output_data: dict | None     # 输出数据
    error: str | None            # 错误信息
```

#### 执行计划 (ExecutionPlan)

```python
class ExecutionPlan(TypedDict):
    """执行计划"""
    tasks: list[Task]                    # 任务列表
    execution_order: list[str]            # 执行顺序（拓扑排序）
    requires_collaboration: bool          # 是否需要协作
    parallel_groups: list[list[str]]      # 可并行执行的任务分组
```

#### 任务分析结果 (TaskAnalysis)

```python
class TaskAnalysis(TypedDict):
    """任务分析结果"""
    raw_intents: list[str]                # 原始意图列表
    primary_intent: str                   # 主要意图
    requires_planning: bool               # 是否需要规划
    complexity: Literal["simple", "medium", "complex"]  # 复杂度
    extracted_entities: dict              # 提取的实体
    sub_tasks: list[dict]                 # 识别的子任务
```

### 3.2 核心模块设计

#### 3.2.1 TaskAnalyzer - 任务分析器

```python
# 新增文件: app/agents/task_analyzer.py
class TaskAnalyzer:
    """任务分析器 - 分析用户请求，识别任务类型和复杂度"""

    async def analyze(self, message: str, user_profile: dict) -> TaskAnalysis:
        """
        分析用户请求

        Args:
            message: 用户消息
            user_profile: 用户画像

        Returns:
            TaskAnalysis: 任务分析结果
        """
        # 1. 调用LLM进行多意图识别
        multi_intent_result = await self._multi_intent_recognition(message, user_profile)

        # 2. 判断是否需要规划
        requires_planning = self._check_requires_planning(multi_intent_result)

        # 3. 拆分子任务
        sub_tasks = self._decompose_tasks(multi_intent_result)

        return TaskAnalysis(
            raw_intents=multi_intent_result["intents"],
            primary_intent=multi_intent_result["primary_intent"],
            requires_planning=requires_planning,
            complexity=multi_intent_result.get("complexity", "simple"),
            extracted_entities=multi_intent_result.get("entities", {}),
            sub_tasks=sub_tasks
        )

    async def _multi_intent_recognition(self, message: str, user_profile: dict) -> dict:
        """多意图识别 - 识别所有可能的意图"""
        prompt = MULTI_INTENT_PROMPT.format(
            message=message,
            user_profile=user_profile
        )
        # 调用LLM...
```

#### 3.2.2 TaskPlanner - 任务规划器

```python
# 新增文件: app/agents/task_planner.py
class TaskPlanner:
    """任务规划器 - 拆分子任务，确定执行顺序"""

    def __init__(self, agent_registry: dict[str, BaseSubAgent]):
        self.agent_registry = agent_registry

    def plan(self, analysis: TaskAnalysis) -> ExecutionPlan:
        """
        生成执行计划

        Args:
            analysis: 任务分析结果

        Returns:
            ExecutionPlan: 执行计划
        """
        tasks = []
        task_id_counter = 0

        # 1. 为每个子任务创建Task对象
        for sub_task in analysis["sub_tasks"]:
            task = Task(
                id=f"task_{task_id_counter}",
                type=sub_task["type"],
                description=sub_task["description"],
                agent_name=self._map_intent_to_agent(sub_task["type"]),
                input_data=sub_task.get("input_data", {}),
                depends_on=sub_task.get("depends_on", []),
                status=TaskStatus.PENDING,
                output_data=None,
                error=None
            )
            tasks.append(task)
            task_id_counter += 1

        # 2. 拓扑排序确定执行顺序
        execution_order = self._topological_sort(tasks)

        # 3. 识别可并行执行的任务
        parallel_groups = self._find_parallel_groups(tasks)

        return ExecutionPlan(
            tasks=tasks,
            execution_order=execution_order,
            requires_collaboration=len(tasks) > 1,
            parallel_groups=parallel_groups
        )

    def _topological_sort(self, tasks: list[Task]) -> list[str]:
        """拓扑排序 - 确定任务执行顺序"""
        # 构建依赖图
        # 执行Kahn算法或DFS...
        pass

    def _find_parallel_groups(self, tasks: list[Task]) -> list[list[str]]:
        """识别可并行执行的任务"""
        # 无依赖的任务可以并行
        pass
```

#### 3.2.3 SharedContextPool - 共享上下文池

```python
# 新增文件: app/agents/shared_context.py
class SharedContextPool:
    """共享上下文池 - 跨任务共享数据"""

    def __init__(self):
        self._data: dict[str, Any] = {}
        self._locks: dict[str, asyncio.Lock] = {}
        self._events: dict[str, asyncio.Event] = {}

    def write(self, key: str, value: Any):
        """写入数据"""
        self._data[key] = value
        # 触发等待该数据的任务
        if key in self._events:
            self._events[key].set()

    def read(self, key: str) -> Any:
        """读取数据"""
        return self._data.get(key)

    async def wait_for(self, key: str, timeout: float = 30.0) -> Any:
        """等待数据准备好（用于依赖处理）"""
        if key in self._data:
            return self._data[key]

        if key not in self._events:
            self._events[key] = asyncio.Event()

        try:
            await asyncio.wait_for(self._events[key].wait(), timeout)
            return self._data.get(key)
        except asyncio.TimeoutError:
            raise TimeoutError(f"等待数据 {key} 超时")

    def get_workout_plan(self) -> dict | None:
        """获取训练计划（快捷方法）"""
        return self._data.get("workout_plan")

    def set_workout_plan(self, plan: dict):
        """设置训练计划"""
        self._data["workout_plan"] = plan

    def clear(self):
        """清空上下文"""
        self._data.clear()
        self._events.clear()
```

#### 3.2.4 ResultAggregator - 结果聚合器

```python
# 新增文件: app/agents/result_aggregator.py
class ResultAggregator:
    """结果聚合器 - 合并多任务结果"""

    def aggregate(self, tasks: list[Task], context: SharedContextPool) -> dict:
        """
        聚合多任务结果

        Args:
            tasks: 执行完成的任务列表
            context: 共享上下文

        Returns:
            dict: 聚合后的最终结果
        """
        # 1. 按执行顺序整理结果
        results_by_type = {}
        for task in tasks:
            if task["status"] == TaskStatus.COMPLETED:
                results_by_type[task["type"]] = task["output_data"]

        # 2. 根据任务组合选择聚合策略
        if "workout" in results_by_type and "explanation" in results_by_type:
            return self._aggregate_workout_with_explanation(results_by_type)
        elif "workout" in results_by_type and "chat" in results_by_type:
            return self._aggregate_workout_with_chat(results_by_type)
        else:
            return self._aggregate_simple(results_by_type)

    def _aggregate_workout_with_explanation(self, results: dict) -> dict:
        """聚合训练计划 + 解释"""
        workout_plan = results.get("workout", {}).get("plan")
        explanation = results.get("explanation", {}).get("content")

        return {
            "type": "workout_with_explanation",
            "content": f"{explanation}\n\n---\n\n{workout_plan}",
            "plan": workout_plan,
            "response_format": "markdown_with_json"
        }
```

### 3.3 Prompt 设计

#### 多意图识别 Prompt

```python
# prompts.py 新增
MULTI_INTENT_PROMPT = """你是微动MicoFit的任务分析助手。

用户消息: {message}

用户画像:
{fitness_level} | {goal} | {scene} | {time_budget}分钟

## 任务类型定义

1. **workout** - 训练计划相关
   - 生成计划、调整计划、换计划
   - 部位训练、场景训练、时间训练
   - 强度调整

2. **chat** - 普通对话
   - 知识问答、动作咨询
   - 闲聊、感谢

3. **explanation** - 解释说明
   - 解释动作、解释计划
   - 为什么推荐这个

4. **feedback** - 训练反馈
   - 反馈训练感受
   - 调整建议

## 输出格式

```json
{{
    "intents": ["workout", "explanation"],           // 识别到的所有意图
    "primary_intent": "workout",                     // 主要意图
    "complexity": "complex",                         // simple | medium | complex
    "sub_tasks": [                                   // 子任务列表
        {{
            "type": "workout",
            "description": "生成训练计划",
            "input_data": {{"focus": "core", "duration": 15}},
            "depends_on": []
        }},
        {{
            "type": "explanation",
            "description": "解释计划中的每个动作",
            "input_data": {{"plan_reference": "task_0"}},  // 依赖上一个任务
            "depends_on": ["task_0"]
        }}
    ],
    "entities": {{
        "focus_body_part": "core",
        "duration": 15
    }}
}}
```

请分析用户消息：
"""
```

### 3.4 场景示例

#### 场景1: "制定训练计划并解释每个动作"

```
1. TaskAnalyzer 分析:
   - 识别意图: ["workout", "explanation"]
   - 复杂度: complex
   - 子任务: [生成计划, 解释动作]

2. TaskPlanner 规划:
   - task_0: type=workout, depends_on=[]
   - task_1: type=explanation, depends_on=[task_0]

3. TaskExecutor 执行:
   - 执行 task_0 → WorkoutSubAgent → 生成计划 → 写入 SharedContextPool
   - 等待 task_0 完成
   - 执行 task_1 → ChatSubAgent(带计划上下文) → 解释动作
   - 合并结果

4. ResultAggregator 聚合:
   - 返回: "计划已生成，以下是每个动作的详细解释..." + JSON计划
```

#### 场景2: "今天练什么？" (简单场景)

```
1. TaskAnalyzer 分析:
   - 识别意图: ["workout"]
   - 复杂度: simple
   - 子任务: [生成计划]

2. TaskPlanner 规划:
   - task_0: type=workout, depends_on=[]

3. TaskExecutor 执行:
   - 直接执行 task_0 → WorkoutSubAgent

4. 结果: 直接返回训练计划
```

---

## 四、文件修改清单

### 4.1 新增文件

| 文件路径 | 描述 |
|---------|------|
| `backend/app/agents/models.py` | 数据模型定义 (Task, ExecutionPlan等) |
| `backend/app/agents/task_analyzer.py` | 任务分析器 |
| `backend/app/agents/task_planner.py` | 任务规划器 |
| `backend/app/agents/task_executor.py` | 任务执行器 |
| `backend/app/agents/shared_context.py` | 共享上下文池 |
| `backend/app/agents/result_aggregator.py` | 结果聚合器 |
| `backend/app/agents/planner_agent.py` | PlannerAgent (主入口) |

### 4.2 修改文件

| 文件路径 | 修改内容 |
|---------|---------|
| `backend/app/agents/state.py` | 新增 PlannerState, TaskState |
| `backend/app/agents/prompts.py` | 新增 MULTI_INTENT_PROMPT |
| `backend/app/agents/router_agent.py` | 重命名为 planner_agent.py 或保留兼容 |
| `backend/app/api/v1/ai.py` | 修改调用入口 |

### 4.3 核心类图

```
┌─────────────────────────────────────────────────────────────────┐
│                        PlannerAgent                              │
│  - task_analyzer: TaskAnalyzer                                  │
│  - task_planner: TaskPlanner                                     │
│  - task_executor: TaskExecutor                                  │
│  - shared_context: SharedContextPool                             │
│  - result_aggregator: ResultAggregator                          │
│                                                                  │
│  + process(): AsyncGenerator                                     │
│  + analyze(): TaskAnalysis                                       │
│  + plan(): ExecutionPlan                                         │
│  + execute(): dict                                               │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐
│  TaskAnalyzer   │  │  TaskPlanner    │  │   TaskExecutor      │
│  - analyze()    │  │  - plan()        │  │   - execute()       │
│  - _multi_intent│  │  - _topo_sort()  │  │   - _execute_task() │
│                 │  │  - _find_parallel│  │   - _wait_deps()    │
└─────────────────┘  └─────────────────┘  └─────────────────────┘
         │                   │                       │
         │                   │                       │
         ▼                   ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SharedContextPool                            │
│  - _data: dict                  - write():                    │
│  - _events: dict                - read():                      │
│  - get_workout_plan()           - wait_for():                  │
│  - set_workout_plan()           - clear():                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 五、执行流程

### 5.1 完整流程图

```
用户请求
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. TaskAnalyzer.analyze()                                       │
│    - 多意图识别                                                  │
│    - 任务拆分                                                   │
│    - 返回 TaskAnalysis                                          │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. TaskPlanner.plan()                                           │
│    - 创建Task对象                                                │
│    - 拓扑排序                                                   │
│    - 确定并行任务                                                │
│    - 返回 ExecutionPlan                                         │
└─────────────────────────────────────────────────────────────────┘
    │
    ├─── 简单任务 (complexity=simple) ────────────────────────────│
    │                                                              │
    ▼                                                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3a. TaskExecutor.execute_simple()                               │
│    - 直接调用对应SubAgent                                        │
│    - 返回单任务结果                                              │
└─────────────────────────────────────────────────────────────────┘
    │
    ├─── 复杂任务 (complexity=complex) ───────────────────────────│
    │                                                              │
    ▼                                                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3b. TaskExecutor.execute_complex()                              │
│    ┌─────────────────────────────────────────────────────────┐ │
│    │ for task_id in execution_order:                         │ │
│    │   - 检查依赖是否完成                                     │ │
│    │   - 如果依赖未完成，等待                                  │ │
│    │   - 准备输入数据（合并依赖输出）                         │ │
│    │   - 调用对应SubAgent                                     │ │
│    │   - 写入SharedContextPool                                │ │
│    │   - 更新任务状态                                         │ │
│    └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. ResultAggregator.aggregate()                                │
│    - 根据任务类型选择聚合策略                                    │
│    - 合并输出                                                    │
│    - 返回最终响应                                                │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
   用户
```

---

## 六、向后兼容方案

### 6.1 渐进式迁移

```python
# 方案1: 共存
# 保留原RouterAgent，新增PlannerAgent
# 通过配置切换使用哪个Agent

# 方案2: 自动选择
# TaskAnalyzer 自动判断:
# - 单意图 → 使用原Router流程
# - 多意图 → 使用Planner流程
```

### 6.2 配置项

```python
# config.py 新增
class Settings:
    # ... 现有配置 ...

    # Planner 相关
    ENABLE_PLANNER_MODE: bool = True          # 启用Planner模式
    COMPLEXITY_THRESHOLD: str = "medium"       # 复杂度阈值
    TASK_EXECUTION_TIMEOUT: int = 120          # 任务执行超时(秒)
```

---

## 七、测试方案

### 7.1 单元测试

- `test_task_analyzer.py` - 测试多意图识别
- `test_task_planner.py` - 测试任务规划和拓扑排序
- `test_shared_context.py` - 测试上下文读写和事件

### 7.2 集成测试

- `test_simple_workflow.py` - 单意图场景测试
- `test_complex_workflow.py` - 多意图协作场景测试
- `test_plan_with_explanation.py` - "计划+解释"场景测试

### 7.3 测试用例

```python
# test_complex_workout.py
async def test_workout_with_explanation():
    """测试: 生成训练计划并解释每个动作"""

    # 输入
    message = "给我制定一个训练计划，然后解释一下每个动作"

    # 执行
    result = await planner.process(message, user_profile)

    # 验证
    assert result["type"] == "workout_with_explanation"
    assert "plan" in result
    assert result["plan"]["modules"] is not None
    assert len(result["content"]) > 0  # 包含解释内容
```

---

## 八、风险与应对

| 风险 | 影响 | 应对措施 |
|-----|-----|---------|
| LLM多意图识别不稳定 | 任务拆分错误 | 添加置信度阈值，低于阈值走简单流程 |
| 任务依赖死循环 | 任务无法完成 | 拓扑排序检测环 |
| 子Agent超时 | 整体响应慢 | 添加超时控制，部分失败返回已完成的 |
| 结果合并不理想 | 输出格式乱 | 针对不同组合设计专门聚合策略 |

---

## 九、总结

| 特性 | 当前Router | 升级后Planner |
|-----|-----------|--------------|
| 任务处理 | 单一意图 | 多意图/复杂任务 |
| Agent协作 | 无 | 支持依赖传递 |
| 执行方式 | 线性 | 拓扑排序+并行 |
| 结果处理 | 直接返回 | 智能聚合 |
| 扩展性 | 添加if-else | 新增Agent即可 |

通过以上方案，项目将支持复杂多步骤任务的处理，实现真正的多Agent协作。
