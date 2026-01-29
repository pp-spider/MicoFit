# MicroFit 数据表结构文档

> 本文档详细描述了MicroFit项目所有数据表的结构、字段定义、约束条件和关系映射。

---

## 目录

- [一、数据表概览](#一数据表概览)
- [二、数据表详细设计](#二数据表详细设计)
- [三、外键关系](#三外键关系)
- [四、索引设计](#四索引设计)
- [五、数据字典](#五数据字典)

---

## 一、数据表概览

### 1.1 ER图

```
┌──────────────────┐
│  users           │ 用户认证表
├──────────────────┤
│ user_id (PK)     │─────┬──────────────────────────────────────┐
│ password_hash    │     │                                      │
│ nickname         │     │                                      │
│ is_active        │     │                                      │
└──────────────────┘     │                                      │
                         │                                      │
┌────────────────────────┼──────────────────────────────────────┼─────────────┐
│                         │                                      │             │
│    ┌────────────────────▼──────────┐      ┌───────────────────▼──────────┐ │
│    │  user_profiles                │      │  workout_plans                │ │
│    ├───────────────────────────────┤      ├──────────────────────────────┤ │
│    │ user_id (PK, FK)             │◄─────│ user_id (FK)                 │ │
│    │ nickname (unique)             │      │ user_nickname                │ │
│    │ height/weight/bmi             │      │ id (PK)                      │ │
│    │ fitness_level                 │      │ date                         │ │
│    │ scene/time_budget             │      │ is_completed                 │ │
│    │ limitations/equipment         │      │ modules (JSON)               │ │
│    │ goal/weekly_days              │      └──────────────────────────────┘ │
│    └───────────────────────────────┘                 │                     │
│                                                         │                     │
│    ┌────────────────────────────────────────────────────┘                     │
│    │                                                                            │
│    │  ┌────────────────────────────────────────────────────────────────────┐  │
│    │  │  workout_records                                                    │  │
│    │  ├────────────────────────────────────────────────────────────────────┤  │
│    │  │ id (PK)                                                            │  │
│    │  │ user_id (FK)                                                       │  │
│    │  │ user_nickname                                                      │  │
│    │  │ workout_id (FK) ──────────────────┐                                │  │
│    │  │ date/status/duration              │                                │  │
│    └──┴────────────────────────────────────┼────────────────────────────────┘  │
│       │                                    │                                   │
│       │                                    │                                   │
│       │  ┌─────────────────────────────────▼──────────────────────────────┐  │
│       │  │  workout_feedbacks                                              │  │
│       │  ├────────────────────────────────────────────────────────────────┤  │
│       │  │ id (PK)                                                        │  │
│       │  │ user_id (FK)                                                   │  │
│       │  │ user_nickname                                                  │  │
│       │  │ workout_id (FK) ───────────────────────────────────────────────┘  │
│       │  │ workout_date/completion/feeling/tomorrow                           │
│       │  │ ai_adjustment                                                     │
│       └──┴────────────────────────────────────────────────────────────────────┘
```

### 1.2 数据表清单

| 序号 | 表名 | 中文名称 | 主键类型 | 说明 |
|------|------|----------|----------|------|
| 1 | `users` | 用户认证表 | 字符串主键 | 存储用户登录认证信息 |
| 2 | `user_profiles` | 用户画像表 | 复合主键 | 存储用户健身画像数据 |
| 3 | `workout_plans` | 训练计划表 | 字符串主键 | 存储AI生成的训练计划 |
| 4 | `workout_records` | 训练记录表 | 自增主键 | 存储用户训练历史记录 |
| 5 | `workout_feedbacks` | 训练反馈表 | 自增主键 | 存储用户训练反馈数据 |

### 1.3 关系概览

| 从表 | 从表字段 | 主表 | 主表字段 | 关系类型 |
|------|----------|------|----------|----------|
| user_profiles | user_id | users | user_id | N:1 (CASCADE) |
| workout_plans | user_id | users | user_id | N:1 (CASCADE) |
| workout_records | user_id | users | user_id | N:1 (CASCADE) |
| workout_feedbacks | user_id | users | user_id | N:1 (CASCADE) |
| workout_records | workout_id | workout_plans | id | N:1 (SET NULL) |
| workout_feedbacks | workout_id | workout_plans | id | N:1 (SET NULL) |

---

## 二、数据表详细设计

### 2.1 users - 用户认证表

#### 2.1.1 表结构

```sql
CREATE TABLE users (
    user_id VARCHAR(100) PRIMARY KEY,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME
);
```

#### 2.1.2 字段说明

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `user_id` | VARCHAR(100) | PRIMARY KEY, NOT NULL | - | 用户唯一标识，与nickname相同 |
| `password_hash` | VARCHAR(255) | NOT NULL | - | Bcrypt加密后的密码哈希 |
| `nickname` | VARCHAR(100) | NOT NULL | - | 用户显示昵称 |
| `is_active` | BOOLEAN | NOT NULL | TRUE | 账号是否激活 |
| `created_at` | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 账号创建时间（UTC） |
| `last_login` | DATETIME | NULLABLE | - | 最后登录时间（UTC） |

#### 2.1.3 索引

| 索引名 | 字段 | 类型 | 说明 |
|--------|------|------|------|
| PRIMARY | user_id | PRIMARY KEY | 主键索引 |

#### 2.1.4 ORM模型

```python
# app/models/auth_user.py
class User(Base):
    __tablename__ = "users"

    user_id: Mapped[str] = mapped_column(String(100), primary_key=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    nickname: Mapped[str] = mapped_column(String(100), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    last_login: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
```

---

### 2.2 user_profiles - 用户画像表

#### 2.2.1 表结构

```sql
CREATE TABLE user_profiles (
    user_id VARCHAR(100) PRIMARY KEY,
    nickname VARCHAR(100) UNIQUE NOT NULL,
    height FLOAT NOT NULL,
    weight FLOAT NOT NULL,
    bmi FLOAT,
    fitness_level VARCHAR(20) NOT NULL DEFAULT 'beginner',
    scene VARCHAR(20) NOT NULL DEFAULT 'living',
    time_budget INTEGER NOT NULL DEFAULT 12,
    limitations JSON NOT NULL DEFAULT '[]',
    equipment VARCHAR(20) NOT NULL DEFAULT 'none',
    goal VARCHAR(20) NOT NULL DEFAULT 'sedentary',
    weekly_days INTEGER NOT NULL DEFAULT 3,
    preferred_time JSON NOT NULL DEFAULT '[]',
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
```

#### 2.2.2 字段说明

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `user_id` | VARCHAR(100) | PRIMARY KEY, FK | - | 用户ID，外键关联users表 |
| `nickname` | VARCHAR(100) | UNIQUE, NOT NULL | - | 用户昵称，唯一索引 |
| `height` | FLOAT | NOT NULL | - | 身高（厘米） |
| `weight` | FLOAT | NOT NULL | - | 体重（公斤） |
| `bmi` | FLOAT | NULLABLE | - | BMI指数（自动计算） |
| `fitness_level` | VARCHAR(20) | NOT NULL | 'beginner' | 健身等级 |
| `scene` | VARCHAR(20) | NOT NULL | 'living' | 训练场景 |
| `time_budget` | INTEGER | NOT NULL | 12 | 时间预算（分钟） |
| `limitations` | JSON | NOT NULL | '[]' | 身体限制列表 |
| `equipment` | VARCHAR(20) | NOT NULL | 'none' | 装备类型 |
| `goal` | VARCHAR(20) | NOT NULL | 'sedentary' | 训练目标 |
| `weekly_days` | INTEGER | NOT NULL | 3 | 每周运动天数 |
| `preferred_time` | JSON | NOT NULL | '[]' | 偏好时段列表 |

#### 2.2.3 枚举值说明

**fitness_level（健身等级）**
| 值 | 说明 |
|----|------|
| `beginner` | 健身新手，很少运动 |
| `occasional` | 偶尔运动，每周1-2次 |
| `regular` | 经常运动，每周3次以上 |

**scene（训练场景）**
| 值 | 说明 |
|----|------|
| `bed` | 床上场景 |
| `office` | 办公室场景 |
| `living` | 客厅场景 |
| `outdoor` | 户外场景 |
| `hotel` | 酒店场景 |

**time_budget（时间预算）**
| 值 | 说明 |
|----|------|
| 5 | 5分钟快速训练 |
| 12 | 12分钟标准训练 |
| 20 | 20分钟完整训练 |

**limitations（身体限制）**
| 值 | 说明 |
|----|------|
| `waist` | 腰部限制 |
| `knee` | 膝盖限制 |
| `shoulder` | 肩部限制 |
| `wrist` | 手腕限制 |

**equipment（装备类型）**
| 值 | 说明 |
|----|------|
| `none` | 无器械 |
| `mat` | 瑜伽垫 |
| `chair` | 椅子 |

**goal（训练目标）**
| 值 | 说明 |
|----|------|
| `fat-loss` | 减脂塑形 |
| `sedentary` | 久坐缓解 |
| `strength` | 增强体能 |
| `sleep` | 助眠放松 |

**preferred_time（偏好时段）**
| 值 | 说明 |
|----|------|
| `morning` | 早晨 |
| `noon` | 中午 |
| `afternoon` | 下午 |
| `evening` | 晚上 |
| `night` | 深夜 |

#### 2.2.4 索引

| 索引名 | 字段 | 类型 | 说明 |
|--------|------|------|------|
| PRIMARY | user_id | PRIMARY KEY | 主键索引 |
| idx_nickname | nickname | UNIQUE | 昵称唯一索引 |

#### 2.2.5 ORM模型

```python
# app/models/user.py
class UserProfile(Base):
    __tablename__ = "user_profiles"

    user_id: Mapped[str] = mapped_column(
        String(100), ForeignKey("users.user_id", ondelete="CASCADE"), primary_key=True
    )
    nickname: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    height: Mapped[float] = mapped_column(Float, nullable=False)
    weight: Mapped[float] = mapped_column(Float, nullable=False)
    bmi: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    fitness_level: Mapped[str] = mapped_column(String(20), nullable=False, default="beginner")
    scene: Mapped[str] = mapped_column(String(20), nullable=False, default="living")
    time_budget: Mapped[int] = mapped_column(Integer, nullable=False, default=12)
    limitations: Mapped[List[str]] = mapped_column(JSON, nullable=False, default=list)
    equipment: Mapped[str] = mapped_column(String(20), nullable=False, default="none")
    goal: Mapped[str] = mapped_column(String(20), nullable=False, default="sedentary")
    weekly_days: Mapped[int] = mapped_column(Integer, nullable=False, default=3)
    preferred_time: Mapped[List[str]] = mapped_column(JSON, nullable=False, default=list)
```

---

### 2.3 workout_plans - 训练计划表

#### 2.3.1 表结构

```sql
CREATE TABLE workout_plans (
    id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(100) NOT NULL,
    user_nickname VARCHAR(100) NOT NULL,
    title VARCHAR(100) NOT NULL DEFAULT '今日微动',
    subtitle VARCHAR(100),
    total_duration INTEGER NOT NULL,
    scene VARCHAR(50),
    rpe INTEGER NOT NULL DEFAULT 6,
    ai_note VARCHAR(500),
    modules JSON NOT NULL DEFAULT '[]',
    date VARCHAR(10) NOT NULL,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    is_refreshed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
```

#### 2.3.2 字段说明

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `id` | VARCHAR(100) | PRIMARY KEY | - | 计划唯一标识，格式：workout_日期_用户昵称 |
| `user_id` | VARCHAR(100) | FK, NOT NULL | - | 用户ID，外键关联users表 |
| `user_nickname` | VARCHAR(100) | NOT NULL | - | 用户昵称（保留用于查询兼容） |
| `title` | VARCHAR(100) | NOT NULL | '今日微动' | 计划标题 |
| `subtitle` | VARCHAR(100) | NULLABLE | - | 计划副标题（根据星期几生成） |
| `total_duration` | INTEGER | NOT NULL | - | 总训练时长（分钟） |
| `scene` | VARCHAR(50) | NULLABLE | - | 训练场景名称 |
| `rpe` | INTEGER | NOT NULL | 6 | 运动强度（1-10级） |
| `ai_note` | VARCHAR(500) | NULLABLE | - | AI调整说明 |
| `modules` | JSON | NOT NULL | '[]' | 训练模块列表（详细结构见下文） |
| `date` | VARCHAR(10) | NOT NULL | - | 训练日期，格式：YYYY-MM-DD |
| `is_completed` | BOOLEAN | NOT NULL | FALSE | 是否已完成 |
| `is_refreshed` | BOOLEAN | NOT NULL | FALSE | 是否刷新过 |
| `created_at` | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 创建时间 |
| `updated_at` | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 更新时间 |

#### 2.3.3 modules JSON结构

```json
{
  "modules": [
    {
      "id": "m1",
      "name": "综合训练",
      "duration": 12,
      "exercises": [
        {
          "id": "ex_neck",
          "name": "颈部侧拉伸",
          "duration": 45,
          "description": "缓解颈部僵硬，改善血液循环",
          "steps": ["步骤1", "步骤2", "步骤3", "步骤4"],
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

#### 2.3.4 RPE强度对照表

| fitness_level | RPE值 | 说明 |
|---------------|-------|------|
| beginner | 4 | 新手强度 |
| occasional | 6 | 中等强度 |
| regular | 7 | 进阶强度 |

#### 2.3.5 星期副标题映射

| 星期 | weekday | subtitle |
|------|---------|----------|
| 周一 | 0 | 周一激活 |
| 周二 | 1 | 周二舒压 |
| 周三 | 2 | 周三强化 |
| 周四 | 3 | 周四调整 |
| 周五 | 4 | 周五冲刺 |
| 周六 | 5 | 周六恢复 |
| 周日 | 6 | 周日充电 |

#### 2.3.6 索引

| 索引名 | 字段 | 类型 | 说明 |
|--------|------|------|------|
| PRIMARY | id | PRIMARY KEY | 主键索引 |
| idx_user_date | user_id, date | COMPOSITE | 用户日期复合索引 |
| idx_user_nickname | user_nickname | INDEX | 用户昵称索引（兼容） |

#### 2.3.7 ORM模型

```python
# app/models/workout.py
class WorkoutPlan(Base):
    __tablename__ = "workout_plans"

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(100), ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False
    )
    user_nickname: Mapped[str] = mapped_column(String(100), nullable=False)
    title: Mapped[str] = mapped_column(String(100), nullable=False, default="今日微动")
    subtitle: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    total_duration: Mapped[int] = mapped_column(Integer, nullable=False)
    scene: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    rpe: Mapped[int] = mapped_column(Integer, nullable=False, default=6)
    ai_note: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    modules: Mapped[List[dict]] = mapped_column(JSON, nullable=False, default=list)
    date: Mapped[str] = mapped_column(String(10), nullable=False)
    is_completed: Mapped[bool] = mapped_column(Integer, nullable=False, default=False)
    is_refreshed: Mapped[bool] = mapped_column(Integer, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )
```

---

### 2.4 workout_records - 训练记录表

#### 2.4.1 表结构

```sql
CREATE TABLE workout_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id VARCHAR(100) NOT NULL,
    user_nickname VARCHAR(100) NOT NULL,
    workout_id VARCHAR(100),
    date VARCHAR(10) NOT NULL,
    day_of_week INTEGER NOT NULL,
    duration INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'planned',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (workout_id) REFERENCES workout_plans(id) ON DELETE SET NULL
);
```

#### 2.4.2 字段说明

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `id` | INTEGER | PRIMARY KEY, AUTO | - | 自增主键 |
| `user_id` | VARCHAR(100) | FK, NOT NULL | - | 用户ID，外键关联users表 |
| `user_nickname` | VARCHAR(100) | NOT NULL | - | 用户昵称（保留用于查询兼容） |
| `workout_id` | VARCHAR(100) | FK, NULLABLE | - | 训练计划ID，外键关联workout_plans表 |
| `date` | VARCHAR(10) | NOT NULL | - | 训练日期，格式：YYYY-MM-DD |
| `day_of_week` | INTEGER | NOT NULL | - | 星期几，0=周一，6=周日 |
| `duration` | INTEGER | NOT NULL | 0 | 训练时长（分钟） |
| `status` | VARCHAR(20) | NOT NULL | 'planned' | 训练状态 |
| `created_at` | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 创建时间 |
| `updated_at` | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 更新时间 |

#### 2.4.3 status（训练状态）枚举

| 值 | 说明 | 触发条件 |
|----|------|----------|
| `completed` | 已完成 | 反馈completion为smooth或easy |
| `partial` | 部分完成 | 反馈completion为tooHard或barely |
| `planned` | 已计划 | 创建训练计划时 |
| `none` | 无训练 | 无训练记录 |

#### 2.4.4 索引

| 索引名 | 字段 | 类型 | 说明 |
|--------|------|------|------|
| PRIMARY | id | PRIMARY KEY | 主键索引 |
| idx_user_date | user_id, date | COMPOSITE | 用户日期复合索引 |
| idx_workout_id | workout_id | INDEX | 训练计划索引 |

#### 2.4.5 ORM模型

```python
# app/models/record.py
class WorkoutRecord(Base):
    __tablename__ = "workout_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(100), ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False
    )
    user_nickname: Mapped[str] = mapped_column(String(100), nullable=False)
    workout_id: Mapped[Optional[str]] = mapped_column(
        String(100), ForeignKey("workout_plans.id", ondelete="SET NULL"), nullable=True
    )
    date: Mapped[str] = mapped_column(String(10), nullable=False)
    day_of_week: Mapped[int] = mapped_column(Integer, nullable=False)
    duration: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="planned")
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )
```

---

### 2.5 workout_feedbacks - 训练反馈表

#### 2.5.1 表结构

```sql
CREATE TABLE workout_feedbacks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id VARCHAR(100) NOT NULL,
    user_nickname VARCHAR(100) NOT NULL,
    workout_id VARCHAR(100),
    workout_date VARCHAR(10) NOT NULL,
    workout_duration INTEGER NOT NULL,
    completion VARCHAR(20) NOT NULL,
    feeling VARCHAR(20) NOT NULL,
    tomorrow VARCHAR(20) NOT NULL,
    ai_adjustment VARCHAR(500),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (workout_id) REFERENCES workout_plans(id) ON DELETE SET NULL
);
```

#### 2.5.2 字段说明

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `id` | INTEGER | PRIMARY KEY, AUTO | - | 自增主键 |
| `user_id` | VARCHAR(100) | FK, NOT NULL | - | 用户ID，外键关联users表 |
| `user_nickname` | VARCHAR(100) | NOT NULL | - | 用户昵称（保留用于查询兼容） |
| `workout_id` | VARCHAR(100) | FK, NULLABLE | - | 训练计划ID，外键关联workout_plans表 |
| `workout_date` | VARCHAR(10) | NOT NULL | - | 训练日期，格式：YYYY-MM-DD |
| `workout_duration` | INTEGER | NOT NULL | - | 训练时长（分钟） |
| `completion` | VARCHAR(20) | NOT NULL | - | 完成度评价 |
| `feeling` | VARCHAR(20) | NOT NULL | - | 训练感受 |
| `tomorrow` | VARCHAR(20) | NOT NULL | - | 明日状态期望 |
| `ai_adjustment` | VARCHAR(500) | NULLABLE | - | AI调整建议 |
| `created_at` | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 反馈提交时间 |

#### 2.5.3 completion（完成度）枚举

| 值 | 说明 | 对应状态 | AI调整 |
|----|------|----------|--------|
| `tooHard` | 太难 | partial | 降低强度，减少动作组数 |
| `barely` | 勉强完成 | partial | 保持当前 |
| `smooth` | 顺利完成 | completed | 保持当前 |
| `easy` | 太轻松 | completed | 适当增加动作时长 |

#### 2.5.4 feeling（感受）枚举

| 值 | 说明 | AI调整 |
|----|------|--------|
| `uncomfortable` | 不舒服 | 明日增加拉伸放松 |
| `tired` | 疲惫 | 安排休息 |
| `justRight` | 刚好 | 保持计划 |
| `energized` | 充满活力 | 保持当前训练节奏 |

#### 2.5.5 tomorrow（明日状态）枚举

| 值 | 说明 | AI调整 |
|----|------|--------|
| `recovery` | 需要恢复 | 安排恢复性训练 |
| `maintain` | 保持强度 | 保持当前 |
| `intensify` | 增加强度 | 适当提高训练强度 |

#### 2.5.6 AI调整响应生成逻辑

```
调整建议 = "收到！明天已为你调整：\n"

