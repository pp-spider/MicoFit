# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

**微动 MicoFit** - 一个基于 Flutter 的健身应用，为忙碌人群提供 AI 随身教练，利用碎片时间（3-20分钟）在任意场景完成有效训练。

### 核心功能
- **今日计划** - AI 生成的每日训练计划，根据用户状态动态调整
- **动作详情** - 带计时器的训练动作指导
- **训练反馈** - 训练后快速反馈，AI 根据反馈调整次日计划
- **周历视图** - 本周训练记录和统计数据

**Dart SDK 要求**: `^3.10.7`（见 [pubspec.yaml](pubspec.yaml)）

## 常用命令

### 运行应用
```bash
flutter run              # 在连接的设备上运行
flutter run -d chrome    # 在 Chrome 浏览器中运行（Web）
flutter run -d windows   # 在 Windows 平台运行
```

### 热重载
- 在应用运行时按 `r` 进行热重载（保留状态）
- 按 `R` 进行热重启（重置状态）
- 保存文件会自动触发热重载

### 测试
```bash
flutter test             # 运行所有测试
flutter test test/widget_test.dart  # 运行单个测试文件
```

### 代码分析
```bash
flutter analyze          # 静态分析代码
flutter format lib/      # 格式化代码
```

### 依赖管理
```bash
flutter pub get          # 获取依赖
flutter pub upgrade      # 升级依赖
```

### 构建
```bash
flutter build apk        # 构建 Android APK
flutter build ios        # 构建 iOS（需要 macOS）
flutter build web        # 构建 Web 应用
flutter build windows    # 构建 Windows 应用
```

## 代码架构

### 目录结构
```
lib/
├── main.dart                    # 应用入口，包含路由和状态管理
├── models/                      # 数据模型
│   ├── exercise.dart            # 动作模型
│   ├── feedback.dart            # 反馈模型
│   ├── user_profile.dart        # 用户画像模型
│   ├── weekly_data.dart         # 周数据模型
│   └── workout.dart             # 训练计划模型
├── pages/                       # 页面
│   ├── today_plan_page.dart     # 今日计划页面
│   ├── exercise_detail_page.dart # 动作详情页面
│   ├── feedback_page.dart       # 反馈页面
│   └── weekly_view_page.dart    # 周历视图页面
├── widgets/                     # 可复用组件
│   ├── bottom_nav.dart          # 底部导航栏
│   └── workout_card.dart        # 训练卡片组件
└── utils/                       # 工具函数
    └── sample_data.dart         # 示例数据

test/
└── widget_test.dart             # Widget 测试文件
```

### 路由管理
应用使用简单的状态管理进行页面切换，在 [MainPage](lib/main.dart) 中通过 `_currentPage` 字符串控制当前显示的页面：

| 页面 | 路由值 | 描述 |
|------|--------|------|
| 今日计划 | `today` | 显示每日训练计划卡片 |
| 动作详情 | `exercise` | 带计时器的动作详情页 |
| 反馈 | `feedback` | 训练后反馈问卷 |
| 周历 | `weekly` | 本周训练统计和日历 |
| 个人资料 | `profile` | 用户个人资料（待实现） |

### 数据流
```
MainPage (状态管理)
    │
    ├── WorkoutPlan (训练计划数据)
    │   └── modules → WorkoutModule → Exercise
    │
    ├── WeeklyStats (周统计数据)
    │   └── records → DayRecord
    │
    └── 页面导航回调
        ├── onNavigate(String page)
        ├── onStartWorkout()
        ├── onComplete()
        └── onBack()
```

### 设计规范

#### 颜色系统
| 用途 | 颜色值 |
|------|--------|
| 主题色 (Mint) | `#2DD4BF` |
| 主题色深 | `#14B8A6` |
| 文字主色 | `#115E59` |
| AI 紫色 | `#8B5CF6` |
| 背景色 | `#F5F5F0` |
| 成功色 | `#10B981` |
| 警告色 | `#F59E0B` |

#### 圆角规范
- 卡片/容器: `12-24px`
- 按钮: `12-16px`
- 输入框: `12px`

#### 间距规范
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
