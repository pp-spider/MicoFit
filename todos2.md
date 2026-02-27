# MicoFit AI Agent 架构修正方案

## 背景

当前后端AI架构存在以下核心问题：
1. **接口未单一暴露**：前端需要选择调用 `/chat/stream` 或 `/workouts/generate/stream`
2. **两个Agent没有协同**：ChatAgent 和 WorkoutAgent 完全独立，ChatAgent 不会调用 WorkoutAgent
3. **提示词大量重复**：两个Agent共用 `_get_workout_generation_prompt()` 等重复内容
4. **计划生成无统一验证**：ChatAgent 能生成计划但没有完整验证逻辑

---

## 目标

1. 统一前端AI接口为单一入口 `/api/v1/ai/chat/stream`
2. 实现 ChatAgent 作为主Agent，WorkoutAgent 作为子服务的协同架构
3. 移除重复提示词，优化Token使用
4. 所有训练计划必须经过 WorkoutAgent 的验证流程

---

## 修正方案详情

### 第一阶段：后端接口整合

#### 1.1 保留单一对外接口

**保留**:
- `POST /api/v1/ai/chat/stream` - 流式聊天（唯一AI对话入口）
- `POST /api/v1/ai/chat/continue` - 继续流式生成

**废弃**（改为内部调用）:
- `POST /api/v1/ai/workouts/generate/stream` → 改为 ChatAgent 内部调用
- `POST /api/v1/ai/workouts/generate` → 改为 ChatAgent 内部调用

#### 1.2 ChatAgent 集成 WorkoutAgent 调用

修改 `backend/app/agents/chat_agent.py`：

```python
class ChatAgent:
    def __init__(self):
        self.llm = ChatOpenAI(...)
        self.workout_agent = WorkoutAgent()  # 新增：持有WorkoutAgent实例

    async def _should_generate_workout(self, user_message: str) -> bool:
        """意图识别：判断是否需要生成训练计划"""
        # 使用简单的关键词匹配或LLM判断
        workout_keywords = [
            "生成计划", "今日训练", "练什么", "给我计划",
            "训练方案", "锻炼计划", "今天练", "推荐动作"
        ]
        return any(kw in user_message.lower() for kw in workout_keywords)

    async def chat_stream(self, ...):
        # 判断是否需要生成计划
        if await self._should_generate_workout(user_message):
            # 调用WorkoutAgent生成计划
            async for chunk in self._generate_workout_via_agent(
                user_id, user_profile
            ):
                yield chunk
        else:
            # 普通对话
            async for chunk in self._normal_chat(...):
                yield chunk

    async def _generate_workout_via_agent(
        self, user_id: str, user_profile: dict
    ) -> AsyncGenerator[dict, None]:
        """通过WorkoutAgent生成计划"""
        # 1. 先发送文本说明
        yield {"type": "chunk", "content": "正在为您生成今日训练计划...\n\n"}

        # 2. 调用WorkoutAgent
        plan_result = None
        async for chunk in self.workout_agent.generate(user_id, user_profile):
            if chunk["type"] == "plan":
                plan_result = chunk["plan"]
            elif chunk["type"] == "error":
                yield chunk
                return

        # 3. 包装结果返回
        if plan_result:
            # 生成友好说明
            description = self._build_plan_description(plan_result)
            yield {"type": "chunk", "content": description}
            yield {"type": "plan", "plan": plan_result}

        yield {"type": "done", "has_plan": plan_result is not None}

    def _build_plan_description(self, plan: dict) -> str:
        """构建计划的友好描述"""
        return f"""
💪 **{plan['title']}** - {plan['subtitle']}

⏱️ 总时长：{plan['total_duration']}分钟
📍 场景：{plan['scene']}
🔥 强度：RPE {plan['rpe']}/10

包含 {len(plan['modules'])} 个训练模块...
"""
```

#### 1.3 修改提示词去除重复

修改 `backend/app/agents/prompts.py`：

