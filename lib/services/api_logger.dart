import 'dart:developer' as developer;

/// API 请求日志记录器
class ApiLogger {
  /// 是否启用日志（生产环境可关闭）
  static const bool _enableLog = true;

  /// 是否启用详细日志（包含请求/响应体）
  static const bool _enableDetailLog = true;

  /// 记录请求
  static void logRequest({
    required String method,
    required String path,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
  }) {
    if (!_enableLog) return;

    final buffer = StringBuffer();
    buffer.write('🚀 API 请求 [$method] $path');

    if (queryParameters != null && queryParameters.isNotEmpty) {
      buffer.write('\n   Query: $queryParameters');
    }

    if (_enableDetailLog && body != null && body.isNotEmpty) {
      buffer.write('\n   Body: ${_formatJson(body)}');
    }

    developer.log(buffer.toString(), name: 'API');
  }

  /// 记录响应
  static void logResponse({
    required String method,
    required String path,
    required int statusCode,
    int? durationMs,
    dynamic data,
  }) {
    if (!_enableLog) return;

    final statusIcon = _getStatusIcon(statusCode);
    final buffer = StringBuffer();
    buffer.write('$statusIcon API 响应 [$method] $path | 状态: $statusCode');

    if (durationMs != null) {
      buffer.write(' | 耗时: ${durationMs}ms');
    }

    if (_enableDetailLog && data != null && statusCode < 400) {
      buffer.write('\n   Data: ${_formatJson(data)}');
    }

    final logLevel = statusCode >= 400 ? 1000 : 200; // developer.log level
    developer.log(buffer.toString(), name: 'API', level: logLevel);
  }

  /// 记录错误
  static void logError({
    required String method,
    required String path,
    required String errorType,
    required String message,
    int? statusCode,
    dynamic error,
  }) {
    if (!_enableLog) return;

    final buffer = StringBuffer();
    buffer.write('❌ API 错误 [$method] $path\n');
    buffer.write('   类型: $errorType');
    if (statusCode != null) {
      buffer.write(' | 状态码: $statusCode');
    }
    buffer.write('\n   消息: $message');

    if (_enableDetailLog && error != null) {
      buffer.write('\n   详情: $error');
    }

    developer.log(buffer.toString(), name: 'API', level: 1000);
  }

  /// 获取状态图标
  static String _getStatusIcon(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return '✅';
    if (statusCode >= 300 && statusCode < 400) return '➡️';
    if (statusCode >= 400 && statusCode < 500) return '⚠️';
    if (statusCode >= 500) return '💥';
    return '📡';
  }

  /// 格式化 JSON（限制长度避免日志过长）
  static String _formatJson(dynamic data) {
    if (data == null) return 'null';

    String str;
    if (data is String) {
      str = data;
    } else if (data is Map || data is List) {
      str = data.toString();
    } else {
      str = data.toString();
    }

    // 限制长度
    const maxLength = 500;
    if (str.length > maxLength) {
      return '${str.substring(0, maxLength)}...';
    }
    return str;
  }

  /// 记录普通信息
  static void info(String message) {
    if (!_enableLog) return;
    developer.log('ℹ️ $message', name: 'API');
  }

  /// 记录警告
  static void warning(String message) {
    if (!_enableLog) return;
    developer.log('⚠️ $message', name: 'API', level: 900);
  }

  /// 记录调试信息
  static void debug(String message) {
    if (!_enableLog) return;
    developer.log('🔍 $message', name: 'API', level: 500);
  }
}
