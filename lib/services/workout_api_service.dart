import 'api_service.dart';
import '../models/workout.dart';

/// 训练计划 API 服务
class WorkoutApiService extends ApiService {
  WorkoutApiService({required super.baseUrl});

  /// 获取今日训练计划
  Future<WorkoutPlan> getTodayWorkout(
    String userId, {
    String? date, // 可选日期参数 (YYYY-MM-DD)
  }) async {
    final params = {'userId': userId};
    if (date != null) {
      params['date'] = date;
    }

    return get(
      '/api/v1/workouts/today',
      queryParameters: params,
      mapper: (data) => WorkoutPlan.fromJson(data),
    );
  }

  /// 刷新训练计划（换一组）
  Future<WorkoutPlan> refreshWorkout(String userId) async {
    return get(
      '/api/v1/workouts/refresh',
      queryParameters: {'userId': userId},
      mapper: (data) => WorkoutPlan.fromJson(data),
    );
  }
}
