import 'agent_output.dart';

/// 聊天消息类型
enum ChatMessageType {
  user,    // 用户消息
  assistant,  // AI助手消息
}

/// 聊天消息结构化数据类型
enum ChatMessageDataType {
  workoutPlan,  // 健身计划
}

/// 聊天消息类型扩展
extension ChatMessageTypeExtension on ChatMessageType {
  String get value {
    switch (this) {
      case ChatMessageType.user:
        return 'user';
      case ChatMessageType.assistant:
        return 'assistant';
    }
  }

  static ChatMessageType fromString(String value) {
    switch (value) {
      case 'user':
        return ChatMessageType.user;
      case 'assistant':
        return ChatMessageType.assistant;
      default:
        return ChatMessageType.user;
    }
  }
}

/// 聊天消息
class ChatMessage {
  final String id;
  final ChatMessageType type;
  final String content;
  final DateTime timestamp;

  // 结构化数据（用于健身计划等）
  final Map<String, dynamic>? structuredData;
  final ChatMessageDataType? dataType;

  // 会话ID（从后端获取时）
  final String? sessionId;

  // Agent 执行输出（用于多 Agent 场景）
  final List<AgentOutput>? agentOutputs;

  ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.structuredData,
    this.dataType,
    this.sessionId,
    this.agentOutputs,
  });

  /// 创建用户消息
  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ChatMessageType.user,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  /// 创建AI消息
  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ChatMessageType.assistant,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  /// 创建包含健身计划的AI消息
  factory ChatMessage.withWorkoutPlan({
    required String content,
    required Map<String, dynamic> workoutPlanJson,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ChatMessageType.assistant,
      content: content,
      timestamp: DateTime.now(),
      structuredData: workoutPlanJson,
      dataType: ChatMessageDataType.workoutPlan,
    );
  }

  /// 创建包含Agent输出的AI消息
  factory ChatMessage.withAgentOutputs({
    required String content,
    required List<AgentOutput> agentOutputs,
    Map<String, dynamic>? workoutPlanJson,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ChatMessageType.assistant,
      content: content,
      timestamp: DateTime.now(),
      structuredData: workoutPlanJson,
      dataType: workoutPlanJson != null ? ChatMessageDataType.workoutPlan : null,
      agentOutputs: agentOutputs,
    );
  }

  /// 从JSON创建（本地格式）
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      type: ChatMessageTypeExtension.fromString(json['type'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      structuredData: json['structuredData'] as Map<String, dynamic>?,
      dataType: json['dataType'] != null
          ? ChatMessageDataType.values.firstWhere(
              (e) => e.name == json['dataType'],
              orElse: () => ChatMessageDataType.workoutPlan,
            )
          : null,
      sessionId: json['sessionId'] as String?,
      agentOutputs: (json['agentOutputs'] as List<dynamic>?)
          ?.map((e) => AgentOutput.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 从后端API响应创建
  factory ChatMessage.fromApiJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      type: ChatMessageTypeExtension.fromString(json['role'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['created_at'] as String),
      structuredData: json['structured_data'] as Map<String, dynamic>?,
      dataType: json['data_type'] != null
          ? ChatMessageDataType.values.firstWhere(
              (e) => e.name == json['data_type'],
              orElse: () => ChatMessageDataType.workoutPlan,
            )
          : null,
      sessionId: json['session_id'] as String?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      if (structuredData != null) 'structuredData': structuredData,
      if (dataType != null) 'dataType': dataType!.name,
      if (sessionId != null) 'sessionId': sessionId,
      if (agentOutputs != null)
        'agentOutputs': agentOutputs!.map((e) => e.toJson()).toList(),
    };
  }

  /// 复制并修改部分字段
  ChatMessage copyWith({
    String? id,
    ChatMessageType? type,
    String? content,
    DateTime? timestamp,
    Map<String, dynamic>? structuredData,
    ChatMessageDataType? dataType,
    String? sessionId,
    List<AgentOutput>? agentOutputs,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      structuredData: structuredData ?? this.structuredData,
      dataType: dataType ?? this.dataType,
      sessionId: sessionId ?? this.sessionId,
      agentOutputs: agentOutputs ?? this.agentOutputs,
    );
  }
}
