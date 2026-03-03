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
      // 转换为后端期望的格式
      final feedbackData = {
        'plan_id': null,  // 后端可选
        'record_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'duration': duration,
        'completion': feedback.completion.name,
        'feeling': feedback.feeling.name,
        'tomorrow': feedback.tomorrow.name,
        'pain_locations': feedback.painLocations,
        'completed': true,
      };
      await OfflineQueueService().addFeedback(feedbackData);
    }
  }

  /// 加载所有训练记录
  Future<List<WorkoutRecord>> _loadAllRecords() async {
    final recordsJson = await UserDataHelper.getString(AppConfig.keyWorkoutRecords);
    
    if (recordsJson == null) return [];

    try {
      final recordsList = jsonDecode(recordsJson) as List;
      debugPrint('[RecordLocalService] 原始 JSON 记录数: ${recordsList.length}');
      // 检查前几条记录的格式
      if (recordsList.isNotEmpty) {
        final firstRecord = recordsList[0] as Map<String, dynamic>;
        debugPrint('[RecordLocalService] 第一条记录 keys: ${firstRecord.keys.toList()}');
      }

      return recordsList
          .map((json) => WorkoutRecord.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[RecordLocalService] 解析记录失败: $e');
      return [];
    }
  }

  /// 获取月度统计数据
  Future<MonthlyStats> getMonthlyStats(int year, int month) async {
    final records = await _loadAllRecords();

    debugPrint('[RecordLocalService] 加载到 ${records.length} 条训练记录');

    // 筛选当月记录（使用日期部分比较，避免时区转换导致错误）
    // 只比较年月日，不进行时区转换，确保数据准确性
    final monthlyRecords = records.where((record) {
      // 提取日期部分进行比较（处理 ISO8601 格式）
      final dateStr = record.date.toIso8601String().split('T').first;
      final recordDate = DateTime.parse(dateStr);
      return recordDate.year == year && recordDate.month == month;
    }).toList();

    debugPrint('[RecordLocalService] $year年$month月有 ${monthlyRecords.length} 条记录');

    // 生成每日记录
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final List<DayRecord> dayRecords = [];
    int totalMinutes = 0;
    int completedDays = 0;

    // 按日期聚合记录（使用统一格式的日期字符串作为 key）
    // 注意：统一使用 padLeft 确保格式一致，避免跨月数据错误
    final Map<String, List<WorkoutRecord>> recordsByDay = {};
    for (final record in monthlyRecords) {
      final localDate = record.date.toLocal();
      // 使用 padLeft 确保格式一致，如 "2026-02-05"
      final dateKey = '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
      recordsByDay.putIfAbsent(dateKey, () => []).add(record);
    }

    // 生成每日记录
    final now = DateTime.now();
    // 使用本地时区的"今天"日期进行判断
    final today = DateTime(now.year, now.month, now.day);
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dayOfWeek = date.weekday % 7;
      final isToday = today.year == year && today.month == month && today.day == day;
      final isPast = date.isBefore(today);
      // 使用与 recordsByDay 相同的格式
      final dateKey = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

      DayStatus status;
      int duration = 0;

      if (recordsByDay.containsKey(dateKey)) {
        final dayRecordsList = recordsByDay[dateKey]!;
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
  /// 只保存 completed（已完成）和 partial（部分完成）状态的记录
  Future<void> saveFromBackend(Map<String, dynamic> backendStats) async {
    final records = backendStats['records'] as List<dynamic>? ?? [];

    debugPrint('[RecordLocalService] 后端返回 ${records.length} 条记录');

    // 加载现有记录
    final recordsJson = await UserDataHelper.getString(AppConfig.keyWorkoutRecords);
    final List<dynamic> localRecords =
        recordsJson != null ? jsonDecode(recordsJson) as List : [];

    debugPrint('[RecordLocalService] 本地现有 ${localRecords.length} 条记录');

    // 先清理本地无效记录（只保留 completed 和 partial）
    final validLocalRecords = localRecords.where((r) {
      try {
        final record = r as Map<String, dynamic>;
        final completed = record['completed'] as bool? ?? false;
        // 保留 completed=true 的记录
        return completed == true;
      } catch (e) {
        return false;
      }
    }).toList();

    if (validLocalRecords.length != localRecords.length) {
      debugPrint('[RecordLocalService] 清理了 ${localRecords.length - validLocalRecords.length} 条无效记录');
    }

    // 合并后端记录（只处理 completed 和 partial）
    int addedCount = 0;
    for (final record in records) {
      try {
        final recordData = record as Map<String, dynamic>;
        final recordDate = recordData['date'] as String?;
        if (recordDate == null) continue;

        // 只处理已完成和部分完成的记录
        final status = recordData['status'] as String?;
        final duration = recordData['duration'] as int? ?? 0;

        // 过滤：只保存 completed 或 partial，且有训练时长
        final isValidStatus = status == 'completed' || status == 'partial';
        if (!isValidStatus || duration <= 0) continue;

        // 检查本地是否已存在
        final existingIndex = validLocalRecords.indexWhere((r) {
          final rDate = r['date'] as String?;
          final localDatePart = rDate?.split('T').first;
          return localDatePart == recordDate;
        });

        if (existingIndex == -1) {
          // 构建完整的训练记录数据
          final completeRecord = {
            'date': recordDate,
            'duration': duration,
            'feedback': {
              'completion': status == 'completed' ? 'smooth' : 'barely',
              'feeling': 'justRight',
              'tomorrow': 'maintain',
              'painLocations': <String>[],
            },
            'completed': status == 'completed',
          };
          validLocalRecords.add(completeRecord);
          addedCount++;
          debugPrint('[RecordLocalService] 添加后端记录: $recordDate, status: $status, 时长: $duration');
        }
      } catch (e) {
        debugPrint('[RecordLocalService] 解析后端记录失败: $e');
      }
    }

    // 保存合并后的数据
    await UserDataHelper.setString(
      AppConfig.keyWorkoutRecords,
      jsonEncode(validLocalRecords),
    );

    debugPrint('[RecordLocalService] 保存了 ${validLocalRecords.length} 条训练记录（新增 $addedCount 条）');
  }
}
