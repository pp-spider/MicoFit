# MicoFit AI Agent 实现分析报告

## 一、技术框架

### 1.1 后端技术栈

| 框架/库 | 用途 | 关键配置 |
|---------|------|----------|
| **LangGraph** | Agent工作流编排 | 状态图驱动的工作流 |
| **LangChain Core** | 消息类型定义和基础组件 | HumanMessage, SystemMessage, AIMessage |
| **LangChain OpenAI** | OpenAI模型集成 | ChatOpenAI类 |
| **OpenAI API** | LLM服务 | GPT-4o-mini (默认), GPT-3.5-turbo(摘要) |
| **SQLAlchemy** | ORM数据库操作 | 2.0.35 |
| **MySQL (aiomysql)** | 异步数据库 | - |
| **sse-starlette** | SSE流式响应 | EventSourceResponse |

**模型配置** (`backend/app/core/config.py`):
```python
OPENAI_MODEL: str = "gpt-4o-mini"
OPENAI_BASE_URL: str = "https://api.openai.com/v1"
OPENAI_TEMPERATURE: float = 0.7
OPENAI_MAX_TOKENS: int = 8192
```

### 1.2 前端技术栈

| 框架/库 | 用途 |
|---------|------|
| **Flutter** | 跨平台UI框架 |
| **Provider** | 状态管理 |
| **http** | HTTP客户端，支持SSE |
| **SharedPreferences** | 本地数据持久化 |
| **flutter_markdown** | Markdown渲染 |

---

## 二、Agent架构

### 2.1 后端Agent设计

项目实现了**两个核心Agent**，分别位于：
- `backend/app/agents/workout_agent.py` - 训练计划生成Agent
- `backend/app/agents/chat_agent.py` - 聊天对话Agent

#### WorkoutAgent（训练计划生成Agent）

**工作流图（LangGraph StateGraph）**：
```
build_prompt → generate → parse → validate → END
```

**核心类结构**：
```python
class WorkoutAgent:
    def __init__(self):
        self.llm = ChatOpenAI(...)  # OpenAI模型实例
        self.workflow = self._build_workflow()  # LangGraph工作流

    def _build_workflow(self) -> StateGraph:
        # 4节点工作流
        workflow.add_node("build_prompt", self._build_prompt_node)
        workflow.add_node("generate", self._generate_node)
        workflow.add_node("parse", self._parse_node)
        workflow.add_node("validate", self._validate_node)
```

**验证逻辑**：
- 检查必要字段：`id`, `title`, `modules`, `total_duration`, `scene`, `rpe`
- 验证时长范围：1-60分钟
- 验证RPE强度：1-10

#### ChatAgent（聊天对话Agent）

**核心配置**：
```python
class ChatAgent:
    MAX_HISTORY_MESSAGES = 20  # 最大历史消息数

    def __init__(self):
        self.llm = ChatOpenAI(..., streaming=True)  # 启用流式
```

**关键方法**：
- `_build_messages()` - 构建消息列表（系统提示+历史+当前消息）
- `chat_stream()` - 流式聊天，支持SSE
- `chat_sync()` - 同步聊天
- `chat_stream_continue()` - 继续之前的流式生成（应用从后台恢复时使用）

### 2.2 前端服务层设计

#### AIApiService (`lib/services/ai_api_service.dart`)

**核心方法**：
```dart
// 流式聊天（SSE）
Stream<AIStreamChunk> sendMessageStream({String? sessionId, required String message})

// 继续流式生成（断点续传）
Stream<AIStreamChunk> continueStream({required String sessionId, required String existingContent})

// 流式生成训练计划
Stream<AIStreamChunk> generateWorkoutPlanStream({Map<String, dynamic>? preferences})
```

#### AIEnhancedService (`lib/services/ai_enhanced_service.dart`)

包含熔断器、缓存、重试机制：
```dart
class AIEnhancedService {
  final CircuitBreaker _circuitBreaker;
  final AIResponseCache _cache;
  final ContextCompressor _compressor;
  final RetryConfig _retryConfig;
}
```

---

## 三、记忆模块（长短期记忆）

### 3.1 短期记忆（会话内记忆）

**实现方式**：数据库存储 + 上下文窗口

**配置参数** (`backend/app/services/context_service.py`)：
```python
class ContextService:
    MAX_RECENT_MESSAGES = 20      # 保留最近20条消息
    MAX_CONTEXT_TOKENS = 4000     # 最大上下文token数
    SUMMARY_THRESHOLD = 10        # 超过10条消息触发摘要
```

**数据库模型**：

