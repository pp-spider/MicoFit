import 'api_service.dart';
import '../models/weekly_data.dart';
import '../models/feedback.dart';

/// 训练记录 API 服务
class RecordApiService extends ApiService {
  RecordApiService({required super.baseUrl});

  /// 获取月度训练记录
  Future<MonthlyStats> getMonthlyRecords(
    String userId,
    int year,
    int month,
  ) async {
    return get(
      '/api/v1/records/monthly',
      queryParameters: {
        'userId': userId,
        'year': year,
        'month': month,
      },
      mapper: (data) => MonthlyStats.fromJson(data),
    );
  }

  /// 提交训练反馈
  Future<FeedbackResponse> submitFeedback({
    required String userId,
    required WorkoutFeedback feedback,
    required String workoutDate,
    required int workoutDuration,
  }) async {
    return post(
      '/api/v1/feedback',
      body: {
        'user_id': userId, // 后端使用蛇形命名
        'workout_date': workoutDate,
        'workout_duration': workoutDuration,
        ...feedback.toJson(),
      },
      mapper: (data) => FeedbackResponse.fromJson(data),
    );
  }
}

/// 反馈响应模型
class FeedbackResponse {
  final bool success;
  final String aiAdjustment;

  FeedbackResponse({
    required this.success,
    required this.aiAdjustment,
  });

  factory FeedbackResponse.fromJson(Map<String, dynamic> json) {
    return FeedbackResponse(
      success: json['success'] as bool,
      aiAdjustment: json['aiAdjustment'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'aiAdjustment': aiAdjustment,
    };
  }
}
