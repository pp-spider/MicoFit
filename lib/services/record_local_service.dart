import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/workout_record.dart';
import '../models/weekly_data.dart';
import '../models/feedback.dart';
import '../utils/user_data_helper.dart';
import 'offline_queue_service.dart';

/// 本地记录服务 - 负责训练记录的保存和查询（用户数据隔离）
class RecordLocalService {
  /// 保存训练反馈和记录
  Future<void> saveFeedback({
    required DateTime date,
    required WorkoutFeedback feedback,
    required int duration,
    bool syncToBackend = true,
  }) async {
    // 加载现有记录
    final recordsJson = await UserDataHelper.getString(AppConfig.keyWorkoutRecords);
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
    await UserDataHelper.setString(
      AppConfig.keyWorkoutRecords,
      jsonEncode(recordsList),
    );

    // 如果需要同步，添加到离线队列
    if (syncToBackend) {
      final recordData = newRecord.toJson();
      await OfflineQueueService().addFeedback(recordData);
    }
  }

  /// 加载所有训练记录
  Future<List<WorkoutRecord>> _loadAllRecords() async {
    final recordsJson = await UserDataHelper.getString(AppConfig.keyWorkoutRecords);

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

    debugPrint('[RecordLocalService] 加载到 ${records.length} 条训练记录');

    // 筛选当月记录（使用本地时区的日期进行比较）
    final monthlyRecords = records.where((record) {
      final localDate = record.date.toLocal();
      return localDate.year == year && localDate.month == month;
    }).toList();

    debugPrint('[RecordLocalService] $year年$month月有 ${monthlyRecords.length} 条记录');

    // 生成每日记录
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final List<DayRecord> dayRecords = [];
    int totalMinutes = 0;
    int completedDays = 0;

    // 按日期聚合记录（使用本地日期）
    final Map<int, List<WorkoutRecord>> recordsByDay = {};
    for (final record in monthlyRecords) {
      final localDate = record.date.toLocal();
      final day = localDate.day;
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

    // 获取用户画像来确定目标分钟数
    final profileJson = await UserDataHelper.getString(AppConfig.keyUserProfile);
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
    await UserDataHelper.remove(AppConfig.keyWorkoutRecords);
  }

  /// 保存从后端拉取的月度统计数据
  /// 将后端数据转换为训练记录并保存到本地
  Future<void> saveFromBackend(Map<String, dynamic> backendStats) async {
    final records = backendStats['records'] as List<dynamic>? ?? [];

    // 加载现有记录
    final recordsJson = await UserDataHelper.getString(AppConfig.keyWorkoutRecords);
    final List<dynamic> localRecords =
        recordsJson != null ? jsonDecode(recordsJson) as List : [];

    // 合并后端记录
    for (final record in records) {
      try {
        final recordData = record as Map<String, dynamic>;
        // 检查是否已存在（按日期判断）
        final recordDate = recordData['date'] as String?;
        if (recordDate == null) continue;

        // 检查本地是否已存在
        final existingIndex = localRecords.indexWhere((r) {
          final rDate = r['date'] as String?;
          return rDate == recordDate;
        });

        if (existingIndex == -1) {
          // 不存在，添加
          localRecords.add(recordData);
        }
        // 已存在则保留本地数据（本地优先）
      } catch (e) {
        debugPrint('[RecordLocalService] 解析后端记录失败: $e');
      }
    }

    // 保存合并后的数据
    await UserDataHelper.setString(
      AppConfig.keyWorkoutRecords,
      jsonEncode(localRecords),
    );

    debugPrint('[RecordLocalService] 保存了 ${localRecords.length} 条训练记录（含后端数据）');
  }
}
