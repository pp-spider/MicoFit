# AI Agent Planner 机制技术实现分析报告

## 一、项目概述

本项目是一个基于 Flutter 的健身应用（MicoFit），其 FastAPI 后端实现了一套完整的 AI Agent 系统。该系统采用 **双层 Agent 架构**，支持两种工作模式：

1. **RouterAgent 模式** - 简单路由：意图识别 + 单 SubAgent 调用
2. **PlannerAgent 模式** - 复杂协作：多意图分析 + 多任务规划执行

---

## 二、整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                      外部调用 (API层)                              │
│                  PlannerAgent / RouterAgent                      │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┴─────────────────────┐
        │                                           │
        ▼                                           ▼
┌───────────────────────┐               ┌───────────────────────┐
│   PlannerAgent        │               │   RouterAgent         │
│   (复杂多任务)         │               │   (简单双意图)         │
│                       │               │                       │
│ 1. TaskAnalyzer      │               │ 1. 意图识别           │
│ 2. TaskPlanner       │               │ 2. 路由决策           │
│ 3. TaskExecutor      │               │ 3. SubAgent调用        │
│ 4. ResultAggregator  │               │ 4. 结果整理           │
└───────────────────────┘               └───────────────────────┘
        │                                           │
        └─────────────────────┬─────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │       SubAgent 层             │
              │  ┌─────────┐   ┌──────────┐  │
              │  │ Chat    │   │ Workout  │  │
              │  │SubAgent │   │ SubAgent │  │
              │  └─────────┘   └──────────┘  │
              └───────────────────────────────┘
```

---

## 三、核心数据模型

### 3.1 任务状态与类型

**文件**: `backend/app/agents/models.py`

```python
class TaskStatus(str, Enum):
    PENDING = "pending"              # 待执行
    RUNNING = "running"              # 执行中
    COMPLETED = "completed"          # 已完成
    FAILED = "failed"                # 执行失败
    WAITING_DEPENDENCY = "waiting_dependency"  # 等待依赖

class TaskType(str, Enum):
    WORKOUT = "workout"              # 训练计划
    CHAT = "chat"                    # 普通对话
    FEEDBACK = "feedback"            # 反馈处理
    EXPLANATION = "explanation"      # 解释说明
    ANALYSIS = "analysis"            # 分析任务
```

### 3.2 核心数据结构

```python
class Task:
    id: str                          # 任务唯一标识
    type: TaskType                   # 任务类型
    agent_name: str                  # 执行的Agent名称
    depends_on: list[str]            # 依赖的任务ID列表
    status: TaskStatus               # 任务状态
    output_data: dict                # 任务输出数据

class ExecutionPlan:
    tasks: list[Task]                # 所有任务
    execution_order: list[str]        # 执行顺序
    parallel_groups: list[list[str]] # 并行任务组

class TaskAnalysis:
    raw_intents: list[str]           # 原始意图列表
    primary_intent: str              # 主要意图
    requires_planning: bool          # 是否需要规划
    complexity: str                   # 复杂度: simple/medium/complex
    extracted_entities: dict        # 提取的实体
    sub_tasks: list[dict]            # 子任务列表(含依赖关系)
```

---

## 四、PlannerAgent 核心实现

**文件**: `backend/app/agents/planner_agent.py`

### 4.1 工作流程

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ TaskAnalyzer │ → │ TaskPlanner  │ → │ TaskExecutor │ → │   Result     │
│   (任务分析)   │    │   (任务规划)   │    │   (任务执行)   │    │  Aggregator  │
└──────────────┘    └──────────────┘    └──────────────┘    │   (结果聚合)   │
                                                            └──────────────┘
```

### 4.2 核心处理流程

```python
async def process(self, user_message, user_profile, ...):
    # 步骤1: 任务分析 - 识别多意图
    task_analysis = await self.task_analyzer.analyze(
        user_message=user_message,
        user_profile=user_profile
    )

    # 步骤2: 任务规划 - 拆分子任务，确定执行顺序
    execution_plan = self.task_planner.plan(task_analysis)

    # 步骤3: 任务执行 - 按计划执行任务
    for task_id in execution_plan.get("execution_order"):
        executed_task = await self.task_executor._execute_task(task, ...)
        yield chunk  # 流式输出

    # 步骤4: 结果聚合 - 合并多任务结果
    aggregated = self.result_aggregator.aggregate(tasks, context)
```

