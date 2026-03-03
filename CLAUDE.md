# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Python环境
执行python相关命令先进入到python3.12环境中(conda activate python3.12)

## 项目概述

**微动 MicoFit** - 一个基于 Flutter 的健身应用 + FastAPI 后端，为忙碌人群提供 AI 随身教练，利用碎片时间（3-20分钟）在任意场景完成有效训练。

### 核心功能
- **今日计划** - AI 生成的每日训练计划，根据用户状态动态调整
- **动作详情** - 带计时器的训练动作指导
- **训练反馈** - 训练后快速反馈，AI 根据反馈调整次日计划
- **周历视图** - 本周训练记录和统计数据
- **AI 聊天** - 与 AI 教练对话，获取健身建议
- **离线同步** - 支持离线使用，网络恢复后自动同步

**Dart SDK 要求**: `^3.10.7`（见 [pubspec.yaml](pubspec.yaml)）

## 常用命令

### Flutter 前端

```bash
flutter run              # 在连接的设备上运行
flutter run -d chrome   # 在 Chrome 浏览器中运行（Web）
flutter run -d windows   # 在 Windows 平台运行
flutter run -d android   # 在 Android 设备/模拟器运行
```

### 测试
```bash
flutter test             # 运行所有测试
flutter test test/widget_test.dart  # 运行单个测试文件
```

### 代码分析
```bash
flutter analyze          # 静态分析代码
flutter format lib/     # 格式化代码
dart fix --apply        # 自动修复代码问题
```

### 依赖管理
```bash
flutter pub get         # 获取依赖
flutter pub upgrade     # 升级依赖
flutter pub outdated    # 查看过期的依赖包
```

### 构建
```bash
flutter build apk       # 构建 Android APK
flutter build appbundle # 构建 Android App Bundle
flutter build ios       # 构建 iOS（需要 macOS）
flutter build web       # 构建 Web 应用
flutter build windows   # 构建 Windows 应用
```

### 后端 (FastAPI)

```bash
cd backend
pip install -r requirements.txt  # 安装 Python 依赖
uvicorn main:app --reload        # 启动开发服务器 (默认 http://localhost:8000)
```

## 代码架构

### 整体架构
```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Frontend                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Pages      │  │  Providers  │  │     Services        │ │
│  │  (UI 层)     │←→│ (状态管理)   │←→│   (API/本地存储)     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│         ↓                                    ↓               │
│  ┌─────────────┐                   ┌─────────────────────┐ │
│  │  Widgets    │                   │  Sync Manager       │ │
│  │  (组件库)    │                   │  (离线同步)          │ │
│  └─────────────┘                   └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ↓ HTTP
┌─────────────────────────────────────────────────────────────┐
│                    FastAPI Backend                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   API       │  │  Services   │  │     Agents         │ │
│  │  (Endpoints)│←→│  (业务逻辑)  │←→│  (AI 训练/聊天)     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│         ↓                                    ↓               │
│  ┌─────────────┐                   ┌─────────────────────┐ │
│  │   Models    │                   │   Database         │ │
│  │  (SQLModel) │                   │   (PostgreSQL)     │ │
│  └─────────────┘                   └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 前端目录结构

```
lib/
├── main.dart                    # 应用入口，Provider 配置
├── config/                      # 配置文件
│   └── app_config.dart         # API 地址、环境配置
├── models/                      # 数据模型
│   ├── exercise.dart           # 动作模型
│   ├── feedback.dart           # 反馈模型
│   ├── user_profile.dart       # 用户画像模型
│   ├── weekly_data.dart        # 周数据模型
│   └── workout.dart            # 训练计划模型
├── pages/                       # 页面
│   ├── today_plan_page.dart    # 今日计划页面
│   ├── exercise_detail_page.dart # 动作详情页面
│   ├── feedback_page.dart      # 反馈页面
│   ├── weekly_view_page.dart   # 周历视图页面
│   ├── profile_page.dart       # 个人中心页面
│   ├── onboarding_page.dart    # 信息录入页面
│   ├── ai_chat_page.dart       # AI 聊天页面
│   ├── login_page.dart         # 登录页面
│   └── splash_page.dart        # 启动页
├── providers/                   # 状态管理（Provider 模式）
│   ├── auth_provider.dart      # 认证状态
│   ├── user_profile_provider.dart # 用户画像
│   ├── workout_provider.dart  # 训练计划
│   ├── workout_progress_provider.dart # 训练进度
│   ├── chat_provider.dart      # AI 聊天
│   ├── sync_provider.dart      # 同步状态
│   └── monthly_stats_provider.dart # 月度统计
├── services/                    # 服务层
│   ├── http_client.dart        # HTTP 客户端封装
│   ├── auth_api_service.dart   # 认证 API
│   ├── user_api_service.dart   # 用户 API
│   ├── workout_api_service.dart # 训练 API
│   ├── ai_api_service.dart     # AI 服务
│   ├── network_service.dart    # 网络状态检测
│   ├── sync_manager.dart       # 离线同步管理器
│   ├── data_sync_service.dart # 数据同步服务
│   ├── sync_api_service.dart   # 同步 API
│   └── offline_queue_service.dart # 离线队列
├── widgets/                     # 可复用组件
│   ├── bottom_nav.dart         # 底部导航栏
│   ├── workout_card.dart       # 训练卡片组件
│   └── sync_status_indicator.dart # 同步状态指示器
└── utils/                       # 工具函数
    └── sample_data.dart         # 示例数据

