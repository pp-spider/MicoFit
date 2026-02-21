/// 应用配置
class AppConfig {
  // 应用配置
  static const String appVersion = '1.0.0';

  // API 配置
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.5.14:8000',
  );

  // Token 存储 Key
  static const String keyAccessToken = 'micofit_access_token';
  static const String keyRefreshToken = 'micofit_refresh_token';
  static const String keyTokenExpiresAt = 'micofit_token_expires_at';
  static const String keyRefreshTokenExpiresAt = 'micofit_refresh_token_expires_at';
  static const String keyUserId = 'micofit_user_id';

  // 本地数据存储Key
  static const String keyUserProfile = 'micofit_user_profile';
  static const String keyWorkoutRecords = 'micofit_workout_records';
  static const String keyLocalUserId = 'micofit_local_user_id';
  static const String keyWorkoutProgress = 'micofit_workout_progress';

  // Token 有效期（秒），比后端稍短以提前刷新
  static const int accessTokenExpireSeconds = 1500; // 25分钟
  static const int refreshTokenExpireDays = 7;
}
