# MicoFit 项目图标使用清单

本文档记录了项目中所有使用 Flutter Material Icons 的位置。

## 图标统计

| 图标名称 | 使用次数 | 描述 |
|---------|---------|------|
| `Icons.check` | 5 | ✓ 勾选/完成 |
| `Icons.local_fire_department` | 4 | 🔥 火焰/卡路里 |
| `Icons.lightbulb` | 3 | 💡 提示/建议 |
| `Icons.chevron_right` | 3 | › 右箭头 |
| `Icons.refresh` | 2 | ↻ 刷新 |
| `Icons.person` | 2 | 👤 人物 |
| `Icons.auto_awesome` | 3 | ✨ AI/特效 |
| `Icons.arrow_forward` | 2 | → 前进 |
| `Icons.play_arrow` | 2 | ▶ 播放 |

---

## 详细使用列表

### 1. `lib/widgets/bottom_nav.dart` - 底部导航栏

| 行号 | 图标 | 用途 |
|------|------|------|
| 34 | `Icons.today` | 今日计划 |
| 39 | `Icons.calendar_view_week` | 周历视图 |
| 44 | `Icons.person` | 个人资料 |

### 2. `lib/widgets/workout_card.dart` - 训练卡片

| 行号 | 图标 | 用途 |
|------|------|------|
| 95 | `Icons.sync` | AI 重新生成 |
| 112 | `Icons.refresh` | 刷新计划 |
| 150 | `Icons.access_time` | 训练时长 |
| 162 | `Icons.location_on` | 训练场景 |
| 172 | `Icons.bolt` | RPE 强度 |
| 302 | `Icons.chevron_right` | 开始训练 |
| 371 | `Icons.lightbulb` | 训练建议 |

### 3. `lib/pages/today_plan_page.dart` - 今日计划页面

| 行号 | 图标 | 用途 |
|------|------|------|
| 107 | `Icons.wb_sunny` | 日期图标 |
| 151 | `Icons.local_fire_department` | 卡路里消耗 |

### 4. `lib/pages/weekly_view_page.dart` - 周历视图页面

| 行号 | 图标 | 用途 |
|------|------|------|
| 113 | `Icons.calendar_today` | 日期图标 |
| 535 | `Icons.lightbulb` | 周总结提示 |
| 620 | `Icons.local_fire_department` | 总卡路里 |
| 659 | `Icons.chevron_right` | 查看详情 |

### 5. `lib/pages/profile_page.dart` - 个人资料页面

| 行号 | 图标 | 用途 |
|------|------|------|
| 142 | `Icons.person_outline` | 头像占位 |
| 230 | `Icons.person` | 性别图标 |
| 268 | `Icons.local_fire_department` | 每日目标 |
| 274 | `Icons.height` | 身高 |
| 284 | `Icons.monitor_weight` | 体重 |
| 290 | `Icons.emoji_events` | 健身目标 |
| 306 | `Icons.place` | 训练地点 |
| 321 | `Icons.edit` | 编辑资料 |
| 327 | `Icons.refresh` | 重置画像 |
| 416 | `Icons.flag` | 目标旗帜 |

### 6. `lib/pages/onboarding_page.dart` - 引导页面

| 行号 | 图标 | 用途 |
|------|------|------|
| 287 | `Icons.close` | 关闭按钮 |
| 652 | `Icons.check` | 选项选中 |
| 1090 | `Icons.check` | 选中状态 |
| 1159 | `Icons.auto_awesome` | AI 图标 |
| 1278 | `Icons.arrow_forward` | 下一步 |
| 1328 | `Icons.arrow_forward` | 开始按钮 |

### 7. `lib/pages/feedback_page.dart` - 反馈页面

| 行号 | 图标 | 用途 |
|------|------|------|
| 118 | `Icons.auto_awesome` | AI 建议 |
| 446 | `Icons.check` | 选项选中 |
| 479 | `Icons.smart_toy` | AI 机器人 |
| 611 | `Icons.check` / `Icons.auto_awesome` | 提交按钮 |

### 8. `lib/pages/exercise_detail_page.dart` - 动作详情页面

| 行号 | 图标 | 用途 |
|------|------|------|
| 186 | `Icons.play_arrow` | 开始训练 |
| 216 | `Icons.check` | 完成标记 |
| 255 | `Icons.chevron_left` | 返回按钮 |
| 325 | `Icons.accessibility_new` | 徒手动作 |
| 327 | `Icons.circle_outlined` | 器械动作 |
| 329 | `Icons.directions_run` | 有氧动作 |
| 331 | `Icons.fitness_center` | 力量动作 |
| 362 | `Icons.format_list_numbered` | 组数列表 |
| 436 | `Icons.warning_amber_rounded` | 安全提示 |
| 480 | `Icons.air` | 呼吸节奏 |
| 624 | `Icons.play_arrow` / `Icons.pause` | 计时器控制 |
| 642 | `Icons.skip_next` | 跳过组 |

---

## 完整图标列表

### 导航类
- `Icons.chevron_right` - 右箭头
- `Icons.chevron_left` - 左箭头
- `Icons.arrow_forward` - 前进箭头

### 操作类
- `Icons.play_arrow` - 播放
- `Icons.pause` - 暂停
- `Icons.skip_next` - 跳过
- `Icons.refresh` - 刷新
- `Icons.sync` - 同步
- `Icons.check` - 勾选
- `Icons.close` - 关闭
- `Icons.edit` - 编辑

### 人物类
- `Icons.person` - 人物
- `Icons.person_outline` - 人物轮廓

### 时间日历类
- `Icons.today` - 今日
- `Icons.calendar_today` - 日历
- `Icons.calendar_view_week` - 周视图
- `Icons.access_time` - 时间
- `Icons.wb_sunny` - 晴天（日期）

### 健身类
- `Icons.local_fire_department` - 火焰/卡路里
- `Icons.fitness_center` - 健身
- `Icons.accessibility_new` - 徒手
- `Icons.directions_run` - 跑步/有氧
- `Icons.bolt` - 闪电/强度
- `Icons.monitor_weight` - 体重
- `Icons.height` - 身高

### 状态提示类
- `Icons.lightbulb` - 提示/建议
- `Icons.warning_amber_rounded` - 警告
- `Icons.auto_awesome` - AI/特效
- `Icons.smart_toy` - AI 机器人
- `Icons.format_list_numbered` - 列表
- `Icons.air` - 呼吸

### 其他
- `Icons.location_on` - 位置
- `Icons.place` - 地点
- `Icons.emoji_events` - 奖杯/目标
- `Icons.flag` - 旗帜/目标
- `Icons.circle_outlined` - 圆圈轮廓

---

## 注意事项

所有这些图标来自 Flutter Material Icons，通过字体文件 (`MaterialIcons-Regular.otf`) 渲染，**已内置在应用中，支持完全离线使用**。
