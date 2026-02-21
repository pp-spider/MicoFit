import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/auth_tokens.dart';
import '../services/auth_api_service.dart';
import '../services/data_sync_service.dart';
import '../utils/user_data_helper.dart';

/// 认证状态管理
class AuthProvider extends ChangeNotifier {
  final AuthApiService _authService;

  User? _user;
  AuthTokens? _tokens;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isNewLogin = false; // 标记是否为新登录，用于数据刷新
  bool _isOfflineMode = false; // 离线模式标记（有有效Token但无法获取用户信息）

  AuthProvider({AuthApiService? authService})
      : _authService = authService ?? AuthApiService();

  // Getters
  User? get user => _user;
  AuthTokens? get tokens => _tokens;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => (_user != null && _tokens != null) || _isOfflineMode;
  bool get isNewLogin => _isNewLogin;
  bool get isOfflineMode => _isOfflineMode;

  /// 标记新登录状态为已处理
  void markNewLoginHandled() {
    _isNewLogin = false;
  }

  /// 初始化：尝试自动登录
  Future<void> init() async {
    _isLoading = true;

    // 延迟通知，避免在 widget 构建过程中调用 notifyListeners
    await Future.microtask(() {});

    try {
      // 检查是否有有效的 Token（使用本地存储，不需要网络）
      final hasValidToken = await _authService.hasValidToken();

      if (hasValidToken) {
        // 检查 Token 是否需要刷新（可能需要网络）
        // 使用 access token 的过期时间来判断是否需要刷新 access token
        final expiresAt = await _authService.getTokenExpiresAt();
        if (expiresAt != null && DateTime.now().add(const Duration(minutes: 5)).isAfter(expiresAt)) {
          // Access token 即将过期，尝试静默刷新
          await _refreshTokenSilent();
        }

        // 尝试获取用户信息（无网络时使用本地缓存）
        try {
          _user = await _authService.getCurrentUser();
          _isOfflineMode = false;
        } catch (e) {
          // 网络错误，进入离线模式
          debugPrint('获取用户信息失败（离线模式）: $e');
          final cachedUserId = await _authService.getUserId();
          if (cachedUserId != null) {
            UserDataHelper.setCurrentUserId(cachedUserId);
            _isOfflineMode = true;
            debugPrint('使用本地缓存用户ID进入离线模式');
          }
        }

        // 设置用户数据隔离的当前用户ID
        if (_user != null) {
          UserDataHelper.setCurrentUserId(_user!.id);
        }

        // 读取存储的 Token 信息
        final accessToken = await _authService.getAccessToken();
        final refreshToken = await _authService.getRefreshToken();
        final expiresAtFinal = await _authService.getTokenExpiresAt();
        final refreshTokenExpiresAt = await _authService.getRefreshTokenExpiresAt();

        if (accessToken != null && refreshToken != null && expiresAtFinal != null && refreshTokenExpiresAt != null) {
          _tokens = AuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: 'bearer',
            expiresIn: expiresAtFinal.difference(DateTime.now()).inSeconds,
            refreshTokenExpiresIn: refreshTokenExpiresAt.difference(DateTime.now()).inSeconds,
          );
        }

        // 如果是在线模式，同步后端数据
        if (!_isOfflineMode) {
          await DataSyncService().syncOnLogin();
        }

        debugPrint('自动登录完成: ${_isOfflineMode ? "离线模式" : "在线"}');
      } else {
        debugPrint('无有效Token，需要重新登录');
        _isOfflineMode = false;
      }
    } catch (e) {
      // 其他错误（如 Token 解析错误），清除本地数据
      debugPrint('自动登录失败: $e');
      _isOfflineMode = false;
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
      _isOfflineMode = false;

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
      _isOfflineMode = false;

      // 设置用户数据隔离的当前用户ID
      if (_user != null) {
        UserDataHelper.setCurrentUserId(_user!.id);
      }

      _isNewLogin = true; // 标记为新登录

      // 登录成功后同步后端数据
      await DataSyncService().syncOnLogin();

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
      // 清除当前用户的所有本地数据（SharedPreferences）
      await UserDataHelper.clearCurrentUserData();
      // 清除用户数据隔离的当前用户ID
      UserDataHelper.clearCurrentUserId();
      _user = null;
      _tokens = null;
      _isOfflineMode = false;
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
      // 网络错误或刷新失败，保持登录状态，允许离线使用
      debugPrint('刷新 Token 失败（保持离线模式）: $e');
      return false;
    }
  }

  /// 尝试恢复在线模式（网络恢复后调用）
  Future<void> restoreOnlineMode() async {
    if (!_isOfflineMode || _tokens == null) return;

    try {
      _user = await _authService.getCurrentUser();
      _isOfflineMode = false;
      notifyListeners();
      debugPrint('已恢复在线模式');
    } catch (e) {
      debugPrint('恢复在线模式失败: $e');
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
