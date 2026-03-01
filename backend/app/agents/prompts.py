"""提示词模板"""

def _get_base_prompt(user_profile: dict | None) -> str:
    """
    共用基础提示词组件

    Args:
        user_profile: 用户画像信息

    Returns:
        str: 基础提示词字符串
    """
    buffer = []

    # 基础角色定义
    buffer.append("你是微动MicoFit的专属AI健身教练。")
    buffer.append("你的职责是为用户提供专业的健身建议、训练指导和健康咨询。")
    buffer.append("")

    # 用户画像信息
    if user_profile:
        buffer.append("---")
        buffer.append("**用户画像信息**")
        buffer.append(f"- 昵称：{user_profile.get('nickname', '用户')}")
        buffer.append(f"- 健身水平：{_get_fitness_level_label(user_profile.get('fitness_level', ''))}")
        buffer.append(f"- 健身目标：{_get_goal_label(user_profile.get('goal', ''))}")
        buffer.append(f"- 常用场景：{_get_scene_label(user_profile.get('scene', ''))}")
        buffer.append(f"- 时间预算：每次约{user_profile.get('time_budget', 12)}分钟")

        limitations = user_profile.get('limitations', [])
        if limitations and len(limitations) > 0:
            buffer.append(f"- 身体限制：{'、'.join(limitations)}")

        buffer.append(f"- 可用装备：{_get_equipment_label(user_profile.get('equipment', ''))}")
        buffer.append(f"- 每周训练天数：{user_profile.get('weekly_days', 3)}天")
        buffer.append("---")
        buffer.append("")
    else:
        buffer.append("用户尚未设置画像信息。")
        buffer.append("")

    return "\n".join(buffer)


def build_system_prompt(
    user_profile: dict | None = None,
    context_summary: str | None = None,
    recent_memories: list[str] | None = None
) -> str:
    """
    构建ChatAgent系统提示词 - 专注于对话

    Args:
        user_profile: 用户画像信息
        context_summary: 当前会话的上下文摘要
        recent_memories: 近期跨会话记忆要点
    """
    buffer = []

    # 基础信息
    buffer.append(_get_base_prompt(user_profile))

    # 添加上下文摘要（如果有）
    if context_summary:
        buffer.append("**对话上下文摘要**")
        buffer.append(context_summary)
        buffer.append("")

    # 添加近期记忆（如果有）
    if recent_memories and len(recent_memories) > 0:
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


def build_workout_system_prompt(user_profile: dict | None = None) -> str:
    """
    构建WorkoutAgent系统提示词 - 专注于计划生成

    Args:
        user_profile: 用户画像信息

    Returns:
        str: 专门用于生成训练计划的系统提示词
    """
    buffer = []

    # 使用共用基础提示词
    buffer.append(_get_base_prompt(user_profile))

    # 添加计划生成专用指导
    buffer.append(_get_workout_generation_prompt())

    return "\n".join(buffer)


