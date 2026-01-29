import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/weekly_data.dart';
import '../services/record_api_service.dart';

/// 月度统计状态管理
class MonthlyStatsProvider extends ChangeNotifier {
  final RecordApiService _apiService;

  MonthlyStats? _monthlyStats;
  bool _isLoading = false;
  String? _errorMessage;

  MonthlyStatsProvider({required RecordApiService apiService})
      : _apiService = apiService;

  // Getters
  MonthlyStats? get monthlyStats => _monthlyStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 加载月度统计
  Future<void> loadMonthlyStats(
    String userId,
    int year,
    int month,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (AppConfig.enableApi) {
        _monthlyStats = await _apiService.getMonthlyRecords(userId, year, month);
      } else {
        // 使用模拟数据
        await Future.delayed(const Duration(milliseconds: 300));
        _monthlyStats = MonthlyStats.createSample();
      }
    } catch (e) {
      _errorMessage = e.toString();
      if (AppConfig.useFallbackWhenApiFails) {
        _monthlyStats = MonthlyStats.createSample();
      } else {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
