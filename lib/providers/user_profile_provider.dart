import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/user_profile.dart';
import '../services/workout_local_service.dart';
import '../services/user_api_service.dart';
import '../utils/user_data_helper.dart';

/// 用户画像状态管理（用户数据隔离）
class UserProfileProvider extends ChangeNotifier {
  final UserApiService _apiService;

  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfileProvider({
    UserApiService? apiService,
  })  : _apiService = apiService ?? UserApiService();

  // Getters
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasProfile => _profile != null;

  /// 初始化 - 优先从后端获取，失败时回退到本地
  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 尝试从后端获取用户画像
      final serverProfile = await _apiService.getProfile();
      if (serverProfile != null) {
        _profile = serverProfile;
        // 同步到本地
        await _saveToLocal(_profile!);
      } else {
        // 后端返回 null（可能是网络错误），从本地加载
        await _loadFromLocal();
      }
    } catch (e) {
      // 后端获取失败，尝试从本地加载
      await _loadFromLocal();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 从本地加载
  Future<void> _loadFromLocal() async {
    final profileJson = await UserDataHelper.getString(AppConfig.keyUserProfile);
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

  /// 保存用户画像（本地+后端）
  Future<void> saveProfile(UserProfile profile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = profile;
      // 1. 先保存到本地
      await _saveToLocal(_profile!);

      // 2. 尝试同步到后端（使用 upsert，不存在则创建，存在则更新）
      try {
        final serverProfile = await _apiService.upsertProfile(_profile!);
        _profile = serverProfile;
        await _saveToLocal(_profile!);
        debugPrint('用户画像同步到后端成功');
      } catch (e) {
        debugPrint('用户画像同步到后端失败: $e');
        // 后端同步失败不影响本地保存，后续可以再次同步
      }

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
    await UserDataHelper.setString(AppConfig.keyUserProfile, jsonEncode(profile.toJson()));
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

  /// 从后端获取最新用户画像
  Future<bool> fetchFromServer() async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final serverProfile = await _apiService.getProfile();
      if (serverProfile != null) {
        _profile = serverProfile;
        await _saveToLocal(_profile!);
        return true;
      } else {
        _errorMessage = '无法从服务器获取用户画像';
        return false;
      }
    } catch (e) {
      _errorMessage = '获取用户画像失败: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 同步本地画像到后端
  Future<bool> syncToServer() async {
    if (_profile == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final serverProfile = await _apiService.upsertProfile(_profile!);
      _profile = serverProfile;
      await _saveToLocal(_profile!);
      debugPrint('同步用户画像到后端成功');
      return true;
    } catch (e) {
      debugPrint('同步用户画像到后端失败: $e');
      _errorMessage = '同步失败: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清除用户画像（仅清除当前用户的）
  Future<void> clearProfile() async {
    await UserDataHelper.remove(AppConfig.keyUserProfile);
    _profile = null;
    notifyListeners();
  }
}
