import 'api_service.dart';
import '../models/auth_user.dart';
import '../models/auth_response.dart';

/// 认证 API 服务
class AuthApiService extends ApiService {
  AuthApiService({required super.baseUrl});

  /// 登录
  Future<AuthResponse> login(AuthUser user) async {
    return post(
      '/api/v1/auth/login',
      body: user.toJson(),
      mapper: (data) => AuthResponse.fromJson(data),
    );
  }

  /// 注册
  Future<AuthResponse> register(AuthUser user) async {
    return post(
      '/api/v1/auth/register',
      body: user.toJson(),
      mapper: (data) => AuthResponse.fromJson(data),
    );
  }

  /// 刷新 Token
  Future<AuthResponse> refreshToken(String token) async {
    return post(
      '/api/v1/auth/refresh',
      body: {'token': token},
      mapper: (data) => AuthResponse.fromJson(data),
    );
  }

  /// 登出
  Future<void> logout(String token) async {
    await post(
      '/api/v1/auth/logout',
      body: {'token': token},
      mapper: (data) => data,
    );
  }
}