IF completion == "tooHard":
    调整建议 += "• 降低强度，减少动作组数\n"
ELIF completion == "easy":
    调整建议 += "• 适当增加动作时长\n"

IF feeling == "uncomfortable":
    调整建议 += "• 明日增加拉伸放松\n"
ELIF feeling == "energized":
    调整建议 += "• 保持当前训练节奏\n"

IF tomorrow == "recovery":
    调整建议 += "• 安排恢复性训练\n"
ELIF tomorrow == "intensify":
    调整建议 += "• 适当提高训练强度\n"

IF 无任何调整:
    调整建议 += "• 保持当前训练计划"
```

#### 2.5.7 索引

| 索引名 | 字段 | 类型 | 说明 |
|--------|------|------|------|
| PRIMARY | id | PRIMARY KEY | 主键索引 |
| idx_user_date | user_id, workout_date | COMPOSITE | 用户日期复合索引 |
| idx_workout_id | workout_id | INDEX | 训练计划索引 |

#### 2.5.8 ORM模型

```python
# app/models/feedback.py
class WorkoutFeedback(Base):
    __tablename__ = "workout_feedbacks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(100), ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False
    )
    user_nickname: Mapped[str] = mapped_column(String(100), nullable=False)
    workout_id: Mapped[Optional[str]] = mapped_column(
        String(100), ForeignKey("workout_plans.id", ondelete="SET NULL"), nullable=True
    )
    workout_date: Mapped[str] = mapped_column(String(10), nullable=False)
    workout_duration: Mapped[int] = mapped_column(Integer, nullable=False)
    completion: Mapped[str] = mapped_column(String(20), nullable=False)
    feeling: Mapped[str] = mapped_column(String(20), nullable=False)
    tomorrow: Mapped[str] = mapped_column(String(20), nullable=False)
    ai_adjustment: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
