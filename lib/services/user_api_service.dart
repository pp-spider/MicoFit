import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import 'http_client.dart';

/// 用户 API 服务
class UserApiService {
  final ApiHttpClient _httpClient;

  UserApiService({ApiHttpClient? httpClient})
      : _httpClient = httpClient ?? ApiHttpClient();

  /// 获取用户画像
  /// 网络错误时返回 null，允许离线使用
  Future<UserProfile?> getProfile() async {
    try {
      final response = await _httpClient.get('/api/v1/profiles/');

      if (!ApiHttpClient.isSuccess(response)) {
        // API 返回错误（非网络错误），返回 null
        return null;
      }

      final data = ApiHttpClient.parseResponse(response);
      if (data == null) {
        return null;
      }

      return UserProfile.fromJson(data);
    } catch (e) {
      // 网络错误，返回 null
      return null;
    }
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

  /// 更新用户头像URL
  Future<bool> updateAvatar(String avatarUrl) async {
    try {
      final response = await _httpClient.put(
        '/api/v1/users/me',
        body: jsonEncode({'avatar_url': avatarUrl}),
      );

      if (!ApiHttpClient.isSuccess(response)) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[UserApiService] 更新头像失败: $e');
      return false;
    }
  }

  /// 获取当前用户信息（包含头像）
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final response = await _httpClient.get('/api/v1/users/me');

      if (!ApiHttpClient.isSuccess(response)) {
        return null;
      }

      return ApiHttpClient.parseResponse(response);
    } catch (e) {
      return null;
    }
  }
}
