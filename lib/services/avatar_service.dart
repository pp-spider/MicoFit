import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../utils/user_data_helper.dart';
import 'http_client.dart';

/// 头像服务 - 处理头像上传和本地存储
class AvatarService {
  static const String _avatarKey = 'user_avatar_path';
  static const String _avatarUrlKey = 'user_avatar_url';
  final ImagePicker _picker = ImagePicker();
  final ApiHttpClient _httpClient = ApiHttpClient();

  /// 从相册选择图片
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('[AvatarService] 选择图片失败: $e');
      return null;
    }
  }

  /// 从相机拍照
  Future<File?> takePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('[AvatarService] 拍照失败: $e');
      return null;
    }
  }

  /// 保存头像到本地应用目录
  Future<String?> saveAvatarLocally(File imageFile) async {
    try {
      // 获取应用文档目录
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String avatarDir = '${appDir.path}/avatars';

      // 确保目录存在
      final Directory directory = Directory(avatarDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 获取当前用户ID
      final String? userId = await UserDataHelper.getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        debugPrint('[AvatarService] 用户未登录，无法保存头像');
        return null;
      }

      // 生成文件名：userId_timestamp.jpg
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = '${userId}_$timestamp.jpg';
      final String filePath = '$avatarDir/$fileName';

      // 删除旧头像（如果存在）
      await _deleteOldAvatar();

      // 复制图片到应用目录
      final File localFile = await imageFile.copy(filePath);

      // 保存路径到 SharedPreferences
      await UserDataHelper.setString('${_avatarKey}_$userId', filePath);

      debugPrint('[AvatarService] 头像保存成功: $filePath');
      return localFile.path;
    } catch (e) {
      debugPrint('[AvatarService] 保存头像失败: $e');
      return null;
    }
  }

  /// 删除旧头像
  Future<void> _deleteOldAvatar() async {
    try {
      final String? userId = await UserDataHelper.getCurrentUserId();
      if (userId == null || userId.isEmpty) return;

      final String? oldPath = await UserDataHelper.getString('${_avatarKey}_$userId');
      if (oldPath != null && oldPath.isNotEmpty) {
        final File oldFile = File(oldPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
          debugPrint('[AvatarService] 删除旧头像: $oldPath');
        }
      }
    } catch (e) {
      debugPrint('[AvatarService] 删除旧头像失败: $e');
    }
  }

  /// 获取本地头像路径
  Future<String?> getLocalAvatarPath() async {
    try {
      final String? userId = await UserDataHelper.getCurrentUserId();
      if (userId == null || userId.isEmpty) return null;

      final String? path = await UserDataHelper.getString('${_avatarKey}_$userId');
      if (path != null && path.isNotEmpty) {
        // 检查文件是否存在
        final File file = File(path);
        if (await file.exists()) {
          return path;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[AvatarService] 获取头像路径失败: $e');
      return null;
    }
  }

  /// 清除当前用户的头像
  Future<void> clearAvatar() async {
    try {
      await _deleteOldAvatar();

      final String? userId = await UserDataHelper.getCurrentUserId();
      if (userId != null && userId.isNotEmpty) {
        await UserDataHelper.remove('${_avatarKey}_$userId');
      }

      debugPrint('[AvatarService] 头像已清除');
    } catch (e) {
      debugPrint('[AvatarService] 清除头像失败: $e');
    }
  }

  /// 显示选择图片来源的对话框
  /// 返回选择的路径或 null（如果取消）
  Future<String?> showImageSourceDialog(BuildContext context) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '更换头像',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        color: Color(0xFF2DD4BF),
                      ),
                    ),
                    title: const Text(
                      '从相册选择',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Color(0xFF2DD4BF),
                      ),
                    ),
                    title: const Text(
                      '拍照',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (source == null) return null;

    File? imageFile;
    if (source == ImageSource.gallery) {
      imageFile = await pickImageFromGallery();
    } else {
      imageFile = await takePhoto();
    }

    if (imageFile != null) {
      return await saveAvatarLocally(imageFile);
    }

    return null;
  }

  /// 上传头像到后端服务器
  /// 返回后端返回的头像URL
  Future<String?> uploadAvatarToServer(File imageFile) async {
    try {
      // 获取 token
      final token = await _httpClient.getToken();
      if (token == null) {
        debugPrint('[AvatarService] 未登录，无法上传头像');
        return null;
      }

      // 创建 multipart 请求
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/users/me/avatar');
      final request = http.MultipartRequest('POST', uri);

      // 添加认证 header
      request.headers['Authorization'] = 'Bearer $token';

      // 添加图片文件
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: 'avatar.jpg',
      ));

      // 发送请求
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final avatarUrl = data['avatar_url'] as String?;
        if (avatarUrl != null) {
          // 保存头像URL到本地
          await UserDataHelper.setString(_avatarUrlKey, avatarUrl);
          debugPrint('[AvatarService] 头像上传成功: $avatarUrl');
          return avatarUrl;
        }
      } else {
        debugPrint('[AvatarService] 头像上传失败: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      debugPrint('[AvatarService] 头像上传失败: $e');
      return null;
    }
  }

  /// 获取后端头像URL
  Future<String?> getServerAvatarUrl() async {
    try {
      final response = await _httpClient.get('/api/v1/users/me');
      if (ApiHttpClient.isSuccess(response)) {
        final data = ApiHttpClient.parseResponse(response);
        if (data != null && data['avatar_url'] != null) {
          final avatarUrl = data['avatar_url'] as String;
          // 保存到本地
          await UserDataHelper.setString(_avatarUrlKey, avatarUrl);
          return avatarUrl;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[AvatarService] 获取后端头像失败: $e');
      return null;
    }
  }

  /// 获取保存的后端头像URL
  Future<String?> getCachedAvatarUrl() async {
    return await UserDataHelper.getString(_avatarUrlKey);
  }
}
