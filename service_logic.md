# 微动 MicoFit - 业务逻辑文档

## 1. 项目架构

### 1.1 技术栈
- **前端框架**: Flutter (Dart SDK ^3.10.7)
- **状态管理**: Provider
- **本地存储**: SharedPreferences
- **网络请求**: HTTP
- **架构模式**: 分层架构 (Model-Service-Provider-Page)

### 1.2 目录结构
```
lib/
├── main.dart                    # 应用入口
├── config/                      # 配置
│   └── app_config.dart          # 应用配置
├── models/                      # 数据模型
│   ├── auth_user.dart           # 认证用户
│   ├── auth_response.dart       # 认证响应
│   ├── user_profile.dart        # 用户画像
│   ├── exercise.dart            # 训练动作
│   ├── workout.dart             # 训练计划
│   ├── feedback.dart            # 训练反馈
│   └── weekly_data.dart         # 周/月数据
├── services/                    # API 服务层
│   ├── api_service.dart         # API 基类
│   ├── auth_service.dart        # 认证会话管理
│   ├── auth_api_service.dart    # 认证 API
│   ├── user_api_service.dart    # 用户画像 API
│   ├── workout_api_service.dart # 训练计划 API
│   ├── record_api_service.dart  # 训练记录 API
│   ├── options_api_service.dart # 选项配置 API
│   ├── api_exception.dart       # 异常定义
│   └── api_logger.dart          # 日志记录
├── providers/                   # 状态管理层
│   ├── auth_provider.dart       # 认证状态
│   ├── user_profile_provider.dart  # 用户画像状态
│   ├── workout_provider.dart    # 训练计划状态
│   └── monthly_stats_provider.dart  # 月度统计状态
└── pages/                       # 页面层
    ├── login_page.dart          # 登录页
    ├── register_page.dart       # 注册页
    ├── onboarding_page.dart     # 用户画像构建页
    ├── today_plan_page.dart     # 今日计划页
    ├── exercise_detail_page.dart # 动作详情页
    ├── feedback_page.dart       # 反馈页
    ├── weekly_view_page.dart    # 周历视图页
    └── profile_page.dart        # 个人资料页
```

---

## 2. 核心业务模块

### 2.1 认证模块

#### 2.1.1 认证流程

```
┌─────────────┐      ┌─────────────────┐      ┌─────────────┐
│  LoginPage  │─────>│  AuthProvider   │─────>│AuthApiService│
└─────────────┘      └─────────────────┘      └─────────────┘
                            │                        │
                            v                        v
                     ┌─────────────┐        ┌─────────────┐
                     │ AuthService │        │   Backend   │
                     │ (会话管理)   │        │  /api/v1/   │
                     └─────────────┘        └─────────────┘
```

#### 2.1.2 API 端点

| 功能 | 方法 | 端点 | 请求体 | 响应 |
|------|------|------|--------|------|
| 登录 | POST | `/api/v1/auth/login` | `{userId, password}` | `AuthResponse` |
| 注册 | POST | `/api/v1/auth/register` | `{userId, password}` | `AuthResponse` |
| 刷新 Token | POST | `/api/v1/auth/refresh` | `{token}` | `AuthResponse` |
| 登出 | POST | `/api/v1/auth/logout` | `{token}` | - |

#### 2.1.3 会话管理

**AuthService** (单例) 负责会话的持久化：

- **存储位置**: SharedPreferences (key: `micofit_auth`)
- **存储内容**: `AuthResponse` (token, userId, nickname, expiresIn)
- **状态**: `AuthStatus` (unknown, authenticated, unauthenticated)

```dart
// 初始化
await AuthService().init(prefs);

// 保存会话
await AuthService().saveSession(authResponse, prefs);

// 清除会话
await AuthService().clearSession(prefs);
```

---

### 2.2 用户画像模块

#### 2.2.1 用户画像数据结构