```python
# backend/app/models/chat_session.py
class ChatSession(Base):
    id = Column(CHAR(36), primary_key=True)
    user_id = Column(CHAR(36), ForeignKey("users.id"), nullable=False)
    title = Column(String(100))                    # 会话标题
    context_summary = Column(Text)                 # 会话上下文摘要（关键！）
    message_count = Column(Integer, default=0)
    created_at = Column(DateTime)
    updated_at = Column(DateTime)

class ChatMessage(Base):
    id = Column(CHAR(36), primary_key=True)
    session_id = Column(CHAR(36), ForeignKey("chat_sessions.id"))
    role = Column(String(20))                      # user/assistant/system/tool
    content = Column(Text)
    structured_data = Column(JSON)                 # 结构化数据（如训练计划JSON）
    data_type = Column(String(50))                 # workout_plan/text/tool_call
    tool_calls = Column(JSON)
    tool_call_id = Column(String(100))
    created_at = Column(DateTime)
```

### 3.2 长期记忆（跨会话记忆）

**实现方式**：会话摘要 + 用户记忆统计

#### ContextSummarizer 类

```python
class ContextSummarizer:
    """消息摘要器 - 对长对话进行智能摘要"""

    def __init__(self):
        self.llm = ChatOpenAI(
            model="gpt-3.5-turbo",  # 使用轻量级模型做摘要
            temperature=0.3,
            max_tokens=500,
        )

    async def summarize_messages(self, messages, max_summary_length=800) -> str:
        # 使用LLM生成对话摘要
```

**摘要关注点**：
1. 用户的健身目标、偏好和限制
2. 已生成的训练计划类型和效果
3. 用户的反馈和调整需求
4. 重要的个人信息（如伤病、可用器材等）

**摘要触发策略**：
- 每20条消息更新一次摘要
- 使用轻量级模型(GPT-3.5-turbo)生成摘要
- 保留最近20条原始消息 + 摘要作为上下文

#### 用户跨会话记忆

```python
async def get_user_memory(self, user_id: str, days: int = 7) -> Dict[str, Any]:
    """
    获取用户近期记忆（跨会话）
    包括：
    - recent_topics: 近期会话主题摘要列表
    - plans_generated: 生成的计划数量统计
    - sessions_count: 会话数量
    """
    # 查询最近N天的会话
    cutoff_date = datetime.utcnow() - timedelta(days=days)
```

### 3.3 记忆存储位置汇总

| 记忆类型 | 存储位置 | 表/字段 |
|---------|---------|---------|
| 原始消息 | MySQL数据库 | `chat_messages`表 |
| 会话摘要 | MySQL数据库 | `chat_sessions.context_summary` |
| 用户画像 | MySQL数据库 | `user_profiles`表 |
| 训练计划 | MySQL数据库 | `workout_plans`表 |
| 实时上下文 | 内存（请求期间） | `ChatAgentState` / `WorkoutAgentState` |
| 前端本地缓存 | SharedPreferences | `chat_history`, `pending_workout_plan` |

### 3.4 前端本地存储

**ChatLocalService** (`lib/services/chat_local_service.dart`):
```dart
class ChatLocalService {
  static const String _chatHistoryKey = 'chat_history';
  static const String _pendingPlanKey = 'pending_workout_plan';
  static const int _maxMessages = 100;  // 最大保存消息数量
}
```

**用户数据隔离** (`lib/utils/user_data_helper.dart`):
```dart
static Future<String> buildUserKey(String key) async {
  final userId = await getCurrentUserId();
  if (userId == null || userId.isEmpty) {
    return 'anonymous_$key';
  }
  return 'user_${userId}_$key';
}
```

---

## 四、上下文管理

### 4.1 状态定义（LangGraph）

**文件**: `backend/app/agents/state.py`

```python
class WorkoutAgentState(TypedDict):
    """训练计划生成Agent状态"""
    messages: Annotated[Sequence[BaseMessage], operator.add]
    user_id: str
    user_profile: dict | None
    workout_plan: dict | None
    plan_json_str: str | None
    validation_passed: bool
    error_message: str | None
    stream_chunks: list[str]

class ChatAgentState(TypedDict):
    """聊天Agent状态"""
    messages: Annotated[Sequence[BaseMessage], operator.add]
    user_id: str
    session_id: str
    user_profile: dict | None
    stream_chunks: list[str]
    has_workout_plan: bool
    workout_plan: dict | None
    error_message: str | None
```

### 4.2 上下文构建流程

**ChatAgent的上下文构建** (`_build_messages`方法)：

```python
def _build_messages(self, user_message, user_profile, history,
                   context_summary, recent_memories):
    messages = []

    # 1. 系统提示词（包含上下文摘要和记忆）
    system_prompt = build_system_prompt(
        user_profile=user_profile,
        context_summary=context_summary,      # 当前会话摘要
        recent_memories=recent_memories       # 跨会话记忆
    )
    messages.append(SystemMessage(content=system_prompt))

    # 2. 历史消息（最近20条）
    if history:
        recent_history = history[-self.MAX_HISTORY_MESSAGES:]
        for msg in recent_history:
            if role == "user":
                messages.append(HumanMessage(content=content))
            elif role == "assistant":
                messages.append(AIMessage(content=content))

    # 3. 当前用户消息
    messages.append(HumanMessage(content=user_message))

    return messages
```

### 4.3 系统提示词构建

**文件**: `backend/app/agents/prompts.py`

