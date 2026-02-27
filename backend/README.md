# 微动 MicoFit 后端架构设计文档

## 1. 整体架构模式

该项目采用**分层架构（Layered Architecture）**，结合**领域驱动设计（DDD）**的思想，整体架构清晰分为以下几层：

```
┌─────────────────────────────────────────────────────────────┐
│                      API 层 (Presentation)                   │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌────────┐ │
│  │  auth   │ │  users  │ │ workouts│ │   ai    │ │  sync  │ │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    服务层 (Service/Business)                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│  │AuthService  │ │UserService  │ │ WorkoutService          │ │
│  ├─────────────┤ ├─────────────┤ ├─────────────────────────┤ │
│  │AIService    │ │ChatService  │ │ ContextService          │ │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Agent 层 (AI 编排)                        │
│  ┌─────────────────┐ ┌─────────────────┐ ┌────────────────┐ │
│  │  WorkoutAgent   │ │   ChatAgent     │ │ContextSummarizer│ │
│  │  (训练计划生成)  │ │  (聊天对话)      │ │  (会话摘要)     │ │
│  └─────────────────┘ └─────────────────┘ └────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    数据层 (Data Access)                      │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌────────────────────┐ │
│  │  User   │ │UserProfile│ │WorkoutPlan│ │ ChatSession     │ │
│  ├─────────┤ ├─────────┤ ├─────────┤ ├────────────────────┤ │
│  │WorkoutRecord│ │WorkoutProgress│ │ChatMessage│          │ │
│  └─────────┘ └─────────┘ └─────────┘ └────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    基础设施层 (Infrastructure)                │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│  │  MySQL      │ │  SQLAlchemy │ │    LangGraph/OpenAI     │ │
│  │ (aiomysql)  │ │ (async ORM) │ │      (AI LLM)           │ │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 目录结构

```
backend/
├── main.py                      # FastAPI 应用入口
├── requirements.txt             # Python 依赖
├── alembic/                     # 数据库迁移
│   ├── env.py                   # Alembic 环境配置
│   └── versions/                # 迁移脚本
└── app/
    ├── __init__.py
    ├── api/                     # API 层（路由）
    │   ├── __init__.py
    │   └── v1/                  # API 版本 1
    │       ├── __init__.py
    │       ├── auth.py          # 认证路由
    │       ├── users.py         # 用户管理路由
    │       ├── profiles.py      # 用户画像路由
    │       ├── workouts.py      # 训练计划路由
    │       ├── feedback.py      # 训练反馈路由
    │       ├── ai.py            # AI 聊天/计划生成路由
    │       ├── sync.py          # 数据同步路由
    │       └── chat_sessions.py # 聊天会话路由
    ├── core/                    # 核心配置
    │   ├── __init__.py
    │   ├── config.py            # 应用配置（Settings）
    │   ├── security.py          # JWT/密码哈希
    │   ├── deps.py              # 依赖注入（获取当前用户）
    │   └── exception_handler.py # 全局异常处理
    ├── db/                      # 数据库相关
    │   ├── __init__.py
    │   ├── base.py              # SQLAlchemy Base
    │   └── session.py           # 异步会话管理
    ├── models/                  # ORM 模型（数据层）
    │   ├── __init__.py
    │   ├── user.py              # 用户模型
    │   ├── user_profile.py      # 用户画像模型
    │   ├── workout_plan.py      # 训练计划/记录模型
    │   ├── workout_progress.py  # 训练进度模型
    │   └── chat_session.py      # 聊天会话/消息模型
    ├── schemas/                 # Pydantic Schemas（DTO）
    │   ├── __init__.py
    │   ├── auth.py              # 认证相关 Schema
    │   ├── user.py              # 用户 Schema
    │   ├── profile.py           # 用户画像 Schema
    │   ├── workout.py           # 训练计划 Schema
    │   └── chat.py              # 聊天 Schema
    ├── services/                # 业务逻辑层
    │   ├── __init__.py
    │   ├── auth_service.py      # 认证服务
    │   ├── user_service.py      # 用户服务
    │   ├── workout_service.py   # 训练计划服务
    │   ├── ai_service.py        # AI 服务（编排层）
    │   ├── chat_service.py      # 聊天服务
    │   └── context_service.py   # 上下文/记忆服务
    └── agents/                  # AI Agent 层
        ├── __init__.py
        ├── state.py             # Agent 状态定义
        ├── prompts.py           # Prompt 模板
        ├── router_agent.py      # 主代理（意图识别 + 路由）
        ├── base_sub_agent.py    # SubAgent 基类
        ├── chat_sub_agent.py    # 聊天对话 SubAgent
        └── workout_sub_agent.py # 训练计划生成 SubAgent
