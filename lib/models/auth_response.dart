import 'auth_tokens.dart';
import 'user.dart';

/// 登录/注册响应模型
class AuthResponse {
  final AuthTokens tokens;
  final User user;

  AuthResponse({
    required this.tokens,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      tokens: AuthTokens.fromJson(json),
      user: User.fromJson(json['user'] ?? {}),
    );
  }
}
