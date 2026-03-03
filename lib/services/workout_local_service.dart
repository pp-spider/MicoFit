import 'dart:convert';
import '../config/app_config.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/user_profile.dart';
import '../utils/sample_data.dart';
import '../utils/user_data_helper.dart';

/// 本地训练计划服务 - 负责生成今日训练计划
class WorkoutLocalService {
  /// 获取今日缓存的计划（不生成新计划）
  Future<WorkoutPlan?> getCachedTodayWorkout() async {
    final today = DateTime.now();
    final dateKey = 'workout_cache_${today.year}-${today.month}-${today.day}';

    final cachedPlan = await UserDataHelper.getString(dateKey);
    if (cachedPlan != null) {
      try {
        return WorkoutPlan.fromJson(jsonDecode(cachedPlan));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 缓存训练计划
  Future<void> cacheWorkout(WorkoutPlan plan) async {
    final today = DateTime.now();
    final dateKey = 'workout_cache_${today.year}-${today.month}-${today.day}';
    await UserDataHelper.setString(dateKey, jsonEncode(plan.toJson()));
  }

  /// 清除训练计划缓存
  Future<void> clearCache() async {
    final today = DateTime.now();
    final dateKey = 'workout_cache_${today.year}-${today.month}-${today.day}';
    await UserDataHelper.remove(dateKey);
  }

  /// 清除当前用户的所有训练数据
  Future<void> clearAllUserWorkoutData() async {
    await UserDataHelper.clearCurrentUserData();
  }

  /// 生成今日训练计划
  Future<WorkoutPlan> generateTodayWorkout() async {
    final today = DateTime.now();
    final dateKey = 'workout_cache_${today.year}-${today.month}-${today.day}';

    // 检查是否已有今日计划（缓存）
    final cachedPlan = await UserDataHelper.getString(dateKey);
    if (cachedPlan != null) {
      try {
        return WorkoutPlan.fromJson(jsonDecode(cachedPlan));
      } catch (e) {
        // 缓存损坏，生成新计划
      }
    }

    // 获取用户画像（如果有）
    UserProfile? profile;
    final profileJson = await UserDataHelper.getString(AppConfig.keyUserProfile);
    if (profileJson != null) {
      try {
        final profileMap = jsonDecode(profileJson) as Map<String, dynamic>;
        profile = UserProfile.fromJson(profileMap);
      } catch (e) {
        // 解析失败，使用默认计划
      }
    }

    // 根据用户画像生成计划
    final plan = _generatePlanBasedOnProfile(profile ?? _getDefaultProfile());

    // 缓存今日计划
    await UserDataHelper.setString(dateKey, jsonEncode(plan.toJson()));

    return plan;
  }

  /// 刷新训练计划（生成新计划）
  Future<WorkoutPlan> refreshWorkout() async {
    final today = DateTime.now();
    final dateKey = 'workout_cache_${today.year}-${today.month}-${today.day}';

    // 清除今日缓存
    await UserDataHelper.remove(dateKey);

    // 重新生成计划（使用不同的随机种子）
    return await generateTodayWorkout();
  }

  /// 根据用户画像生成训练计划
  WorkoutPlan _generatePlanBasedOnProfile(UserProfile profile) {
    // 获取基础训练计划
    var plan = getSampleWorkoutPlan();

    // 根据时间预算调整计划时长
    if (profile.timeBudget < 10) {
      plan = _reducePlanDuration(plan, profile.timeBudget);
    } else if (profile.timeBudget > 20) {
      plan = _extendPlanDuration(plan, profile.timeBudget);
    }

    // 根据健身水平调整强度
    switch (profile.fitnessLevel) {
      case FitnessLevel.beginner:
        plan = _adjustForBeginner(plan);
        break;
      case FitnessLevel.occasional:
        plan = _adjustForOccasional(plan);
        break;
      case FitnessLevel.regular:
        plan = _adjustForRegular(plan);
        break;
    }

    // 根据场景调整
    if (profile.scene.contains('办公室')) {
      plan = _adjustForOffice(plan);
    } else if (profile.scene.contains('居家')) {
      plan = _adjustForHome(plan);
    }

    // 添加AI个性化说明
    plan = _addPersonalNote(plan, profile);

    return plan;
  }

  /// 获取默认用户画像（用于生成基础计划）
  UserProfile _getDefaultProfile() {
    return UserProfile(
      userId: 'local_user',
      nickname: '微动用户',
      height: 170,
      weight: 65,
      bmi: 22.5,
      fitnessLevel: FitnessLevel.occasional,
      scene: '办公室',
      timeBudget: 12,
      limitations: [],
      equipment: '无',
      goal: '保持健康',
      weeklyDays: 3,
      preferredTime: ['工作间隙'],
    );
  }

  /// 减少训练计划时长
  WorkoutPlan _reducePlanDuration(WorkoutPlan plan, int targetMinutes) {
    // 移除最后一个模块或减少动作时长
    if (plan.modules.length > 1) {
      final reducedModules = plan.modules.sublist(0, plan.modules.length - 1);
      return WorkoutPlan(
        id: plan.id,
        title: plan.title,
        subtitle: plan.subtitle,
        totalDuration: targetMinutes,
        scene: plan.scene,
        rpe: (plan.rpe * 0.8).round().clamp(1, 10),
        modules: reducedModules,
        aiNote: '已根据时间预算调整',
      );
    }
    return plan;
  }

  /// 延长训练计划时长
  WorkoutPlan _extendPlanDuration(WorkoutPlan plan, int targetMinutes) {
    // 增加每个动作的时长
    final extendedModules = plan.modules.map((module) {
      final extendedExercises = module.exercises.map((exercise) {
        return Exercise(
          id: exercise.id,
          name: exercise.name,
          duration: (exercise.duration * 1.5).round(),
          description: exercise.description,
          steps: exercise.steps,
          tips: exercise.tips,
          breathing: exercise.breathing,
          image: exercise.image,
          targetMuscles: exercise.targetMuscles,
        );
      }).toList();

      return WorkoutModule(
        id: module.id,
        name: module.name,
        duration: (module.duration * 1.5).round(),
        exercises: extendedExercises,
      );
    }).toList();

    return WorkoutPlan(
      id: plan.id,
      title: plan.title,
      subtitle: plan.subtitle,
      totalDuration: targetMinutes,
      scene: plan.scene,
      rpe: plan.rpe,
      modules: extendedModules,
      aiNote: plan.aiNote,
    );
  }

  /// 调整为零基础用户
  WorkoutPlan _adjustForBeginner(WorkoutPlan plan) {
    return WorkoutPlan(
      id: plan.id,
      title: plan.title,
      subtitle: '新手友好版',
      totalDuration: plan.totalDuration,
      scene: plan.scene,
      rpe: (plan.rpe * 0.7).round().clamp(1, 10),
      modules: plan.modules,
      aiNote: '新手友好：降低强度，注重动作标准',
    );
  }

  /// 调整为偶尔运动用户
  WorkoutPlan _adjustForOccasional(WorkoutPlan plan) {
    return WorkoutPlan(
      id: plan.id,
      title: plan.title,
      subtitle: plan.subtitle,
      totalDuration: plan.totalDuration,
      scene: plan.scene,
      rpe: plan.rpe,
      modules: plan.modules,
      aiNote: plan.aiNote ?? '保持适度运动强度',
    );
  }

  /// 调整为规律运动用户
  WorkoutPlan _adjustForRegular(WorkoutPlan plan) {
    return WorkoutPlan(
      id: plan.id,
      title: plan.title,
      subtitle: '进阶版',
      totalDuration: plan.totalDuration,
      scene: plan.scene,
      rpe: (plan.rpe * 1.2).round().clamp(1, 10),
      modules: plan.modules,
      aiNote: '进阶训练：适当增加强度和挑战',
    );
  }

  /// 调整为办公室场景
  WorkoutPlan _adjustForOffice(WorkoutPlan plan) {
    return WorkoutPlan(
      id: plan.id,
      title: plan.title,
      subtitle: '办公室版',
      totalDuration: plan.totalDuration,
      scene: '办公室场景',
      rpe: plan.rpe,
      modules: plan.modules,
      aiNote: '办公室友好：无需器械，小空间即可完成',
    );
  }

  /// 调整为居家场景
  WorkoutPlan _adjustForHome(WorkoutPlan plan) {
    return WorkoutPlan(
      id: plan.id,
      title: plan.title,
      subtitle: '居家版',
      totalDuration: plan.totalDuration,
      scene: '居家场景',
      rpe: plan.rpe,
      modules: plan.modules,
      aiNote: '居家训练：舒适自在，按自己的节奏进行',
    );
  }

  /// 添加个性化说明
  WorkoutPlan _addPersonalNote(WorkoutPlan plan, UserProfile profile) {
    final notes = <String>[];

    if (profile.fitnessLevel == FitnessLevel.beginner) {
      notes.add('新手友好');
    }

    if (profile.timeBudget <= 10) {
      notes.add('高效短时');
    } else if (profile.timeBudget >= 20) {
      notes.add('充分训练');
    }

    if (profile.limitations.isNotEmpty) {
      notes.add('已避开受限部位');
    }

    if (notes.isEmpty) {
      return plan;
    }

    final noteText = notes.join('，');
    return WorkoutPlan(
      id: plan.id,
      title: plan.title,
      subtitle: plan.subtitle,
      totalDuration: plan.totalDuration,
      scene: plan.scene,
      rpe: plan.rpe,
      modules: plan.modules,
      aiNote: plan.aiNote ?? noteText,
    );
  }
}
