/// 徽章等级
enum BadgeLevel {
  bronze, // 铜
  silver, // 银
  gold,   // 金
  platinum, // 白金
}

extension BadgeLevelExtension on BadgeLevel {
  String get label {
    switch (this) {
      case BadgeLevel.bronze:
        return '铜';
      case BadgeLevel.silver:
        return '银';
      case BadgeLevel.gold:
        return '金';
      case BadgeLevel.platinum:
        return '白金';
    }
  }

  String get description {
    switch (this) {
      case BadgeLevel.bronze:
        return '初级成就';
      case BadgeLevel.silver:
        return '中级成就';
      case BadgeLevel.gold:
        return '高级成就';
      case BadgeLevel.platinum:
        return '大师成就';
    }
  }

  int get points {
    switch (this) {
      case BadgeLevel.bronze:
        return 10;
      case BadgeLevel.silver:
        return 25;
      case BadgeLevel.gold:
        return 50;
      case BadgeLevel.platinum:
        return 100;
    }
  }
}

/// 徽章类型
enum BadgeType {
  streak,      // 连续打卡
  totalTime,   // 累计时长
  totalDays,   // 累计天数
  earlyBird,   // 早起鸟
  nightOwl,    // 夜猫子
  allScenes,   // 全场景
  perfectWeek, // 完美周
  feedbacker,  // 反馈达人
  firstWorkout,// 首次训练
  consistency, // 持之以恒
}

/// 成就徽章模型
class Achievement {
  final String id;
  final String name;
  final String description;
  final BadgeType type;
  final BadgeLevel level;
  final String iconName;
  final int requirement; // 达成条件数值
  final DateTime? unlockedAt;
  final bool isUnlocked;
  final int progress; // 当前进度

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.level,
    required this.iconName,
    required this.requirement,
    this.unlockedAt,
    this.isUnlocked = false,
    this.progress = 0,
  });

  /// 获取进度百分比
  double get progressPercent {
    if (requirement == 0) return 0;
    return (progress / requirement).clamp(0, 1);
  }

  /// 获取进度文本
  String get progressText {
    return '$progress/$requirement';
  }

  /// 复制并更新状态
  Achievement copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? progress,
  }) {
    return Achievement(
      id: id,
      name: name,
      description: description,
      type: type,
      level: level,
      iconName: iconName,
      requirement: requirement,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'level': level.name,
      'iconName': iconName,
      'requirement': requirement,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'progress': progress,
    };
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: BadgeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BadgeType.streak,
      ),
      level: BadgeLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => BadgeLevel.bronze,
      ),
      iconName: json['iconName'] as String,
      requirement: json['requirement'] as int,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
      progress: json['progress'] as int? ?? 0,
    );
  }
}

/// 预定义徽章列表
class AchievementDefinitions {
  static List<Achievement> get all => [
    // 连续打卡系列
    const Achievement(
      id: 'streak_7',
      name: '一周坚持',
      description: '连续打卡7天',
      type: BadgeType.streak,
      level: BadgeLevel.bronze,
      iconName: 'local_fire_department',
      requirement: 7,
    ),
    const Achievement(
      id: 'streak_30',
      name: '月度达人',
      description: '连续打卡30天',
      type: BadgeType.streak,
      level: BadgeLevel.silver,
      iconName: 'local_fire_department',
      requirement: 30,
    ),
    const Achievement(
      id: 'streak_100',
      name: '百日筑基',
      description: '连续打卡100天',
      type: BadgeType.streak,
      level: BadgeLevel.gold,
      iconName: 'local_fire_department',
      requirement: 100,
    ),

    // 累计时长系列
    const Achievement(
      id: 'time_10h',
      name: '初出茅庐',
      description: '累计训练10小时',
      type: BadgeType.totalTime,
      level: BadgeLevel.bronze,
      iconName: 'timer',
      requirement: 600,
    ),
    const Achievement(
      id: 'time_50h',
      name: '持之以恒',
      description: '累计训练50小时',
      type: BadgeType.totalTime,
      level: BadgeLevel.silver,
      iconName: 'timer',
      requirement: 3000,
    ),
    const Achievement(
      id: 'time_100h',
      name: '时间大师',
      description: '累计训练100小时',
      type: BadgeType.totalTime,
      level: BadgeLevel.gold,
      iconName: 'timer',
      requirement: 6000,
    ),

    // 累计天数系列
    const Achievement(
      id: 'days_10',
      name: '开始行动',
      description: '累计训练10天',
      type: BadgeType.totalDays,
      level: BadgeLevel.bronze,
      iconName: 'calendar_today',
      requirement: 10,
    ),
    const Achievement(
      id: 'days_50',
      name: '习惯养成',
      description: '累计训练50天',
      type: BadgeType.totalDays,
      level: BadgeLevel.silver,
      iconName: 'calendar_today',
      requirement: 50,
    ),
    const Achievement(
      id: 'days_100',
      name: '终身习惯',
      description: '累计训练100天',
      type: BadgeType.totalDays,
      level: BadgeLevel.gold,
      iconName: 'calendar_today',
      requirement: 100,
    ),

    // 完美周
    const Achievement(
      id: 'perfect_week_1',
      name: '完美一周',
      description: '一周7天全部完成训练',
      type: BadgeType.perfectWeek,
      level: BadgeLevel.bronze,
      iconName: 'emoji_events',
      requirement: 1,
    ),
    const Achievement(
      id: 'perfect_week_4',
      name: '完美月',
      description: '连续4周完美周',
      type: BadgeType.perfectWeek,
      level: BadgeLevel.silver,
      iconName: 'emoji_events',
      requirement: 4,
    ),

    // 早起鸟
    const Achievement(
      id: 'early_bird',
      name: '早起鸟',
      description: '在早上6-8点完成训练',
      type: BadgeType.earlyBird,
      level: BadgeLevel.bronze,
      iconName: 'wb_sunny',
      requirement: 1,
    ),

    // 夜猫子
    const Achievement(
      id: 'night_owl',
      name: '夜猫子',
      description: '在晚上9点后完成训练',
      type: BadgeType.nightOwl,
      level: BadgeLevel.bronze,
      iconName: 'nights_stay',
      requirement: 1,
    ),

    // 全场景
    const Achievement(
      id: 'all_scenes',
      name: '场景探索者',
      description: '在所有场景都训练过',
      type: BadgeType.allScenes,
      level: BadgeLevel.silver,
      iconName: 'explore',
      requirement: 5,
    ),

    // 反馈达人
    const Achievement(
      id: 'feedback_10',
      name: '反馈达人',
      description: '连续提交10次反馈',
      type: BadgeType.feedbacker,
      level: BadgeLevel.bronze,
      iconName: 'feedback',
      requirement: 10,
    ),

    // 首次训练
    const Achievement(
      id: 'first_workout',
      name: '迈出第一步',
      description: '完成首次训练',
      type: BadgeType.firstWorkout,
      level: BadgeLevel.bronze,
      iconName: 'directions_run',
      requirement: 1,
    ),
  ];
}