```dart
UserProfile {
  nickname: String          // 用户 ID（昵称）
  height: double            // 身高 (cm)
  weight: double            // 体重 (kg)
  bmi: double               // BMI
  fitnessLevel: enum        // 健身水平 (beginner/occasional/regular)
  scene: String             // 训练场景
  timeBudget: int           // 时间预算 (分钟)
  limitations: List<String> // 身体限制
  equipment: String         // 可用器械
  goal: String              // 健身目标
  weeklyDays: int           // 每周训练天数
  preferredTime: List<String> // 偏好时段
}
```

#### 2.2.2 用户画像流程

```
┌─────────────────┐      ┌─────────────────────┐
│  OnboardingPage │─────>│ UserProfileProvider │
└─────────────────┘      └─────────────────────┘
                               │         │
                    本地持久化           API 同步
                               │         │
                               v         v
                        ┌──────────────────┐
                        │ SharedPreferences │
                        │      +            │
                        │   UserApiService  │
                        └──────────────────┘
```

#### 2.2.3 API 端点

| 功能 | 方法 | 端点 | 请求体 | 响应 |
|------|------|------|--------|------|
| 获取用户画像 | GET | `/api/v1/users/profile?userId=xxx` | - | `UserProfile` |
| 创建用户画像 | POST | `/api/v1/users/profile` | `UserProfile` | `UserProfile` |
| 更新用户画像 | PUT | `/api/v1/users/profile` | `UserProfile` | `UserProfile` |

#### 2.2.4 本地存储策略

- **存储位置**: SharedPreferences (key: `micofit_user_profile`)
- **加载优先级**: 本地缓存 → 服务器同步
- **更新策略**: 先更新服务器，成功后更新本地缓存

---

### 2.3 训练计划模块

#### 2.3.1 训练计划数据结构

```dart
WorkoutPlan {
  id: String              // 计划 ID
  title: String           // 标题
  subtitle: String        // 副标题
  totalDuration: int      // 总时长 (分钟)
  scene: String           // 场景
  rpe: int                // 运动强度 (1-10)
  aiNote: String?         // AI 备注
  modules: List<WorkoutModule>  // 训练模块
}

WorkoutModule {
  id: String              // 模块 ID
  name: String            // 模块名称
  duration: int           // 时长 (分钟)
  exercises: List<Exercise>  // 动作列表
}

Exercise {
  id: String              // 动作 ID
  name: String            // 动作名称
  duration: int           // 时长 (秒)
  description: String     // 描述
  steps: List<String>     // 步骤
  tips: String            // 提示
  breathing: String       // 呼吸指导
  image: String           // 图片 URL
  targetMuscles: List<String>  // 目标肌肉群
}
```

#### 2.3.2 训练计划流程

```
┌──────────────────┐      ┌──────────────────┐
│  TodayPlanPage   │─────>│ WorkoutProvider  │
└──────────────────┘      └──────────────────┘
                                │
                                v
                         ┌──────────────┐
                         │   API 或     │
                         │  本地 Sample  │
                         └──────────────┘
```

#### 2.3.3 API 端点

| 功能 | 方法 | 端点 | 参数 | 响应 |
|------|------|------|------|------|
| 获取今日计划 | GET | `/api/v1/workouts/today` | `userId, date?` | `WorkoutPlan` |
| 刷新训练计划 | GET | `/api/v1/workouts/refresh` | `userId` | `WorkoutPlan` |

#### 2.3.4 训练执行流程

```
┌──────────────┐    ┌──────────────────┐    ┌──────────────┐
│ 今日计划页面  │───>│ 动作详情页面     │───>│ 反馈页面     │
│ TodayPlan    │    │ ExerciseDetail   │    │ Feedback     │
└──────────────┘    └──────────────────┘    └──────────────┘
                           │                       │
                    带计时器的动作指导          提交反馈
```

---

### 2.4 反馈模块

