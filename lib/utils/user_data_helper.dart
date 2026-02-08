import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_api_service.dart';

/// 用户数据隔离助手
/// 管理按用户隔离的本地存储
class UserDataHelper {
  static final AuthApiService _authService = AuthApiService();

  // 内存中缓存当前用户ID，避免从 storage 读取的时序问题
  static String? _currentUserId;

  /// 设置当前用户ID（在登录/注册成功后调用）
  static void setCurrentUserId(String userId) {
    _currentUserId = userId;
    debugPrint('[UserDataHelper] 设置当前用户ID: $userId');
  }

  /// 清除当前用户ID（在登出时调用）
  static void clearCurrentUserId() {
    _currentUserId = null;
    debugPrint('[UserDataHelper] 清除当前用户ID');
  }

  /// 获取当前用户ID，如果未登录返回 null
  static Future<String?> getCurrentUserId() async {
    // 优先使用内存中的 userId
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      return _currentUserId;
    }
    // 内存中没有，从 storage 读取
    final userId = await _authService.getUserId();
    if (userId != null && userId.isNotEmpty) {
      _currentUserId = userId;
    }
    return userId;
  }

  /// 构建用户隔离的存储key
  /// 格式: user_{userId}_{key}
  static Future<String> buildUserKey(String key) async {
    final userId = await getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      // 未登录时使用默认key
      return key;
    }
    return 'user_${userId}_$key';
  }

  /// 获取字符串值
  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = await buildUserKey(key);
    return prefs.getString(userKey);
  }

  /// 设置字符串值
  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = await buildUserKey(key);
    await prefs.setString(userKey, value);
  }

  /// 获取整数值
  static Future<int?> getInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = await buildUserKey(key);
    return prefs.getInt(userKey);
  }

  /// 设置整数值
  static Future<void> setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = await buildUserKey(key);
    await prefs.setInt(userKey, value);
  }

  /// 获取布尔值
  static Future<bool?> getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = await buildUserKey(key);
    return prefs.getBool(userKey);
  }

  /// 设置布尔值
  static Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = await buildUserKey(key);
    await prefs.setBool(userKey, value);
  }

  /// 获取字符串列表
  static Future<List<String>?> getStringList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = await buildUserKey(key);
    return prefs.getStringList(userKey);
  }

  /// 设置字符串列表
  static Future<void> setStringList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = await buildUserKey(key);
    await prefs.setStringList(userKey, value);
  }

  /// 删除指定key
  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = await buildUserKey(key);
    await prefs.remove(userKey);
  }

  /// 获取当前用户的所有key（用于调试）
  static Future<List<String>> getCurrentUserKeys() async {
    final userId = await getCurrentUserId();
    if (userId == null || userId.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final prefix = 'user_${userId}_';
    return allKeys.where((key) => key.startsWith(prefix)).toList();
  }

  /// 清除当前用户的所有数据
  static Future<void> clearCurrentUserData() async {
    final userId = await getCurrentUserId();
    if (userId == null || userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final prefix = 'user_${userId}_';
    final keysToRemove = prefs.getKeys().where((key) => key.startsWith(prefix)).toList();

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }
}
