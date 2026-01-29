# 微动 MicoFit

> 一个基于 Flutter 的健身应用，为忙碌人群提供 AI 随身教练，利用碎片时间（3-20分钟）在任意场景完成有效训练。

## 项目概述

MicoFit 是一款智能健身应用，通过 AI 生成个性化的每日训练计划，帮助用户在忙碌生活中保持健康。应用支持多种运动场景（办公室、家庭、户外等），并根据用户反馈动态调整训练计划。

### 核心功能

- **今日计划** - AI 生成的每日训练计划，根据用户状态动态调整
- **动作详情** - 带计时器的训练动作指导，包含要领、注意事项和呼吸节奏
- **训练反馈** - 训练后快速反馈，AI 根据反馈调整次日计划
- **打卡记录** - 本月训练打卡日历和统计数据
- **个人中心** - 用户资料管理、运动目标设置

## 技术栈

| 技术 | 版本 | 说明 |
|------|------|------|
| Flutter | 3.10.7+ | 跨平台 UI 框架 |
| Dart | 3.10.7+ | 编程语言 |
| Material Design 3 | - | UI 设计系统 |
| shared_preferences | 2.2.2 | 本地数据存储 |

## 环境要求

- Flutter SDK >= 3.10.7
- Dart SDK >= 3.10.7
- Android Studio / VS Code
- Android SDK (Android 开发)
- Xcode (iOS 开发，需要 macOS)

## 快速开始

### 1. 克隆项目

```bash
git clone <repository-url>
cd micofit
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 运行应用

```bash
# 在连接的设备上运行
flutter run

# 在 Chrome 浏览器中运行（Web）
flutter run -d chrome

# 在 Windows 平台运行
flutter run -d windows

# 在 Android 设备/模拟器运行
flutter run -d android
```

### 4. 热重载

应用运行时：
- 按 `r` 进行热重载（保留状态）
- 按 `R` 进行热重启（重置状态）
- 保存文件会自动触发热重载

## 项目架构

### 目录结构

```
lib/
├── main.dart                    # 应用入口，包含路由和状态管理
├── models/                      # 数据模型层
│   ├── exercise.dart            # 动作模型
│   ├── feedback.dart            # 反馈模型
│   ├── user_profile.dart        # 用户画像模型
│   ├── weekly_data.dart         # 打卡数据模型
│   └── workout.dart             # 训练计划模型
├── pages/                       # 页面层
│   ├── today_plan_page.dart     # 今日计划页面
│   ├── exercise_detail_page.dart # 动作详情页面
│   ├── feedback_page.dart       # 反馈页面
│   ├── weekly_view_page.dart    # 打卡记录页面
│   ├── profile_page.dart        # 个人中心页面
│   └── onboarding_page.dart     # 信息录入页面
├── widgets/                     # 可复用组件
│   ├── bottom_nav.dart          # 底部导航栏
│   └── workout_card.dart        # 训练卡片组件
└── utils/                       # 工具层
    └── sample_data.dart         # 示例数据

assets/
└── exercises/                   # 动作示意图资源
    ├── exercise-neck.png
    ├── exercise-core.png
    └── exercise-leg.png

test/
└── widget_test.dart             # Widget 测试文件
```

### 路由管理

应用使用简单的状态管理进行页面切换，在 `MainPage` 中通过 `_currentPage` 字符串控制当前显示的页面：

| 页面 | 路由值 | 描述 |
|------|--------|------|
| 信息录入 | `onboarding` | 用户首次使用时的信息收集 |
| 今日计划 | `today` | 显示每日训练计划卡片 |
| 动作详情 | `exercise` | 带计时器的动作详情页 |
| 训练进行 | `workout` | 训练执行页面（按模块切换动作） |
| 反馈 | `feedback` | 训练后反馈问卷 |
| 打卡 | `weekly` | 本月训练统计和日历 |
| 个人中心 | `profile` | 用户个人资料和设置 |

### 数据流

```
MainPage (状态管理中心)
    │
    ├── UserProfile (用户数据)
    │   ├── 基本信息（姓名、性别、年龄）
    │   ├── 身体数据（身高、体重、BMI）
    │   ├── 运动偏好（场景、装备、目标）
    │   └── 运动目标（每周天数、每次时长）
    │
    ├── WorkoutPlan (训练计划数据)
    │   └── modules → WorkoutModule → Exercise
    │
    ├── WeeklyStats (打卡统计数据)
    │   └── records → DayRecord (按月显示)
    │
    └── 页面导航回调
        ├── onNavigate(String page)
        ├── onStartWorkout()
        ├── onComplete()
        └── onBack()
```

### 设计规范

#### 颜色系统

| 用途 | 颜色值 | 说明 |
|------|--------|------|
| 主题色 (Mint) | `#2DD4BF` | 主按钮、图标、进度条 |
| 主题色深 | `#14B8A6` | 次要强调元素 |
| 主题色更深 | `#0F766E` | 选中文本、强调文本 |
| 文字主色 | `#115E59` | 标题、正文 |
| AI 紫色 | `#8B5CF6` | AI 相关功能 |
| 背景色 | `#F5F5F0` | 页面背景 |
| 成功色 | `#10B981` | 完成状态 |
| 警告色 | `#F59E0B` | 提示信息 |
| 危险色 | `#EF4444` | 删除、重置操作 |

#### 圆角规范

- 卡片/容器: `12-24px`
- 按钮: `12-16px`
- 输入框: `12px`
- 圆形按钮/图标: `Circle()`

#### 间距规范

- 页面边距: `24px`
- 卡片内边距: `16-24px`
- 组件间距: `12-16px`
- 按钮内边距: `12-20px` (垂直), `20-48px` (水平)

## 开发命令

### 运行应用

```bash
flutter run              # 在连接的设备上运行
flutter run -d chrome    # 在 Chrome 浏览器中运行（Web）
flutter run -d windows   # 在 Windows 平台运行
flutter run -d android   # 在 Android 运行
```

### 测试

```bash
flutter test             # 运行所有测试
flutter test test/widget_test.dart  # 运行单个测试文件
```

### 代码分析

```bash
flutter analyze          # 静态分析代码
flutter format lib/      # 格式化代码
dart fix --apply         # 自动修复代码问题
```

### 依赖管理

```bash
flutter pub get          # 获取依赖
flutter pub upgrade      # 升级依赖
flutter pub outdated     # 查看过期的依赖包
```

### 构建

```bash
flutter build apk        # 构建 Android APK
flutter build appbundle  # 构建 Android App Bundle
flutter build ios        # 构建 iOS（需要 macOS）
flutter build web        # 构建 Web 应用
flutter build windows    # 构建 Windows 应用
flutter build macos      # 构建 macOS 应用
```

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

### 资源文件未加载

确保 `pubspec.yaml` 中已声明资源目录：

```yaml
flutter:
  assets:
    - assets/exercises/
```

声明后需要运行 `flutter pub get`。

## 项目状态

### 已完成功能

- ✅ 今日计划展示（包含训练卡片）
- ✅ 动作详情页面（带计时器）
- ✅ 训练反馈问卷
- ✅ 打卡记录视图（月历展示）
- ✅ 个人中心页面
- ✅ 用户信息录入流程
- ✅ 底部导航栏
- ✅ 本地数据持久化
- ✅ 运动目标设置

### 待优化项

- 🔄 集成真实 AI 接口（当前使用模拟数据）
- 🔄 完善用户训练历史记录
- 🔄 添加社交分享功能
- 🔄 完善动画效果

## 许可证

本项目仅供学习和参考使用。

## 联系方式

如有问题或建议，欢迎通过 Issues 反馈。