```

---

## 三、外键关系

### 3.1 外键汇总

| 外键名称 | 从表 | 从表字段 | 主表 | 主表字段 | ON DELETE |
|----------|------|----------|------|----------|-----------|
| fk_user_profiles_user_id | user_profiles | user_id | users | user_id | CASCADE |
| fk_workout_plans_user_id | workout_plans | user_id | users | user_id | CASCADE |
| fk_workout_records_user_id | workout_records | user_id | users | user_id | CASCADE |
| fk_workout_feedbacks_user_id | workout_feedbacks | user_id | users | user_id | CASCADE |
| fk_workout_records_workout_id | workout_records | workout_id | workout_plans | id | SET NULL |
| fk_workout_feedbacks_workout_id | workout_feedbacks | workout_id | workout_plans | id | SET NULL |

### 3.2 级联规则说明

**CASCADE（级联删除）**
- 当删除 `users` 表中的记录时，自动删除以下关联记录：
  - `user_profiles` 对应的用户画像
  - `workout_plans` 对应的训练计划
  - `workout_records` 对应的训练记录
  - `workout_feedbacks` 对应的训练反馈

**SET NULL（设为空）**
- 当删除 `workout_plans` 表中的记录时：
  - `workout_records.workout_id` 设为 NULL
  - `workout_feedbacks.workout_id` 设为 NULL
  - 记录本身不会被删除，只是失去了关联的训练计划

### 3.3 关系图

```
users (1) ──┬──> (N) user_profiles
            ├──> (N) workout_plans ──┬──> (N) workout_records
            ├──> (N) workout_records │     └──> (N) workout_feedbacks
            └──> (N) workout_feedbacks