def _get_workout_generation_prompt() -> str:
    """获取计划生成提示词"""
    return """
**健身计划生成**
当用户要求生成、修改或调整今日健身计划时:

1. 【优先使用已知信息】首先检查上方"系统提供的用户画像信息"区域
   - 如果该区域信息完整（包含目标、水平、场景、时间、限制等），直接使用这些信息生成计划
   - 无需调用 get_user_profile 工具

2. 【工具调用条件】仅在以下情况才调用 get_user_profile：
   - 上方用户信息区域明显缺失关键字段（如没有目标、场景或时间预算）
   - 用户明确提到"更新我的信息"或"查看最新设置"
   - 你需要确认系统提示词中的信息是否为最新数据

3. 【信息不完整处理】
   - 如果 hasProfile 为 false（用户未设置画像），引导用户先完成画像设置
   - 如果部分信息缺失，可基于已有信息生成计划，并在回复中询问缺失部分

4. 需求明确后，按以下格式输出:
   - 先用简洁友好的文字说明计划亮点
   - 然后用 Markdown 表格展示训练概览
   - 最后必须用 ```json ... ``` 代码块输出完整的JSON数据

5. JSON格式必须严格符合以下结构:
```json
{
  "id": "唯一标识字符串",
  "title": "今日微动",
  "subtitle": "核心力量强化",
  "total_duration": 15,
  "scene": "办公室",
  "rpe": 6,
  "ai_note": "针对核心需求设计",
  "modules": [
    {
      "id": "module_1",
      "name": "模块名称",
      "duration": 5,
      "exercises": [
        {
          "id": "ex_1",
          "name": "动作名称",
          "duration": 60,
          "description": "动作描述",
          "steps": ["步骤1", "步骤2"],
          "tips": "动作提示",
          "breathing": "呼吸指导",
          "image": "assets/exercises/exercise-core.png",
          "target_muscles": ["腹直肌"]
        }
      ]
    }
  ]
}
```

6. 重要约束:
- 总时长必须在用户时间预算内
- RPE强度: 零基础3-5, 偶尔运动5-7, 规律运动6-8
- 必须避开用户的身体限制部位
- 只使用用户可用装备或无需装备的动作
- 每个模块至少包含1个动作
- **必须确保JSON格式正确，缺少JSON将导致用户无法应用计划**

7. 输出示例（参考格式）:
> 💪 为你准备了一套核心训练计划！
>
> | 模块 | 时长 | 动作数 |
> |------|------|--------|
> | 工位核心激活 | 5分钟 | 3个 |
> | 办公室有氧 | 10分钟 | 2个 |
>
> ```json
> {完整的计划JSON}
> ```
""".strip()


def _get_intent_recognition_prompt() -> str:
    """获取意图识别提示词"""
    return """
**意图识别**
当用户提及以下内容时，主动提供调整训练计划的服务:
- "换个计划"、"不想练这个"、"有别的吗"
- "太简单"、"太难"、"强度不够"
- "没时间"、"时间不够"、"快点"
- "练腰"、"练腿"、"练核心"、"练手臂"等部位需求
- "在办公室"、"在家"等场景变化
- "膝盖不好"、"腰疼"、"有伤病"等身体限制
""".strip()


def _get_fitness_level_label(level: str) -> str:
    """获取健身水平标签"""
    mapping = {
        "beginner": "零基础",
        "occasional": "偶尔运动",
        "regular": "规律运动"
    }
    return mapping.get(level, level)


def _get_goal_label(goal: str) -> str:
    """获取目标标签"""
    mapping = {
        "fat-loss": "减脂塑形",
        "sedentary": "缓解久坐",
        "strength": "增强体能",
        "sleep": "改善睡眠"
    }
    return mapping.get(goal, goal)


def _get_scene_label(scene: str) -> str:
    """获取场景标签"""
    mapping = {
        "bed": "床上",
        "office": "办公室",
        "living": "客厅",
        "outdoor": "户外",
        "hotel": "酒店"
    }
    return mapping.get(scene, scene)


def _get_equipment_label(equipment) -> str:
    """获取装备标签

    Args:
        equipment: 装备，可以是字符串或列表

    Returns:
        str: 标签字符串
    """
    mapping = {
        "none": "无需装备",
        "mat": "瑜伽垫",
        "chair": "椅子",
        "towel": "毛巾",
        "resistance_band": "弹力带",
        "small_weights": "小哑铃",
        "徒手": "无需装备",
        "弹力带": "弹力带",
        "瑜伽垫": "瑜伽垫",
        "哑铃": "小哑铃"
    }

    # 处理列表类型
    if isinstance(equipment, list):
        labels = []
        for eq in equipment:
            if eq in mapping:
                labels.append(mapping[eq])
            else:
                labels.append(eq)
        return "、".join(labels) if labels else "未知"

    # 处理字符串类型
    if not equipment:
        return "未知"

    return mapping.get(equipment, equipment)