```python
# 1. 提取共用基础提示词
def _get_base_prompt(user_profile: dict | None) -> str:
    """共用基础提示词组件"""
    buffer = []
    buffer.append("你是微动MicoFit的专属AI健身教练。")
    buffer.append("你的职责是为用户提供专业的健身建议、训练指导和健康咨询。")
    buffer.append("")

    if user_profile:
        buffer.append("---")
        buffer.append("**用户画像信息**")
        buffer.append(f"- 昵称：{user_profile.get('nickname', '用户')}")
        buffer.append(f"- 健身水平：{_get_fitness_level_label(user_profile.get('fitness_level', ''))}")
        buffer.append(f"- 目标：{_get_goal_label(user_profile.get('goal', ''))}")
        buffer.append(f"- 场景：{_get_scene_label(user_profile.get('scene', ''))}")
        buffer.append(f"- 时间预算：{user_profile.get('time_budget', 12)}分钟")
        buffer.append("---")
        buffer.append("")

    return "\n".join(buffer)


# 2. ChatAgent 专用提示词（移除计划生成内容）
def build_system_prompt(
    user_profile: dict | None = None,
    context_summary: str | None = None,
    recent_memories: list[str] | None = None
) -> str:
    """ChatAgent系统提示词 - 专注于对话"""
    buffer = []

    # 基础信息
    buffer.append(_get_base_prompt(user_profile))

    # 上下文摘要
    if context_summary:
        buffer.append("**对话上下文摘要**")
        buffer.append(context_summary)
        buffer.append("")

    # 近期记忆
    if recent_memories:
        buffer.append("**近期重要信息**")
        for memory in recent_memories:
            buffer.append(f"• {memory}")
        buffer.append("")

    # 回复要求（仅对话相关）
    buffer.append("回复要求：")
    buffer.append("1. 专业但易懂，避免过于专业的术语")
    buffer.append("2. 基于用户画像信息给出针对性建议")
    buffer.append("3. 如果涉及伤病，提醒用户咨询医生")
    buffer.append("4. 保持友好鼓励的语气")
    buffer.append("5. 回复简洁有力，重点突出")
    buffer.append("6. 使用emoji适当点缀")
    buffer.append("")

    # 重要：说明计划生成功能已内置
    buffer.append("**注意**：当用户需要训练计划时，系统会自动调用专门的计划生成服务。")
    buffer.append("你只需正常对话，计划生成会在后台自动完成。")

    return "\n".join(buffer)


# 3. WorkoutAgent 专用提示词（保持不变）
def build_workout_system_prompt(user_profile: dict | None = None) -> str:
    """WorkoutAgent系统提示词 - 专注于计划生成"""
    buffer = []

    buffer.append(_get_base_prompt(user_profile))

    # 计划生成专用指导
    buffer.append(_get_workout_generation_prompt())

    return "\n".join(buffer)
```

---

### 第二阶段：前端适配修改

#### 2.1 废弃独立计划生成接口调用

修改 `lib/services/ai_api_service.dart`：

```dart
class AIApiService {
  // ✅ 保留 - 唯一AI接口
  Stream<AIStreamChunk> sendMessageStream({
    String? sessionId,
    required String message,
  }) async* {
    // 调用 /api/v1/ai/chat/stream
  }

  // ✅ 保留 - 断点续传
  Stream<AIStreamChunk> continueStream({...}) async* {...}

  // ❌ 废弃 - 不再直接调用
  // Stream<AIStreamChunk> generateWorkoutPlanStream({...})
  // 改为通过 sendMessageStream 发送"生成计划"消息

  // 如果需要生成计划，统一使用：
  // sendMessageStream(message: "请为我生成今日训练计划")
}
```

#### 2.2 更新 AIEnhancedService

修改 `lib/services/ai_enhanced_service.dart`：

```dart
class AIEnhancedService {
  // 移除 generateWorkoutPlanWithCache 方法
  // 所有AI交互统一通过 sendMessageStreamWithRetry

  Stream<AIStreamChunk> sendMessageStreamWithRetry({
    String? sessionId,
    required String message,
    List<Map<String, dynamic>>? contextMessages,
  }) async* {
    // 统一使用聊天接口
    // 如果要生成计划，message 应该是"生成计划"类消息
  }

  // 如果需要显式生成计划，提供便捷方法
  Stream<AIStreamChunk> generateWorkoutPlan({
    Map<String, dynamic>? preferences,
  }) async* {
    // 构建自然语言消息
    final message = _buildPlanRequestMessage(preferences);

    yield* sendMessageStreamWithRetry(
      message: message,
    );
  }

  String _buildPlanRequestMessage(Map<String, dynamic>? prefs) {
    final buffer = StringBuffer("请为我生成今日训练计划");

    if (prefs != null) {
      if (prefs['scene'] != null) {
        buffer.write("，场景：${prefs['scene']}");
      }
      if (prefs['time_budget'] != null) {
        buffer.write("，时间：${prefs['time_budget']}分钟");
      }
      if (prefs['focus'] != null) {
        buffer.write("，重点：${prefs['focus']}");
      }
    }

    return buffer.toString();
  }
}
```

#### 2.3 修改前端页面调用

修改 `lib/pages/ai_chat_page.dart` 中的快捷提示：

```dart
// 快捷问题列表
final List<String> _quickQuestions = [
  '今天适合什么训练？',  // 触发计划生成
  '如何缓解运动后的疲劳？',  // 普通对话
  '有什么减脂建议吗？',  // 普通对话
  '我想增强核心力量',  // 可以触发计划生成
];

// 点击快捷提示时
void _onQuickPromptTap(String prompt) {
  // 统一使用 sendMessage，无需判断类型
  _chatProvider.sendMessage(prompt);
}
```