```python
def build_system_prompt(user_profile, context_summary, recent_memories) -> str:
    buffer = []

    # 1. 基础角色定义
    buffer.append("你是微动MicoFit的专属AI健身教练。")
    buffer.append("你的职责是为用户提供专业的健身建议、训练指导和健康咨询。")

    # 2. 添加上下文摘要（如果有）
    if context_summary:
        buffer.append("**【对话上下文摘要】**")
        buffer.append(context_summary)

    # 3. 添加近期记忆（跨会话）
    if recent_memories:
        buffer.append("**【近期重要信息】**")
        for memory in recent_memories:
            buffer.append(f"• {memory}")

    # 4. Function Calling 工具使用说明
    buffer.append("**工具使用**")
    buffer.append("你可以使用以下工具获取信息：")
    buffer.append("- get_user_profile: 获取用户的完整健身画像信息")

    # 5. 用户画像信息区域
    buffer.append("**【系统提供的用户画像信息】**")
    if user_profile:
        buffer.append(f"- **昵称**：{user_profile.get('nickname')}")
        buffer.append(f"- **健身水平**：{fitness_level_label}")
        buffer.append(f"- **健身目标**：{goal_label}")
        # ...

    return "\n".join(buffer)
```

### 4.4 上下文服务（ContextService）

**文件**: `backend/app/services/context_service.py`

**核心功能**：

| 方法 | 功能 |
|------|------|
| `get_context_for_chat()` | 获取聊天所需的完整上下文（摘要+最近消息） |
| `add_message_and_update_summary()` | 添加消息并智能更新摘要 |
| `generate_session_title()` | 基于第一条消息自动生成会话标题 |
| `get_user_memory()` | 获取用户跨会话记忆 |
| `get_session_memory_detail()` | 获取会话详细记忆 |
| `get_multi_session_summaries()` | 获取多个会话摘要列表 |
| `extract_key_info_from_session()` | 从会话中提取关键信息 |

### 4.5 前端上下文模型

**AIChatContext** (`lib/models/ai_chat_context.dart`):

```dart
class AIChatContext {
  final String? userNickname;
  final String? fitnessLevel;
  final String? goal;
  final String? scene;
  final int? timeBudget;
  final List<String>? limitations;
  final String? equipment;
  final List<ChatMessage> recentHistory;
}
```

**用途**：
- 构建个性化系统提示词
- 包含用户画像信息
- 转换为系统提示词供AI使用

### 4.6 上下文压缩与优化

**ContextCompressor** (`lib/services/ai_enhanced_service.dart`):

```dart
class ContextCompressor {
  final int maxContextLength = 4000;
  final int maxMessages = 20;

  // 压缩策略：保留第一条（系统提示）和最后 N-1 条
  List<Map<String, dynamic>> compress(messages) {
    return [
      messages.first,
      ...messages.sublist(messages.length - maxMessages + 1),
    ];
  }
}
```

---

## 五、前后端交互

### 5.1 流式响应（SSE）

**后端API端点** (`backend/app/api/v1/ai.py`):

```python
from sse_starlette.sse import EventSourceResponse

@router.post("/chat/stream")
async def chat_stream(request, current_user, db):
    service = AIService(db)

    async def event_generator():
        async for chunk in service.stream_chat(user_id, session_id, message):
            yield {
                "event": chunk.get("type", "chunk"),
                "data": json.dumps(chunk, ensure_ascii=False)
            }

    return EventSourceResponse(
        event_generator(),
        media_type="text/event-stream"
    )
```

**事件类型**：
- `chunk`: 文本流块
- `plan`: 包含生成的训练计划
- `done`: 完成
- `error`: 错误
- `session_created`: 新会话创建

### 5.2 前端流式处理

```dart
Stream<AIStreamChunk> sendMessageStream({String? sessionId, required String message}) async* {
  final request = http.Request(
    'POST',
    Uri.parse('${AppConfig.apiBaseUrl}/api/v1/ai/chat/stream'),
  );

  request.headers['Accept'] = 'text/event-stream';  // SSE 流式响应

  // 解析 SSE 流
  await for (final line in response.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    if (line.startsWith('data: ')) {
      final data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
      yield AIStreamChunk.fromJson(data);
    }
  }
}
```

---

## 六、关键设计亮点总结

### 6.1 后端亮点

1. **LangGraph工作流**：WorkoutAgent使用4节点工作流（build_prompt → generate → parse → validate），实现结构化的计划生成和验证

2. **双层记忆系统**：
   - 短期：会话内最近20条消息
   - 长期：跨会话摘要 + 用户记忆统计

3. **智能摘要**：使用轻量级模型（GPT-3.5-turbo）自动生成会话摘要，减少上下文窗口压力

4. **流式响应**：全面支持SSE流式输出，提升用户体验

5. **工具调用准备**：Prompt中已定义`get_user_profile`工具使用规范，为Function Calling预留扩展点

6. **会话智能命名**：基于意图识别和关键词提取自动生成会话标题

