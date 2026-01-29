import 'api_service.dart';
import 'api_exception.dart';
import '../models/user_profile.dart';

/// 用户画像 API 服务
class UserApiService extends ApiService {
  UserApiService({required super.baseUrl});

  /// 获取用户画像
  Future<UserProfile> getUserProfile(String userId) async {
    return get(
      '/api/v1/users/profile',
      queryParameters: {'userId': userId},
      mapper: (data) => UserProfile.fromJson(data),
    );
  }

  /// 检查用户画像是否存在
  Future<bool> checkProfileExists(String userId) async {
    try {
      await get(
        '/api/v1/users/profile',
        queryParameters: {'userId': userId},
        mapper: (data) => UserProfile.fromJson(data),
      );
      return true;
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        return false; // 404 表示画像不存在
      }
      rethrow; // 其他错误继续抛出
    }
  }

  /// 创建用户画像
  Future<UserProfile> createUserProfile(UserProfile profile) async {
    return post(
      '/api/v1/users/profile',
      body: profile.toJson(),
      mapper: (data) => UserProfile.fromJson(data),
    );
  }

  /// 更新用户画像
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    return put(
      '/api/v1/users/profile',
      body: profile.toJson(),
      mapper: (data) => UserProfile.fromJson(data),
    );
  }
}
