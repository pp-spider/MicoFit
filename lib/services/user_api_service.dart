import 'dart:convert';
import '../models/user_profile.dart';
import 'http_client.dart';

/// 用户 API 服务
class UserApiService {
  final ApiHttpClient _httpClient;

  UserApiService({ApiHttpClient? httpClient})
      : _httpClient = httpClient ?? ApiHttpClient();

  /// 获取用户画像
  Future<UserProfile> getProfile() async {
    final response = await _httpClient.get('/api/v1/profiles/');

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data == null) {
      throw Exception('获取用户画像失败：服务器响应无效');
    }

    return UserProfile.fromJson(data);
  }

  /// 创建用户画像
  Future<UserProfile> createProfile(UserProfile profile) async {
    final response = await _httpClient.post(
      '/api/v1/profiles/',
      body: jsonEncode(profile.toJson()),
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data == null) {
      throw Exception('创建用户画像失败：服务器响应无效');
    }

    return UserProfile.fromJson(data);
  }

  /// 更新用户画像
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final response = await _httpClient.put(
      '/api/v1/profiles/',
      body: jsonEncode(profile.toJson()),
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data == null) {
      throw Exception('更新用户画像失败：服务器响应无效');
    }

    return UserProfile.fromJson(data);
  }

  /// 创建或更新用户画像（upsert）
  Future<UserProfile> upsertProfile(UserProfile profile) async {
    final response = await _httpClient.post(
      '/api/v1/profiles/upsert',
      body: jsonEncode(profile.toJson()),
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data == null) {
      throw Exception('保存用户画像失败：服务器响应无效');
    }

    return UserProfile.fromJson(data);
  }
}
