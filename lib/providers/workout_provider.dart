import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/workout_local_service.dart';

/// 训练计划状态管理
class WorkoutProvider extends ChangeNotifier {
  final WorkoutLocalService _localService = WorkoutLocalService();

  WorkoutPlan? _todayWorkout;
  bool _isLoading = false;
  String? _errorMessage;

  WorkoutProvider();

  // Getters
  WorkoutPlan? get todayWorkout => _todayWorkout;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasWorkout => _todayWorkout != null;

  /// 加载今日训练计划
  Future<void> loadTodayWorkout() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _todayWorkout = await _localService.generateTodayWorkout();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 刷新训练计划
  Future<void> refreshWorkout() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _todayWorkout = await _localService.refreshWorkout();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 直接设置今日训练计划（用于 AI 生成的计划）
  void setWorkout(WorkoutPlan plan) {
    _todayWorkout = plan;
    _errorMessage = null;
    notifyListeners();
  }

  /// 从 JSON 加载训练计划
  void loadWorkoutFromJson(Map<String, dynamic> json) {
    try {
      _todayWorkout = WorkoutPlan.fromJson(json);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = '计划加载失败: $e';
      notifyListeners();
    }
  }
}
