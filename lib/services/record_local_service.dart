import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/workout_record.dart';
import '../models/weekly_data.dart';
import '../models/feedback.dart';

/// 本地记录服务 - 负责训练记录的保存和查询
class RecordLocalService {
  /// 保存训练反馈和记录
  Future<void> saveFeedback({
    required DateTime date,
    required WorkoutFeedback feedback,
    required int duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 加载现有记录
    final recordsJson = prefs.getString(AppConfig.keyWorkoutRecords);
    final List<dynamic> recordsList =
        recordsJson != null ? jsonDecode(recordsJson) as List : [];

    // 添加新记录
    final newRecord = WorkoutRecord(
      date: date,
      duration: duration,
      feedback: feedback,
      completed: true,
    );

    recordsList.add(newRecord.toJson());

    // 保存回存储
    await prefs.setString(
      AppConfig.keyWorkoutRecords,
      jsonEncode(recordsList),
    );
  }

  /// 加载所有训练记录
  Future<List<WorkoutRecord>> _loadAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getString(AppConfig.keyWorkoutRecords);

    if (recordsJson == null) return [];

    try {
      final recordsList = jsonDecode(recordsJson) as List;
      return recordsList
          .map((json) => WorkoutRecord.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取月度统计数据
  Future<MonthlyStats> getMonthlyStats(int year, int month) async {
    final records = await _loadAllRecords();

    // 筛选当月记录
    final monthlyRecords = records.where((record) {
      final d = record.date;
      return d.year == year && d.month == month;
    }).toList();

    // 生成每日记录
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final List<DayRecord> dayRecords = [];
    int totalMinutes = 0;
    int completedDays = 0;

    // 按日期聚合记录
    final Map<int, List<WorkoutRecord>> recordsByDay = {};
    for (final record in monthlyRecords) {
      final day = record.date.day;
      recordsByDay.putIfAbsent(day, () => []).add(record);
    }

    // 生成每日记录
    final now = DateTime.now();
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dayOfWeek = date.weekday % 7;
      final isToday = now.year == year && now.month == month && now.day == day;
      final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

      DayStatus status;
      int duration = 0;

      if (recordsByDay.containsKey(day)) {
        final dayRecordsList = recordsByDay[day]!;
        duration = dayRecordsList.fold(0, (sum, r) => sum + r.duration);
        status = DayStatus.completed;
        totalMinutes += duration;
        completedDays++;
      } else if (isToday) {
        status = DayStatus.planned;
      } else if (isPast) {
        status = DayStatus.none;
      } else {
        status = DayStatus.none;
      }

      dayRecords.add(DayRecord(
        date: '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
        dayOfWeek: dayOfWeek,
        duration: duration,
        status: status,
      ));
    }

    // 获取用户画像来确定目标分钟数（可选，这里使用默认值）
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(AppConfig.keyUserProfile);
    int targetMinutes = 300; // 默认目标300分钟/月

    if (profileJson != null) {
      try {
        final profile = jsonDecode(profileJson) as Map<String, dynamic>;
        final weeklyDays = profile['weeklyDays'] as int? ?? 3;
        final timeBudget = profile['timeBudget'] as int? ?? 12;
        // 目标 = 每周天数 * 每次时长 * 4周
        targetMinutes = weeklyDays * timeBudget * 4;
      } catch (e) {
        // 使用默认值
      }
    }

    return MonthlyStats(
      year: year,
      month: month,
      totalMinutes: totalMinutes,
      targetMinutes: targetMinutes,
      completedDays: completedDays,
      records: dayRecords,
    );
  }

  /// 获取最近的反馈记录
  Future<List<WorkoutRecord>> getRecentRecords({int limit = 10}) async {
    final records = await _loadAllRecords();

    // 按日期降序排序
    records.sort((a, b) => b.date.compareTo(a.date));

    return records.take(limit).toList();
  }

  /// 清除所有记录
  Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.keyWorkoutRecords);
  }
}