### 6.2 前端亮点

1. **服务层增强**：采用SSE流式通信实现实时AI响应，支持断点续传；增强型服务包含熔断器、缓存、重试机制提高稳定性

2. **状态管理**：Provider模式管理聊天状态，支持应用生命周期处理（后台恢复流式生成），节流更新优化UI性能

3. **上下文管理**：后端LangGraph Agent维护对话上下文，前端通过sessionId标识会话，AIChatContext构建系统提示词

4. **本地存储**：SharedPreferences存储，支持用户数据隔离（多用户场景），主要缓存待确认计划和临时消息

5. **UI设计**：精致的Material Design风格，支持Markdown渲染、流式光标动画、健身计划预览卡片、快捷提示网格等

---

## 七、核心文件清单

### 后端关键文件

| 文件路径 | 说明 |
|---------|------|
| `backend/app/agents/workout_agent.py` | 训练计划生成Agent |
| `backend/app/agents/chat_agent.py` | 聊天对话Agent |
| `backend/app/agents/prompts.py` | Prompt模板 |
| `backend/app/agents/state.py` | Agent状态定义 |
| `backend/app/services/context_service.py` | 上下文服务 |
| `backend/app/models/chat_session.py` | 聊天会话模型 |
| `backend/app/api/v1/ai.py` | AI API端点 |

### 前端关键文件

| 文件路径 | 说明 |
|---------|------|
| `lib/services/ai_api_service.dart` | AI API服务 |
| `lib/services/ai_enhanced_service.dart` | 增强型AI服务（含熔断器、缓存） |
| `lib/providers/chat_provider.dart` | 聊天状态管理 |
| `lib/pages/ai_chat_page.dart` | AI聊天页面 |
| `lib/models/ai_chat_context.dart` | AI聊天上下文模型 |
| `lib/models/chat_message.dart` | 聊天消息模型 |
| `lib/models/chat_session.dart` | 聊天会话模型 |
| `lib/services/chat_local_service.dart` | 本地聊天服务 |

---

## 八、后端AI功能接口详解

### 8.1 接口概览

后端AI相关接口分布在两个路由文件中：

| 路由文件 | 前缀 | 功能类别 |
|---------|------|---------|
| `ai.py` | `/api/v1/ai` | AI聊天、计划生成、记忆管理 |
| `chat_sessions.py` | `/api/v1/chat-sessions` | 会话CRUD操作 |

---

### 8.2 AI核心接口 (`/api/v1/ai`)

#### 1. 流式聊天接口

**Endpoint**: `POST /api/v1/ai/chat/stream`

**功能**: 与AI教练进行流式对话（SSE），支持实时返回AI回复内容

**请求参数**:
```json
{
  "session_id": "string | null",  // 会话ID，null则创建新会话
  "message": "string"              // 用户消息内容
}
```

**SSE事件类型**:

| 事件类型 | 说明 | 数据结构 |
|---------|------|---------|
| `session_created` | 新会话创建 | `{type, session_id}` |
| `chunk` | 文本流块 | `{type, content}` |
| `plan` | 生成的训练计划 | `{type, plan, plan_id}` |
| `done` | 生成完成 | `{type, session_id, has_plan}` |
| `error` | 错误信息 | `{type, message}` |

**内部流程**:
1. 获取或创建会话（新会话返回`session_created`事件）
2. 查询用户画像信息
3. 获取会话上下文（摘要+近期消息）
4. 获取用户跨会话记忆（最近3个主题）
5. 保存用户消息到数据库
6. 新会话自动生成标题
7. 调用`ChatAgent.chat_stream()`流式生成
8. 如生成训练计划，保存到数据库并返回`plan`事件
9. 生成完成保存AI回复，更新会话摘要

---

#### 2. 继续流式生成接口

**Endpoint**: `POST /api/v1/ai/chat/continue`

**功能**: 当应用从后台恢复时，继续之前的流式生成

**请求参数**:
```json
{
  "session_id": "string",      // 会话ID
  "existing_content": "string"  // 前端已接收的内容
}
```

**使用场景**:
- 用户在AI生成回复时将应用切换到后台
- 应用恢复后调用此接口获取剩余内容
- 避免重复生成，节省Token

---

#### 3. 流式生成训练计划

**Endpoint**: `POST /api/v1/ai/workouts/generate/stream`

**功能**: 流式生成个性化训练计划（SSE）

**请求参数**:
```json
{
  "preferences": {
    "scene": "string",       // 可选：场景偏好
    "time_budget": 15,       // 可选：时间预算（分钟）
    "focus": "string"        // 可选：重点训练部位
  }
}
```

**SSE事件类型**:

| 事件类型 | 说明 |
|---------|------|
| `chunk` | 生成过程中的文本流 |
| `plan` | 生成的训练计划JSON |
| `saved` | 计划已保存到数据库（返回plan_id） |
| `error` | 错误信息 |
| `done` | 生成完成 |

