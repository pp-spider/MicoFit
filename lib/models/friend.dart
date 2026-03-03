/// 好友关系状态枚举
enum FriendshipStatus {
  /// 待接受
  pending,
  /// 已接受
  accepted,
  /// 已拒绝
  rejected,
  /// 已屏蔽
  blocked,
}

/// 好友模型
/// 表示用户之间的好友关系
class Friend {
  /// 好友关系ID
  final String id;

  /// 用户ID（当前用户）
  final String userId;

  /// 好友用户ID
  final String friendId;

  /// 好友昵称
  final String friendNickname;

  /// 好友头像URL（可选）
  final String? friendAvatarUrl;

  /// 好友等级
  final int friendLevel;

  /// 好友连续打卡天数
  final int friendStreakDays;

  /// 好友总训练时长（分钟）
  final int friendTotalDuration;

  /// 好友总训练天数
  final int friendTotalDays;

  /// 关系状态
  final FriendshipStatus status;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  const Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendNickname,
    this.friendAvatarUrl,
    this.friendLevel = 1,
    this.friendStreakDays = 0,
    this.friendTotalDuration = 0,
    this.friendTotalDays = 0,
    this.status = FriendshipStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从JSON创建
  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      friendId: json['friend_id'] as String,
      friendNickname: json['friend_nickname'] as String,
      friendAvatarUrl: json['friend_avatar_url'] as String?,
      friendLevel: json['friend_level'] as int? ?? 1,
      friendStreakDays: json['friend_streak_days'] as int? ?? 0,
      friendTotalDuration: json['friend_total_duration'] as int? ?? 0,
      friendTotalDays: json['friend_total_days'] as int? ?? 0,
      status: FriendshipStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FriendshipStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// 转为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'friend_nickname': friendNickname,
      'friend_avatar_url': friendAvatarUrl,
      'friend_level': friendLevel,
      'friend_streak_days': friendStreakDays,
      'friend_total_duration': friendTotalDuration,
      'friend_total_days': friendTotalDays,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 复制并修改
  Friend copyWith({
    String? id,
    String? userId,
    String? friendId,
    String? friendNickname,
    String? friendAvatarUrl,
    int? friendLevel,
    int? friendStreakDays,
    int? friendTotalDuration,
    int? friendTotalDays,
    FriendshipStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Friend(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendId: friendId ?? this.friendId,
      friendNickname: friendNickname ?? this.friendNickname,
      friendAvatarUrl: friendAvatarUrl ?? this.friendAvatarUrl,
      friendLevel: friendLevel ?? this.friendLevel,
      friendStreakDays: friendStreakDays ?? this.friendStreakDays,
      friendTotalDuration: friendTotalDuration ?? this.friendTotalDuration,
      friendTotalDays: friendTotalDays ?? this.friendTotalDays,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 好友请求模型
class FriendRequest {
  /// 请求ID
  final String id;

  /// 发送者ID
  final String senderId;

  /// 发送者昵称
  final String senderNickname;

  /// 发送者头像
  final String? senderAvatarUrl;

  /// 接收者ID
  final String receiverId;

  /// 验证消息
  final String? message;

  /// 创建时间
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.senderNickname,
    this.senderAvatarUrl,
    required this.receiverId,
    this.message,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      senderNickname: json['sender_nickname'] as String,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      receiverId: json['receiver_id'] as String,
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_nickname': senderNickname,
      'sender_avatar_url': senderAvatarUrl,
      'receiver_id': receiverId,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// 排行榜类型枚举
enum LeaderboardType {
  /// 本周连续打卡
  weeklyStreak,
  /// 本月总时长
  monthlyDuration,
  /// 总训练天数
  totalDays,
  /// 等级排行
  level,
}

/// 排行榜条目模型
class LeaderboardEntry {
  /// 用户ID
  final String userId;

  /// 昵称
  final String nickname;

  /// 头像URL
  final String? avatarUrl;

  /// 等级
  final int level;

  /// 排名
  final int rank;

  /// 数值（根据类型不同含义不同）
  final int value;

  /// 是否为当前用户
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.level,
    required this.rank,
    required this.value,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] as String,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatar_url'] as String?,
      level: json['level'] as int,
      rank: json['rank'] as int,
      value: json['value'] as int,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'level': level,
      'rank': rank,
      'value': value,
      'is_current_user': isCurrentUser,
    };
  }

  /// 格式化数值显示
  String get formattedValue {
    switch (value) {
      case > 60 when value < 1440:
        return '${(value / 60).toStringAsFixed(1)}小时';
      case >= 1440:
        return '${(value / 1440).toStringAsFixed(1)}天';
      default:
        return '$value';
    }
  }
}

/// 排行榜数据模型
class Leaderboard {
  /// 排行榜类型
  final LeaderboardType type;

  /// 标题
  final String title;

  /// 条目列表
  final List<LeaderboardEntry> entries;

  /// 更新时间
  final DateTime updatedAt;

  /// 当前用户排名（null表示未上榜）
  final int? myRank;

  /// 当前用户数值
  final int? myValue;

  const Leaderboard({
    required this.type,
    required this.title,
    required this.entries,
    required this.updatedAt,
    this.myRank,
    this.myValue,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    return Leaderboard(
      type: LeaderboardType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LeaderboardType.weeklyStreak,
      ),
      title: json['title'] as String,
      entries: (json['entries'] as List)
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      myRank: json['my_rank'] as int?,
      myValue: json['my_value'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'title': title,
      'entries': entries.map((e) => e.toJson()).toList(),
      'updated_at': updatedAt.toIso8601String(),
      'my_rank': myRank,
      'my_value': myValue,
    };
  }

  /// 获取示例数据
  static Leaderboard createSample(LeaderboardType type) {
    final titles = {
      LeaderboardType.weeklyStreak: '本周连续打卡榜',
      LeaderboardType.monthlyDuration: '本月训练时长榜',
      LeaderboardType.totalDays: '总训练天数榜',
      LeaderboardType.level: '等级排行榜',
    };

    final sampleEntries = [
      const LeaderboardEntry(
        userId: 'user1',
        nickname: '健身达人',
        level: 15,
        rank: 1,
        value: 30,
      ),
      const LeaderboardEntry(
        userId: 'user2',
        nickname: '早起鸟儿',
        level: 12,
        rank: 2,
        value: 28,
      ),
      const LeaderboardEntry(
        userId: 'user3',
        nickname: '跑步爱好者',
        level: 10,
        rank: 3,
        value: 25,
      ),
      const LeaderboardEntry(
        userId: 'user4',
        nickname: '瑜伽修行者',
        level: 8,
        rank: 4,
        value: 20,
      ),
      const LeaderboardEntry(
        userId: 'user5',
        nickname: '力量训练者',
        level: 9,
        rank: 5,
        value: 18,
      ),
    ];

    return Leaderboard(
      type: type,
      title: titles[type] ?? '排行榜',
      entries: sampleEntries,
      updatedAt: DateTime.now(),
      myRank: 12,
      myValue: 15,
    );
  }
}
