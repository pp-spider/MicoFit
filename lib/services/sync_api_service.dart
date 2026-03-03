import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'http_client.dart';

/// 同步 API 服务
/// 负责与后端同步 API 交互
class SyncApiService {
  final ApiHttpClient _httpClient;

  SyncApiService({ApiHttpClient? httpClient})
      : _httpClient = httpClient ?? ApiHttpClient();

  /// 同步训练记录
  Future<bool> syncWorkoutRecord(Map<String, dynamic> recordData) async {
    try {
      // 兼容 camelCase 和 snake_case 两种格式
      final planId = recordData['planId'] ?? recordData['plan_id'];
      final completedAt = recordData['completedAt'] ?? recordData['completed_at'];
      final duration = recordData['duration'] ?? recordData['duration'];
      final completedExercises = recordData['completedExercises'] ??
          recordData['completed_exercises'] ??
          [];

      final request = {
        'plan_id': planId,
        'completed_at': completedAt,
        'duration': duration,
        'completed_exercises': completedExercises,
      };

      debugPrint('[SyncApiService] 同步训练记录: planId=$planId, completedAt=$completedAt, duration=$duration');

      final response = await _httpClient.post(
        '/api/v1/sync/workout-records',
        body: jsonEncode([request]),
      );

      if (ApiHttpClient.isSuccess(response)) {
        debugPrint('[SyncApiService] 训练记录同步成功');
        return true;
      } else {
        debugPrint('[SyncApiService] 训练记录同步失败: ${ApiHttpClient.getErrorMessage(response)}');
        return false;
      }
    } catch (e) {
      debugPrint('[SyncApiService] 训练记录同步异常: $e');
      return false;
    }
  }

  /// 批量同步训练记录
  Future<SyncResult> syncWorkoutRecords(List<Map<String, dynamic>> records) async {
    try {
      final requests = records.map((record) => {
        // 兼容 camelCase 和 snake_case 两种格式
        'plan_id': record['planId'] ?? record['plan_id'],
        'completed_at': record['completedAt'] ?? record['completed_at'],
        'duration': record['duration'] ?? record['duration'],
        'completed_exercises': record['completedExercises'] ??
            record['completed_exercises'] ??
            [],
      }).toList();

      final response = await _httpClient.post(
        '/api/v1/sync/workout-records',
        body: jsonEncode(requests),
      );

      if (ApiHttpClient.isSuccess(response)) {
        final data = ApiHttpClient.parseResponse(response);
        debugPrint('[SyncApiService] 批量训练记录同步成功: ${data?['synced_count']}');
        return SyncResult(
          success: true,
          syncedCount: data?['synced_count'] ?? 0,
          failedCount: data?['failed_count'] ?? 0,
        );
      } else {
        debugPrint('[SyncApiService] 批量训练记录同步失败');
        return SyncResult(success: false, syncedCount: 0, failedCount: records.length);
      }
    } catch (e) {
      debugPrint('[SyncApiService] 批量训练记录同步异常: $e');
      return SyncResult(success: false, syncedCount: 0, failedCount: records.length);
    }
  }

  /// 同步训练反馈
  Future<bool> syncFeedback(Map<String, dynamic> feedbackData) async {
    try {
      final request = {
        'plan_id': feedbackData['plan_id'],
        'record_date': feedbackData['record_date'],
        'duration': feedbackData['duration'],
        'completion': feedbackData['completion'],
        'feeling': feedbackData['feeling'],
        'tomorrow': feedbackData['tomorrow'],
        'pain_locations': feedbackData['pain_locations'] ?? [],
        'completed': feedbackData['completed'] ?? true,
      };

      final response = await _httpClient.post(
        '/api/v1/sync/feedback',
        body: jsonEncode(request),
      );

      if (ApiHttpClient.isSuccess(response)) {
        debugPrint('[SyncApiService] 反馈同步成功');
        return true;
      } else {
        debugPrint('[SyncApiService] 反馈同步失败: ${ApiHttpClient.getErrorMessage(response)}');
        return false;
      }
    } catch (e) {
      debugPrint('[SyncApiService] 反馈同步异常: $e');
      return false;
    }
  }

  /// 同步用户画像
  Future<bool> syncProfile(Map<String, dynamic> profileData) async {
    try {
      final request = {
        'nickname': profileData['nickname'],
        'fitness_level': profileData['fitnessLevel'],
        'goal': profileData['goal'],
        'scene': profileData['scene'],
        'time_budget': profileData['timeBudget'],
        'limitations': profileData['limitations'] ?? [],
        'equipment': profileData['equipment'],
        'weekly_days': profileData['weeklyDays'],
      };

      // 移除 null 值
      request.removeWhere((key, value) => value == null);

      final response = await _httpClient.post(
        '/api/v1/sync/profile',
        body: jsonEncode(request),
      );

      if (ApiHttpClient.isSuccess(response)) {
        debugPrint('[SyncApiService] 用户画像同步成功');
        return true;
      } else {
        debugPrint('[SyncApiService] 用户画像同步失败: ${ApiHttpClient.getErrorMessage(response)}');
        return false;
      }
    } catch (e) {
      debugPrint('[SyncApiService] 用户画像同步异常: $e');
      return false;
    }
  }