**内部流程**:
1. 获取用户画像
2. 应用额外偏好设置覆盖画像
3. 调用`WorkoutAgent.generate()`流式生成
4. 保存计划到数据库
5. 返回`saved`事件包含plan_id

---

#### 4. 非流式生成训练计划

**Endpoint**: `POST /api/v1/ai/workouts/generate`

**功能**: 同步生成训练计划，直接返回结果

**响应**:
```json
{
  "success": true,
  "plan": { /* 训练计划对象 */ },
  "plan_id": "string"
}
```

---

#### 5. 获取会话上下文信息

**Endpoint**: `GET /api/v1/ai/chat/sessions/{session_id}/context`

**功能**: 获取会话的上下文信息，包括摘要和Token估算

**响应**:
```json
{
  "session_id": "string",
  "title": "string",
  "summary": "string",      // 会话摘要
  "total_tokens": 1500,     // 预估Token数
  "message_count": 20
}
```

---

#### 6. 获取用户跨会话记忆

**Endpoint**: `GET /api/v1/ai/chat/user-memory`

**功能**: 获取用户近期的跨会话记忆

**查询参数**:
- `days`: 查询天数范围（默认7天）

**响应**:
```json
{
  "user_id": "string",
  "days": 7,
  "memory": {
    "recent_topics": ["减脂计划", "核心训练"],  // 近期主题
    "plans_generated": 5,                       // 生成计划数
    "sessions_count": 3                         // 会话数量
  }
}
```

---

#### 7. 重新生成会话摘要

**Endpoint**: `POST /api/v1/ai/chat/sessions/{session_id}/regenerate-summary`

**功能**: 手动触发会话摘要的重新生成

**响应**:
```json
{
  "session_id": "string",
  "summary": "新的会话摘要内容",
  "message_count": 50
}
```

---

#### 8. 获取用户所有聊天消息

**Endpoint**: `GET /api/v1/ai/chat/messages`

**功能**: 获取用户所有会话的消息（用于数据同步）

**查询参数**:
- `limit`: 每会话消息限制（默认50）

**响应**:
```json
{
  "messages": [
    {
      "id": "string",
      "session_id": "string",
      "role": "user|assistant",
      "content": "string",
      "data_type": "text|workout_plan",
      "structured_data": {},
      "tool_calls": [],
      "created_at": "2024-01-01T00:00:00"
    }
  ]
}
```

---

#### 9. 获取会话完整记忆

**Endpoint**: `GET /api/v1/ai/chat/sessions/{session_id}/memory`

**功能**: 获取会话的完整记忆信息（用于前端恢复对话）

**响应**:
```json
{
  "session": {
    "id": "string",
    "title": "string",
    "created_at": "string",
    "updated_at": "string",
    "message_count": 20
  },
  "memory": {
    "summary": "会话摘要",
    "total_tokens": 1500,
    "recent_topics": ["主题1", "主题2"]
  },
  "history": [  // 最近50条消息
    {
      "id": "string",
      "role": "user|assistant",
      "content": "string",
      "data_type": "string",
      "created_at": "string"
    }
  ]
}
```

---

#### 10. 获取会话消息列表

**Endpoint**: `GET /api/v1/ai/chat/sessions/{session_id}/messages`

**功能**: 分页获取指定会话的消息

**查询参数**:
- `limit`: 限制数量（默认100，最大200）
- `offset`: 偏移量（分页）

**响应**:
```json
{
  "session_id": "string",
  "messages": [...],
  "total": 150  // 会话总消息数
}
```

---

#### 11. 搜索会话消息

**Endpoint**: `GET /api/v1/ai/chat/sessions/{session_id}/search`

**功能**: 在历史消息中搜索关键词

**查询参数**:
- `query`: 搜索关键词

**响应**:
```json
{
  "session_id": "string",
  "query": "减脂",
  "results": [
    {
      "id": "string",
      "role": "assistant",
      "content": "完整消息内容",
      "snippet": "...减脂方案...",  // 匹配片段
      "created_at": "string"
    }
  ],
  "total": 5
}
```

**实现说明**: 当前使用简单关键词匹配，可后续升级为向量搜索

---

#### 12. 获取会话统计

**Endpoint**: `GET /api/v1/ai/chat/sessions/{session_id}/stats`

**功能**: 获取会话的详细统计数据

**响应**:
```json
{
  "session_id": "string",
  "stats": {
    "total_messages": 50,
    "user_messages": 25,
    "assistant_messages": 25,
    "interaction_turns": 25,        // 交互轮数
    "workout_plans_generated": 3,   // 生成计划数
    "total_characters": 5000,       // 总字符数
    "avg_message_length": 100       // 平均消息长度
  },
  "session": {
    "title": "string",
    "created_at": "string",
    "updated_at": "string",
    "has_summary": true
  }
}
```

---

#### 13. 获取会话关键信息

**Endpoint**: `GET /api/v1/ai/chat/sessions/{session_id}/key-info`

**功能**: 从会话中提取关键信息（用于个性化推荐）