def build_intent_recognition_prompt(user_message: str, user_profile: dict | None = None) -> str:
    """
    构建意图识别提示词 - 使用 LLM 进行智能意图识别

    Args:
        user_message: 用户消息
        user_profile: 用户画像信息

    Returns:
        str: 意图识别提示词
    """
    profile_info = ""
    if user_profile:
        profile_info = f"""
**用户画像信息：**
- 健身水平：{_get_fitness_level_label(user_profile.get('fitness_level', ''))}
- 健身目标：{_get_goal_label(user_profile.get('goal', ''))}
- 常用场景：{_get_scene_label(user_profile.get('scene', ''))}
- 时间预算：{user_profile.get('time_budget', 12)}分钟
"""

    # 构建提示词模板
    prompt_template = """你是微动MicoFit的意图识别助手。你的任务是分析用户消息，识别用户的真实意图。

{profile_info}

## 意图分类

1. **workout** - 用户想要生成、修改或调整训练计划
   - 明确请求："给我生成一个训练计划"、"今天练什么"
   - 调整计划："换个计划"、"这个太难了"、"我想练腿"
   - 场景/时间变化："我在办公室，给我计划"、"只有10分钟"
   - 身体限制："我膝盖不好，调整计划"
   - 隐含需求："今天有点累，想动一下"、"坐了一天，想舒展一下"

2. **chat** - 普通对话、咨询、闲聊
   - 健身知识："深蹲怎么做"、"什么是HIIT"
   - 健康咨询："运动后怎么拉伸"、"怎么吃才能减脂"
   - 动作指导："平板支撑要注意什么"
   - 闲聊："你好"、"谢谢"、"再见"
   - 反馈："今天训练很棒"、"这个计划不错"

## 输出格式

请严格按以下JSON格式输出（不要包含其他文字）：

```json
{{
    "intent": "workout" | "chat",
    "confidence": 0.0-1.0,
    "reasoning": "简要说明判断理由",
    "entities": {{
        "focus_body_part": "legs" | "core" | "arms" | "back" | "chest" | "glutes" | null,
        "scene": "office" | "home" | "outdoor" | "bed" | "hotel" | null,
        "duration": number | null,
        "intensity": "low" | "medium" | "high" | null,
        "equipment": string | null
    }}
}}
```

## 示例

用户消息："我在办公室，只有15分钟，想练一下核心"
```json
{{
    "intent": "workout",
    "confidence": 0.95,
    "reasoning": "用户明确请求在办公室场景下生成15分钟的核心训练计划",
    "entities": {{
        "focus_body_part": "core",
        "scene": "office",
        "duration": 15,
        "intensity": null,
        "equipment": null
    }}
}}
```

用户消息："深蹲怎么做才标准？"
```json
{{
    "intent": "chat",
    "confidence": 0.95,
    "reasoning": "用户询问深蹲动作要领，属于健身知识咨询",
    "entities": {{
        "focus_body_part": "legs",
        "scene": null,
        "duration": null,
        "intensity": null,
        "equipment": null
    }}
}}
```

用户消息："今天有点累，想稍微动一下"
```json
{{
    "intent": "workout",
    "confidence": 0.85,
    "reasoning": "用户表示累但想动一下，隐含需要轻度训练计划",
    "entities": {{
        "focus_body_part": null,
        "scene": null,
        "duration": null,
        "intensity": "low",
        "equipment": null
    }}
}}
```

请分析以下用户消息：
"""

    return prompt_template.format(profile_info=profile_info) + user_message


# ============================================================================
# Planner Agent 多意图识别 Prompt
# ============================================================================

