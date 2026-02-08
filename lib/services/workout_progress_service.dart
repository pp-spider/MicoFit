import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/workout_progress.dart';
import '../models/workout.dart';

/// 训练进度服务 - 管理训练进度的保存和加载
class WorkoutProgressService {
  /// 存储键
  static const String _keyProgress = AppConfig.keyWorkoutProgress;

  /// 获取今日进度
  Future<WorkoutProgress?> getTodayProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final progressJson = prefs.getString(_keyProgress);

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

  /// 保存进度
  Future<void> saveProgress(WorkoutProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyProgress,
      jsonEncode(progress.toJson()),
    );
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProgress);
  }

  /// 重置今日进度（用于重新开始训练）
  Future<WorkoutProgress> resetTodayProgress(WorkoutPlan plan) async {
    await clearProgress();
    return await createInitialProgress(plan);
  }
}