**响应**:
```json
{
  "session_id": "string",
  "key_info": {
    "topics_discussed": ["减脂", "有氧"],
    "goals_mentioned": ["减重5公斤"],
    "workout_plans": [...],
    "questions_asked": [...]
  }
}
```

---

#### 14. 获取所有会话摘要列表

**Endpoint**: `GET /api/v1/ai/chat/sessions-summaries`

**功能**: 获取用户所有会话的摘要列表（用于会话历史展示）

**查询参数**:
- `limit`: 限制数量（默认10）

**响应**:
```json
{
  "user_id": "string",
  "sessions": [
    {
      "session_id": "string",
      "title": "string",
      "summary": "string",
      "message_count": 20,
      "created_at": "string"
    }
  ],
  "total": 5
}
```

---

#### 15. 获取记忆时间线

**Endpoint**: `GET /api/v1/ai/chat/memory/timeline`

**功能**: 按时间顺序展示用户与AI的交互历史

**查询参数**:
- `days`: 时间范围天数（默认30天）

**响应**:
```json
{
  "user_id": "string",
  "days": 30,
  "timeline": [
    {
      "session_id": "string",
      "title": "string",
      "first_message": "用户第一条消息",
      "message_count": 20,
      "workout_plans_count": 2,
      "has_summary": true,
      "created_at": "string",
      "updated_at": "string"
    }
  ],
  "total_sessions": 10
}
```

---

### 8.3 会话管理接口 (`/api/v1/chat-sessions`)

#### 1. 获取会话列表

**Endpoint**: `GET /api/v1/chat-sessions`

**查询参数**:
- `limit`: 限制数量（默认50，最大100）
- `offset`: 偏移量（分页）

**响应**: `List<ChatSessionSchema>`

---

#### 2. 获取单个会话

**Endpoint**: `GET /api/v1/chat-sessions/{session_id}`

**响应**: `ChatSessionSchema`

---

#### 3. 获取会话消息历史

**Endpoint**: `GET /api/v1/chat-sessions/{session_id}/messages`

**查询参数**:
- `limit`: 限制数量（默认100，最大200）
- `offset`: 偏移量

**响应**: `List<ChatMessageSchema>`

---

#### 4. 创建新会话

**Endpoint**: `POST /api/v1/chat-sessions`

**请求体**:
```json
{
  "title": "string"  // 可选，默认"新对话"
}
```

**响应**: `ChatSessionSchema`

---

#### 5. 重命名会话

**Endpoint**: `PATCH /api/v1/chat-sessions/{session_id}`

**请求体**:
```json
{
  "title": "新标题"
}
```

---

#### 6. 删除会话

**Endpoint**: `DELETE /api/v1/chat-sessions/{session_id}`

**响应**: `204 No Content`

---

#### 7. 自动生成会话标题

**Endpoint**: `POST /api/v1/chat-sessions/{session_id}/generate-title`

**功能**: 基于用户首条消息自动生成会话标题

**请求体**:
```json
{
  "first_message": "我想减脂，有什么建议吗"
}
```

**说明**:
- 如果会话已有非默认标题，不会覆盖
- 使用`ContextService.generate_session_title()`智能生成

---

### 8.4 AIService 核心方法

`AIService` 是AI功能的编排层，封装了Agent调用和业务逻辑：

#### 1. stream_chat
```python
async def stream_chat(
    self,
    user_id: str,
    session_id: str | None,
    message: str
) -> AsyncGenerator[dict, None]
```
- 流式聊天主方法
- 协调上下文获取、记忆加载、消息保存
- 返回SSE事件流

#### 2. continue_stream_chat
```python
async def continue_stream_chat(
    self,
    user_id: str,
    session_id: str,
    existing_content: str
) -> AsyncGenerator[dict, None]
```
- 继续之前的流式生成
- 用于应用从后台恢复场景

#### 3. generate_workout_plan
```python
async def generate_workout_plan(
    self,
    user_id: str,
    preferences: dict | None = None
) -> dict
```
- 同步生成训练计划
- 应用用户偏好覆盖画像设置
- 保存到数据库

#### 4. stream_generate_workout_plan
```python
async def stream_generate_workout_plan(
    self,
    user_id: str,
    preferences: dict | None = None
) -> AsyncGenerator[dict, None]
```
- 流式生成训练计划
- 返回生成过程和最终结果

#### 5. get_today_plan
```python
async def get_today_plan(
    self,
    user_id: str,
    plan_date: date | None = None
) -> dict | None
```
- 获取今日训练计划
- 支持指定日期
- 无今日计划时返回最近计划

---

### 8.5 接口权限控制

所有AI接口都使用JWT认证，通过`get_current_user`依赖获取当前用户：

```python
async def chat_stream(
    request: ChatStreamRequest,
    current_user: User = Depends(get_current_user),  // 认证
    db: AsyncSession = Depends(get_db),
):
```

**权限验证逻辑**:
1. 会话级操作（如获取消息、删除会话）验证会话归属
2. 用户只能访问自己的会话和数据
3. 验证失败返回 `404 Not Found`（防止会话ID遍历）

