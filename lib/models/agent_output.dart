/// Agent 执行状态
enum AgentStatus { completed, running, waiting }

/// Agent 内容项类型
enum AgentContentType { text, list, progress, typing, success, warning, error }

/// Agent 内容项
class AgentContentItem {
  final AgentContentType type;
  final String? text;
  final List<String>? items;
  final int? percent;

  const AgentContentItem._({
    required this.type,
    this.text,
    this.items,
    this.percent,
  });

  /// 普通文本
  factory AgentContentItem.text(String text) =>
      AgentContentItem._(type: AgentContentType.text, text: text);

  /// 列表项
  factory AgentContentItem.list(List<String> items) =>
      AgentContentItem._(type: AgentContentType.list, items: items);

  /// 进度条
  factory AgentContentItem.progress(int percent) => AgentContentItem._(
    type: AgentContentType.progress,
    percent: percent.clamp(0, 100),
  );

  /// 打字动画
  factory AgentContentItem.typing(String text) =>
      AgentContentItem._(type: AgentContentType.typing, text: text);

  /// 成功提示
  factory AgentContentItem.success(String text) =>
      AgentContentItem._(type: AgentContentType.success, text: text);

  /// 警告提示
  factory AgentContentItem.warning(String text) =>
      AgentContentItem._(type: AgentContentType.warning, text: text);

  /// 错误提示
  factory AgentContentItem.error(String text) =>
      AgentContentItem._(type: AgentContentType.error, text: text);

  @override
  String toString() {
    return 'AgentContentItem(type: $type, text: $text, items: $items, percent: $percent)';
  }
}

/// Agent 输出状态
class AgentOutput {
  final String id;
  final String name;
  final String icon;
  final AgentStatus status;
  final String? taskType;
  final List<AgentContentItem> contentItems;
  final bool isExpanded;
  final String? messageContent; // Agent 生成的消息内容

  const AgentOutput({
    required this.id,
    required this.name,
    required this.icon,
    required this.status,
    this.taskType,
    this.contentItems = const [],
    this.isExpanded = false,
    this.messageContent,
  });

  /// 创建副本，支持部分属性更新
  AgentOutput copyWith({
    String? id,
    String? name,
    String? icon,
    AgentStatus? status,
    String? taskType,
    List<AgentContentItem>? contentItems,
    bool? isExpanded,
    String? messageContent,
  }) {
    return AgentOutput(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      status: status ?? this.status,
      taskType: taskType ?? this.taskType,
      contentItems: contentItems ?? this.contentItems,
      isExpanded: isExpanded ?? this.isExpanded,
      messageContent: messageContent ?? this.messageContent,
    );
  }

  /// 更新状态
  AgentOutput withStatus(AgentStatus status) => copyWith(status: status);

  /// 切换展开状态
  AgentOutput toggleExpanded() => copyWith(isExpanded: !isExpanded);

  /// 添加内容项
  AgentOutput addContentItem(AgentContentItem item) =>
      copyWith(contentItems: [...contentItems, item]);

  /// 更新最后一个内容项（用于进度更新）
  AgentOutput updateLastContentItem(AgentContentItem item) {
    if (contentItems.isEmpty) return addContentItem(item);
    final newItems = [...contentItems];
    newItems[newItems.length - 1] = item;
    return copyWith(contentItems: newItems);
  }

  /// 获取显示用的颜色名称
  String get colorName {
    switch (id) {
      case 'workout':
      case 'workout_sub_agent':
        return 'emerald';
      case 'chat':
      case 'chat_sub_agent':
        return 'blue';
      case 'analysis':
        return 'amber';
      case 'research':
        return 'purple';
      case 'summary_agent':
        return 'emerald';
      default:
        return 'teal';
    }
  }

  /// 从后端agent名称映射到显示名称
  static String getDisplayName(String agentId) {
    final Map<String, String> nameMap = {
      'workout_sub_agent': 'Workout Agent',
      'chat_sub_agent': 'Chat Agent',
      'analysis_agent': 'Analysis Agent',
      'research_agent': 'Research Agent',
      'planner_agent': 'Planner Agent',
      'task_analyzer': 'Task Analyzer',
      'task_executor': 'Task Executor',
      'summary_agent': 'Summary Agent',
    };
    return nameMap[agentId] ?? agentId;
  }

  /// 从后端agent名称映射到图标
  static String getIcon(String agentId) {
    final Map<String, String> iconMap = {
      'workout_sub_agent': '💪',
      'chat_sub_agent': '💬',
      'analysis_agent': '📊',
      'research_agent': '🔍',
      'planner_agent': '📋',
      'task_analyzer': '🔎',
      'task_executor': '⚡',
      'summary_agent': '✨',
    };
    return iconMap[agentId] ?? '🤖';
  }

  @override
  String toString() {
    return 'AgentOutput(id: $id, name: $name, status: $status, contentItems: ${contentItems.length})';
  }
}
