# 微动 MicoFit - API 接口文档

## 基础信息

- **基础地址**: `http://127.0.0.1:9999`
- **API 版本**: `/api/v1`
- **数据格式**: `application/json`
- **字符编码**: `UTF-8`
- **请求超时**: 10 秒

---

## 目录

1. [用户画像相关](#1-用户画像相关)
2. [训练计划相关](#2-训练计划相关)
3. [训练记录相关](#3-训练记录相关)
4. [训练反馈相关](#4-训练反馈相关)
5. [选项配置相关](#5-选项配置相关)
6. [错误码说明](#错误码说明)

---

## 1. 用户画像相关

### 1.1 获取用户画像

**接口描述**: 根据用户 ID 获取用户画像信息

**请求路径**: `/api/v1/users/profile`

**请求方法**: `GET`

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| userId | string | 是 | 用户昵称/ID |

**请求示例**:
```http
GET /api/v1/users/profile?userId=zhangsan
```

**响应示例**:
```json
{
  "nickname": "张三",
  "height": 170.0,
  "weight": 65.0,
  "bmi": 22.5,
  "fitnessLevel": "regular",
  "scene": "office",
  "timeBudget": 12,
  "limitations": ["shoulder"],
  "equipment": "mat",
  "goal": "sedentary",
  "weeklyDays": 3,
  "preferredTime": ["morning", "evening"]
}
```

**字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| nickname | string | 用户昵称 |
| height | number | 身高（厘米） |
| weight | number | 体重（千克） |
| bmi | number | BMI 指数 |
| fitnessLevel | string | 健身等级：`beginner`(零基础) / `occasional`(偶尔运动) / `regular`(规律运动) |
| scene | string | 运动场景：`bed`(床上) / `office`(办公室) / `living`(客厅) / `outdoor`(户外) / `hotel`(酒店) |
| timeBudget | number | 时间预算（分钟）：5 / 12 / 20 |
| limitations | string[] | 身体限制：`waist`(腰肌劳损) / `knee`(膝盖不适) / `shoulder`(肩颈僵硬) / `wrist`(手腕不适) |
| equipment | string | 可用装备：`none`(仅徒手) / `mat`(瑜伽垫) / `chair`(椅子) |
| goal | string | 运动目标：`fat-loss`(减脂塑形) / `sedentary`(缓解久坐) / `strength`(增强体能) / `sleep`(改善睡眠) |
| weeklyDays | number | 每周运动天数（2-7） |
| preferredTime | string[] | 偏好时段：`morning`(早晨) / `noon`(午休) / `evening`(晚间) |

**业务逻辑**:
1. 根据 userId 查询数据库中的用户画像
2. 如果用户不存在，返回 404 错误
3. 返回用户画像的完整信息

---

### 1.2 创建用户画像

**接口描述**: 创建新的用户画像

**请求路径**: `/api/v1/users/profile`

**请求方法**: `POST`

**请求头**:
```
Content-Type: application/json
```

**请求体**:
```json
{
  "nickname": "张三",
  "height": 170.0,
  "weight": 65.0,
  "bmi": 22.5,
  "fitnessLevel": "regular",
  "scene": "office",
  "timeBudget": 12,
  "limitations": ["shoulder"],
  "equipment": "mat",
  "goal": "sedentary",
  "weeklyDays": 3,
  "preferredTime": ["morning", "evening"]
}
```

**响应示例**:
```json
{
  "nickname": "张三",
  "height": 170.0,
  "weight": 65.0,
  "bmi": 22.5,
  "fitnessLevel": "regular",
  "scene": "office",
  "timeBudget": 12,
  "limitations": ["shoulder"],
  "equipment": "mat",
  "goal": "sedentary",
  "weeklyDays": 3,
  "preferredTime": ["morning", "evening"]
}
```

**业务逻辑**:
1. 验证请求数据的完整性和合法性
2. 检查 nickname 是否已存在，如果存在则返回错误
3. 将用户画像保存到数据库
4. 触发 AI 生成首日训练计划
5. 返回创建成功的用户画像

---

### 1.3 更新用户画像

**接口描述**: 更新现有用户画像

**请求路径**: `/api/v1/users/profile`

**请求方法**: `PUT`

**请求头**:
```
Content-Type: application/json
```

**请求体**: 同创建用户画像

**响应示例**: 同创建用户画像

**业务逻辑**:
1. 验证请求数据的完整性和合法性
2. 根据 nickname 查找用户
3. 如果用户不存在，返回 404 错误
4. 更新用户画像信息
5. 如果关键信息（如目标、时间预算）发生变化，触发 AI 重新生成训练计划
6. 返回更新后的用户画像

---

## 2. 训练计划相关

### 2.1 获取今日训练计划

**接口描述**: 根据用户画像获取 AI 生成的今日训练计划

**请求路径**: `/api/v1/workouts/today`

**请求方法**: `GET`

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| userId | string | 是 | 用户昵称/ID |
| date | string | 否 | 指定日期（格式：YYYY-MM-DD），默认为今天 |

**请求示例**:
```http
GET /api/v1/workouts/today?userId=zhangsan
```

**响应示例**:
```json
{
  "id": "workout_20240129_zhangsan",
  "title": "今日微动",
  "subtitle": "周二舒压",
  "totalDuration": 12,
  "scene": "办公室场景",
  "rpe": 6,
  "aiNote": "因你昨晚睡眠<6小时，已移除跳跃动作，降低心肺压力",
  "modules": [
    {
      "id": "m1",
      "name": "工位肩颈解放",
      "duration": 3,
      "exercises": [
        {
          "id": "e1",
          "name": "颈部侧拉伸",
          "duration": 45,
          "description": "缓解颈部僵硬，改善血液循环",
          "steps": [
            "坐稳椅面1/3处，脊柱中立",
            "一手扶头侧向轻拉至极限",
            "感受对侧颈部拉伸感",
            "保持自然呼吸，不要憋气"
          ],
          "tips": "避免耸肩，动作轻缓",
          "breathing": "自然呼吸，不要憋气",
          "image": "assets/exercises/exercise-neck.png",
          "targetMuscles": ["颈部", "斜方肌"]
        }
      ]
    }
  ]
}
```

**字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 训练计划唯一标识 |
| title | string | 训练计划标题 |
| subtitle | string | 副标题（如：周一激活、周二舒压等） |
| totalDuration | number | 总时长（分钟） |
| scene | string | 训练场景 |
| rpe | number | 运动强度（1-10） |
| aiNote | string | AI 调整说明（可为空） |
| modules | array | 训练模块列表 |

**Module 字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 模块唯一标识 |
| name | string | 模块名称 |
| duration | number | 模块时长（分钟） |
| exercises | array | 动作列表 |

**Exercise 字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 动作唯一标识 |
| name | string | 动作名称 |
| duration | number | 动作时长（秒） |
| description | string | 动作描述 |
| steps | string[] | 动作步骤 |
| tips | string | 注意事项 |
| breathing | string | 呼吸指导 |
| image | string | 动作图片路径 |
| targetMuscles | string[] | 目标肌肉群 |

**业务逻辑**:
1. 根据 userId 获取用户画像
2. 检查是否已有今日训练计划
3. 如果有，返回缓存计划
4. 如果没有，调用 AI 引擎生成新计划
5. AI 生成逻辑：
   - 根据用户画像（健身等级、场景、时间预算、限制等）选择动作
   - 根据用户目标调整训练重点
   - 根据身体限制排除不适宜动作
   - 根据装备条件选择动作
   - 控制总时长在 timeBudget 范围内
6. 缓存训练计划
7. 返回训练计划

---

### 2.2 刷新训练计划

**接口描述**: 换一组训练计划（今日未完成时）

**请求路径**: `/api/v1/workouts/refresh`

**请求方法**: `GET`

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| userId | string | 是 | 用户昵称/ID |

**请求示例**:
```http
GET /api/v1/workouts/refresh?userId=zhangsan
```

**响应示例**: 同获取今日训练计划

**业务逻辑**:
1. 根据 userId 获取用户画像
2. 检查今日训练是否已完成，如果已完成则不允许刷新
3. 重新调用 AI 引擎生成新计划（使用随机种子确保不同）
4. 更新缓存的训练计划
5. 返回新训练计划

---

## 3. 训练记录相关

### 3.1 获取月度训练记录

**接口描述**: 获取指定月份的训练统计数据

**请求路径**: `/api/v1/records/monthly`

**请求方法**: `GET`

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| userId | string | 是 | 用户昵称/ID |
| year | number | 是 | 年份（如：2024） |
| month | number | 是 | 月份（1-12） |

**请求示例**:
```http
GET /api/v1/records/monthly?userId=zhangsan&year=2024&month=1
```

**响应示例**:
```json
{
  "year": 2024,
  "month": 1,
  "totalMinutes": 85,
  "targetMinutes": 108,
  "completedDays": 5,
  "records": [
    {
      "date": "2024-01-22",
      "dayOfWeek": 1,
      "duration": 12,
      "status": "completed"
    },
    {
      "date": "2024-01-23",
      "dayOfWeek": 2,
      "duration": 15,
      "status": "completed"
    },
    {
      "date": "2024-01-24",
      "dayOfWeek": 3,
      "duration": 8,
      "status": "partial"
    },
    {
      "date": "2024-01-25",
      "dayOfWeek": 4,
      "duration": 0,
      "status": "planned"
    },
    {
      "date": "2024-01-26",
      "dayOfWeek": 5,
      "duration": 0,
      "status": "none"
    }
  ]
}
```

**字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| year | number | 年份 |
| month | number | 月份 |
| totalMinutes | number | 本月累计训练分钟数 |
| targetMinutes | number | 本月目标分钟数（每周天数 × 4 × 时间预算） |
| completedDays | number | 本月已完成天数 |
| records | array | 每日记录列表 |

**DayRecord 字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| date | string | 日期（YYYY-MM-DD） |
| dayOfWeek | number | 星期几（0-6，0=周日） |
| duration | number | 训练时长（分钟） |
| status | string | 状态：`completed`(已完成) / `partial`(部分完成) / `planned`(已计划) / `none`(未安排) |

**业务逻辑**:
1. 根据 userId、year、month 查询训练记录
2. 如果没有记录，返回空数据
3. 计算总时长、目标时长、完成天数
4. 返回月度统计数据

---

## 4. 训练反馈相关

### 4.1 提交训练反馈

**接口描述**: 用户完成训练后提交反馈，AI 根据反馈调整次日计划

**请求路径**: `/api/v1/feedback`

**请求方法**: `POST`

**请求头**:
```
Content-Type: application/json
```

**请求体**:
```json
{
  "userId": "zhangsan",
  "completion": "smooth",
  "feeling": "justRight",
  "tomorrow": "maintain",
  "workoutDuration": 12,
  "workoutDate": "2024-01-29"
}
```

**字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| userId | string | 用户昵称/ID |
| completion | string | 完成度：`tooHard`(太难未完成) / `barely`(勉强完成) / `smooth`(顺利完成) / `easy`(轻松有余力) |
| feeling | string | 身体感受：`uncomfortable`(某部位不适) / `tired`(有点累) / `justRight`(刚刚好) / `energized`(精力充沛) |
| tomorrow | string | 明日状态：`recovery`(需要恢复) / `maintain`(保持即可) / `intensify`(可以提高) |
| workoutDuration | number | 本次训练时长（分钟） |
| workoutDate | string | 训练日期（YYYY-MM-DD） |

**响应示例**:
```json
{
  "success": true,
  "aiAdjustment": "收到！明天已为你调整：\n• 移除跳跃动作\n• 增加腰背拉伸\n• 强度维持RPE 6"
}
```

**业务逻辑**:
1. 保存训练反馈记录
2. 更新当日训练记录状态
3. 调用 AI 分析反馈：
   - 如果 completion 是 `tooHard`，降低次日强度
   - 如果 completion 是 `easy`，适当增加强度
   - 如果 feeling 是 `uncomfortable`，记录不适部位，次日调整动作
   - 如果 tomorrow 是 `recovery`，次日安排恢复性训练
   - 如果 tomorrow 是 `intensify`，次日适当提高强度
4. 生成次日训练计划调整说明
5. 返回 AI 调整建议

---

## 5. 选项配置相关

### 5.1 获取选项配置

**接口描述**: 获取前端 onboarding 页面所需的所有选项配置

**请求路径**: `/api/v1/options`

**请求方法**: `GET`

**请求示例**:
```http
GET /api/v1/options
```

**响应示例**:
```json
{
  "fitnessLevels": [
    {"value": "beginner", "label": "零基础", "icon": "eco", "desc": "很少运动"},
    {"value": "occasional", "label": "偶尔运动", "icon": "eco", "desc": "每周1-2次"},
    {"value": "regular", "label": "规律运动", "icon": "park", "desc": "每周3次以上"}
  ],
  "scenes": [
    {"value": "bed", "label": "床上", "icon": "bed"},
    {"value": "office", "label": "办公室", "icon": "work"},
    {"value": "living", "label": "客厅", "icon": "weekend"},
    {"value": "outdoor", "label": "户外", "icon": "park"},
    {"value": "hotel", "label": "酒店", "icon": "hotel"}
  ],
  "timeOptions": [
    {"value": 5, "label": "3-5分钟", "desc": "快速激活"},
    {"value": 12, "label": "10-15分钟", "desc": "标准训练"},
    {"value": 20, "label": "15-20分钟", "desc": "完整训练"}
  ],
  "limitations": [
    {"value": "waist", "label": "腰肌劳损"},
    {"value": "knee", "label": "膝盖不适"},
    {"value": "shoulder", "label": "肩颈僵硬"},
    {"value": "wrist", "label": "手腕不适"}
  ],
  "equipment": [
    {"value": "none", "label": "仅徒手", "icon": "back_hand"},
    {"value": "mat", "label": "有瑜伽垫", "icon": "self_improvement"},
    {"value": "chair", "label": "有椅子", "icon": "chair"}
  ],
  "goals": [
    {"value": "fat-loss", "label": "减脂塑形", "icon": "local_fire_department", "desc": "燃烧脂肪，塑造线条"},
    {"value": "sedentary", "label": "缓解久坐", "icon": "chair", "desc": "改善久坐不适"},
    {"value": "strength", "label": "增强体能", "icon": "bolt", "desc": "提升身体素质"},
    {"value": "sleep", "label": "改善睡眠", "icon": "bedtime", "desc": "放松身心助眠"}
  ],
  "preferredTimes": [
    {"value": "morning", "label": "早晨", "icon": "wb_sunny"},
    {"value": "noon", "label": "午休", "icon": "free_breakfast"},
    {"value": "evening", "label": "晚间", "icon": "nights_stay"}
  ]
}
```

**业务逻辑**:
1. 返回所有静态配置选项
2. 这些配置通常存储在数据库或配置文件中
3. 可以支持动态更新，无需发版即可调整选项

---

## 错误码说明

### HTTP 状态码

| 状态码 | 说明 |
|--------|------|
| 200 | 请求成功 |
| 400 | 请求参数错误 |
| 404 | 资源不存在 |
| 500 | 服务器内部错误 |

### 错误响应格式

```json
{
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "用户不存在"
  }
}
```

### 常见错误码

| 错误码 | 说明 |
|--------|------|
| USER_NOT_FOUND | 用户不存在 |
| INVALID_PARAMS | 请求参数无效 |
| DUPLICATE_USER | 用户已存在 |
| WORKOUT_COMPLETED | 今日训练已完成，无法刷新 |
| NETWORK_ERROR | 网络连接失败 |
| SERVER_ERROR | 服务器错误 |

---

## 附录

### 数据模型

所有数据模型定义与 Flutter 客户端保持一致，位于 `lib/models/` 目录：

- `user_profile.dart` - 用户画像模型
- `workout.dart` - 训练计划模型
- `exercise.dart` - 动作模型
- `weekly_data.dart` - 训练记录模型
- `feedback.dart` - 训练反馈模型

### 技术栈建议

- **后端框架**: Node.js + Express / Go + Gin / Python + FastAPI
- **数据库**: MongoDB / PostgreSQL
- **AI 引擎**: OpenAI API / 文心一言 / 通义千问
- **缓存**: Redis（可选）

### 测试账号

```
userId: test_user
password: 123456
```