```

---

## 3. 核心模块详解

### 3.1 API 层 (`app/api/v1/`)

**路由设计**：
- 采用 RESTful API 设计风格
- 使用 FastAPI 的 `APIRouter` 进行模块化路由组织
- 统一前缀 `/api/v1`

**路由列表**：

| 路由文件 | 前缀 | 功能 |
|---------|------|------|
| auth.py | `/auth` | 注册、登录、刷新Token、登出 |
| users.py | `/users` | 用户信息管理 |
| profiles.py | `/profiles` | 用户画像 CRUD |
| workouts.py | `/workouts` | 训练计划、进度管理 |
| feedback.py | `/feedback` | 训练反馈 |
| ai.py | `/ai` | AI 聊天、计划生成（SSE流式） |
| sync.py | `/sync` | 离线数据同步 |
| chat_sessions.py | `/chat-sessions` | 会话管理 |

**依赖注入示例**：
```python
@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    data: RegisterRequest,
    db: AsyncSession = Depends(get_db),  # 数据库会话注入
):
    service = AuthService(db)  # 服务实例化
    # ...
```

**认证机制**：
- 使用 JWT（JSON Web Token）进行身份认证
- 双 Token 策略：Access Token（30分钟）+ Refresh Token（7天）
- HTTP Bearer 认证方式

---

### 3.2 服务层 (`app/services/`)

**业务逻辑组织方式**：

1. **服务类模式**：每个服务对应一个业务领域
   - `AuthService`：认证相关业务
   - `UserService`：用户画像管理
   - `WorkoutService`：训练计划/记录管理
   - `ChatService`：聊天会话管理
   - `AIService`：AI 能力编排（协调多个 Agent）

2. **依赖注入**：服务通过构造函数接收 `AsyncSession`
   ```python
   class WorkoutService:
       def __init__(self, db: AsyncSession):
           self.db = db
   ```

3. **AIService 作为编排层**：
   - 协调 `WorkoutAgent`、`ChatAgent`
   - 整合 `ContextService` 提供记忆能力
   - 处理流式响应（SSE）

---

### 3.3 数据层 (`app/models/`)

**数据库模型设计**：

| 模型 | 文件 | 职责 |
|------|------|------|
| User | `user.py` | 用户基础信息、认证 |
| UserProfile | `user_profile.py` | 健身画像（身高、体重、目标等） |
| WorkoutPlan | `workout_plan.py` | AI生成的训练计划 |
| WorkoutRecord | `workout_plan.py` | 用户训练反馈记录 |
| WorkoutProgress | `workout_progress.py` | 实时训练进度 |
| ChatSession | `chat_session.py` | AI 聊天会话 |
| ChatMessage | `chat_session.py` | 聊天消息 |

**关系定义**：
```python
class User(Base):
    # 关联用户画像（一对一）
    profile = relationship("UserProfile", back_populates="user", uselist=False)

    # 关联训练计划（一对多）
    workout_plans = relationship("WorkoutPlan", back_populates="user")

    # 关联训练记录（一对多）
    workout_records = relationship("WorkoutRecord", back_populates="user")

    # 关联聊天会话（一对多）
    chat_sessions = relationship("ChatSession", back_populates="user")
