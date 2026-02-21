import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import '../models/feedback.dart';
import '../models/workout_progress.dart';
import 'http_client.dart';

/// 训练计划 API 服务
class WorkoutApiService {
  final ApiHttpClient _httpClient;

  WorkoutApiService({ApiHttpClient? httpClient})
      : _httpClient = httpClient ?? ApiHttpClient();

  /// 获取今日训练计划
  /// [date] 可选，指定日期，格式为 yyyy-MM-dd，默认为今日
  Future<WorkoutPlan?> getTodayPlan({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

      final response = await _httpClient.get(
        '/api/v1/workouts/today',
        queryParams: {'plan_date': dateStr},
      );

      if (response.statusCode == 404) {
        return null;
      }

      if (!ApiHttpClient.isSuccess(response)) {
        // API 返回错误（非网络错误），返回 null 让前端使用本地数据
        debugPrint('获取今日计划API错误: ${response.statusCode}');
        return null;
      }

      final data = ApiHttpClient.parseResponse(response);
      if (data == null) return null;

      return WorkoutPlan.fromJson(data);
    } catch (e) {
      // 网络错误，返回 null 让前端使用本地数据
      debugPrint('获取今日计划网络错误: $e');
      return null;
    }
  }

  /// 获取最新的训练计划（按创建时间排序）
  Future<WorkoutPlan?> getLatestPlan() async {
    try {
      final response = await _httpClient.get('/api/v1/workouts/latest');

      if (response.statusCode == 404) {
        return null;
      }

      if (!ApiHttpClient.isSuccess(response)) {
        debugPrint('获取最新计划API错误: ${response.statusCode}');
        return null;
      }

      final data = ApiHttpClient.parseResponse(response);
      if (data == null) return null;

      return WorkoutPlan.fromJson(data);
    } catch (e) {
      debugPrint('获取最新计划网络错误: $e');
      return null;
    }
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

    debugPrint('[WorkoutApiService] /history 响应状态: ${response.statusCode}');
    debugPrint('[WorkoutApiService] /history 响应体: ${response.body}');

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    // /history 返回的是列表，不是 Map，需要直接解析
    final dynamic data = jsonDecode(response.body);
    debugPrint('[WorkoutApiService] /history 返回数据: $data');
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

  // ========== 训练进度 API ==========

  /// 获取今日训练进度
  Future<WorkoutProgress?> getTodayProgress() async {
    try {
      final response = await _httpClient.get('/api/v1/workouts/progress/today');

      if (response.statusCode == 404 || response.statusCode == 204) {
        return null;
      }

      if (!ApiHttpClient.isSuccess(response)) {
        debugPrint('获取今日进度API错误: ${response.statusCode}');
        return null;
      }

      final data = ApiHttpClient.parseResponse(response);
      if (data == null) return null;

      return WorkoutProgress.fromJson(data);
    } catch (e) {
      debugPrint('获取今日进度网络错误: $e');
      return null;
    }
  }

  /// 创建训练进度
  Future<WorkoutProgress?> createProgress({
    required String planId,
    required int totalExercises,
  }) async {
    try {
      final response = await _httpClient.post(
        '/api/v1/workouts/progress',
        body: jsonEncode({
          'plan_id': planId,
          'total_exercises': totalExercises,
        }),
      );

      if (!ApiHttpClient.isSuccess(response)) {
        debugPrint('创建进度API错误: ${response.statusCode}');
        return null;
      }

      final data = ApiHttpClient.parseResponse(response);
      if (data == null || data['progress'] == null) return null;

      return WorkoutProgress.fromJson(data['progress'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('创建进度网络错误: $e');
      return null;
    }
  }

  /// 更新训练进度
  /// 添加 planId 参数以支持离线同步时正确更新进度
  Future<WorkoutProgress?> updateProgress({
    String? planId,
    String? status,
    int? currentModuleIndex,
    int? currentExerciseIndex,
    List<String>? completedExerciseIds,
    int? actualDuration,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (planId != null) body['plan_id'] = planId;
      if (status != null) body['status'] = status;
      if (currentModuleIndex != null) body['current_module_index'] = currentModuleIndex;
      if (currentExerciseIndex != null) body['current_exercise_index'] = currentExerciseIndex;
      if (completedExerciseIds != null) body['completed_exercise_ids'] = completedExerciseIds;
      if (actualDuration != null) body['actual_duration'] = actualDuration;

      final response = await _httpClient.put(
        '/api/v1/workouts/progress',
        body: jsonEncode(body),
      );

      if (!ApiHttpClient.isSuccess(response)) {
        debugPrint('更新进度API错误: ${response.statusCode}');
        return null;
      }

      final data = ApiHttpClient.parseResponse(response);
      if (data == null || data['progress'] == null) return null;

      return WorkoutProgress.fromJson(data['progress'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('更新进度网络错误: $e');
      return null;
    }
  }

  /// 清除今日训练进度
  Future<bool> clearProgress() async {
    try {
      final response = await _httpClient.delete('/api/v1/workouts/progress');

      if (!ApiHttpClient.isSuccess(response)) {
        debugPrint('清除进度API错误: ${response.statusCode}');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('清除进度网络错误: $e');
      return false;
    }
  }
}
