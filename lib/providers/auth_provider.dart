import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_api_service.dart';
import '../services/auth_service.dart';
import '../services/api_exception.dart';
import '../services/user_api_service.dart';
import '../models/auth_user.dart';

/// 认证状态管理
class AuthProvider extends ChangeNotifier {
  final AuthApiService _apiService;
  final AuthService _authService = AuthService();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;
  bool? _hasProfile; // null=未检查, true/false=已检查

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;
  bool? get hasProfile => _hasProfile;
  String? get userId => _authService.userId;
  String? get token => _authService.token;

  AuthProvider({required String apiBaseUrl})
      : _apiService = AuthApiService(baseUrl: apiBaseUrl);

  /// 初始化
  Future<void> init(SharedPreferences prefs) async {
    await _authService.init(prefs);
    _isAuthenticated = _authService.isAuthenticated;
    _hasProfile = null; // 初始化时未检查
    notifyListeners();
  }

  /// 登录（支持离线模式）
  Future<bool> login(
      String userId, String password, SharedPreferences prefs) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 尝试 API 登录
      final user = AuthUser(userId: userId, password: password);
      final response = await _apiService.login(user);

      await _authService.saveSession(response, prefs);
      _isAuthenticated = true;
      _hasProfile = response.hasProfile; // 记录画像状态
      return true;
    } catch (e) {
      // 离线模式：如果 API 失败且配置允许，返回错误信息
      _errorMessage = _parseErrorMessage(e);
      _isAuthenticated = false;
      _hasProfile = null; // 失败时重置
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 注册
  Future<bool> register(
      String userId, String password, SharedPreferences prefs) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = AuthUser(userId: userId, password: password);
      final response = await _apiService.register(user);

      await _authService.saveSession(response, prefs);
      _isAuthenticated = true;
      _hasProfile = response.hasProfile; // 记录画像状态
      return true;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e);
      _isAuthenticated = false;
      _hasProfile = null; // 失败时重置
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 登出
  Future<void> logout(SharedPreferences prefs) async {
    try {
      final token = _authService.token;
      if (token != null) {
        await _apiService.logout(token);
      }
    } catch (e) {
      debugPrint('登出请求失败: $e');
    } finally {
      await _authService.clearSession(prefs);
      _isAuthenticated = false;
      _hasProfile = null; // 重置画像状态
      notifyListeners();
    }
  }

  /// 检查用户画像是否存在
  /// 用于旧版本登录后或 hasProfile 为 null 时的降级处理
  Future<void> checkProfileExists(UserApiService userApiService) async {
    if (_hasProfile != null) return; // 已知状态则不重复检查

    final userId = _authService.userId;
    if (userId == null) return;

    try {
      _hasProfile = await userApiService.checkProfileExists(userId);
    } catch (e) {
      debugPrint('检查用户画像失败: $e');
      _hasProfile = null; // 检查失败则保持未知
    } finally {
      notifyListeners();
    }
  }

  String _parseErrorMessage(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }
    return '未知错误，请稍后重试';
  }
}