```

---

## 四、索引设计

### 4.1 索引汇总

| 表名 | 索引名 | 索引字段 | 索引类型 | 说明 |
|------|--------|----------|----------|------|
| users | PRIMARY | user_id | PRIMARY KEY | 主键索引 |
| user_profiles | PRIMARY | user_id | PRIMARY KEY | 主键索引 |
| user_profiles | idx_nickname | nickname | UNIQUE | 昵称唯一索引 |
| workout_plans | PRIMARY | id | PRIMARY KEY | 主键索引 |
| workout_plans | idx_user_date | user_id, date | COMPOSITE | 用户日期查询优化 |
| workout_plans | idx_user_nickname | user_nickname | INDEX | 兼容查询 |
| workout_records | PRIMARY | id | PRIMARY KEY | 主键索引 |
| workout_records | idx_user_date | user_id, date | COMPOSITE | 用户日期查询优化 |
| workout_records | idx_workout_id | workout_id | INDEX | 训练计划关联查询 |
| workout_feedbacks | PRIMARY | id | PRIMARY KEY | 主键索引 |
| workout_feedbacks | idx_user_date | user_id, workout_date | COMPOSITE | 用户日期查询优化 |
| workout_feedbacks | idx_workout_id | workout_id | INDEX | 训练计划关联查询 |

### 4.2 索引使用场景

**复合索引 idx_user_date**
- 用于查询特定用户在特定日期范围内的记录
- 查询示例：`SELECT * FROM workout_plans WHERE user_id = ? AND date >= ? AND date <= ?`
- 覆盖场景：月度记录查询、训练计划查询

**唯一索引 idx_nickname**
- 保证用户昵称唯一性
- 用于通过昵称快速查找用户画像

---

## 五、数据字典

### 5.1 通用字段

| 字段名 | 类型 | 说明 | 使用范围 |
|--------|------|------|----------|
| `id` | INTEGER/VARCHAR | 主键标识 | 所有表 |
| `user_id` | VARCHAR(100) | 用户唯一标识 | 关联表 |
| `user_nickname` | VARCHAR(100) | 用户昵称 | 关联表（兼容） |
| `created_at` | DATETIME | 创建时间（UTC） | 事务表 |
| `updated_at` | DATETIME | 更新时间（UTC） | 事务表 |

### 5.2 JSON字段

| 表名 | 字段名 | 数据结构 | 说明 |
|--------|--------|----------|------|
| user_profiles | limitations | `string[]` | 身体限制列表 |
| user_profiles | preferred_time | `string[]` | 偏好时段列表 |
| workout_plans | modules | `Module[]` | 训练模块嵌套结构 |

### 5.3 时间格式

| 字段名 | 格式 | 示例 | 说明 |
|--------|------|------|------|
| date | YYYY-MM-DD | 2024-01-15 | 训练日期 |
| created_at | ISO 8601 | 2024-01-15T10:30:00Z | UTC时间戳 |
| updated_at | ISO 8601 | 2024-01-15T10:30:00Z | UTC时间戳 |

### 5.4 状态值映射

**训练记录状态（status）**
| 状态值 | 中文 | 来源 |
|--------|------|------|
| completed | 已完成 | feedback.completion ∈ {smooth, easy} |
| partial | 部分完成 | feedback.completion ∈ {tooHard, barely} |
| planned | 已计划 | 创建训练计划时 |
| none | 无训练 | 无记录时 |

---

## 附录

### A. 数据库初始化SQL

```sql
-- 用户认证表
CREATE TABLE users (
    user_id VARCHAR(100) PRIMARY KEY,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME
);

