import 'package:flutter/material.dart';
import '../models/workout_progress.dart';
import '../models/workout.dart';
import '../services/workout_progress_service.dart';

/// 训练进度状态管理
class WorkoutProgressProvider extends ChangeNotifier {
  final WorkoutProgressService _service = WorkoutProgressService();

  WorkoutProgress? _progress;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  WorkoutProgress? get progress => _progress;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get hasProgress => _progress != null;
  /// 今日是否已完成训练（需要状态为completed且有实际训练时长）
  bool get isTodayCompleted {
    if (_progress == null) return false;
    if (_progress!.status != WorkoutStatus.completed) return false;
    // 检查是否有实际训练时长（至少完成一个动作）
    if (_progress!.completedExerciseIds.isEmpty) return false;
    return true;
  }
  bool get isInProgress => _progress?.status == WorkoutStatus.inProgress;
  bool get isNotStarted => _progress?.status == WorkoutStatus.notStarted;

  /// 加载今日进度
  Future<void> loadTodayProgress() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _progress = await _service.getTodayProgress();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建初始进度
  Future<void> createInitialProgress(WorkoutPlan plan) async {
    _isLoading = true;
    notifyListeners();

    try {
      _progress = await _service.createInitialProgress(plan);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 开始训练
  Future<void> startWorkout(WorkoutPlan plan) async {
    try {
      _progress = await _service.startWorkout(plan);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// 更新进度
  Future<void> updateProgress({
    required int currentModuleIndex,
    required int currentExerciseIndex,
    required List<String> completedExerciseIds,
  }) async {
    if (_progress == null) return;

    try {
      _progress = await _service.updateProgress(
        planId: _progress!.planId,
        currentModuleIndex: currentModuleIndex,
        currentExerciseIndex: currentExerciseIndex,
        completedExerciseIds: completedExerciseIds,
      );
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// 完成训练
  /// 注意：训练记录的离线同步现在由 WorkoutProgressService 统一处理
  Future<void> completeWorkout() async {
    if (_progress == null) return;

    try {
      // 完成训练（包含进度保存和训练记录添加到离线队列）
      await _service.completeWorkout(_progress!.planId);

      await loadTodayProgress(); // 重新加载以获取更新后的状态
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// 重置进度
  Future<void> resetProgress(WorkoutPlan plan) async {
    try {
      _progress = await _service.resetTodayProgress(plan);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// 清除进度
  Future<void> clearProgress() async {
    try {
      await _service.clearProgress();
      _progress = null;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
