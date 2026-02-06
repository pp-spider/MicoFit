import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/auth_tokens.dart';
import '../models/user.dart';
import 'http_client.dart';

/// 认证 API 服务
class AuthApiService {
  final ApiHttpClient _httpClient;
  final FlutterSecureStorage _storage;

  AuthApiService({
    ApiHttpClient? httpClient,
    FlutterSecureStorage? storage,
  })  : _httpClient = httpClient ?? ApiHttpClient(),
        _storage = storage ?? const FlutterSecureStorage();

  /// 注册
  Future<AuthTokens> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final response = await _httpClient.post(
      '/api/v1/auth/register',
      body: jsonEncode({
        'email': email,
        'password': password,
        'nickname': nickname,
      }),
      requireAuth: false,
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data == null) {
      throw Exception('注册失败：服务器响应无效');
    }

    final tokens = AuthTokens.fromJson(data);
    await _saveTokens(tokens);
    return tokens;
  }

  /// 登录
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final response = await _httpClient.post(
      '/api/v1/auth/login',
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
      requireAuth: false,
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data == null) {
      throw Exception('登录失败：服务器响应无效');
    }

    final tokens = AuthTokens.fromJson(data);
    await _saveTokens(tokens);
    return tokens;
  }

  /// 刷新 Token
  Future<AuthTokens> refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('${_httpClient.baseUrl}/api/v1/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode != 200) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data == null) {
      throw Exception('刷新 Token 失败：服务器响应无效');
    }

    final tokens = AuthTokens.fromJson(data);
    await _saveTokens(tokens);
    return tokens;
  }

  /// 登出
  Future<void> logout() async {
    try {
      // 调用后端登出接口（可选）
      await _httpClient.post('/api/v1/auth/logout');
    } catch (e) {
      // 忽略错误，继续清除本地存储
    } finally {
      await _clearTokens();
    }
  }

  /// 获取当前用户信息
  Future<User> getCurrentUser() async {
    final response = await _httpClient.get('/api/v1/auth/me');

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data == null) {
      throw Exception('获取用户信息失败：服务器响应无效');
    }

    final user = User.fromJson(data);
    await _storage.write(key: AppConfig.keyUserId, value: user.id);
    return user;
  }

  /// 保存 Token 到安全存储
  Future<void> _saveTokens(AuthTokens tokens) async {
    await _storage.write(
      key: AppConfig.keyAccessToken,
      value: tokens.accessToken,
    );
    await _storage.write(
      key: AppConfig.keyRefreshToken,
      value: tokens.refreshToken,
    );
    await _storage.write(
      key: AppConfig.keyTokenExpiresAt,
      value: tokens.expiresAt.toIso8601String(),
    );
  }

  /// 清除 Token
  Future<void> _clearTokens() async {
    await _storage.delete(key: AppConfig.keyAccessToken);
    await _storage.delete(key: AppConfig.keyRefreshToken);
    await _storage.delete(key: AppConfig.keyTokenExpiresAt);
    await _storage.delete(key: AppConfig.keyUserId);
  }

  /// 获取存储的 Access Token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConfig.keyAccessToken);
  }

  /// 获取存储的 Refresh Token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConfig.keyRefreshToken);
  }

  /// 获取 Token 过期时间
  Future<DateTime?> getTokenExpiresAt() async {
    final expiresAtStr = await _storage.read(key: AppConfig.keyTokenExpiresAt);
    if (expiresAtStr == null) return null;
    return DateTime.parse(expiresAtStr);
  }

  /// 获取存储的用户 ID
  Future<String?> getUserId() async {
    return await _storage.read(key: AppConfig.keyUserId);
  }

  /// 检查是否有有效的 Token
  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    if (token == null) return false;

    final expiresAt = await getTokenExpiresAt();
    if (expiresAt == null) return false;

    return DateTime.now().isBefore(expiresAt);
  }
}