---

### 8.6 数据流图

```
┌─────────────┐     POST /chat/stream      ┌─────────────┐
│   用户请求   │ ─────────────────────────> │  AI Service │
└─────────────┘                            └──────┬──────┘
                                                  │
                       ┌──────────────────────────┼──────────────────────────┐
                       │                          │                          │
                       ▼                          ▼                          ▼
              ┌─────────────┐           ┌─────────────┐            ┌─────────────┐
              │ ChatService │           │UserService  │            │ContextService│
              └──────┬──────┘           └─────────────┘            └──────┬──────┘
                     │                                                    │
                     ▼                                                    ▼
              ┌─────────────┐                                    ┌─────────────┐
              │ChatSession  │                                    │  记忆管理    │
              │ChatMessage  │                                    │  摘要生成    │
              └─────────────┘                                    └─────────────┘
                       │
                       ▼
              ┌─────────────┐
              │  ChatAgent  │
              │ (LangGraph) │
              └──────┬──────┘
                     │
                     ▼
              ┌─────────────┐
              │ OpenAI API  │
              └─────────────┘
```

---

## 九、两个Agent的协同调用关系与问题分析

### 9.1 当前架构问题

#### 问题1：两个Agent独立运行，没有协同

```
┌─────────────────────────────────────────────────────────────┐
│                         当前架构                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   用户消息 ──► ┌─────────────┐                              │
│                │  ChatAgent  │ ──► 通用对话回复               │
│                └─────────────┘                              │
│                      │                                      │
│                      │ (提示词中包含生成计划指导，            │
│                      │  但实际调用的是同一个Agent)           │
│                      ▼                                      │
│                可以输出计划JSON                               │
│                                                             │
│   用户点击"生成计划" ──► ┌─────────────┐                    │
│                        │ WorkoutAgent │ ──► 专用计划生成      │
│                        └─────────────┘    (4节点工作流+验证)  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**核心问题**：
1. **没有真正的Agent协同** - ChatAgent和WorkoutAgent是独立的，ChatAgent不会调用WorkoutAgent
2. **功能重叠** - 两个Agent都能生成计划，但实现方式不同
3. **提示词重复** - 两个Agent的提示词有大量重复内容

---

### 9.2 提示词重复分析

查看 `backend/app/agents/prompts.py`：

```python
# build_system_prompt (ChatAgent使用)
def build_system_prompt(...):
    buffer.append("你是微动MicoFit的专属AI健身教练。")
    # ... 用户画像信息 ...
    buffer.append(_get_workout_generation_prompt())  # <-- 第94行
    buffer.append(_get_intent_recognition_prompt())

# build_workout_system_prompt (WorkoutAgent使用)
def build_workout_system_prompt(...):
    buffer.append("你是微动MicoFit的专属AI健身教练...")
    # ... 用户画像信息 ...
    buffer.append(_get_workout_generation_prompt())  # <-- 第126行
```

**重复内容**：

| 重复项 | 位置 | 说明 |
|--------|------|------|
| 角色定义 | 两个函数开头 | "你是微动MicoFit的专属AI健身教练" |
| 用户画像信息 | 两个函数 | 相同的字段和格式 |
| `_get_workout_generation_prompt()` | 第94行和第126行 | **完全相同的计划生成指导** |
| 健身水平/目标/场景映射 | 底部辅助函数 | 共用相同的映射函数 |

**重复提示词内容**（`_get_workout_generation_prompt`）:
- JSON格式规范
- 约束条件（时长、RPE、身体限制）
- 输出示例

这导致：**ChatAgent的提示词包含了完整的计划生成指导，但ChatAgent并没有调用WorkoutAgent！**

---

### 9.3 理想的协同架构

#### 方案一：ChatAgent作为主入口，调用WorkoutAgent（推荐）

```
┌─────────────────────────────────────────────────────────────┐
│                     理想架构（方案一）                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   用户消息 ──► ┌─────────────┐                              │
│                │  ChatAgent  │                              │
│                │  (主Agent)  │                              │
│                └──────┬──────┘                              │
│                       │                                     │
│           ┌───────────┼───────────┐                        │
│           │           │           │                        │
│           ▼           ▼           ▼                        │
│    ┌──────────┐ ┌──────────┐ ┌──────────┐                 │
│    │ 意图识别  │ │ 一般对话  │ │ 生成计划  │                 │
│    └──────────┘ └──────────┘ └────┬─────┘                 │
│                                   │                        │
│                                   ▼                        │
│                         ┌─────────────┐                    │
│                         │ WorkoutAgent │                   │
│                         │ (子Agent调用)│                   │
│                         └─────────────┘                    │
│                                   │                        │
│                                   ▼                        │
│                              返回计划JSON                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**实现方式**：
- ChatAgent通过**工具调用(Tool Calling)**或**直接API调用**触发WorkoutAgent
- WorkoutAgent作为专门的计划生成服务
- 只保留一个对外接口 `/chat/stream`

