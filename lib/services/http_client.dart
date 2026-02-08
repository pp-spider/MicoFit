import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../config/app_config.dart';

/// 封装 HTTP 客户端，自动注入 Token
class ApiHttpClient {
  final String baseUrl;
  final FlutterSecureStorage _storage;

  ApiHttpClient({
    String? baseUrl,
    FlutterSecureStorage? storage,
  })  : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _storage = storage ?? const FlutterSecureStorage();

  /// 获取 Access Token
  Future<String?> _getAccessToken() async {
    return await _storage.read(key: AppConfig.keyAccessToken);
  }

  /// 公共方法：获取 Access Token（用于 SSE 流）
  Future<String?> getToken() async {
    return await _getAccessToken();
  }

  /// 发送 GET 请求
  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final requestHeaders = await _buildHeaders(headers, requireAuth);

    return http.get(uri, headers: requestHeaders);
  }

  /// 发送 POST 请求
  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final requestHeaders = await _buildHeaders(headers, requireAuth);

    return http.post(uri, headers: requestHeaders, body: body);
  }

  /// 发送 PUT 请求
  Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final requestHeaders = await _buildHeaders(headers, requireAuth);

    return http.put(uri, headers: requestHeaders, body: body);
  }

  /// 发送 PATCH 请求
  Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final requestHeaders = await _buildHeaders(headers, requireAuth);

    return http.patch(uri, headers: requestHeaders, body: body);
  }

  /// 发送 DELETE 请求
  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final requestHeaders = await _buildHeaders(headers, requireAuth);

    return http.delete(uri, headers: requestHeaders);
  }

  /// 构建请求头
  Future<Map<String, String>> _buildHeaders(
    Map<String, String>? customHeaders,
    bool requireAuth,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?customHeaders,
    };

    if (requireAuth) {
      final token = await _getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// 解析响应
  static Map<String, dynamic>? parseResponse(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// 检查响应是否成功
  static bool isSuccess(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// 获取错误消息
  static String getErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['detail'] as String? ?? '请求失败';
    } catch (e) {
      return '请求失败 (状态码: ${response.statusCode})';
    }
  }
}
