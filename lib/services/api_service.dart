import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_logger.dart';
import 'auth_service.dart';

/// API 服务基类
class ApiService {
  final String baseUrl;
  final AuthService _authService = AuthService();

  ApiService({required this.baseUrl});

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // 添加认证 Token
    final token = _authService.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// GET 请求
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic data) mapper,
  }) async {
    final startTime = DateTime.now();
    try {
      final uri = Uri.parse('$baseUrl$path').replace(
        queryParameters: queryParameters?.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );

      ApiLogger.logRequest(
        method: 'GET',
        path: path,
        queryParameters: queryParameters,
      );

      final response = await http
          .get(uri, headers: _headers)
          .timeout(AppConfig.timeout);

      return _handleResponse(response, mapper, path, 'GET', startTime);
    } on TimeoutException catch (e) {
      ApiLogger.logError(
        method: 'GET',
        path: path,
        errorType: 'TimeoutException',
        message: '请求超时',
        error: e,
      );
      throw TimeoutException();
    } catch (e) {
      ApiLogger.logError(
        method: 'GET',
        path: path,
        errorType: e.runtimeType.toString(),
        message: e.toString(),
        error: e,
      );
      throw _handleError(e);
    }
  }

  /// POST 请求
  Future<T> post<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(dynamic data) mapper,
  }) async {
    final startTime = DateTime.now();
    try {
      final uri = Uri.parse('$baseUrl$path');

      ApiLogger.logRequest(
        method: 'POST',
        path: path,
        body: body,
      );

      final response = await http
          .post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.timeout);

      return _handleResponse(response, mapper, path, 'POST', startTime);
    } on TimeoutException catch (e) {
      ApiLogger.logError(
        method: 'POST',
        path: path,
        errorType: 'TimeoutException',
        message: '请求超时',
        error: e,
      );
      throw TimeoutException();
    } catch (e) {
      ApiLogger.logError(
        method: 'POST',
        path: path,
        errorType: e.runtimeType.toString(),
        message: e.toString(),
        error: e,
      );
      throw _handleError(e);
    }
  }

  /// PUT 请求
  Future<T> put<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(dynamic data) mapper,
  }) async {
    final startTime = DateTime.now();
    try {
      final uri = Uri.parse('$baseUrl$path');

      ApiLogger.logRequest(
        method: 'PUT',
        path: path,
        body: body,
      );

      final response = await http
          .put(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.timeout);

      return _handleResponse(response, mapper, path, 'PUT', startTime);
    } on TimeoutException catch (e) {
      ApiLogger.logError(
        method: 'PUT',
        path: path,
        errorType: 'TimeoutException',
        message: '请求超时',
        error: e,
      );
      throw TimeoutException();
    } catch (e) {
      ApiLogger.logError(
        method: 'PUT',
        path: path,
        errorType: e.runtimeType.toString(),
        message: e.toString(),
        error: e,
      );
      throw _handleError(e);
    }
  }

  T _handleResponse<T>(
    http.Response response,
    T Function(dynamic) mapper,
    String path,
    String method,
    DateTime startTime,
  ) {
    final duration = DateTime.now().difference(startTime).inMilliseconds;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      ApiLogger.logResponse(
        method: method,
        path: path,
        statusCode: response.statusCode,
        durationMs: duration,
      );

      if (response.body.isEmpty) {
        return mapper(null);
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      ApiLogger.logResponse(
        method: method,
        path: path,
        statusCode: response.statusCode,
        durationMs: duration,
        data: data,
      );
      return mapper(data);
    } else if (response.statusCode == 401) {
      ApiLogger.logError(
        method: method,
        path: path,
        errorType: 'Unauthorized',
        message: '未授权访问',
        statusCode: response.statusCode,
      );
      throw UnauthorizedException();
    } else if (response.statusCode >= 500) {
      ApiLogger.logError(
        method: method,
        path: path,
        errorType: 'ServerError',
        message: '服务器错误: ${response.statusCode}',
        statusCode: response.statusCode,
      );
      throw ServerException('服务器错误: ${response.statusCode}');
    } else {
      // 尝试解析后端错误响应
      Map<String, dynamic>? errorBody;
      try {
        errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        // 忽略解析错误
      }

      final exception = ApiException.fromResponse(response.statusCode, errorBody);

      ApiLogger.logError(
        method: method,
        path: path,
        errorType: exception.errorCode ?? 'HttpError',
        message: exception.message,
        statusCode: response.statusCode,
        error: errorBody,
      );

      throw exception;
    }
  }

  Exception _handleError(dynamic error) {
    if (error is ApiException) {
      return error;
    }
    return NetworkException();
  }
}
