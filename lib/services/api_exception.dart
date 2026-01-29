/// API 错误码定义
class ApiErrorCode {
  static const String userNotFound = 'USER_NOT_FOUND';
  static const String duplicateUser = 'DUPLICATE_USER';
  static const String invalidParams = 'INVALID_PARAMS';
  static const String workoutCompleted = 'WORKOUT_COMPLETED';
  static const String unknown = 'UNKNOWN_ERROR';
}

/// API 错误响应模型
class ApiErrorResponse {
  final String? code;
  final String? message;

  ApiErrorResponse({this.code, this.message});

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) {
    return ApiErrorResponse(
      code: json['code'] as String?,
      message: json['message'] as String?,
    );
  }

  @override
  String toString() => 'ApiErrorResponse(code: $code, message: $message)';
}

/// API 异常基类
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  ApiException(this.message, [this.statusCode, this.errorCode]);

  factory ApiException.fromResponse(int statusCode, Map<String, dynamic>? body) {
    String code = ApiErrorCode.unknown;
    String msg = '请求失败';

    if (body != null) {
      final error = ApiErrorResponse.fromJson(body);
      code = error.code ?? ApiErrorCode.unknown;
      msg = error.message ?? msg;
    }

    return ApiException(msg, statusCode, code);
  }

  bool get isUserNotFound => errorCode == ApiErrorCode.userNotFound;
  bool get isDuplicateUser => errorCode == ApiErrorCode.duplicateUser;
  bool get isInvalidParams => errorCode == ApiErrorCode.invalidParams;
  bool get isWorkoutCompleted => errorCode == ApiErrorCode.workoutCompleted;

  @override
  String toString() =>
      'ApiException: $message (statusCode: $statusCode, errorCode: $errorCode)';
}

/// 网络异常
class NetworkException extends ApiException {
  NetworkException([String message = '网络连接失败，请检查网络设置'])
      : super(message, null, null);
}

/// 服务器异常
class ServerException extends ApiException {
  ServerException([String message = '服务器错误，请稍后重试'])
      : super(message, 500, null);
}

/// 超时异常
class TimeoutException extends ApiException {
  TimeoutException([String message = '请求超时，请检查网络连接'])
      : super(message, null, null);
}

/// 未授权异常
class UnauthorizedException extends ApiException {
  UnauthorizedException([String message = '未授权访问'])
      : super(message, 401, null);
}

/// 认证失败异常
class AuthenticationException extends ApiException {
  AuthenticationException([String message = '登录失败，请检查账号密码'])
      : super(message, 401, 'AUTH_FAILED');
}

/// Token 过期异常
class TokenExpiredException extends ApiException {
  TokenExpiredException([String message = '登录已过期，请重新登录'])
      : super(message, 401, 'TOKEN_EXPIRED');
}

/// 用户已存在异常
class UserAlreadyExistsException extends ApiException {
  UserAlreadyExistsException([String message = '用户已存在'])
      : super(message, 400, 'USER_EXISTS');
}
