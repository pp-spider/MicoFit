import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/workout.dart';
import '../services/workout_api_service.dart';
import '../utils/sample_data.dart';

/// 训练计划状态管理
class WorkoutProvider extends ChangeNotifier {
  final WorkoutApiService _apiService;

  WorkoutPlan? _todayWorkout;
  bool _isLoading = false;
  String? _errorMessage;

  WorkoutProvider({required WorkoutApiService apiService})
      : _apiService = apiService;

  // Getters
  WorkoutPlan? get todayWorkout => _todayWorkout;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasWorkout => _todayWorkout != null;

  /// 加载今日训练计划
  Future<void> loadTodayWorkout(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (AppConfig.enableApi) {
        _todayWorkout = await _apiService.getTodayWorkout(userId);
      } else {
        // 使用模拟数据
        await Future.delayed(const Duration(milliseconds: 300));
        _todayWorkout = getSampleWorkoutPlan();
      }
    } catch (e) {
      _errorMessage = e.toString();
      if (AppConfig.useFallbackWhenApiFails) {
        _todayWorkout = getSampleWorkoutPlan();
      } else {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 刷新训练计划
  Future<void> refreshWorkout(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (AppConfig.enableApi) {
        _todayWorkout = await _apiService.refreshWorkout(userId);
      } else {
        // 使用模拟数据（重置一下表示刷新）
        await Future.delayed(const Duration(milliseconds: 300));
        _todayWorkout = getSampleWorkoutPlan();
      }
    } catch (e) {
      _errorMessage = e.toString();
      if (AppConfig.useFallbackWhenApiFails) {
        _todayWorkout = getSampleWorkoutPlan();
      } else {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
