import 'weekly_data.dart';

/// 洞察类型
enum InsightType {
  trend,      // 趋势分析
  suggestion, // 建议
  milestone,  // 里程碑
  warning,    // 警告
  achievement,// 成就
}

/// 智能数据洞察模型
class WorkoutInsight {
  final String id;
  final InsightType type;
  final String title;
  final String description;
  final String? actionText;
  final String? actionRoute;
  final DateTime generatedAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  const WorkoutInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.actionText,
    this.actionRoute,
    required this.generatedAt,
    this.isRead = false,
    this.metadata,
  });

  /// 获取类型图标
  String get iconName {
    switch (type) {
      case InsightType.trend:
        return 'trending_up';
      case InsightType.suggestion:
        return 'lightbulb';
      case InsightType.milestone:
        return 'emoji_events';
      case InsightType.warning:
        return 'warning';
      case InsightType.achievement:
        return 'stars';
    }
  }

  /// 获取类型颜色
  int get colorValue {
    switch (type) {
      case InsightType.trend:
        return 0xFF2DD4BF;
      case InsightType.suggestion:
        return 0xFF8B5CF6;
      case InsightType.milestone:
        return 0xFFFFD700;
      case InsightType.warning:
        return 0xFFF59E0B;
      case InsightType.achievement:
        return 0xFF10B981;
    }
  }

  WorkoutInsight copyWith({
    bool? isRead,
  }) {
    return WorkoutInsight(
      id: id,
      type: type,
      title: title,
      description: description,
      actionText: actionText,
      actionRoute: actionRoute,
      generatedAt: generatedAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'actionText': actionText,
      'actionRoute': actionRoute,
      'generatedAt': generatedAt.toIso8601String(),
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  factory WorkoutInsight.fromJson(Map<String, dynamic> json) {
    return WorkoutInsight(
      id: json['id'] as String,
      type: InsightType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => InsightType.suggestion,
      ),
      title: json['title'] as String,
      description: json['description'] as String,
      actionText: json['actionText'] as String?,
      actionRoute: json['actionRoute'] as String?,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// 洞察生成器
class InsightGenerator {
  /// 基于月度统计生成洞察
  static List<WorkoutInsight> generateFromMonthlyStats(
    MonthlyStats stats,
    MonthlyStats? previousStats,
  ) {
    final insights = <WorkoutInsight>[];
    final now = DateTime.now();

    // 1. 趋势分析
    if (previousStats != null) {
      final changePercent = previousStats.totalMinutes > 0
          ? ((stats.totalMinutes - previousStats.totalMinutes) /
                  previousStats.totalMinutes *
                  100)
              .toInt()
          : 0;

      if (changePercent > 20) {
        insights.add(WorkoutInsight(
          id: 'trend_up_${now.millisecondsSinceEpoch}',
          type: InsightType.trend,
          title: '训练量显著提升',
          description: '本月训练时长比上月增加了 $changePercent%，保持这个势头！',
          generatedAt: now,
        ));
      } else if (changePercent < -20) {
        insights.add(WorkoutInsight(
          id: 'trend_down_${now.millisecondsSinceEpoch}',
          type: InsightType.warning,
          title: '训练量有所下降',
          description: '本月训练时长比上月减少了 ${-changePercent}%，建议调整计划。',
          actionText: '查看建议',
          actionRoute: '/ai-chat',
          generatedAt: now,
        ));
      }
    }

    // 2. 目标完成建议
    if (stats.progressPercent < 50 && now.day > 20) {
      insights.add(WorkoutInsight(
        id: 'goal_warning_${now.millisecondsSinceEpoch}',
        type: InsightType.suggestion,
        title: '本月目标完成度较低',
        description: '本月已过去${now.day}天，但目标仅完成${stats.progressPercent.toInt()}%。建议增加训练频率或时长。',
        actionText: '调整目标',
        actionRoute: '/profile',
        generatedAt: now,
      ));
    }

    // 3. 连续训练建议
    final recentRecords = stats.records
        .where((r) =>
            r.date.compareTo('${now.year}-${now.month.toString().padLeft(2, '0')}-${(now.day - 7).toString().padLeft(2, '0')}') >=
            0)
        .toList();
    final gapDays = _findLongestGap(recentRecords);
    if (gapDays >= 3) {
      insights.add(WorkoutInsight(
        id: 'gap_warning_${now.millisecondsSinceEpoch}',
        type: InsightType.warning,
        title: '训练中断提醒',
        description: '您已经 $gapDays 天没有训练了，保持连续性对健身效果很重要！',
        actionText: '开始训练',
        actionRoute: '/today',
        generatedAt: now,
      ));
    }

    // 4. 最佳表现
    final bestDay = stats.records.reduce((a, b) => a.duration > b.duration ? a : b);
    if (bestDay.duration > 30) {
      insights.add(WorkoutInsight(
        id: 'best_day_${now.millisecondsSinceEpoch}',
        type: InsightType.achievement,
        title: '创纪录的一天',
        description: '${bestDay.date} 您完成了 ${bestDay.duration} 分钟的训练，是本月最佳表现！',
        generatedAt: now,
      ));
    }

    return insights;
  }

  /// 生成每周洞察
  static List<WorkoutInsight> generateWeeklyInsights(
    List<DayRecord> weekRecords,
    int weekNumber,
  ) {
    final insights = <WorkoutInsight>[];
    final now = DateTime.now();

    final completedDays = weekRecords.where((r) => r.status == DayStatus.completed).length;
    final totalMinutes = weekRecords.fold(0, (sum, r) => sum + r.duration);

    // 完美周
    if (completedDays >= 7) {
      insights.add(WorkoutInsight(
        id: 'perfect_week_${now.millisecondsSinceEpoch}',
        type: InsightType.milestone,
        title: '完美一周！',
        description: '恭喜您完成了一周7天的训练，这是${completedDays >= 7 ? '第 $weekNumber 个' : ''}完美周！',
        generatedAt: now,
      ));
    }

    // 周总结
    insights.add(WorkoutInsight(
      id: 'weekly_summary_${now.millisecondsSinceEpoch}',
      type: InsightType.trend,
      title: '本周训练总结',
      description: '本周训练 $completedDays 天，共计 $totalMinutes 分钟，平均每次 ${completedDays > 0 ? (totalMinutes / completedDays).toStringAsFixed(0) : 0} 分钟。',
      generatedAt: now,
    ));

    return insights;
  }

  static int _findLongestGap(List<DayRecord> records) {
    if (records.isEmpty) return 0;

    int maxGap = 0;
    int currentGap = 0;

    for (final record in records) {
      if (record.duration == 0) {
        currentGap++;
        if (currentGap > maxGap) {
          maxGap = currentGap;
        }
      } else {
        currentGap = 0;
      }
    }

    return maxGap;
  }
}