#### 2.4.1 反馈数据结构

```dart
WorkoutFeedback {
  completion: CompletionLevel   // 完成程度
    - tooHard    // 太难未完成
    - barely     // 勉强完成
    - smooth     // 顺利完成
    - easy       // 轻松有余力

  feeling: FeelingLevel         // 身体感受
    - uncomfortable  // 某部位不适
    - tired          // 有点累
    - justRight      // 刚刚好
    - energized      // 精力充沛

  tomorrow: TomorrowPreference  // 明日偏好
    - recovery   // 需要恢复
    - maintain   // 保持即可
    - intensify  // 可以提高
}
```

#### 2.4.2 反馈流程

```
┌──────────────┐      ┌──────────────────┐
│ FeedbackPage │─────>│ RecordApiService │
└──────────────┘      └──────────────────┘
                            │
                            v
                     ┌──────────────┐
                     │ 提交反馈     │
                     │ AI 调整次日  │
                     └──────────────┘
```

#### 2.4.3 API 端点

| 功能 | 方法 | 端点 | 请求体 | 响应 |
|------|------|------|--------|------|
| 提交反馈 | POST | `/api/v1/feedback` | `{userId, workoutDate, workoutDuration, completion, feeling, tomorrow}` | `{success, aiAdjustment}` |

#### 2.4.4 反馈作用

AI 根据用户反馈调整次日训练计划：
- **太难未完成** → 降低难度、减少时长
- **轻松有余力** → 提高难度、增加时长
- **某部位不适** → 避开相关肌群
- **精力充沛** → 可增加强度

---

### 2.5 统计模块

#### 2.5.1 数据结构

```dart
MonthlyStats {
  year: int                    // 年份
  month: int                   // 月份
  totalMinutes: int            // 总训练分钟数
  targetMinutes: int           // 目标分钟数
  completedDays: int           // 完成天数
  records: List<DayRecord>     // 每日记录
}

DayRecord {
  date: String                 // 日期 (YYYY-MM-DD)
  dayOfWeek: int               // 周几 (0-6, 0=周日)
  duration: int                // 时长 (分钟)
  status: DayStatus            // 状态
    - completed   // 已完成
    - partial     // 部分完成
    - planned     // 已计划
    - none        // 未安排
}
```

#### 2.5.2 API 端点

| 功能 | 方法 | 端点 | 参数 | 响应 |
|------|------|------|------|------|
| 获取月度记录 | GET | `/api/v1/records/monthly` | `userId, year, month` | `MonthlyStats` |

#### 2.5.3 统计指标

- **进度百分比**: `totalMinutes / targetMinutes * 100`
- **剩余分钟数**: `targetMinutes - totalMinutes`
- **日均分钟数**: `totalMinutes / completedDays`

---

### 2.6 选项配置模块

#### 2.6.1 API 端点

| 功能 | 方法 | 端点 | 响应 |
|------|------|------|------|
| 获取选项配置 | GET | `/api/v1/options` | `Map<String, dynamic>` |

用于获取系统的各种选项配置（如场景列表、器械类型、身体部位等）

---

## 3. API 服务架构

### 3.1 ApiService 基类

**[api_service.dart](lib/services/api_service.dart)** 是所有 API 服务的基类，提供：

- **统一请求头**: 自动添加 Authorization Bearer Token
- **HTTP 方法封装**: GET、POST、PUT
- **异常处理**: 统一的错误处理和转换
- **日志记录**: 请求/响应日志
- **超时控制**: 可配置的超时时间

#### 3.1.1 请求流程

```
┌──────────────┐
│ ApiService   │
│  .get()      │
│  .post()     │
│  .put()      │
└──────┬───────┘
       │
       ├─> 1. 添加认证 Token 到 Headers
       │
       ├─> 2. 记录请求日志 (ApiLogger)
       │
       ├─> 3. 发送 HTTP 请求
       │
       ├─> 4. 处理响应
       │    ├─ 2xx: 成功，解析数据
       │    ├─ 401: 未授权 (UnauthorizedException)
       │    ├─ 5xx: 服务器错误 (ServerException)
       │    └─ 其他: 业务异常 (ApiException)
       │
       └─> 5. 记录响应日志
```

