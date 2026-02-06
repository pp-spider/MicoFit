/// Token 响应模型
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn; // 秒

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
    };
  }

  /// 计算过期时间（当前时间 + expiresIn）
  DateTime get expiresAt {
    return DateTime.now().add(Duration(seconds: expiresIn));
  }

  /// 检查是否即将过期（剩余时间少于5分钟）
  bool get isAboutToExpire {
    final expiresAt = this.expiresAt;
    final now = DateTime.now();
    return expiresAt.difference(now).inMinutes < 5;
  }

  /// 检查是否已过期
  bool get isExpired {
    final expiresAt = this.expiresAt;
    final now = DateTime.now();
    return now.isAfter(expiresAt);
  }
}
