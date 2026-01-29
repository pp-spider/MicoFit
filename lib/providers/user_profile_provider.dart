import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user_profile.dart';
import '../services/user_api_service.dart';

/// 用户画像状态管理
class UserProfileProvider extends ChangeNotifier {
  final UserApiService _apiService;
  final SharedPreferences _prefs;

  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  static const String _keyProfile = 'micofit_user_profile';

  UserProfileProvider({
    required UserApiService apiService,
    required SharedPreferences prefs,
  })  : _apiService = apiService,
        _prefs = prefs;

  // Getters
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasProfile => _profile != null;

  /// 初始化：根据 hasProfile 状态决定加载策略
  Future<void> init({bool hasProfile = false}) async {
    _loadFromLocal();

    if (AppConfig.enableApi && hasProfile && _profile != null) {
      // 后端确认有画像，从服务器同步
      await _syncFromServer();
    } else if (AppConfig.enableApi && !hasProfile) {
      // 后端确认无画像，清除本地缓存
      await clearProfile();
    }
  }

  /// 从本地加载
  void _loadFromLocal() {
    final profileJson = _prefs.getString(_keyProfile);
    if (profileJson != null) {
      try {
        final profileMap = jsonDecode(profileJson) as Map<String, dynamic>;
        _profile = UserProfile.fromJson(profileMap);
        notifyListeners();
      } catch (e) {
        debugPrint('解析本地用户数据失败: $e');
      }
    }
  }

  /// 从服务器同步
  Future<void> _syncFromServer() async {
    if (_profile?.userId == null) return;

    try {
      final serverProfile = await _apiService.getUserProfile(_profile!.userId);
      await _saveToLocal(serverProfile);
      _profile = serverProfile;
      notifyListeners();
    } catch (e) {
      debugPrint('同步用户数据失败: $e');
    }
  }

  /// 保存用户画像（本地 + API）
  Future<void> saveProfile(UserProfile profile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (AppConfig.enableApi) {
        _profile = await _apiService.createUserProfile(profile);
      } else {
        _profile = profile;
      }

      await _saveToLocal(_profile!);
    } catch (e) {
      _errorMessage = e.toString();
      if (AppConfig.useFallbackWhenApiFails) {
        _profile = profile;
        await _saveToLocal(profile);
      } else {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存到本地
  Future<void> _saveToLocal(UserProfile profile) async {
    await _prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
  }

  /// 更新目标设置
  Future<void> updateGoals({
    int? weeklyDays,
    int? timeBudget,
  }) async {
    if (_profile == null) return;

    final updatedProfile = UserProfile(
      userId: _profile!.userId,
      nickname: _profile!.nickname,
      height: _profile!.height,
      weight: _profile!.weight,
      bmi: _profile!.bmi,
      fitnessLevel: _profile!.fitnessLevel,
      scene: _profile!.scene,
      timeBudget: timeBudget ?? _profile!.timeBudget,
      limitations: _profile!.limitations,
      equipment: _profile!.equipment,
      goal: _profile!.goal,
      weeklyDays: weeklyDays ?? _profile!.weeklyDays,
      preferredTime: _profile!.preferredTime,
      createdAt: _profile!.createdAt,
      updatedAt: _profile!.updatedAt,
    );

    await saveProfile(updatedProfile);
  }

  /// 清除用户画像
  Future<void> clearProfile() async {
    await _prefs.remove(_keyProfile);
    _profile = null;
    notifyListeners();
  }
}