---

## 五、TaskAnalyzer (任务分析器)

**文件**: `backend/app/agents/task_analyzer.py`

### 5.1 核心职责

1. **多意图识别** - 使用 LLM 识别所有可能意图
2. **复杂度评估** - simple / medium / complex
3. **实体提取** - 部位、场景、时长、强度
4. **子任务拆分** - 生成依赖关系图

### 5.2 核心方法

```python
async def analyze(self, user_message, user_profile):
    # 1. 调用LLM进行多意图识别
    multi_intent_result = await self._multi_intent_recognition(...)

    # 2. 判断是否需要规划
    requires_planning = len(intents) > 1 or complexity in ["medium", "complex"]

    # 3. 返回任务分析结果
    return TaskAnalysis(
        raw_intents=intents,
        primary_intent=primary_intent,
        requires_planning=requires_planning,
        complexity=complexity,
        extracted_entities=entities,
        sub_tasks=sub_tasks
    )
```

### 5.3 多意图识别 Prompt

```json
{
    "intents": ["workout", "explanation"],
    "primary_intent": "workout",
    "complexity": "complex",
    "sub_tasks": [
        {
            "type": "workout",
            "description": "生成训练计划",
            "depends_on": []
        },
        {
            "type": "explanation",
            "description": "解释动作",
            "depends_on": ["task_0"]
        }
    ]
}
```

### 5.4 降级分析机制

当 LLM 调用失败时，使用基于关键词的简单判断作为兜底：

```python
# 检测训练关键词
workout_keywords = ["训练", "练", "计划", "动", "运动", "健身"]
# 检测解释关键词
explain_keywords = ["解释", "说明", "为什么", "什么意思"]
```

---

## 六、TaskPlanner (任务规划器)

**文件**: `backend/app/agents/task_planner.py`

### 6.1 核心职责

1. **创建 Task 对象** - 将子任务转换为标准 Task 结构
2. **拓扑排序** - Kahn 算法确定执行顺序
3. **并行识别** - 识别可并行执行的任务组
4. **意图映射** - 映射任务类型到 Agent

### 6.2 意图到 Agent 映射

```python
def _map_intent_to_agent(self, intent):
    mapping = {
        "workout": "workout_sub_agent",
        "chat": "chat_sub_agent",
        "explanation": "chat_sub_agent",
        "feedback": "chat_sub_agent"
    }
    return mapping.get(intent, "chat_sub_agent")
```

### 6.3 拓扑排序算法 (Kahn 算法)

```python
def _topological_sort(self, tasks):
    # 构建入度表
    in_degree = {task.id: len(task.depends_on) for task in tasks}

    # 从入度为0的任务开始
    queue = [task for task in tasks if in_degree[task.id] == 0]

    # 按优先级排序：workout(3) > explanation(2) > chat(1)
    priority = {"workout": 3, "explanation": 2, "chat": 1}
    queue.sort(key=lambda t: priority.get(t.type.value, 0), reverse=True)

    # 遍历更新依赖任务的入度
    while queue:
        current = queue.pop(0)
        result.append(current.id)
        for task in tasks:
            if current.id in task.depends_on:
                in_degree[task.id] -= 1
                if in_degree[task.id] == 0:
                    queue.append(task)

    return result
```

### 6.4 并行组识别

```python
def _find_parallel_groups(self, tasks, execution_order):
    # 检查任务是否可以并行
    # 条件：无相互依赖
    # 返回分组：[[task_0, task_1], [task_2], [task_3]]
```

---

## 七、TaskExecutor (任务执行器)

**文件**: `backend/app/agents/task_executor.py`

### 7.1 核心职责

1. 按执行顺序执行任务
2. 处理任务依赖
3. 调用对应的 SubAgent
4. 管理共享上下文

### 7.2 任务执行流程