backend/
├── main.py                      # FastAPI 入口
├── app/
│   ├── api/v1/                 # API 路由
│   │   ├── auth.py             # 认证接口
│   │   ├── users.py            # 用户接口
│   │   ├── profiles.py         # 用户画像接口
│   │   ├── workouts.py         # 训练计划接口
│   │   ├── feedback.py         # 反馈接口
│   │   ├── ai.py               # AI 接口
│   │   └── sync.py             # 同步接口
│   ├── services/               # 业务逻辑
│   │   ├── auth_service.py
│   │   ├── user_service.py
│   │   ├── workout_service.py
│   │   ├── ai_service.py
│   │   └── context_service.py
│   ├── agents/                 # AI Agent
│   │   ├── workout_agent.py    # 训练计划生成
│   │   ├── chat_agent.py       # 聊天对话
│   │   ├── prompts.py          # Prompt 模板
│   │   └── state.py            # Agent 状态
│   ├── models/                 # 数据库模型
│   ├── schemas/                # Pydantic schemas
│   └── core/                   # 核心配置
└── requirements.txt            # Python 依赖
```

### 状态管理（Provider 模式）

应用使用 `provider` 包进行状态管理，在 [main.dart](lib/main.dart) 中配置多个 `ChangeNotifierProvider`：

| Provider | 职责 |
|----------|------|
| `AuthProvider` | 用户认证、登录状态、Token 管理 |
| `UserProfileProvider` | 用户画像数据、偏好设置 |
| `WorkoutProvider` | 今日训练计划 |
| `WorkoutProgressProvider` | 训练进度跟踪 |
| `ChatProvider` | AI 聊天对话历史 |
| `SyncProvider` | 离线同步状态 |
| `MonthlyStatsProvider` | 月度统计数据 |

### API 通信

- 使用 `http` 包进行 HTTP 请求
- `http_client.dart` 封装了统一的请求头和错误处理
- Token 通过 `flutter_secure_storage` 安全存储

### 离线同步机制

```
NetworkService (检测网络状态)
       ↓
SyncProvider (管理同步状态)
       ↓
OfflineQueueService (离线队列)
       ↓
DataSyncService (数据同步)
       ↓
SyncManager (同步协调器) ←→ SyncAPI (后端接口)
```

## 设计规范

### 颜色系统
| 用途 | 颜色值 |
|------|--------|
| 主题色 (Mint) | `#2DD4BF` |
| 主题色深 | `#14B8A6` |
| 文字主色 | `#115E59` |
| AI 紫色 | `#8B5CF6` |
| 背景色 | `#F5F5F0` |
| 成功色 | `#10B981` |
| 警告色 | `#F59E0B` |

### 圆角规范
- 卡片/容器: `12-24px`
- 按钮: `12-16px`
- 输入框: `12px`

### 间距规范
- 页面边距: `24px`
- 卡片内边距: `16-24px`
- 组件间距: `12-16px`

## Lint 配置

项目使用 `flutter_lints` 包进行代码检查，配置文件为 [analysis_options.yaml](analysis_options.yaml)。可以通过 `flutter analyze` 运行分析。

## 常见问题

### Flutter 启动锁

如果遇到 `Waiting for another flutter command to release the startup lock...` 错误，在 Windows 上运行：

```powershell
taskkill /F /IM dart.exe
taskkill /F /IM flutter.exe
del /F /Q "%LOCALAPPDATA%\Pub\Cache\.pubtmp\flutter-tools-lock"
```

### withOpacity 废弃警告

代码中使用了已废弃的 `withOpacity()` 方法，这是 Flutter 新版本的行为变更。不影响功能，后续可替换为 `withValues()` 方法。
