/// 应用配置
class AppConfig {
  // 应用配置
  static const String appVersion = '1.0.0';

  // API 配置
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.31.97:8000',
  );

  // Token 存储 Key
  static const String keyAccessToken = 'micofit_access_token';
  static const String keyRefreshToken = 'micofit_refresh_token';
  static const String keyTokenExpiresAt = 'micofit_token_expires_at';
  static const String keyUserId = 'micofit_user_id';

  // 本地数据存储Key
  static const String keyUserProfile = 'micofit_user_profile';
  static const String keyWorkoutRecords = 'micofit_workout_records';
  static const String keyLocalUserId = 'micofit_local_user_id';
  static const String keyWorkoutProgress = 'micofit_workout_progress';

  // AI配置 Key
  static const String keyAIBaseUrl = 'ai_base_url';
  static const String keyAIApiKey = 'ai_api_key';
  static const String keyAIModel = 'ai_model';

  // AI 配置默认值
  static const String defaultAIBaseUrl = 'https://api.openai.com';
  static const String defaultAIModel = 'gpt-4o-mini';

  // AI 配置限制
  static const int maxHistoryMessages = 10;
  static const int maxTokens = 8192;
  static const double defaultTemperature = 0.7;

  // Token 有效期（秒），比后端稍短以提前刷新
  static const int accessTokenExpireSeconds = 1500; // 25分钟
  static const int refreshTokenExpireDays = 7;
}
