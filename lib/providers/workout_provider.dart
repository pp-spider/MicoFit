import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/workout_local_service.dart';
import '../services/workout_api_service.dart';

/// 训练计划状态管理
/// 优先从后端获取数据，失败时降级到本地
class WorkoutProvider extends ChangeNotifier {
  final WorkoutLocalService _localService = WorkoutLocalService();
  final WorkoutApiService _apiService = WorkoutApiService();

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
  /// 优先从后端获取最新的训练计划，如果后端没有则使用本地生成
  Future<void> loadTodayWorkout() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. 优先从后端获取最新的训练计划
      final backendPlan = await _apiService.getLatestPlan();
      if (backendPlan != null) {
        _todayWorkout = backendPlan;
        // 同时缓存到本地
        await _localService.cacheWorkout(backendPlan);
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 2. 后端没有计划，尝试从本地缓存获取
      final localPlan = await _localService.getCachedTodayWorkout();
      if (localPlan != null) {
        _todayWorkout = localPlan;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 3. 本地也没有，生成默认计划
      _todayWorkout = await _localService.generateTodayWorkout();
    } catch (e) {
      _errorMessage = e.toString();
      // 出错时尝试使用本地数据
      try {
        final localPlan = await _localService.getCachedTodayWorkout();
        if (localPlan != null) {
          _todayWorkout = localPlan;
        } else {
          _todayWorkout = await _localService.generateTodayWorkout();
        }
      } catch (_) {
        // 忽略本地错误
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 刷新训练计划
  /// 清除本地缓存并重新获取
  Future<void> refreshWorkout() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 清除本地缓存
      await _localService.clearCache();

      // 重新获取（会先从后端获取，如果没有则生成新的）
      await loadTodayWorkout();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 直接设置今日训练计划（用于 AI 生成的计划）
  /// 同时会缓存到本地
  void setWorkout(WorkoutPlan plan) {
    _todayWorkout = plan;
    _errorMessage = null;
    // 异步缓存到本地
    _localService.cacheWorkout(plan).catchError((e) {
      debugPrint('缓存计划失败: $e');
    });
    notifyListeners();
  }

  /// 应用计划到今日（调用后端API）
  Future<void> applyPlan(String planId) async {
    try {
      await _apiService.applyPlan(planId);
    } catch (e) {
      debugPrint('应用计划到后端失败: $e');
      // 不抛出错误，允许离线使用
    }
  }

  /// 标记计划为已完成（调用后端API）
  Future<void> completePlan(String planId) async {
    try {
      await _apiService.completePlan(planId);
    } catch (e) {
      debugPrint('标记计划完成到后端失败: $e');
      // 不抛出错误，允许离线使用
    }
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

  /// 获取历史训练计划（从后端）
  Future<List<WorkoutPlan>> getHistoryPlans({DateTime? startDate, DateTime? endDate}) async {
    try {
      return await _apiService.getHistoryPlans(startDate: startDate, endDate: endDate);
    } catch (e) {
      debugPrint('获取历史计划失败: $e');
      return [];
    }
  }
}
