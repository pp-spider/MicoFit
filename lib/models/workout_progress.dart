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

  /// 从 JSON 解析
  factory WorkoutProgress.fromJson(Map<String, dynamic> json) {
    return WorkoutProgress(
      dateKey: json['dateKey'] as String,
      planId: json['planId'] as String,
      status: WorkoutStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => WorkoutStatus.notStarted,
      ),
      currentModuleIndex: json['currentModuleIndex'] as int? ?? 0,
      currentExerciseIndex: json['currentExerciseIndex'] as int? ?? 0,
      totalExercises: json['totalExercises'] as int,
      completedExerciseIds:
          (json['completedExerciseIds'] as List?)?.cast<String>() ?? [],
      startTime: DateTime.parse(json['startTime'] as String),
      lastUpdateTime: DateTime.parse(json['lastUpdateTime'] as String),
      actualDuration: json['actualDuration'] as int? ?? 0,
    );
  }

  /// 转换为 JSON
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
