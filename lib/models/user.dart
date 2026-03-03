/// 用户基础模型
class User {
  final String id;
  final String email;
  final String nickname;
  final String? avatarUrl;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  User({
    required this.id,
    required this.email,
    required this.nickname,
    this.avatarUrl,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatar_url'] as String?,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? json['isVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'is_active': isActive,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      if (lastLoginAt != null) 'last_login_at': lastLoginAt!.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? nickname,
    String? avatarUrl,
    bool? isActive,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