### 3.2 异常体系

**[api_exception.dart](lib/services/api_exception.dart)** 定义了完整的异常类型：

| 异常类型 | HTTP 状态码 | 错误码 | 场景 |
|----------|-------------|--------|------|
| `UnauthorizedException` | 401 | - | 未授权访问 |
| `ServerException` | 500+ | - | 服务器错误 |
| `TimeoutException` | - | - | 请求超时 |
| `NetworkException` | - | - | 网络连接失败 |
| `AuthenticationException` | 401 | AUTH_FAILED | 登录失败 |
| `TokenExpiredException` | 401 | TOKEN_EXPIRED | Token 过期 |
| `UserAlreadyExistsException` | 400 | USER_EXISTS | 用户已存在 |
| `ApiException` | 其他 | - | 通用 API 异常 |

#### 3.2.1 错误码定义

```dart
class ApiErrorCode {
  static const String userNotFound = 'USER_NOT_FOUND';
  static const String duplicateUser = 'DUPLICATE_USER';
  static const String invalidParams = 'INVALID_PARAMS';
  static const String workoutCompleted = 'WORKOUT_COMPLETED';
  static const String unknown = 'UNKNOWN_ERROR';
}
```

### 3.3 日志系统

**[api_logger.dart](lib/services/api_logger/api_logger.dart)** 提供统一的日志记录：

- **日志级别**: 普通、详细（包含请求/响应体）
- **日志内容**: 方法、路径、参数、响应状态、耗时
- **日志格式**: 带图标的结构化日志

```
🚀 API 请求 [GET] /api/v1/workouts/today
✅ API 响应 [GET] /api/v1/workouts/today | 状态: 200 | 耗时: 345ms
❌ API 错误 [POST] /api/v1/auth/login | 状态: 401
```

---

## 4. 状态管理架构

### 4.1 Provider 架构

项目使用 **Provider** 进行状态管理，每个 Provider 负责一个业务域：

| Provider | 职责 | 依赖服务 |
|----------|------|----------|
| `AuthProvider` | 认证状态管理 | `AuthApiService` + `AuthService` |
| `UserProfileProvider` | 用户画像管理 | `UserApiService` + SharedPreferences |
| `WorkoutProvider` | 训练计划管理 | `WorkoutApiService` |
| `MonthlyStatsProvider` | 月度统计管理 | `RecordApiService` |

### 4.2 数据加载策略

所有 Provider 都遵循相同的数据加载模式：

```dart
// 1. 开始加载
_isLoading = true;
_errorMessage = null;
notifyListeners();

try {
  // 2. 根据 AppConfig.enableApi 决定数据源
  if (AppConfig.enableApi) {
    // 从 API 加载
    _data = await _apiService.fetchData();
  } else {
    // 使用本地模拟数据
    _data = getSampleData();
  }
} catch (e) {
  // 3. 错误处理
  _errorMessage = e.toString();

  // 4. Fallback 策略
  if (AppConfig.useFallbackWhenApiFails) {
    _data = getSampleData();
  } else {
    rethrow;
  }
} finally {
  // 5. 结束加载
  _isLoading = false;
  notifyListeners();
}
```

---

## 5. 应用配置

**[app_config.dart](lib/config/app_config.dart)** 提供全局配置：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `apiBaseUrl` | `http://127.0.0.1:9999` | API 基础地址 |
| `enableApi` | `true` | 是否启用 API（功能开关） |
| `useFallbackWhenApiFails` | `true` | API 失败时是否使用本地数据 |
| `timeout` | `10秒` | 请求超时时间 |

