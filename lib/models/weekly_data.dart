/// 每日记录状态
enum DayStatus {
  completed,  // 已完成
  partial,    // 部分完成
  planned,    // 已计划
  none,       // 未安排
}

extension DayStatusExtension on DayStatus {
  String get label {
    switch (this) {
      case DayStatus.completed:
        return '已完成';
      case DayStatus.partial:
        return '部分完成';
      case DayStatus.planned:
        return '已计划';
      case DayStatus.none:
        return '未安排';
    }
  }
}

/// 单日记录
class DayRecord {
  final String date;
  final int dayOfWeek; // 0-6, 0是周日
  final int duration;  // 分钟
  final DayStatus status;

  DayRecord({
    required this.date,
    required this.dayOfWeek,
    required this.duration,
    required this.status,
  });

  factory DayRecord.fromJson(Map<String, dynamic> json) {
    return DayRecord(
      date: json['date'] as String,
      dayOfWeek: json['dayOfWeek'] as int,
      duration: json['duration'] as int,
      status: DayStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DayStatus.none,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'dayOfWeek': dayOfWeek,
      'duration': duration,
      'status': status.name,
    };
  }
}

/// 月度统计数据
class MonthlyStats {
  final int year;
  final int month;
  final int totalMinutes;
  final int targetMinutes;
  final int completedDays;
  final List<DayRecord> records;

  MonthlyStats({
    required this.year,
    required this.month,
    required this.totalMinutes,
    required this.targetMinutes,
    required this.completedDays,
    required this.records,
  });

  /// 获取当月天数
  int get daysInMonth {
    return DateTime(year, month + 1, 0).day;
  }

  /// 获取当月第一天是周几
  int get firstDayOfWeek {
    return DateTime(year, month, 1).weekday % 7;
  }

  /// 进度百分比
  double get progressPercent {
    return (totalMinutes / targetMinutes * 100).clamp(0, 100);
  }

  /// 剩余分钟数
  int get remainingMinutes {
    return (targetMinutes - totalMinutes).clamp(0, targetMinutes);
  }

  /// 日均分钟数
  double get avgDailyMinutes {
    return completedDays > 0 ? totalMinutes / completedDays : 0;
  }

  factory MonthlyStats.fromJson(Map<String, dynamic> json) {
    return MonthlyStats(
      year: json['year'] as int,
      month: json['month'] as int,
      totalMinutes: json['totalMinutes'] as int,
      targetMinutes: json['targetMinutes'] as int,
      completedDays: json['completedDays'] as int,
      records: (json['records'] as List)
          .map((e) => DayRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
      'totalMinutes': totalMinutes,
      'targetMinutes': targetMinutes,
      'completedDays': completedDays,
      'records': records.map((e) => e.toJson()).toList(),
    };
  }

  /// 创建当前月份的空数据（全0初始化）
  factory MonthlyStats.createSample() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // 生成全0数据
    final List<DayRecord> records = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dayOfWeek = date.weekday % 7; // 0-6, 0是周日

      records.add(DayRecord(
        date: '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
        dayOfWeek: dayOfWeek,
        duration: 0,
        status: DayStatus.none,
      ));
    }

    return MonthlyStats(
      year: year,
      month: month,
      totalMinutes: 0,
      targetMinutes: 300, // 目标300分钟/月
      completedDays: 0,
      records: records,
    );
  }
}

/// 周统计数据（保留用于兼容）
class WeeklyStats {
  final int totalMinutes;
  final int targetMinutes;
  final int completedDays;
  final List<DayRecord> records;

  WeeklyStats({
    required this.totalMinutes,
    required this.targetMinutes,
    required this.completedDays,
    required this.records,
  });

  double get progressPercent {
    return (totalMinutes / targetMinutes * 100).clamp(0, 100);
  }

  int get remainingMinutes {
    return (targetMinutes - totalMinutes).clamp(0, targetMinutes);
  }

  double get avgDailyMinutes {
    return completedDays > 0 ? totalMinutes / completedDays : 0;
  }

  factory WeeklyStats.fromJson(Map<String, dynamic> json) {
    return WeeklyStats(
      totalMinutes: json['totalMinutes'] as int,
      targetMinutes: json['targetMinutes'] as int,
      completedDays: json['completedDays'] as int,
      records: (json['records'] as List)
          .map((e) => DayRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalMinutes': totalMinutes,
      'targetMinutes': targetMinutes,
      'completedDays': completedDays,
      'records': records.map((e) => e.toJson()).toList(),
    };
  }
}
