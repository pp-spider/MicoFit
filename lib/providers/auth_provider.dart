import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/auth_tokens.dart';
import '../services/auth_api_service.dart';
import '../utils/user_data_helper.dart';

/// 认证状态管理
class AuthProvider extends ChangeNotifier {
  final AuthApiService _authService;

  User? _user;
  AuthTokens? _tokens;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isNewLogin = false; // 标记是否为新登录，用于数据刷新

  AuthProvider({AuthApiService? authService})
      : _authService = authService ?? AuthApiService();

  // Getters
  User? get user => _user;
  AuthTokens? get tokens => _tokens;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null && _tokens != null;
  bool get isNewLogin => _isNewLogin;

  /// 标记新登录状态为已处理
  void markNewLoginHandled() {
    _isNewLogin = false;
  }

  /// 初始化：尝试自动登录
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 检查是否有有效的 Token
      final hasValidToken = await _authService.hasValidToken();

      if (hasValidToken) {
        // 检查 Token 是否需要刷新
        final expiresAt = await _authService.getTokenExpiresAt();
        if (expiresAt != null && DateTime.now().add(const Duration(minutes: 5)).isAfter(expiresAt)) {
          // Token 即将过期，尝试刷新
          await _refreshTokenSilent();
        }

        // 获取用户信息
        _user = await _authService.getCurrentUser();

        // 设置用户数据隔离的当前用户ID
        if (_user != null) {
          UserDataHelper.setCurrentUserId(_user!.id);
        }

        // 读取存储的 Token 信息
        final accessToken = await _authService.getAccessToken();
        final refreshToken = await _authService.getRefreshToken();
        final expiresAtFinal = await _authService.getTokenExpiresAt();

        if (accessToken != null && refreshToken != null && expiresAtFinal != null) {
          _tokens = AuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: 'bearer',
            expiresIn: expiresAtFinal.difference(DateTime.now()).inSeconds,
          );
        }
      }
    } catch (e) {
      // 自动登录失败，清除本地数据
      debugPrint('自动登录失败: $e');
      await _authService.logout();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 注册
  Future<bool> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tokens = await _authService.register(
        email: email,
        password: password,
        nickname: nickname,
      );
      _user = await _authService.getCurrentUser();

      // 设置用户数据隔离的当前用户ID
      if (_user != null) {
        UserDataHelper.setCurrentUserId(_user!.id);
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 登录
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tokens = await _authService.login(
        email: email,
        password: password,
      );
      _user = await _authService.getCurrentUser();

      // 设置用户数据隔离的当前用户ID
      if (_user != null) {
        UserDataHelper.setCurrentUserId(_user!.id);
      }

      _isNewLogin = true; // 标记为新登录
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 登出
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
    } catch (e) {
      debugPrint('登出错误: $e');
    } finally {
      // 清除用户数据隔离的当前用户ID
      UserDataHelper.clearCurrentUserId();
      _user = null;
      _tokens = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 静默刷新 Token
  Future<bool> _refreshTokenSilent() async {
    try {
      final refreshToken = await _authService.getRefreshToken();
      if (refreshToken == null) return false;

      _tokens = await _authService.refreshToken(refreshToken);
      return true;
    } catch (e) {
      debugPrint('刷新 Token 失败: $e');
      // 刷新失败，清除登录状态
      await logout();
      return false;
    }
  }

  /// 解析错误消息
  String _parseErrorMessage(String error) {
    if (error.contains('邮箱已被注册')) {
      return '该邮箱已被注册，请直接登录';
    }
    if (error.contains('邮箱或密码错误')) {
      return '邮箱或密码错误，请检查后重试';
    }
    if (error.contains('用户已被禁用')) {
      return '该账号已被禁用';
    }
    if (error.contains('网络')) {
      return '网络连接失败，请检查网络后重试';
    }
    if (error.contains('401') || error.contains('403')) {
      return '登录已过期，请重新登录';
    }
    if (error.contains('500') || error.contains('502') || error.contains('503')) {
      return '服务器暂时不可用，请稍后重试';
    }
    // 返回原始错误（去除可能的 "Exception: " 前缀）
    return error.replaceFirst('Exception: ', '');
  }

  /// 清除错误消息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