  /// 同步计划完成状态
  Future<bool> syncCompletePlan(String planId) async {
    try {
      final response = await _httpClient.post(
        '/api/v1/sync/complete-plan/$planId',
      );

      if (ApiHttpClient.isSuccess(response)) {
        debugPrint('[SyncApiService] 计划完成状态同步成功: $planId');
        return true;
      } else {
        debugPrint('[SyncApiService] 计划完成状态同步失败');
        return false;
      }
    } catch (e) {
      debugPrint('[SyncApiService] 计划完成状态同步异常: $e');
      return false;
    }
  }

  /// ========== 以下是从后端拉取数据的方法 ==========

  /// 从后端拉取训练记录
  Future<List<Map<String, dynamic>>> fetchWorkoutRecords({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      queryParams['limit'] = limit.toString();

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _httpClient.get('/api/v1/workouts/records?$queryString');

      if (ApiHttpClient.isSuccess(response)) {
        final data = ApiHttpClient.parseResponse(response);
        final List<dynamic> records = data?['records'] ?? [];
        debugPrint('[SyncApiService] 拉取训练记录成功: ${records.length} 条');
        return records.cast<Map<String, dynamic>>();
      } else {
        final errorMsg = ApiHttpClient.getErrorMessage(response);
        debugPrint('[SyncApiService] 拉取训练记录失败: 状态码=${response.statusCode}, 信息=$errorMsg');
        return [];
      }
    } catch (e) {
      debugPrint('[SyncApiService] 拉取训练记录异常: $e');
      return [];
    }
  }

  /// 从后端拉取聊天历史
  Future<List<Map<String, dynamic>>> fetchChatHistory({
    int limit = 50,
  }) async {
    try {
      final response = await _httpClient.get('/api/v1/ai/chat/messages?limit=$limit');

      if (ApiHttpClient.isSuccess(response)) {
        final data = ApiHttpClient.parseResponse(response);
        final List<dynamic> messages = data?['messages'] ?? [];
        debugPrint('[SyncApiService] 拉取聊天历史成功: ${messages.length} 条');
        return messages.cast<Map<String, dynamic>>();
      } else {
        final errorMsg = ApiHttpClient.getErrorMessage(response);
        debugPrint('[SyncApiService] 拉取聊天历史失败: 状态码=${response.statusCode}, 信息=$errorMsg');
        return [];
      }
    } catch (e) {
      debugPrint('[SyncApiService] 拉取聊天历史异常: $e');
      return [];
    }
  }

  /// 从后端拉取月度统计数据
  Future<Map<String, dynamic>?> fetchMonthlyStats(int year, int month) async {
    try {
      final response = await _httpClient.get('/api/v1/workouts/stats/monthly?year=$year&month=$month');

      if (ApiHttpClient.isSuccess(response)) {
        final data = ApiHttpClient.parseResponse(response);
        debugPrint('[SyncApiService] 拉取月度统计成功');
        return data;
      } else {
        final errorMsg = ApiHttpClient.getErrorMessage(response);
        debugPrint('[SyncApiService] 拉取月度统计失败: 状态码=${response.statusCode}, 信息=$errorMsg');
        return null;
      }
    } catch (e) {
      debugPrint('[SyncApiService] 拉取月度统计异常: $e');
      return null;
    }
  }

  /// 健康检查 - 验证服务器是否可达
  /// 返回 true 表示服务器可达，false 表示服务器不可达
  Future<bool> healthCheck() async {
    try {
      // 使用一个轻量级的 API 调用来验证服务器可达性
      // 这里调用用户信息的接口（不需要特殊权限）
      final response = await _httpClient.get('/api/v1/users/me').timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[SyncApiService] 健康检查超时');
          throw Exception('健康检查超时');
        },
      );

      // 无论返回成功还是认证失败，只要能收到 HTTP 响应就说明服务器可达
      // 认证失败 (401) 也是一种可达的证明
      if (response.statusCode == 200 || response.statusCode == 401) {
        debugPrint('[SyncApiService] 健康检查通过: 服务器可达 (状态码: ${response.statusCode})');
        return true;
      }

      debugPrint('[SyncApiService] 健康检查失败: 状态码=${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[SyncApiService] 健康检查失败: $e');
      return false;
    }
  }
}

/// 同步结果
class SyncResult {
  final bool success;
  final int syncedCount;
  final int failedCount;

  SyncResult({
    required this.success,
    required this.syncedCount,
    required this.failedCount,
  });

  bool get isPartialSuccess => success && failedCount > 0;
}
