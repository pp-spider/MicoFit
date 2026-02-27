import 'package:flutter/foundation.dart';
import '../models/friend.dart';

/// 好友 API 服务
class FriendApiService {
  static final FriendApiService _instance = FriendApiService._internal();
  factory FriendApiService() => _instance;
  FriendApiService._internal();

  /// 获取好友列表
  Future<List<Friend>> getFriends() async {
    try {
      // 模拟 API 调用，实际项目中替换为真实接口
      await Future.delayed(const Duration(milliseconds: 800));
      return _getMockFriends();
    } catch (e) {
      debugPrint('获取好友列表失败: $e');
      rethrow;
    }
  }

  /// 获取好友请求列表
  Future<List<FriendRequest>> getFriendRequests() async {
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      return _getMockFriendRequests();
    } catch (e) {
      debugPrint('获取好友请求失败: $e');
      rethrow;
    }
  }

  /// 发送好友请求
  Future<void> sendFriendRequest({
    required String friendId,
    String? message,
  }) async {
    try {
      // TODO: 实现真实 API 调用
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('发送好友请求: $friendId, 消息: $message');
    } catch (e) {
      debugPrint('发送好友请求失败: $e');
      rethrow;
    }
  }

  /// 接受好友请求
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      // TODO: 实现真实 API 调用
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('接受好友请求: $requestId');
    } catch (e) {
      debugPrint('接受好友请求失败: $e');
      rethrow;
    }
  }

  /// 拒绝好友请求
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      // TODO: 实现真实 API 调用
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('拒绝好友请求: $requestId');
    } catch (e) {
      debugPrint('拒绝好友请求失败: $e');
      rethrow;
    }
  }

  /// 删除好友
  Future<void> removeFriend(String friendId) async {
    try {
      // TODO: 实现真实 API 调用
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('删除好友: $friendId');
    } catch (e) {
      debugPrint('删除好友失败: $e');
      rethrow;
    }
  }

  /// 搜索用户
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      return _getMockSearchResults(query);
    } catch (e) {
      debugPrint('搜索用户失败: $e');
      rethrow;
    }
  }

  /// 获取排行榜
  Future<Leaderboard> getLeaderboard(LeaderboardType type) async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      return Leaderboard.createSample(type);
    } catch (e) {
      debugPrint('获取排行榜失败: $e');
      rethrow;
    }
  }

  /// 模拟数据：好友列表
  List<Friend> _getMockFriends() {
    final now = DateTime.now();
    return [
      Friend(
        id: 'friend1',
        userId: 'current_user',
        friendId: 'user1',
        friendNickname: '健身达人小李',
        friendLevel: 15,
        friendStreakDays: 30,
        friendTotalDuration: 3600,
        friendTotalDays: 45,
        status: FriendshipStatus.accepted,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
      ),
      Friend(
        id: 'friend2',
        userId: 'current_user',
        friendId: 'user2',
        friendNickname: '早起跑步者',
        friendLevel: 12,
        friendStreakDays: 15,
        friendTotalDuration: 2400,
        friendTotalDays: 38,
        status: FriendshipStatus.accepted,
        createdAt: now.subtract(const Duration(days: 25)),
        updatedAt: now,
      ),
      Friend(
        id: 'friend3',
        userId: 'current_user',
        friendId: 'user3',
        friendNickname: '瑜伽爱好者',
        friendLevel: 10,
        friendStreakDays: 7,
        friendTotalDuration: 1800,
        friendTotalDays: 25,
        status: FriendshipStatus.accepted,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now,
      ),
      Friend(
        id: 'friend4',
        userId: 'current_user',
        friendId: 'user4',
        friendNickname: '力量训练王',
        friendLevel: 18,
        friendStreakDays: 45,
        friendTotalDuration: 4800,
        friendTotalDays: 60,
        status: FriendshipStatus.accepted,
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now,
      ),
    ];
  }

  /// 模拟数据：好友请求
  List<FriendRequest> _getMockFriendRequests() {
    final now = DateTime.now();
    return [
      FriendRequest(
        id: 'req1',
        senderId: 'user5',
        senderNickname: '新来的健身者',
        senderAvatarUrl: null,
        receiverId: 'current_user',
        message: '你好，一起健身打卡吧！',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      FriendRequest(
        id: 'req2',
        senderId: 'user6',
        senderNickname: '晨跑达人',
        senderAvatarUrl: null,
        receiverId: 'current_user',
        message: null,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
    ];
  }

  /// 模拟数据：搜索结果
  List<Map<String, dynamic>> _getMockSearchResults(String query) {
    final mockUsers = [
      {
        'id': 'user10',
        'nickname': '健身小白',
        'level': 3,
        'avatar_url': null,
      },
      {
        'id': 'user11',
        'nickname': '瑜伽大师',
        'level': 20,
        'avatar_url': null,
      },
      {
        'id': 'user12',
        'nickname': '跑步狂人',
        'level': 15,
        'avatar_url': null,
      },
    ];

    if (query.isEmpty) return [];

    return mockUsers.where((user) {
      final nickname = user['nickname'] as String;
      return nickname.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }
}
