/// Token 响应模型
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn; // 秒
  final int refreshTokenExpiresIn; // 秒（刷新令牌的过期时间）

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.refreshTokenExpiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int,
      refreshTokenExpiresIn: json['refresh_token_expires_in'] as int? ?? json['expires_in'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'refresh_token_expires_in': refreshTokenExpiresIn,
    };
  }

  /// 计算 access token 过期时间
  DateTime get expiresAt {
    return DateTime.now().add(Duration(seconds: expiresIn));
  }

  /// 计算 refresh token 过期时间（用于判断登录有效性）
  DateTime get refreshTokenExpiresAt {
    return DateTime.now().add(Duration(seconds: refreshTokenExpiresIn));
  }

  /// 检查是否即将过期（剩余时间少于5分钟）
  bool get isAboutToExpire {
    final expiresAt = this.expiresAt;
    final now = DateTime.now();
    return expiresAt.difference(now).inMinutes < 5;
  }

  /// 检查是否已过期（基于 access token）
  bool get isExpired {
    final expiresAt = this.expiresAt;
    final now = DateTime.now();
    return now.isAfter(expiresAt);
  }
}
