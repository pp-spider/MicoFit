import 'package:flutter/foundation.dart';
import '../models/friend.dart';
import '../services/friend_api_service.dart';

/// 好友 Provider
/// 管理好友列表、好友请求、排行榜等状态
class FriendProvider extends ChangeNotifier {
  final FriendApiService _apiService = FriendApiService();

  // 好友列表
  List<Friend> _friends = [];
  List<Friend> get friends => _friends;

  // 好友请求
  List<FriendRequest> _friendRequests = [];
  List<FriendRequest> get friendRequests => _friendRequests;

  // 排行榜
  Leaderboard? _leaderboard;
  Leaderboard? get leaderboard => _leaderboard;

  // 加载状态
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // 错误信息
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// 获取好友列表
  Future<void> loadFriends() async {
    _setLoading(true);
    _clearError();

    try {
      _friends = await _apiService.getFriends();
      notifyListeners();
    } catch (e) {
      _setError('加载好友列表失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 获取好友请求
  Future<void> loadFriendRequests() async {
    _setLoading(true);
    _clearError();

    try {
      _friendRequests = await _apiService.getFriendRequests();
      notifyListeners();
    } catch (e) {
      _setError('加载好友请求失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 发送好友请求
  Future<bool> sendFriendRequest({
    required String friendId,
    String? message,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiService.sendFriendRequest(
        friendId: friendId,
        message: message,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setError('发送好友请求失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 接受好友请求
  Future<bool> acceptFriendRequest(String requestId) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiService.acceptFriendRequest(requestId);
      // 重新加载好友列表和请求列表
      await loadFriends();
      await loadFriendRequests();
      return true;
    } catch (e) {
      _setError('接受好友请求失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 拒绝好友请求
  Future<bool> rejectFriendRequest(String requestId) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiService.rejectFriendRequest(requestId);
      // 重新加载请求列表
      await loadFriendRequests();
      return true;
    } catch (e) {
      _setError('拒绝好友请求失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 删除好友
  Future<bool> removeFriend(String friendId) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiService.removeFriend(friendId);
      // 从本地列表移除
      _friends.removeWhere((f) => f.friendId == friendId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('删除好友失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 搜索用户
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      return await _apiService.searchUsers(query);
    } catch (e) {
      debugPrint('搜索用户失败: $e');
      return [];
    }
  }

  /// 加载排行榜
  Future<void> loadLeaderboard(LeaderboardType type) async {
    _setLoading(true);
    _clearError();

    try {
      _leaderboard = await _apiService.getLeaderboard(type);
      notifyListeners();
    } catch (e) {
      _setError('加载排行榜失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 获取未处理的好友请求数量
  int get pendingRequestsCount {
    return _friendRequests.length;
  }

  /// 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 设置错误信息
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// 清除错误信息
  void _clearError() {
    _errorMessage = null;
  }

  /// 清除数据（用于登出）
  void clearData() {
    _friends = [];
    _friendRequests = [];
    _leaderboard = null;
    _errorMessage = null;
    notifyListeners();
  }
}
