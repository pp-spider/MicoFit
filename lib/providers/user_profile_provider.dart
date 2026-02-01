import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user_profile.dart';
import '../services/workout_local_service.dart';

/// 用户画像状态管理
class UserProfileProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfileProvider({required SharedPreferences prefs}) : _prefs = prefs;

  // Getters
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasProfile => _profile != null;

  /// 初始化
  Future<void> init() async {
    // 使用 Future.microtask 避免在 build 阶段调用 notifyListeners
    await Future.microtask(() {
      _loadFromLocal();
    });
  }

  /// 从本地加载
  void _loadFromLocal() {
    final profileJson = _prefs.getString(AppConfig.keyUserProfile);
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

  /// 保存用户画像（本地）
  Future<void> saveProfile(UserProfile profile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = profile;
      await _saveToLocal(_profile!);
      // 清除训练计划缓存，以便下次加载时基于新画像生成
      await WorkoutLocalService().clearCache();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存到本地
  Future<void> _saveToLocal(UserProfile profile) async {
    await _prefs.setString(AppConfig.keyUserProfile, jsonEncode(profile.toJson()));
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
    await _prefs.remove(AppConfig.keyUserProfile);
    _profile = null;
    notifyListeners();
  }
}
