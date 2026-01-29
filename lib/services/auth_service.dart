import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response.dart';

/// 认证状态
enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

/// 会话管理服务（单例）
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _keyAuth = 'micofit_auth';

  AuthResponse? _currentAuth;

  // Getters
  AuthResponse? get currentAuth => _currentAuth;
  String? get token => _currentAuth?.token;
  String? get userId => _currentAuth?.userId;
  bool get isAuthenticated => _currentAuth != null;
  AuthStatus get status =>
      isAuthenticated ? AuthStatus.authenticated : AuthStatus.unauthenticated;

  /// 初始化
  Future<void> init(SharedPreferences prefs) async {
    final authJson = prefs.getString(_keyAuth);
    if (authJson != null) {
      try {
        _currentAuth = AuthResponse.fromJson(jsonDecode(authJson));
      } catch (e) {
        await clearSession(prefs);
      }
    }
  }

  /// 保存会话
  Future<void> saveSession(
      AuthResponse auth, SharedPreferences prefs) async {
    _currentAuth = auth;
    await prefs.setString(_keyAuth, jsonEncode(auth.toJson()));
  }

  /// 清除会话
  Future<void> clearSession(SharedPreferences prefs) async {
    _currentAuth = null;
    await prefs.remove(_keyAuth);
  }
}