```

**技术特点**：
- 使用 SQLAlchemy 2.0 的 `DeclarativeBase`
- MySQL + aiomysql 异步驱动
- UUID 主键（CHAR(36)）
- 级联删除配置（`cascade="all, delete-orphan"`）

---

### 3.4 Agent 层 (`app/agents/`)

**AI Agent 架构**：

1. **状态定义**（`state.py`）：
   ```python
   class RouterState(TypedDict):
       messages: list
       user_id: str
       intent: str | None
       route_to: str | None
       # ...

   class WorkoutSubAgentState(TypedDict):
       messages: list
       user_id: str
       user_profile: dict | None
       workout_plan: dict | None
       # ...
   ```

2. **RouterAgent**（`router_agent.py`）：
   - 主代理，负责意图识别和路由分发
   - 使用 **LangGraph** 构建工作流
   - 工作流节点：`intent_recognition` → `route` → `chat_sub_agent | workout_sub_agent` → `finalize`
   - 意图识别支持自动判断用户意图（聊天 or 生成训练计划）

3. **SubAgent 架构**：
   - **ChatSubAgent**（`chat_sub_agent.py`）：处理普通对话、健身咨询
   - **WorkoutSubAgent**（`workout_sub_agent.py`）：生成个性化训练计划
   - 都继承自 `BaseSubAgent` 基类
   - 支持流式生成（`stream`）和同步处理（`process`）

4. **Prompt 模板**（`prompts.py`）：
   - 意图识别提示词构建
   - 系统提示词构建（对话用）
   - 训练计划提示词构建
   - 用户画像信息注入

---

### 3.5 核心配置 (`app/core/`)

**配置管理**（`config.py`）：
```python
class Settings(BaseSettings):
    APP_NAME: str = "微动 MicoFit API"
    DATABASE_URL: str  # 从环境变量读取
    SECRET_KEY: str    # JWT 密钥
    OPENAI_API_KEY: str
    # ...

    class Config:
        env_file = "backend/.env"