-- 用户画像表
CREATE TABLE user_profiles (
    user_id VARCHAR(100) PRIMARY KEY,
    nickname VARCHAR(100) UNIQUE NOT NULL,
    height REAL NOT NULL,
    weight REAL NOT NULL,
    bmi REAL,
    fitness_level VARCHAR(20) NOT NULL DEFAULT 'beginner',
    scene VARCHAR(20) NOT NULL DEFAULT 'living',
    time_budget INTEGER NOT NULL DEFAULT 12,
    limitations JSON NOT NULL DEFAULT '[]',
    equipment VARCHAR(20) NOT NULL DEFAULT 'none',
    goal VARCHAR(20) NOT NULL DEFAULT 'sedentary',
    weekly_days INTEGER NOT NULL DEFAULT 3,
    preferred_time JSON NOT NULL DEFAULT '[]',
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX idx_user_profiles_nickname ON user_profiles(nickname);

-- 训练计划表
CREATE TABLE workout_plans (
    id VARCHAR(100) PRIMARY KEY,
    user_id VARCHAR(100) NOT NULL,
    user_nickname VARCHAR(100) NOT NULL,
    title VARCHAR(100) NOT NULL DEFAULT '今日微动',
    subtitle VARCHAR(100),
    total_duration INTEGER NOT NULL,
    scene VARCHAR(50),
    rpe INTEGER NOT NULL DEFAULT 6,
    ai_note VARCHAR(500),
    modules JSON NOT NULL DEFAULT '[]',
    date VARCHAR(10) NOT NULL,
    is_completed BOOLEAN NOT NULL DEFAULT 0,
    is_refreshed BOOLEAN NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX idx_workout_plans_user_date ON workout_plans(user_id, date);

-- 训练记录表
CREATE TABLE workout_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id VARCHAR(100) NOT NULL,
    user_nickname VARCHAR(100) NOT NULL,
    workout_id VARCHAR(100),
    date VARCHAR(10) NOT NULL,
    day_of_week INTEGER NOT NULL,
    duration INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'planned',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (workout_id) REFERENCES workout_plans(id) ON DELETE SET NULL
);

CREATE INDEX idx_workout_records_user_date ON workout_records(user_id, date);

-- 训练反馈表
CREATE TABLE workout_feedbacks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id VARCHAR(100) NOT NULL,
    user_nickname VARCHAR(100) NOT NULL,
    workout_id VARCHAR(100),
    workout_date VARCHAR(10) NOT NULL,
    workout_duration INTEGER NOT NULL,
    completion VARCHAR(20) NOT NULL,
    feeling VARCHAR(20) NOT NULL,
    tomorrow VARCHAR(20) NOT NULL,
    ai_adjustment VARCHAR(500),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (workout_id) REFERENCES workout_plans(id) ON DELETE SET NULL
);

CREATE INDEX idx_workout_feedbacks_user_date ON workout_feedbacks(user_id, workout_date);
```

### B. 修改记录

| 版本 | 日期 | 修改内容 | 修改人 |
|------|------|----------|--------|
| 1.0 | 2026-01-29 | 初始版本，建立完整外键关系 | System |

---

*文档生成时间: 2026-01-29*
*数据库类型: SQLite*
*ORM框架: SQLAlchemy 2.0.35*
*项目版本: 1.0.0*