---

### 第三阶段：AIService 后端编排层修改

修改 `backend/app/services/ai_service.py`：

```python
class AIService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.chat_agent = ChatAgent()  # ChatAgent 已集成 WorkoutAgent
        # self.workout_agent = WorkoutAgent()  # 移除独立持有

    async def stream_chat(self, user_id: str, session_id: str | None, message: str):
        """统一流式聊天入口"""
        # 所有逻辑都在 ChatAgent 内部处理
        async for chunk in self.chat_agent.chat_stream(
            user_id=user_id,
            session_id=session_id,
            user_message=message,
            user_profile=profile_dict,
            history=history_dicts,
            context_summary=context.get("summary"),
            recent_memories=recent_memories
        ):
            # ChatAgent 已经处理了计划生成逻辑
            if chunk["type"] == "plan":
                # 保存到数据库
                plan_record = await self.workout_service.create_plan(...)
                chunk["plan"]["id"] = str(plan_record.id)
                chunk["plan_id"] = str(plan_record.id)

            yield chunk

    # 移除 stream_generate_workout_plan 方法
    # 计划生成统一通过 stream_chat 触发
```

---

### 第四阶段：API路由简化

修改 `backend/app/api/v1/ai.py`：

```python
router = APIRouter(prefix="/ai", tags=["AI"])

# ✅ 保留 - 唯一AI对话接口
@router.post("/chat/stream")
async def chat_stream(...): ...

# ✅ 保留
@router.post("/chat/continue")
async def chat_continue(...): ...

# ❌ 移除以下独立接口（改为内部调用）
# @router.post("/workouts/generate/stream")
# @router.post("/workouts/generate")

# 保留查询类接口
@router.get("/chat/sessions/{session_id}/context")
@router.get("/chat/user-memory")
# ... 其他查询接口
```

---

## 实施步骤

### 步骤1：后端提示词重构（低风险）
- [ ] 修改 `prompts.py`，提取 `_get_base_prompt`
- [ ] 修改 `build_system_prompt`，移除计划生成内容
- [ ] 测试 ChatAgent 对话功能

### 步骤2：ChatAgent 集成 WorkoutAgent（中等风险）
- [ ] 修改 `chat_agent.py`，添加 `WorkoutAgent` 实例
- [ ] 实现 `_should_generate_workout` 意图识别
- [ ] 实现 `_generate_workout_via_agent` 方法
- [ ] 测试计划生成流程

### 步骤3：AIService 简化（中等风险）
- [ ] 移除独立的 `workout_agent` 持有
- [ ] 简化 `stream_chat` 方法
- [ ] 移除 `stream_generate_workout_plan` 方法
- [ ] 测试整体流程

### 步骤4：API路由清理（低风险）
- [ ] 移除 `/workouts/generate/stream` 路由
- [ ] 移除 `/workouts/generate` 路由
- [ ] 更新 API 文档

### 步骤5：前端适配（中等风险）
- [ ] 修改 `AIApiService`，移除 `generateWorkoutPlanStream`
- [ ] 修改 `AIEnhancedService`，统一使用 `sendMessageStreamWithRetry`
- [ ] 修改调用页面，统一使用聊天接口
- [ ] 测试前端功能

---

## 风险与回滚方案

| 风险点 | 影响 | 回滚方案 |
|--------|------|---------|
| 意图识别不准确 | 计划生成触发异常 | 保留原接口作为fallback，前端可选择性使用 |
| ChatAgent 调用 WorkoutAgent 性能问题 | 响应延迟增加 | 优化为异步并行调用，或缓存WorkoutAgent实例 |
| 前端兼容性问题 | 现有功能不可用 | 保留旧接口一段时间，标记为deprecated |

---

## 验证清单

- [ ] 发送"今天练什么"能正确触发计划生成
- [ ] 发送普通对话消息正常回复
- [ ] 生成的计划包含完整验证（通过WorkoutAgent）
- [ ] 前端只使用一个接口 `/chat/stream`
- [ ] Token使用量降低（提示词不重复）
- [ ] 计划生成质量不下降

---

## 预期效果

1. **接口统一**：前端只需调用一个AI接口
2. **架构清晰**：ChatAgent 作为主入口，WorkoutAgent 作为子服务
3. **Token节省**：移除重复提示词，每次请求节省约2000字符
4. **质量保证**：所有计划都经过 WorkoutAgent 的4节点验证流程
5. **维护简单**：单一路径，减少维护成本

---

## 后续优化（可选）

1. **意图识别升级**：使用LLM进行更精确的意图识别
2. **工具调用模式**：LangChain Tool Calling 实现更灵活的Agent协同
3. **计划生成缓存**：WorkoutAgent 层添加缓存，避免重复生成
4. **流式计划展示**：计划生成过程中实时展示进度
