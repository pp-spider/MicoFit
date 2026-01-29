/// 认证响应模型（登录/注册成功后的响应）
class AuthResponse {
  final String token;
  final String userId;
  final String? nickname;
  final int? expiresIn;
  final bool hasProfile; // 用户是否已完成画像

  AuthResponse({
    required this.token,
    required this.userId,
    this.nickname,
    this.expiresIn,
    this.hasProfile = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String,
        userId: json['userId'] as String,
        nickname: json['nickname'] as String?,
        expiresIn: json['expiresIn'] as int?,
        hasProfile: json['hasProfile'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'userId': userId,
        if (nickname != null) 'nickname': nickname,
        if (expiresIn != null) 'expiresIn': expiresIn,
        'hasProfile': hasProfile,
      };
}