```python
async def _execute_task(self, task, context, ...):
    agent_name = task["agent_name"]
    task_type = task["type"]

    # 根据任务类型调用不同的Agent
    if task_type == "workout":
        # 调用WorkoutSubAgent
        async for chunk in agent.stream(state):
            chunks.append(chunk)
            if chunk.get("type") == "plan":
                plan = chunk.get("plan")

        # 写入共享上下文供后续任务使用
        context.set_workout_plan(plan)

    elif task_type == "explanation":
        # 从上下文获取依赖的计划
        plan = context.get_workout_plan()
        # 调用ChatSubAgent解释

    elif task_type == "chat":
        # 直接调用ChatSubAgent
```

### 7.3 依赖处理机制

```python
# 检查依赖是否完成
deps = task.get("depends_on", [])
for dep_id in deps:
    if dep_task.get("status") != TaskStatus.COMPLETED:
        await context.wait_task_complete(dep_id, timeout=30.0)
```

---

## 八、SharedContextPool (共享上下文)

**文件**: `backend/app/agents/shared_context.py`

### 8.1 核心功能

跨任务数据共享，解决任务间数据传递问题。

```python
class SharedContextPool:
    def __init__(self):
        self._data: dict[str, Any] = {}           # 数据存储
        self._events: dict[str, asyncio.Event] = {}  # 事件通知

    # 核心方法
    def write(key, value)      # 写入数据
    def read(key)              # 读取数据
    async def wait_for(key)    # 异步等待数据

    # 快捷方法
    def get_workout_plan()     # 获取训练计划
    def set_workout_plan()     # 设置训练计划
    def get_task_result()      # 获取任务结果
    async def wait_task_complete()  # 等待任务完成
```

### 8.2 核心特性

- 基于 `asyncio.Event` 的任务依赖通知机制
- 支持超时控制的等待机制
- 任务结果跨 Agent 共享

---

## 九、ResultAggregator (结果聚合器)

**文件**: `backend/app/agents/result_aggregator.py`

### 9.1 聚合策略

```python
def aggregate(self, tasks, context):
    results_by_type = {task.type: task.output_data for task in completed}

    if "workout" in results and "explanation" in results:
        return self._aggregate_workout_with_explanation(results)
    elif "workout" in results and "chat" in results:
        return self._aggregate_workout_with_chat(results)
    # ... 更多组合
```

### 9.2 输出格式

```python
AggregatedResult(
    type="workout_with_explanation",
    content="解释内容\n\n---\n\n训练计划内容",
    plan=workout_plan,
    response_format="markdown_with_json",
    tasks_output=results
)
```

---

## 十、SubAgent 实现

### 10.1 BaseSubAgent 抽象基类

**文件**: `backend/app/agents/base_sub_agent.py`

```python
class BaseSubAgent(ABC):
    @property
    @abstractmethod
    def name(self) -> str: pass

    @property
    @abstractmethod
    def description(self) -> str: pass

    @abstractmethod
    async def stream(self, state) -> AsyncGenerator[dict]: pass

    @abstractmethod
    async def process(self, state) -> dict: pass
```

### 10.2 WorkoutSubAgent (训练计划 Agent)

**文件**: `backend/app/agents/workout_sub_agent.py`

**LangGraph 工作流**:

```
build_prompt → generate → parse → validate → [retry | end]
```

**节点说明**:

1. **build_prompt**: 构建系统提示词 + 用户消息
2. **generate**: 流式调用 LLM 生成计划
3. **parse**: 从响应中提取 JSON
4. **validate**: 验证计划字段完整性
5. **retry**: 验证失败时使用 AI 修正错误

**验证规则**:

```python
# 必要字段
required_fields = ["id", "title", "modules", "total_duration", "scene", "rpe"]

# 时长范围
duration = plan.get("total_duration", 0)
if duration <= 0 or duration > 60:
    return False

# RPE范围
r validation_passed =pe = plan.get("rpe", 0)
if rpe < 1 or rpe > 10:
    return validation_passed = False
```

**重试机制**:
- 最大重试次数: 3 次
- 使用 AI 生成修正后的 prompt
- 超过最大次数后返回错误

### 10.3 ChatSubAgent (对话 Agent)

**文件**: `backend/app/agents/chat_sub_agent.py`

**LangGraph 工作流**:

```
build_prompt → generate → post_process → end
```

