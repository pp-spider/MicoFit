import 'package:flutter/material.dart';
import '../models/weekly_data.dart';
import '../services/record_local_service.dart';

/// 月度统计状态管理
class MonthlyStatsProvider extends ChangeNotifier {
  final RecordLocalService _localService = RecordLocalService();

  MonthlyStats? _monthlyStats;
  bool _isLoading = false;
  String? _errorMessage;

  MonthlyStatsProvider();

  // Getters
  MonthlyStats? get monthlyStats => _monthlyStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 加载月度统计
  Future<void> loadMonthlyStats(
    int year,
    int month,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _monthlyStats = await _localService.getMonthlyStats(year, month);
    } catch (e) {
      _errorMessage = e.toString();
      // 使用示例数据作为fallback
      _monthlyStats = MonthlyStats.createSample();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
