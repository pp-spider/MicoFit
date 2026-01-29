/// 应用配置
class AppConfig {
  /// API 基础地址
  static const String apiBaseUrl = 'http://127.0.0.1:9999';

  /// API 版本
  static const String apiVersion = '/api/v1';

  /// 是否启用 API（功能开关，便于测试回退）
  static const bool enableApi = true;

  /// API 失败时是否使用 fallback
  static const bool useFallbackWhenApiFails = true;

  /// 请求超时时间
  static const Duration timeout = Duration(seconds: 10);
}