def build_multi_intent_prompt(user_message: str, user_profile: dict | None = None) -> str:
    """
    构建多意图识别提示词 - 用于 Planner Agent

    识别用户消息中的所有意图，支持复杂多步骤任务。

    Args:
        user_message: 用户消息
        user_profile: 用户画像信息

    Returns:
        str: 多意图识别提示词
    """
    profile_info = ""
    if user_profile:
        profile_info = f"""
**用户画像信息：**
- 健身水平：{_get_fitness_level_label(user_profile.get('fitness_level', ''))}
- 健身目标：{_get_goal_label(user_profile.get('goal', ''))}
- 常用场景：{_get_scene_label(user_profile.get('scene', ''))}
- 时间预算：{user_profile.get('time_budget', 12)}分钟
"""

    prompt_template = """你是微动MicoFit的任务分析助手。你的任务是分析用户消息，识别所有可能的意图。

{profile_info}

## 任务类型定义

1. **workout** - 训练计划相关
   - 生成计划、调整计划、换计划
   - 部位训练、场景训练、时间训练
   - 强度调整
   - 示例："今天练什么"、"给我一个计划"、"换个腿部的"

2. **chat** - 普通对话
   - 健身知识问答、动作咨询
   - 闲聊、感谢、问候
   - 示例："深蹲怎么做"、"谢谢教练"

3. **explanation** - 解释说明
   - 解释动作、解释计划
   - 为什么推荐这个
   - 示例："解释一下这个动作"、"为什么要练这个"

4. **feedback** - 训练反馈
   - 反馈训练感受
   - 调整建议
   - 示例："今天练完好累"、"这个计划太简单了"

## 复杂度定义

- **simple**: 单意图，如"今天练什么？"
- **medium**: 2个相关意图，如"给我一个计划并解释一下"
- **complex**: 多个意图或复杂依赖，如"制定计划并解释每个动作，然后根据我的反馈调整"

## 输出格式

请严格按以下JSON格式输出：

```json
{{
    "intents": ["workout", "explanation"],
    "primary_intent": "workout",
    "complexity": "complex",
    "confidence": 0.95,
    "reasoning": "用户先要求生成计划，然后要求解释动作，所以有2个意图",
    "entities": {{
        "focus_body_part": null,
        "scene": null,
        "duration": null,
        "intensity": null
    }},
    "sub_tasks": [
        {{
            "type": "workout",
            "description": "生成训练计划",
            "input_data": {{}},
            "depends_on": []
        }},
        {{
            "type": "explanation",
            "description": "解释计划中的每个动作",
            "input_data": {{"plan_reference": "task_0"}},
            "depends_on": ["task_0"]
        }}
    ]
}}
```

## 任务依赖规则

- 如果某个任务需要另一个任务的输出，在 depends_on 中指定依赖的任务ID
- 例如：解释任务依赖生成的计划，所以 depends_on: ["task_0"]
- 如果没有依赖，depends_on: []

## 示例

用户消息："制定训练计划并解释每个动作"
```json
{{
    "intents": ["workout", "explanation"],
    "primary_intent": "workout",
    "complexity": "complex",
    "confidence": 0.95,
    "reasoning": "用户要求生成计划并解释动作，是两个有依赖关系的任务",
    "entities": {{}},
    "sub_tasks": [
        {{
            "type": "workout",
            "description": "生成训练计划",
            "input_data": {{}},
            "depends_on": []
        }},
        {{
            "type": "explanation",
            "description": "解释计划中的每个动作",
            "input_data": {{"plan_reference": "task_0"}},
            "depends_on": ["task_0"]
        }}
    ]
}}
```

用户消息："给我一个计划，再聊聊增肌"
```json
{{
    "intents": ["workout", "chat"],
    "primary_intent": "workout",
    "complexity": "medium",
    "confidence": 0.9,
    "reasoning": "用户要求生成计划并讨论增肌，两个独立任务可以并行",
    "entities": {{}},
    "sub_tasks": [
        {{
            "type": "workout",
            "description": "生成训练计划",
            "input_data": {{}},
            "depends_on": []
        }},
        {{
            "type": "chat",
            "description": "讨论增肌知识",
            "input_data": {{"topic": "增肌"}},
            "depends_on": []
        }}
    ]
}}
```

用户消息："今天练什么？"
```json
{{
    "intents": ["workout"],
    "primary_intent": "workout",
    "complexity": "simple",
    "confidence": 0.95,
    "reasoning": "用户只是询问今天的训练计划",
    "entities": {{}},
    "sub_tasks": [
        {{
            "type": "workout",
            "description": "生成今日训练计划",
            "input_data": {{}},
            "depends_on": []
        }}
    ]
}}
```

请分析以下用户消息：
"""

    return prompt_template.format(profile_info=profile_info) + user_message
