import 'package:flutter/material.dart';
import '../models/weekly_data.dart';
import '../services/record_local_service.dart';
import '../services/sync_api_service.dart';

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
  /// 优先从后端获取，失败时回退到本地
  Future<void> loadMonthlyStats(
    int year,
    int month,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. 优先尝试从后端获取
      final backendStats = await _syncApiService.fetchMonthlyStats(year, month);
      if (backendStats != null) {
        // 转换为 MonthlyStats 并保存到本地缓存
        _monthlyStats = _convertToMonthlyStats(backendStats, year, month);
        // 保存到本地供离线使用
        await _localService.saveFromBackend(backendStats);
        debugPrint('[MonthlyStatsProvider] 从后端加载月度统计成功');
      } else {
        // 2. 后端获取失败，使用本地数据
        _monthlyStats = await _localService.getMonthlyStats(year, month);
        debugPrint('[MonthlyStatsProvider] 使用本地月度统计数据');
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
}
