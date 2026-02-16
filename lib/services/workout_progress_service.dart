import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/workout_progress.dart';
import '../models/workout.dart';
import '../utils/user_data_helper.dart';
import 'workout_api_service.dart';
import 'offline_queue_service.dart';

/// 训练进度服务 - 管理训练进度的保存和加载
/// 支持本地持久化和后端同步，确保多设备数据一致
class WorkoutProgressService {
  /// 存储键
  static const String _keyProgress = AppConfig.keyWorkoutProgress;

  final WorkoutApiService _apiService = WorkoutApiService();

  /// 获取今日进度
  /// 优先从后端获取，后端失败时使用本地缓存
  Future<WorkoutProgress?> getTodayProgress() async {
    // 1. 尝试从后端获取
    try {
      final remoteProgress = await _apiService.getTodayProgress();
      if (remoteProgress != null) {
        // 后端有数据，同步到本地并返回
        await _saveToLocal(remoteProgress);
        debugPrint('[WorkoutProgressService] 从后端获取进度成功');
        return remoteProgress;
      }
    } catch (e) {
      debugPrint('[WorkoutProgressService] 从后端获取进度失败: $e');
    }

    // 2. 后端没有数据或失败，从本地获取
    return _getFromLocal();
  }

  /// 从本地获取进度
  Future<WorkoutProgress?> _getFromLocal() async {
    final progressJson = await UserDataHelper.getString(_keyProgress);

    if (progressJson == null) return null;

    try {
      final progress = WorkoutProgress.fromJson(
        jsonDecode(progressJson) as Map<String, dynamic>,
      );

      // 检查是否是今天的进度
      if (progress.isToday) {
        // 检查completed状态的进度是否有效（至少完成一个动作）
        if (progress.status == WorkoutStatus.completed &&
            progress.completedExerciseIds.isEmpty) {
          // 无效数据：completed状态但没有完成任何动作
          debugPrint('[WorkoutProgressService] 发现无效进度数据，自动清除');
          await clearProgress();
          return null;
        }
        return progress;
      }

      // 不是今天的进度，清除并返回null
      await clearProgress();
      return null;
    } catch (e) {
      // 解析失败，清除损坏的数据
      await clearProgress();
      return null;
    }
  }

  /// 保存进度到本地
  Future<void> _saveToLocal(WorkoutProgress progress) async {
    await UserDataHelper.setString(
      _keyProgress,
      jsonEncode(progress.toJson()),
    );
  }

  /// 保存进度（同时保存到本地和后端）
  Future<void> saveProgress(WorkoutProgress progress) async {
    // 1. 先保存到本地
    await _saveToLocal(progress);

    // 2. 同步到后端，失败时加入离线队列
    try {
      await _syncToBackend(progress);
    } catch (e) {
      debugPrint('[WorkoutProgressService] 同步到后端失败: $e');
      // 后端失败，加入离线队列等待后续同步
      await _addToOfflineQueue(progress);
    }
  }

  /// 将进度添加到离线队列
  Future<void> _addToOfflineQueue(WorkoutProgress progress) async {
    final progressData = {
      'planId': progress.planId,
      'status': progress.status.name,
      'currentModuleIndex': progress.currentModuleIndex,
      'currentExerciseIndex': progress.currentExerciseIndex,
      'completedExerciseIds': progress.completedExerciseIds,
      'actualDuration': progress.actualDuration,
      'totalExercises': progress.totalExercises,
      'startTime': progress.startTime.toIso8601String(),
    };

    // 根据状态决定操作类型
    final operationType = progress.status == WorkoutStatus.notStarted
        ? 'CREATE'
        : 'UPDATE';

    try {
      await OfflineQueueService().addWorkoutProgress(operationType, progressData);
      debugPrint('[WorkoutProgressService] 已加入离线队列');
    } catch (e) {
      debugPrint('[WorkoutProgressService] 加入离线队列失败: $e');
    }
  }

  /// 同步进度到后端
  Future<void> _syncToBackend(WorkoutProgress progress) async {
    // 根据状态决定调用哪个 API
    if (progress.status == WorkoutStatus.notStarted) {
      // 创建新进度
      await _apiService.createProgress(
        planId: progress.planId,
        totalExercises: progress.totalExercises,
      );
    } else {
      // 更新现有进度
      await _apiService.updateProgress(
        status: progress.status.name,
        currentModuleIndex: progress.currentModuleIndex,
        currentExerciseIndex: progress.currentExerciseIndex,
        completedExerciseIds: progress.completedExerciseIds,
        actualDuration: progress.actualDuration,
      );
    }
  }

  /// 创建初始进度
  Future<WorkoutProgress> createInitialProgress(WorkoutPlan plan) async {
    // 计算总动作数
    final totalExercises = plan.modules
        .fold<int>(0, (sum, module) => sum + module.exercises.length);

    final progress = WorkoutProgress.createInitial(
      planId: plan.id,
      totalExercises: totalExercises,
    );

    await saveProgress(progress);
    return progress;
  }

  /// 开始训练（状态变为进行中）
  Future<WorkoutProgress> startWorkout(WorkoutPlan plan) async {
    var progress = await getTodayProgress();

    if (progress == null || progress.planId != plan.id) {
      // 创建新进度
      progress = await createInitialProgress(plan);
    }

    // 更新状态为进行中
    final updatedProgress = progress.copyWith(
      status: WorkoutStatus.inProgress,
      lastUpdateTime: DateTime.now(),
    );

    await saveProgress(updatedProgress);
    return updatedProgress;
  }

  /// 更新当前动作进度
  Future<WorkoutProgress> updateProgress({
    required String planId,
    required int currentModuleIndex,
    required int currentExerciseIndex,
    required List<String> completedExerciseIds,
  }) async {
    final progress = await getTodayProgress();

    if (progress == null || progress.planId != planId) {
      throw StateError('未找到有效的训练进度');
    }

    // 更新进度
    final updatedProgress = progress.copyWith(
      currentModuleIndex: currentModuleIndex,
      currentExerciseIndex: currentExerciseIndex,
      completedExerciseIds: completedExerciseIds,
      lastUpdateTime: DateTime.now(),
    );

    await saveProgress(updatedProgress);
    return updatedProgress;
  }

  /// 完成训练
  Future<void> completeWorkout(String planId) async {
    final progress = await getTodayProgress();

    if (progress == null || progress.planId != planId) {
      return; // 没有进度可更新
    }

    // 计算实际训练时长
    final now = DateTime.now();
    final duration = now.difference(progress.startTime).inSeconds;

    // 更新为完成状态
    final completedProgress = progress.copyWith(
      status: WorkoutStatus.completed,
      lastUpdateTime: now,
      actualDuration: duration,
    );

    await saveProgress(completedProgress);
  }

  /// 清除进度（用于测试或重置）
  Future<void> clearProgress() async {
    await UserDataHelper.remove(_keyProgress);

    // 同时清除后端进度
    try {
      await _apiService.clearProgress();
    } catch (e) {
      debugPrint('[WorkoutProgressService] 清除后端进度失败: $e');
    }
  }

  /// 重置今日进度（用于重新开始训练）
  Future<WorkoutProgress> resetTodayProgress(WorkoutPlan plan) async {
    await clearProgress();
    return await createInitialProgress(plan);
  }
}