**职责**:
- 健身知识问答
- 动作指导
- 健康咨询
- 闲聊

---

## 十一、RouterAgent 实现 (简单路由模式)

**文件**: `backend/app/agents/router_agent.py`

### 工作流程

```
用户消息 → 意图识别 → 路由决策 → SubAgent调用 → 结果整理
```

### 核心方法

1. **意图识别** (`_intent_recognition_node`)
2. **路由决策** (`_route_node`)
3. **SubAgent 调用**

---

## 十二、完整数据流示例

### 简单场景 (RouterAgent)

```
用户: "今天练什么"
    │
    ▼
RouterAgent.意图识别
    │ intent="workout", confidence=0.95
    ▼
路由到 WorkoutSubAgent
    │
    ▼
WorkoutSubAgent.stream()
    │ chunk → chunk → plan → done
    ▼
返回给前端
```

### 复杂场景 (PlannerAgent)

```
用户: "给我制定训练计划并解释每个动作"
    │
    ▼
TaskAnalyzer.analyze()
    │ intents=["workout", "explanation"]
    │ complexity="medium"
    │ sub_tasks=[{type:workout}, {type:explanation, depends_on:[task_0]}]
    ▼
TaskPlanner.plan()
    │ execution_order=["task_0", "task_1"]
    │ parallel_groups=[["task_0"], ["task_1"]]
    ▼
TaskExecutor.execute()
    │
    ├─→ task_0: WorkoutSubAgent → 生成计划 → 写入上下文
    │
    └─→ task_1: ChatSubAgent(从上下文获取计划) → 解释动作
    │
    ▼
ResultAggregator.aggregate()
    │ 合并为 "解释内容\n\n---\n\n计划内容"
    ▼
返回给前端
```

---

## 十三、关键设计特点

### 1. 流式输出
- 所有 Agent 支持 `AsyncGenerator` 流式输出
- 前端可以实时显示生成内容
- 包含 `chunk`, `plan`, `done`, `error` 类型

### 2. 任务依赖管理
- 基于 `SharedContextPool` 的事件通知机制
- 支持等待超时处理
- 拓扑排序保证执行顺序

### 3. 多 Agent 协作
- **RouterAgent**: 简单双意图路由
- **PlannerAgent**: 复杂多任务规划
- 意图可映射到对应 SubAgent

### 4. 错误处理和重试
- WorkoutSubAgent 内置验证 + AI 修正重试
- 最大 3 次重试机制
- 降级分析作为兜底

### 5. Prompt 工程
- 角色定义清晰 (AI 健身教练)
- 用户画像信息注入
- JSON 输出格式严格约束
- 多意图识别支持

---

## 十四、文件清单

| 文件 | 职责 |
|------|------|
| `backend/app/agents/models.py` | 数据模型定义 |
| `backend/app/agents/state.py` | Agent 状态定义 |
| `backend/app/agents/prompts.py` | Prompt 模板 |
| `backend/app/agents/shared_context.py` | 共享上下文 |
| `backend/app/agents/base_sub_agent.py` | SubAgent 基类 |
| `backend/app/agents/workout_sub_agent.py` | 训练计划 Agent |
| `backend/app/agents/chat_sub_agent.py` | 对话 Agent |
| `backend/app/agents/router_agent.py` | 路由 Agent |
| `backend/app/agents/planner_agent.py` | 规划 Agent |
| `backend/app/agents/task_analyzer.py` | 任务分析器 |
| `backend/app/agents/task_planner.py` | 任务规划器 |
| `backend/app/agents/task_executor.py` | 任务执行器 |
| `backend/app/agents/result_aggregator.py` | 结果聚合器 |

---

## 十五、总结

本项目的 AI Agent 实现采用了现代 LLM 应用的最佳实践：

1. **模块化设计** - 各组件职责清晰，易于维护和扩展
2. **可配置性** - 通过 Prompt 模板和映射配置实现灵活定制
3. **可靠性** - 完善的错误处理和重试机制
4. **实时性** - 流式输出提升用户体验
5. **协作性** - 多 Agent 协作处理复杂任务

这套系统能够有效支持健身场景下的多种用户需求，从简单的训练计划生成到复杂的多意图对话，都能得到很好的处理。
