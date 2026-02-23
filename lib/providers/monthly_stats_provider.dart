import 'package:flutter/material.dart';
import '../models/weekly_data.dart';
import '../services/record_local_service.dart';
import '../services/sync_api_service.dart';
import '../services/offline_queue_service.dart';

/// 月度统计状态管理
class MonthlyStatsProvider extends ChangeNotifier {
  final RecordLocalService _localService = RecordLocalService();
  final SyncApiService _syncApiService = SyncApiService();

  MonthlyStats? _monthlyStats;
  bool _isLoading = false;
  String? _errorMessage;

  MonthlyStatsProvider();

  // Getters
  MonthlyStats? get monthlyStats => _monthlyStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 加载月度统计
  /// 优先从后端获取，但如果本地有未同步的记录，需要合并显示
  /// 修复：确保离线期间的本地记录不被后端覆盖
  Future<void> loadMonthlyStats(
    int year,
    int month,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. 同时获取后端数据和本地数据
      final backendFuture = _syncApiService.fetchMonthlyStats(year, month);
      final localFuture = _localService.getMonthlyStats(year, month);

      final backendStats = await backendFuture;
      final localStats = await localFuture;

      // 2. 检查是否有未同步的记录（离线期间生成的记录）
      final hasPendingSync = await _checkPendingSync(year, month);

      if (backendStats != null) {
        // 后端有数据
        final backendMonthly = _convertToMonthlyStats(backendStats, year, month);

        // 3. 如果有未同步的本地记录，合并数据（本地优先）
        if (hasPendingSync) {
          debugPrint('[MonthlyStatsProvider] 检测到未同步记录，合并本地数据');
          _monthlyStats = _mergeWithPendingLocalData(backendMonthly, localStats);
        } else {
          _monthlyStats = backendMonthly;
        }

        // 保存到本地供离线使用
        await _localService.saveFromBackend(backendStats);
        debugPrint('[MonthlyStatsProvider] 从后端加载月度统计成功');
      } else {
        // 后端获取失败，使用本地数据（可能是离线状态）
        _monthlyStats = localStats;
        debugPrint('[MonthlyStatsProvider] 后端获取失败，使用本地数据');
      }
    } catch (e) {
      _errorMessage = e.toString();
      // 出错时使用本地数据
      try {
        _monthlyStats = await _localService.getMonthlyStats(year, month);
      } catch (_) {
        // 本地也失败，使用示例数据
        _monthlyStats = MonthlyStats.createSample();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 检查指定月份是否有未同步的记录
  Future<bool> _checkPendingSync(int year, int month) async {
    final pendingOps = OfflineQueueService().getOperationsByType(
      PendingOperationType.workoutRecord,
    );

    for (final op in pendingOps) {
      final completedAt = op.data['completedAt'] as String?;
      if (completedAt != null) {
        try {
          final recordDate = DateTime.parse(completedAt);
          if (recordDate.year == year && recordDate.month == month) {
            return true;
          }
        } catch (e) {
          // 解析失败，忽略
        }
      }
    }
    return false;
  }

  /// 合并后端数据与本地未同步数据
  /// 策略：本地优先，特别是对于今天和最近生成的记录
  MonthlyStats _mergeWithPendingLocalData(
    MonthlyStats backendStats,
    MonthlyStats localStats,
  ) {
    // 创建后端记录的日期映射
    final backendDates = <String, DayRecord>{};
    for (final record in backendStats.records) {
      backendDates[record.date] = record;
    }

    // 合并记录，本地优先
    final mergedRecords = <DayRecord>[];
    final now = DateTime.now();
    final isCurrentMonth = now.year == localStats.year && now.month == localStats.month;

    for (final localRecord in localStats.records) {
      // 如果本地有有效记录（训练时长 > 0），使用本地记录
      if (localRecord.duration > 0) {
        // 检查后端是否有这个日期的记录
        if (backendDates.containsKey(localRecord.date)) {
          // 后端也有，但本地有数据，选择本地
          // 这是正确的行为，因为本地可能是离线期间生成的
          mergedRecords.add(localRecord);
        } else {
          // 后端没有这个日期的记录（可能是未同步的），使用本地
          mergedRecords.add(localRecord);
        }
      } else if (isCurrentMonth && localRecord.date.endsWith('-${now.day.toString().padLeft(2, '0')}')) {
        // 今天的记录还没有，使用后端的（如果有）
        if (backendDates.containsKey(localRecord.date)) {
          mergedRecords.add(backendDates[localRecord.date]!);
        } else {
          mergedRecords.add(localRecord);
        }
      } else {
        // 本地没有训练记录，使用后端记录
        if (backendDates.containsKey(localRecord.date)) {
          mergedRecords.add(backendDates[localRecord.date]!);
        } else {
          mergedRecords.add(localRecord);
        }
      }
    }

    // 重新计算统计数据
    final totalMinutes = mergedRecords.fold<int>(0, (sum, r) => sum + r.duration);
    final completedDays = mergedRecords.where((r) => r.status == DayStatus.completed).length;

    return MonthlyStats(
      year: localStats.year,
      month: localStats.month,
      totalMinutes: totalMinutes,
      targetMinutes: localStats.targetMinutes,
      completedDays: completedDays,
      records: mergedRecords,
    );
  }

  /// 将后端数据转换为 MonthlyStats
  MonthlyStats _convertToMonthlyStats(Map<String, dynamic> data, int year, int month) {
    final totalMinutes = data['total_minutes'] as int? ?? 0;
    final targetMinutes = data['target_minutes'] as int? ?? 300;
    final completedDays = data['completed_days'] as int? ?? 0;
    final records = data['records'] as List<dynamic>? ?? [];

    final dayRecords = <DayRecord>[];
    for (final record in records) {
      dayRecords.add(DayRecord.fromJson(record as Map<String, dynamic>));
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

  /// 刷新月度统计（强制从后端获取）
  Future<void> refreshMonthlyStats(int year, int month) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final backendStats = await _syncApiService.fetchMonthlyStats(year, month);
      if (backendStats != null) {
        _monthlyStats = _convertToMonthlyStats(backendStats, year, month);
        await _localService.saveFromBackend(backendStats);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清除月度统计数据（用户切换时调用）
  void clearStats() {
    _monthlyStats = null;
    _errorMessage = null;
    notifyListeners();
  }
}
