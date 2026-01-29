# 微动 MicoFit - 项目架构详解

## 目录

1. [项目概述](#项目概述)
2. [目录结构总览](#目录结构总览)
3. [Flutter 项目配置代码](#flutter-项目配置代码)
4. [主业务代码详解](#主业务代码详解)
5. [数据流与状态管理](#数据流与状态管理)
6. [路由与导航](#路由与导航)

---

## 项目概述

**微动 MicoFit** 是一个基于 Flutter 开发的跨平台健身应用，为忙碌人群提供 AI 驱动的碎片化运动训练方案。

### 技术栈
- **Flutter**: 3.10.7+
- **Dart**: 3.10.7+
- **状态管理**: 简单的 setState 方式
- **本地存储**: shared_preferences
- **UI 框架**: Material Design 3

---

## 目录结构总览

```
flutter_application_1/
├── lib/                              # 主业务代码目录
│   ├── main.dart                     # 应用入口
│   ├── models/                       # 数据模型层
│   ├── pages/                        # 页面层
│   ├── widgets/                      # 可复用组件
│   └── utils/                        # 工具类
│
├── assets/                           # 资源文件
│   └── exercises/                    # 动作示意图
│
├── android/                          # Android 平台配置
├── ios/                              # iOS 平台配置
├── web/                              # Web 平台配置
├── windows/                          # Windows 平台配置
├── macos/                            # macOS 平台配置
│
├── build/                            # 构建输出（生成）
├── .dart_tool/                       # Dart 工具链（生成）
│
├── pubspec.yaml                      # Flutter 依赖配置
├── analysis_options.yaml             # 代码分析配置
├── README.md                         # 项目说明
└── CLAUDE.md                         # AI 开发指南
```

---

## Flutter 项目配置代码

### 1. 核心配置文件

#### `pubspec.yaml` - 依赖与资源配置
**作用**: 定义项目依赖、版本、资源文件等

```yaml
# 关键配置项
name: flutter_application_1
version: 1.0.0+1
environment:
  sdk: ^3.10.7

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8      # iOS 风格图标
  shared_preferences: ^2.2.2   # 本地存储

flutter:
  assets:
    - assets/exercises/         # 声明资源文件
  uses-material-design: true
```

**配置类型**: ✅ **配置代码**

#### `analysis_options.yaml` - 代码分析配置
**作用**: 配置 Dart 静态分析规则（使用 flutter_lints）

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_const_constructors
    - prefer_final_locals
    # ... 更多规则
```

**配置类型**: ✅ **配置代码**

---

### 2. 平台特定配置

#### Android 配置 (`android/`)

| 文件 | 类型 | 说明 |
|------|------|------|
| `android/app/build.gradle` | 配置代码 | Android 构建配置 |
| `android/app/src/main/AndroidManifest.xml` | 配置代码 | 应用清单文件 |
| `android/local.properties` | 配置代码 | 本地 SDK 路径 |

#### iOS 配置 (`ios/`)

| 文件 | 类型 | 说明 |
|------|------|------|
| `ios/Runner.xcodeproj/` | 配置代码 | Xcode 项目配置 |
| `ios/Runner/Info.plist` | 配置代码 | iOS 应用属性 |
| `ios/Podfile` | 配置代码 | CocoaPods 依赖配置 |

#### Web 配置 (`web/`)

| 文件 | 类型 | 说明 |
|------|------|------|
| `web/manifest.json` | 配置代码 | PWA 清单文件 |
| `web/index.html` | 配置代码 | Web 入口 HTML |

---

## 主业务代码详解

### 主业务代码目录结构

```
lib/
├── main.dart                    # 🔴 应用入口（核心）
├── models/                      # 📊 数据模型层
│   ├── exercise.dart            # 动作模型
│   ├── workout.dart             # 训练计划模型
│   ├── user_profile.dart        # 用户画像模型
│   ├── feedback.dart            # 反馈模型
│   └── weekly_data.dart         # 打卡数据模型
│
├── pages/                       # 📱 页面层（UI）
│   ├── today_plan_page.dart     # 今日计划页面
│   ├── exercise_detail_page.dart # 动作详情页面
│   ├── feedback_page.dart       # 训练反馈页面
│   ├── weekly_view_page.dart    # 打卡记录页面
│   ├── profile_page.dart        # 个人中心页面
│   └── onboarding_page.dart     # 信息录入页面
│
├── widgets/                     # 🧩 可复用组件
│   ├── bottom_nav.dart          # 底部导航栏
│   └── workout_card.dart        # 训练卡片组件
│
└── utils/                       # 🛠️ 工具类
    └── sample_data.dart         # 示例数据生成器
```

---

### 核心文件详解

#### 1. `main.dart` - 应用入口

**类型**: 🔴 **核心业务代码**

**职责**:
- 应用启动入口
- 全局路由管理
- 应用主题配置
- 用户数据持久化

**关键代码结构**:

```dart
// 1. 应用启动
void main() {
  runApp(const MicoFitApp());
}

// 2. 主题配置
class MicoFitApp extends StatelessWidget {
  // Material Design 3 主题
  // 颜色方案: Mint (#2DD4BF) + Purple (#8B5CF6)
}

// 3. 路由与状态管理
class MainPage extends StatefulWidget {
  String _currentPage = 'loading';  // 当前页面路由
  WorkoutPlan _workoutPlan;         // 训练计划数据
  UserProfile? _userProfile;        // 用户数据

  // 页面路由映射
  Widget build(BuildContext context) {
    switch (_currentPage) {
      case 'onboarding': return OnboardingPage(...);
      case 'today': return TodayPlanPage(...);
      case 'exercise': return ExerciseDetailPage(...);
      case 'feedback': return FeedbackPage(...);
      case 'weekly': return WeeklyViewPage(...);
      case 'profile': return ProfilePage(...);
    }
  }
}
```

---

#### 2. 数据模型层 (`models/`)

**类型**: 🔴 **核心业务代码**

##### `exercise.dart` - 动作模型

```dart
class Exercise {
  final String id;
  final String name;              // 动作名称
  final int duration;             // 时长（秒）
  final String description;       // 描述
  final List<String> steps;       // 动作要领
  final String tips;              // 注意事项
  final String breathing;         // 呼吸节奏
  final String image;             // 示意图路径
  final List<String> targetMuscles; // 目标肌群
}
```

##### `workout.dart` - 训练计划模型

```dart
class WorkoutPlan {
  final String id;
  final String title;             // 计划标题
  final String subtitle;          // 副标题
  final int totalDuration;        // 总时长
  final String scene;             // 运动场景
  final int rpe;                  // 强度指标
  final String aiNote;            // AI 备注
  final List<WorkoutModule> modules; // 训练模块
}

class WorkoutModule {
  final String id;
  final String name;              // 模块名称
  final int duration;             // 模块时长
  final List<Exercise> exercises;  // 包含的动作
}
```

##### `user_profile.dart` - 用户画像模型

```dart
class UserProfile {
  final String nickname;          // 昵称
  final double height;            // 身高
  final double weight;            // 体重
  final double bmi;               // BMI
  final FitnessLevel fitnessLevel; // 健身等级
  final String scene;             // 常用场景
  final int timeBudget;           // 时间预算
  final List<String> limitations; // 身体限制
  final String equipment;         // 可用装备
  final String goal;              // 核心目标
  final int weeklyDays;           // 每周天数
  final List<String> preferredTime; // 偏好时段
}

enum FitnessLevel {
  beginner,     // 零基础
  occasional,   // 偶尔运动
  regular,      // 规律运动
}
```

##### `feedback.dart` - 反馈模型

```dart
enum CompletionLevel {
  smooth,      // 顺利完成
  adjusted,    // 稍作调整
  incomplete,  // 未完成
}

enum FeelingLevel {
  great,       // 状态很好
  okay,        // 还可以
  tired,       // 有点累
  pain,        // 不适
}

enum TomorrowPreference {
  maintain,    // 保持
  increase,    // 加量
  decrease,    // 减量
  rest,        // 休息
}
```

##### `weekly_data.dart` - 打卡数据模型

```dart
class WeeklyStats {
  final int totalMinutes;          // 本周总分钟数
  final int targetMinutes;         // 目标分钟数
  final int completedDays;         // 已完成天数
  final List<DayRecord> records;   // 每日记录
}

class DayRecord {
  final String date;               // 日期
  final int dayOfWeek;             // 星期几
  final int duration;              // 运动时长
  final DayStatus status;          // 状态
}

enum DayStatus {
  none,        // 无计划
  planned,     // 已计划
  partial,     // 部分完成
  completed,   // 已完成
}
```

---

#### 3. 页面层 (`pages/`)

**类型**: 🔴 **核心业务代码**

##### `today_plan_page.dart` - 今日计划页面

**职责**:
- 显示今日训练计划
- 展示 AI 推荐理由
- 启动训练流程

**关键组件**:
- 训练卡片展示
- AI 备注显示
- 开始训练按钮

##### `exercise_detail_page.dart` - 动作详情页面

**职责**:
- 显示动作示意图
- 动作要领说明
- 训练计时器功能

**关键功能**:
- 倒计时器
- 暂停/继续
- 完成状态追踪

##### `feedback_page.dart` - 训练反馈页面

**职责**:
- 收集用户训练反馈
- AI 生成建议展示

**三个问题**:
1. 完成度如何？
2. 身体感受？
3. 明天状态预测？

##### `onboarding_page.dart` - 信息录入页面

**职责**:
- 新用户信息采集
- 三步流程：
  - Step 1: 基本信息（昵称、身高、体重）
  - Step 2: 运动场景、时间预算、装备
  - Step 3: 核心目标、每周天数、偏好时段

##### `weekly_view_page.dart` - 打卡记录页面

**职责**:
- 月历打卡视图
- 本周统计数据
- 目标进度显示

##### `profile_page.dart` - 个人中心页面

**职责**:
- 用户信息展示
- 运动目标设置
- 修改个人信息
- 重新录入功能

---

#### 4. 组件层 (`widgets/`)

**类型**: 🔴 **核心业务代码**

##### `bottom_nav.dart` - 底部导航栏

**导航项**:
- 今日 (today)
- 打卡 (weekly)
- 我的 (profile)

##### `workout_card.dart` - 训练卡片

**展示内容**:
- 训练标题
- 时长、场景、强度
- AI 推荐标签

---

#### 5. 工具层 (`utils/`)

**类型**: 🔴 **核心业务代码**

##### `sample_data.dart` - 示例数据生成器

**功能**:
- `getSampleWorkoutPlan()` - 生成示例训练计划
- `getSampleWeeklyData()` - 生成示例打卡数据

---

## 数据流与状态管理

### 状态管理方式

本项目使用 **简单的 setState** 方式进行状态管理：

```
MainPage (状态中心)
    │
    ├── _currentPage (String)        # 当前页面路由
    ├── _userProfile (UserProfile?)   # 用户数据
    ├── _workoutPlan (WorkoutPlan)    # 训练计划
    └── _selectedExercise (Exercise?) # 当前选中动作
```

### 数据持久化

使用 `shared_preferences` 存储用户数据：

```dart
// 保存数据
await prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
await prefs.setBool(_keyOnboardingCompleted, true);

// 加载数据
final profileJson = prefs.getString(_keyProfile);
final profile = UserProfile.fromJson(jsonDecode(profileJson));
```

---

## 路由与导航

### 路由表

| 路由值 | 页面 | 说明 |
|--------|------|------|
| `loading` | 加载页 | 启动时加载数据 |
| `onboarding` | 信息录入 | 首次使用或修改信息 |
| `today` | 今日计划 | 主页面 |
| `exercise` | 动作详情 | 训练执行中 |
| `feedback` | 训练反馈 | 训练完成后 |
| `weekly` | 打卡记录 | 月历视图 |
| `profile` | 个人中心 | 用户设置 |

### 页面跳转方式

```dart
// 导航到页面
void _navigateTo(String page) {
  setState(() {
    _currentPage = page;
  });
}

// 示例跳转
_navigateTo('exercise');  // 进入动作详情
_navigateTo('feedback');  // 提交反馈
_navigateTo('profile');   // 进入个人中心
```

---

## 文件分类总结

### 🔴 主业务代码（需要开发和维护）

| 目录/文件 | 类型 | 说明 |
|-----------|------|------|
| `lib/` | 源代码 | **全部为主业务代码** |
| `assets/` | 资源 | 动作图片资源 |
| `test/` | 测试 | 单元测试代码 |

### ✅ Flutter 配置代码（通常不需要修改）

| 目录/文件 | 类型 | 说明 |
|-----------|------|------|
| `pubspec.yaml` | 配置 | 依赖管理 |
| `analysis_options.yaml` | 配置 | 代码分析规则 |
| `android/` | 配置 | Android 平台配置 |
| `ios/` | 配置 | iOS 平台配置 |
| `web/` | 配置 | Web 平台配置 |
| `windows/` | 配置 | Windows 平台配置 |
| `macos/` | 配置 | macOS 平台配置 |
| `build/` | 生成 | 构建输出（不要手动修改） |
| `.dart_tool/` | 生成 | Dart 工具链（不要手动修改） |

---

## 代码分层架构

```
┌─────────────────────────────────────────┐
│           表现层 (Presentation)          │
│  ┌───────────────────────────────────┐  │
│  │  pages/ - 页面                    │  │
│  │  widgets/ - 可复用组件            │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│         业务逻辑层 (Business Logic)       │
│  ┌───────────────────────────────────┐  │
│  │  main.dart - 路由与状态管理       │  │
│  │  utils/ - 工具函数                │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│          数据层 (Data Layer)             │
│  ┌───────────────────────────────────┐  │
│  │  models/ - 数据模型                │  │
│  │  shared_preferences - 持久化      │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

---

## 开发建议

### 1. 添加新功能时需要修改的文件

| 功能类型 | 需要修改的文件 |
|---------|--------------|
| 新增页面 | `lib/pages/新页面.dart` + `lib/main.dart` |
| 新增数据模型 | `lib/models/新模型.dart` |
| 新增组件 | `lib/widgets/新组件.dart` |
| 修改主题 | `lib/main.dart` |

### 2. 配置文件修改注意事项

| 文件 | 修改时机 | 注意事项 |
|------|---------|---------|
| `pubspec.yaml` | 添加依赖 | 必须运行 `flutter pub get` |
| `android/` | 需要原生功能 | 通常不需要修改 |
| `ios/` | 需要原生功能 | 通常不需要修改 |

---

## 总结

**主业务代码** = `lib/` 目录下的所有 `.dart` 文件
- 这是开发和维护的核心部分
- 包含所有业务逻辑、UI、数据模型

**Flutter 配置代码** = `pubspec.yaml`、平台配置目录
- 通常不需要修改
- 修改后需要重新构建

**生成文件** = `build/`、`.dart_tool/`
- 永远不要手动修改
- 每次构建都会重新生成
