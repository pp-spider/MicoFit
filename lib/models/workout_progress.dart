/// 训练进度状态
enum WorkoutStatus {
  /// 未开始
  notStarted,
  /// 进行中
  inProgress,
  /// 已完成
  completed,
}

/// 训练进度模型
class WorkoutProgress {
  /// 日期标识（格式: YYYY-MM-DD）
  final String dateKey;

  /// 训练计划ID（关联 WorkoutPlan.id）
  final String planId;

  /// 当前状态
  final WorkoutStatus status;

  /// 当前模块索引
  final int currentModuleIndex;

  /// 当前动作索引
  final int currentExerciseIndex;

  /// 总动作数
  final int totalExercises;

  /// 已完成的动作ID列表
  final List<String> completedExerciseIds;

  /// 开始时间
  final DateTime startTime;

  /// 最后更新时间
  final DateTime lastUpdateTime;

  /// 实际训练时长（秒）
  final int actualDuration;

  WorkoutProgress({
    required this.dateKey,
    required this.planId,
    required this.status,
    required this.currentModuleIndex,
    required this.currentExerciseIndex,
    required this.totalExercises,
    required this.completedExerciseIds,
    required this.startTime,
    required this.lastUpdateTime,
    this.actualDuration = 0,
  });

  /// 创建初始进度（未开始）
  factory WorkoutProgress.createInitial({
    required String planId,
    required int totalExercises,
  }) {
    final now = DateTime.now();
    final dateKey = _formatDateKey(now);

    return WorkoutProgress(
      dateKey: dateKey,
      planId: planId,
      status: WorkoutStatus.notStarted,
      currentModuleIndex: 0,
      currentExerciseIndex: 0,
      totalExercises: totalExercises,
      completedExerciseIds: const [],
      startTime: now,
      lastUpdateTime: now,
    );
  }

  /// 从 JSON 解析（支持 camelCase 和 snake_case 两种格式）
  factory WorkoutProgress.fromJson(Map<String, dynamic> json) {
    // 兼容后端返回的 snake_case 字段名
    String? getString(String camelKey, String snakeKey) {
      return json[camelKey] as String? ?? json[snakeKey] as String?;
    }

    int? getInt(String camelKey, String snakeKey) {
      return json[camelKey] as int? ?? json[snakeKey] as int?;
    }

    List<String> getStringList(String camelKey, String snakeKey) {
      final list = json[camelKey] as List? ?? json[snakeKey] as List?;
      return list?.cast<String>() ?? [];
    }

    return WorkoutProgress(
      dateKey: getString('dateKey', 'date_key') ?? '',
      planId: getString('planId', 'plan_id') ?? '',
      status: WorkoutStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => WorkoutStatus.notStarted,
      ),
      currentModuleIndex: getInt('currentModuleIndex', 'current_module_index') ?? 0,
      currentExerciseIndex: getInt('currentExerciseIndex', 'current_exercise_index') ?? 0,
      totalExercises: getInt('totalExercises', 'total_exercises') ?? 0,
      completedExerciseIds: getStringList('completedExerciseIds', 'completed_exercise_ids'),
      startTime: DateTime.parse(getString('startTime', 'start_time') ?? DateTime.now().toIso8601String()),
      lastUpdateTime: DateTime.parse(getString('lastUpdateTime', 'last_update_time') ?? DateTime.now().toIso8601String()),
      actualDuration: getInt('actualDuration', 'actual_duration') ?? 0,
    );
  }

  /// 转换为 JSON（camelCase 格式，用于本地存储）
  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'planId': planId,
      'status': status.name,
      'currentModuleIndex': currentModuleIndex,
      'currentExerciseIndex': currentExerciseIndex,
      'totalExercises': totalExercises,
      'completedExerciseIds': completedExerciseIds,
      'startTime': startTime.toIso8601String(),
      'lastUpdateTime': lastUpdateTime.toIso8601String(),
      'actualDuration': actualDuration,
    };
  }

  /// 转换为后端 JSON（snake_case 格式，用于 API 请求）
  Map<String, dynamic> toBackendJson() {
    return {
      'date_key': dateKey,
      'plan_id': planId,
      'status': status.name,
      'current_module_index': currentModuleIndex,
      'current_exercise_index': currentExerciseIndex,
      'total_exercises': totalExercises,
      'completed_exercise_ids': completedExerciseIds,
      'start_time': startTime.toIso8601String(),
      'last_update_time': lastUpdateTime.toIso8601String(),
      'actual_duration': actualDuration,
    };
  }

  /// 计算完成百分比
  double get progressPercent {
    if (totalExercises == 0) return 0;
    return completedExerciseIds.length / totalExercises;
  }

  /// 检查是否是今天的进度
  bool get isToday {
    final today = _formatDateKey(DateTime.now());
    return dateKey == today;
  }

  /// 静态方法：格式化日期键
  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 复制并修改部分字段
  WorkoutProgress copyWith({
    String? dateKey,
    String? planId,
    WorkoutStatus? status,
    int? currentModuleIndex,
    int? currentExerciseIndex,
    int? totalExercises,
    List<String>? completedExerciseIds,
    DateTime? startTime,
    DateTime? lastUpdateTime,
    int? actualDuration,
  }) {
    return WorkoutProgress(
      dateKey: dateKey ?? this.dateKey,
      planId: planId ?? this.planId,
      status: status ?? this.status,
      currentModuleIndex: currentModuleIndex ?? this.currentModuleIndex,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      totalExercises: totalExercises ?? this.totalExercises,
      completedExerciseIds: completedExerciseIds ?? this.completedExerciseIds,
      startTime: startTime ?? this.startTime,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      actualDuration: actualDuration ?? this.actualDuration,
    );
  }
}
