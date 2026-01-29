import 'api_service.dart';

/// 选项配置 API 服务
class OptionsApiService extends ApiService {
  OptionsApiService({required super.baseUrl});

  /// 获取所有选项配置
  Future<Map<String, dynamic>> getOptions() async {
    return get(
      '/api/v1/options',
      mapper: (data) => data as Map<String, dynamic>,
    );
  }
}
