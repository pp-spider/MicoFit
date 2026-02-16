/// 聊天会话模型
class ChatSession {
  final String id;
  final String? title;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    this.title,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从后端API响应创建
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String?,
      messageCount: json['message_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message_count': messageCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 复制并修改部分字段
  ChatSession copyWith({
    String? id,
    String? title,
    int? messageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      messageCount: messageCount ?? this.messageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