```

**安全模块**（`security.py`）：
- 密码哈希：bcrypt（`passlib`）
- JWT：创建/解码 Token（`python-jose`）
- Token 类型：access / refresh

**依赖注入**（`deps.py`）：
```python
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    # 验证 JWT，查询用户，返回 User 对象
```

---

## 4. 依赖关系

### 模块调用关系图

```
main.py
├── FastAPI App
│   ├── CORS Middleware
│   ├── Exception Handlers
│   └── Routers (api/v1/*)
│
├── app.core.config (settings)
├── app.core.exception_handler
└── app.db.session (get_db)

API Layer (api/v1/*)
├── Depends(get_db) ────────┐
├── Depends(get_current_user)│
└── Service Layer ◄──────────┘

Service Layer
├── app.models.* (ORM)
├── app.schemas.* (DTO)
├── app.agents.* (AI)
└── app.services.* (互相调用)

Agent Layer
├── langchain_openai
├── langgraph
└── app.agents.prompts
```

---

## 5. 关键技术选型

| 技术 | 版本 | 用途 |
|------|------|------|
| **FastAPI** | 0.115.0 | Web 框架，异步 API |
| **SQLAlchemy** | 2.0.35 | ORM，异步数据库操作 |
| **aiomysql** | 0.2.0 | MySQL 异步驱动 |
| **Pydantic** | 2.10.1 | 数据验证、Settings |
| **python-jose** | 3.3.0 | JWT 处理 |
| **passlib** | 1.7.4 | 密码哈希（bcrypt） |
| **LangChain** | latest | LLM 应用框架 |
| **LangGraph** | latest | Agent 工作流编排 |
| **Alembic** | 1.14.0 | 数据库迁移 |
| **sse-starlette** | latest | SSE 流式响应 |

### FastAPI 特性使用

1. **异步支持**：全链路 async/await
2. **依赖注入系统**：`Depends()` 用于 DB 会话、用户认证
3. **自动文档**：OpenAPI/Swagger UI
4. **类型提示**：完整的类型注解
5. **SSE 流式**：`EventSourceResponse` 用于 AI 流式输出

---

## 6. 扩展性设计

### 6.1 中间件

**CORS 中间件**：
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**异常处理中间件**（`exception_handler.py`）：
- `ExceptionHandlerMiddleware`：捕获所有未处理异常
- 自定义异常类：`APIException`、`AuthenticationError`、`ResourceNotFoundError` 等
- 统一错误响应格式

### 6.2 数据库迁移（Alembic）

- 支持自动生成迁移脚本
- 异步迁移执行
- 版本管理

### 6.3 插件机制

**Agent 扩展**：
- 通过 LangGraph 可轻松添加新的 Agent 节点
- Prompt 模板化，支持动态配置

**服务扩展**：
- 服务类通过构造函数接收依赖，易于 Mock 和替换

---

## 7. 核心流程

### 7.1 启动流程（`main.py`）

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    # 1. 创建数据库（如果不存在）
    await create_database_if_not_exists()
    # 2. 创建所有表
    await create_tables()
    yield
    # 3. 关闭时清理
```

### 7.2 依赖注入系统

**数据库会话**（`db/session.py`）：
```python
async def get_db() -> AsyncSession:
    async with async_session_maker() as session:
        try:
            yield session
        finally:
            await session.close()
```

**当前用户获取**（`core/deps.py`）：
```python
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    # 1. 解码 JWT
    # 2. 查询数据库验证用户
    # 3. 返回 User 对象
```

### 7.3 认证/授权机制

1. **注册**：密码 bcrypt 哈希 → 创建用户 → 返回双 Token
2. **登录**：验证密码 → 更新登录时间 → 返回双 Token
3. **刷新**：验证 Refresh Token → 返回新 Token 对
4. **访问保护**：`get_current_user` 依赖验证 Access Token

### 7.4 错误处理机制

**异常层次**：
```
APIException (基类)
├── AuthenticationError (401)
├── PermissionDeniedError (403)
├── ResourceNotFoundError (404)
├── RateLimitError (429)
└── AIServiceError (503)
```

**处理流程**：
1. 业务代码抛出自定义异常
2. `exception_handler` 捕获并转换为 JSONResponse
3. 统一响应格式：`{"success": False, "error": {...}}`

### 7.5 配置管理方案

- **Pydantic Settings**：类型安全的配置
- **环境变量**：`.env` 文件
- **分层配置**：开发/测试/生产环境

---

## 8. 架构亮点

1. **清晰的分层架构**：API → Service → Agent → Model，职责明确
2. **完整的异步支持**：从 HTTP 到数据库全链路异步
3. **AI 原生设计**：LangGraph Agent 工作流、流式 SSE 响应
4. **记忆系统**：ContextService 实现会话摘要和跨会话记忆
5. **离线同步**：专门的 Sync API 支持移动端离线使用
6. **类型安全**：完整的类型注解和 Pydantic 验证
7. **扩展性强**：依赖注入、中间件、Alembic 迁移

---

## 9. 快速开始

### 环境要求

- Python 3.12+
- MySQL 8.0+
- OpenAI API Key

### 安装依赖

```bash
cd backend
conda activate python3.12
pip install -r requirements.txt
```

### 配置环境变量

创建 `.env` 文件：
```env
DATABASE_URL=mysql+aiomysql://user:password@localhost:3306/micofit
SECRET_KEY=your-secret-key
OPENAI_API_KEY=your-openai-api-key
```

### 启动服务

```bash
uvicorn main:app --reload
```

服务将在 `http://localhost:8000` 启动，API 文档访问 `http://localhost:8000/docs`。
