import 'dart:convert';
import '../models/workout.dart';
import '../models/feedback.dart';
import 'http_client.dart';

/// 训练计划 API 服务
class WorkoutApiService {
  final ApiHttpClient _httpClient;

  WorkoutApiService({ApiHttpClient? httpClient})
      : _httpClient = httpClient ?? ApiHttpClient();

  /// 获取今日训练计划
  Future<WorkoutPlan?> getTodayPlan() async {
    final response = await _httpClient.get('/api/v1/workouts/today');

    if (response.statusCode == 404) {
      return null;
    }

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data == null) return null;

    return WorkoutPlan.fromJson(data);
  }

  /// 应用训练计划到今日
  Future<void> applyPlan(String planId) async {
    final response = await _httpClient.post(
      '/api/v1/workouts/apply',
      body: jsonEncode({'plan_id': planId}),
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }
  }

  /// 标记训练计划为已完成
  Future<void> completePlan(String planId) async {
    final response = await _httpClient.post('/api/v1/workouts/$planId/complete');

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }
  }

  /// 获取历史训练计划
  Future<List<WorkoutPlan>> getHistoryPlans({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };

    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
    }

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final response = await _httpClient.get('/api/v1/workouts/history?$queryString');

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final dynamic data = ApiHttpClient.parseResponse(response);
    if (data == null) return [];

    // 处理不同的响应格式
    List<dynamic> plansData = [];

    if (data is List) {
      plansData = data;
    } else if (data is Map && data['items'] is List) {
      plansData = data['items'] as List;
    }

    return plansData.map((p) => WorkoutPlan.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// 获取指定计划详情
  Future<WorkoutPlan> getPlan(String planId) async {
    final response = await _httpClient.get('/api/v1/workouts/$planId');

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data == null) {
      throw Exception('计划数据为空');
    }

    return WorkoutPlan.fromJson(data);
  }

  /// 提交训练反馈
  Future<void> submitFeedback({
    String? planId,
    required int duration,
    required CompletionLevel completion,
    required FeelingLevel feeling,
    required TomorrowPreference tomorrow,
    List<String>? painLocations,
    bool completed = true,
  }) async {
    final response = await _httpClient.post(
      '/api/v1/feedback',
      body: jsonEncode({
        'plan_id': planId,
        'duration': duration,
        'completion': completion.name,
        'feeling': feeling.name,
        'tomorrow': tomorrow.name,
        'pain_locations': painLocations ?? [],
        'completed': completed,
      }),
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }
  }

  /// 检查今日是否已提交反馈
  Future<bool> hasTodayFeedback() async {
    final response = await _httpClient.get('/api/v1/feedback/today');

    if (!ApiHttpClient.isSuccess(response)) {
      return false;
    }

    final data = ApiHttpClient.parseResponse(response);
    return data?['exists'] == true;
  }

  /// 获取今日反馈
  Future<Map<String, dynamic>?> getTodayFeedback() async {
    final response = await _httpClient.get('/api/v1/feedback/today');

    if (!ApiHttpClient.isSuccess(response)) {
      return null;
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data?['exists'] != true) return null;

    return data?['feedback'] as Map<String, dynamic>?;
  }

  /// 获取昨日反馈
  Future<Map<String, dynamic>?> getYesterdayFeedback() async {
    final response = await _httpClient.get('/api/v1/feedback/yesterday');

    if (!ApiHttpClient.isSuccess(response)) {
      return null;
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data?['exists'] != true) return null;

    return data?['feedback'] as Map<String, dynamic>?;
  }

  /// 获取最近反馈记录
  Future<List<Map<String, dynamic>>> getRecentFeedback({int days = 7}) async {
    final response = await _httpClient.get('/api/v1/feedback/recent?days=$days');

    if (!ApiHttpClient.isSuccess(response)) {
      return [];
    }

    final data = ApiHttpClient.parseResponse(response);
    final List<dynamic> records = data?['records'] ?? [];

    return records.cast<Map<String, dynamic>>();
  }

  /// 获取明日计划调整建议
  Future<Map<String, dynamic>?> getNextDayAdjustment() async {
    final response = await _httpClient.post('/api/v1/feedback/adjust-next');

    if (!ApiHttpClient.isSuccess(response)) {
      return null;
    }

    return ApiHttpClient.parseResponse(response);
  }
}
