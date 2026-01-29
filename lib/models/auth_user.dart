/// 认证用户模型（用于登录/注册请求）
class AuthUser {
  final String userId;
  final String password;

  AuthUser({
    required this.userId,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'password': password,
      };
}
