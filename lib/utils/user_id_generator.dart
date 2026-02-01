import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// 用户ID生成器 - 负责生成或获取本地用户ID
class UserIdGenerator {
  static const String _localUserId = 'local_user_001';

  /// 获取或创建本地用户ID
  static Future<String> getOrCreateLocalUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(AppConfig.keyLocalUserId);

    if (userId == null) {
      userId = _localUserId;
      await prefs.setString(AppConfig.keyLocalUserId, userId);
    }

    return userId;
  }

  /// 获取当前用户ID
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.keyLocalUserId);
  }

  /// 重置用户ID
  static Future<void> resetUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.keyLocalUserId);
  }
}