#### 方案二：统一Agent，内部路由

```
┌─────────────────────────────────────────────────────────────┐
│                     理想架构（方案二）                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   统一接口 /chat/stream                                     │
│           │                                                 │
│           ▼                                                 │
│   ┌─────────────┐                                           │
│   │  意图识别   │ ──► 判断是否需要生成计划                     │
│   └──────┬──────┘                                           │
│          │                                                  │
│     ┌────┴────┐                                             │
│     │         │                                             │
│     ▼         ▼                                             │
│ ┌────────┐ ┌─────────────────────────┐                     │
│ │通用回复 │ │ 计划生成子流程（LangGraph）│                    │
│ └────────┘ │ - build_prompt          │                     │
│            │ - generate              │                     │
│            │ - parse                 │                     │
│            │ - validate              │                     │
│            └─────────────────────────┘                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### 9.4 当前代码中的问题细节

#### 问题1：ChatAgent能生成计划，但没有验证

**ChatAgent** (`chat_agent.py` 第111-132行):
```python
def _extract_workout_plan(self, response: str) -> dict | None:
    """从响应中提取训练计划"""
    # 只是简单的正则提取JSON
    # 没有验证字段完整性
    if "modules" in data and "total_duration" in data:
        return data
```

**WorkoutAgent** (`workout_agent.py` 第122-174行):
```python
def _validate_node(self, state: WorkoutAgentState) -> dict:
    """验证节点"""
    # 验证必要字段
    required_fields = ["id", "title", "modules", "total_duration", "scene", "rpe"]
    # 验证时长范围
    # 验证RPE范围
    # 验证模块非空
```

**结果**：ChatAgent生成的计划可能不符合规范，但会被直接返回给前端。

#### 问题2：提示词冗余导致Token浪费

**build_system_prompt** 包含了：
- 基础角色定义
- 上下文摘要
- 近期记忆
- 工具使用说明
- 用户画像信息
- **_get_workout_generation_prompt()** （约2000字符）
- **_get_intent_recognition_prompt()**

**build_workout_system_prompt** 包含了：
- 角色定义（与上面类似）
- 用户画像信息（重复）
- **_get_workout_generation_prompt()** （完全相同的2000字符）

**浪费**：如果两个Agent同时被调用，重复的提示词会消耗大量Token。

---

### 9.5 优化建议

#### 短期优化（最小改动）

1. **移除ChatAgent中的计划生成提示**
   ```python
   # build_system_prompt 中删除这行
   # buffer.append(_get_workout_generation_prompt())
   ```
   让ChatAgent专注于对话，计划生成走WorkoutAgent接口。

2. **ChatAgent调用WorkoutAgent**
   ```python
   # 在ChatAgent中添加工具调用
   async def _call_workout_agent(self, user_profile: dict) -> dict:
       workout_agent = WorkoutAgent()
       result = await workout_agent.generate_sync(
           user_id=self.user_id,
           user_profile=user_profile
       )
       return result
   ```

3. **统一提示词基础部分**
   ```python
   def _get_base_prompt(user_profile: dict) -> str:
       """共用基础提示词"""
       # 角色定义 + 用户画像

   def build_system_prompt(...):
       buffer.append(_get_base_prompt(user_profile))
       buffer.append(_get_chat_guidance())  # 对话指导

   def build_workout_system_prompt(...):
       buffer.append(_get_base_prompt(user_profile))
       buffer.append(_get_workout_generation_prompt())  # 计划生成指导
   ```

#### 长期优化（架构重构）

1. **单一入口架构**
   - 只保留 `/chat/stream` 接口
   - 后端内部路由到不同Agent

2. **工具调用模式**
   ```python
   # ChatAgent配置工具
   tools = [generate_workout_plan_tool]
   self.llm = ChatOpenAI(...).bind_tools(tools)
   ```

3. **共享提示词组件**
   ```
   prompts/
   ├── base.py          # 角色定义、用户画像格式
   ├── workout.py       # 计划生成指导
   ├── chat.py          # 对话指导
   └── intent.py        # 意图识别
   ```

---

### 9.6 结论

| 问题 | 严重程度 | 建议解决方案 |
|------|---------|-------------|
| 两个Agent完全独立，没有协同 | 🔴 高 | ChatAgent通过工具调用WorkoutAgent |
| 提示词大量重复 | 🟡 中 | 提取共用基础提示词组件 |
| ChatAgent能生成计划但无验证 | 🔴 高 | 移除ChatAgent的计划生成能力，统一走WorkoutAgent |
| 两个接口暴露给前端 | 🟡 中 | 统一为单一接口，后端内部路由 |

**最佳实践建议**：

采用**方案一（主从Agent模式）**：
1. ChatAgent作为唯一对外接口
2. 用户需要生成计划时，ChatAgent调用WorkoutAgent
3. WorkoutAgent返回结构化计划给ChatAgent
4. ChatAgent包装后返回给前端

这样既保证了计划质量（有验证），又提供了统一的对话体验。