---

## 6. 应用启动流程

```
┌─────────────────┐
│   main()        │
│   ┌───────────┐ │
│   │初始化Prefs│ │
│   └───────────┘ │
└────────┬────────┘
         │
         v
┌─────────────────┐      ┌──────────────────┐
│ 创建 Providers  │─────>│ AuthProvider.init│
└────────┬────────┘      │ (恢复认证状态)    │
         │               └──────────────────┘
         v
┌─────────────────┐      ┌──────────────────┐
│   MainPage      │─────>│ 检查认证状态      │
│   _currentPage  │      └──────────────────┘
│   = 'loading'   │               │
└─────────────────┘               │
                                 ├─ 未认证 ─> 'login'
                                 │
                                 └─ 已认证 ─> 加载用户画像
                                              │
                                              ├─ 有画像 ─> 'today'
                                              │
                                              └─ 无画像 ─> 'onboarding'
```

---

## 7. 页面导航流程

```
                    ┌──────────────┐
                    │   loading    │
                    └──────┬───────┘
                           │
                ┌──────────┴──────────┐
                │                     │
         未认证 │                     │ 已认证
                v                     v
         ┌──────────────┐    ┌──────────────┐
         │    login     │    │  onboarding  │◄─────┐
         └──────┬───────┘    └──────┬───────┘      │
                │                    │              │
                │ 注册                │              │
                v                    │              │
         ┌──────────────┐            │              │
         │   register   │            │              │
         └──────┬───────┘            │              │
                │                    │              │
                └────────────────────┘              │
                                             完成画像
                                                 │
                                                 v
         ┌──────────────┐    ┌──────────────┐
         │    today     │◄──>│   profile    │
         └──────┬───────┘    └──────────────┘
                │
                │ 开始训练
                v
         ┌──────────────┐
         │  exercise    │
         └──────┬───────┘
                │
                │ 完成动作
                v
         ┌──────────────┐
         │  feedback    │
         └──────┬───────┘
                │
                │ 提交反馈
                v
         ┌──────────────┐
         │   weekly     │
         └──────────────┘
```

---

## 8. 数据命名规范

### 8.1 前后端命名转换

| Dart (前端) | JSON (后端) | 说明 |
|-------------|-------------|------|
| camelCase   | snake_case  | 自动转换 |
| totalDuration | total_duration | 字段名 |
| fitnessLevel | fitness_level | 枚举值 |
| targetMuscles | target_muscles | 列表字段 |

### 8.2 序列化兼容性

所有模型的 `fromJson` 方法都兼容驼峰和蛇形命名：

```dart
fitnessLevel: FitnessLevel.values.firstWhere(
  (e) => e.name == (json['fitness_level'] ?? json['fitnessLevel']),
  orElse: () => FitnessLevel.beginner,
)
```

---

## 9. 离线模式支持

应用支持离线模式运行，通过 `AppConfig.enableApi` 控制：

| 功能 | 在线模式 | 离线模式 |
|------|----------|----------|
| 认证 | API 认证 | 跳过登录 |
| 用户画像 | 服务器同步 | 仅本地存储 |
| 训练计划 | API 获取 | SampleData |
| 统计数据 | API 获取 | SampleData |

---

## 10. 总结

微动 MicoFit 的业务逻辑架构清晰，采用分层设计：

1. **Model 层**: 定义数据结构，处理序列化
2. **Service 层**: 封装 API 调用，统一异常处理
3. **Provider 层**: 状态管理，协调数据和业务逻辑
4. **Page 层**: UI 展示，用户交互

核心业务流程：
- **认证** → **用户画像** → **训练计划** → **动作执行** → **反馈** → **统计**

整个架构支持：
- ✅ API 开关控制
- ✅ Fallback 降级策略
- ✅ 本地数据缓存
- ✅ 完善的异常处理
- ✅ 详细的日志记录
