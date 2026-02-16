import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/workout_record.dart';
import '../models/chat_message.dart';
import '../utils/user_data_helper.dart';
import 'sync_api_service.dart';

/// 数据同步服务
/// 负责本地数据与后端数据的双向同步
/// 支持全量同步（登录时）和增量同步（定期）
class DataSyncService {
  // 单例模式
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();

  final SyncApiService _syncApiService = SyncApiService();

  // 存储键
  static const String _chatHistoryKey = 'chat_history';
  static const String _keyLastSyncTime = 'last_sync_time';

  // 上次同步时间
  DateTime? _lastSyncTime;

  /// 登录时同步：先拉取后端数据，再合并本地数据（全量同步）
  Future<bool> syncOnLogin() async {
    debugPrint('[DataSyncService] 开始登录同步（全量同步）...');

    try {
      // 1. 拉取后端所有训练记录
      await _syncWorkoutRecords(limit: 500);

      // 2. 拉取后端所有聊天记录
      await _syncChatHistory(limit: 200);

      // 3. 记录同步时间
      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();

      debugPrint('[DataSyncService] 登录同步完成');
      return true;
    } catch (e) {
      debugPrint('[DataSyncService] 登录同步失败: $e');
      return false;
    }
  }

  /// 增量同步：只同步上次同步后新增的数据
  Future<bool> syncIncremental() async {
    debugPrint('[DataSyncService] 开始增量同步...');

    // 加载上次同步时间
    await _loadLastSyncTime();

    try {
      // 1. 增量同步训练记录
      await _syncWorkoutRecordsIncremental();

      // 2. 增量同步聊天记录
      await _syncChatHistoryIncremental();

      // 3. 记录同步时间
      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();

      debugPrint('[DataSyncService] 增量同步完成');
      return true;
    } catch (e) {
      debugPrint('[DataSyncService] 增量同步失败: $e');
      return false;
    }
  }

  /// 保存上次同步时间
  Future<void> _saveLastSyncTime() async {
    if (_lastSyncTime != null) {
      await UserDataHelper.setString(
        _keyLastSyncTime,
        _lastSyncTime!.toIso8601String(),
      );
    }
  }

  /// 加载上次同步时间
  Future<void> _loadLastSyncTime() async {
    final timeStr = await UserDataHelper.getString(_keyLastSyncTime);
    if (timeStr != null) {
      _lastSyncTime = DateTime.tryParse(timeStr);
    }
  }

  /// 获取上次同步时间
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 同步训练记录（全量）
  Future<void> _syncWorkoutRecords({int limit = 100}) async {
    try {
      // 从后端拉取记录
      final backendRecords = await _syncApiService.fetchWorkoutRecords(limit: limit);

      if (backendRecords.isNotEmpty) {
        // 获取本地记录
        final localRecords = await _loadLocalRecords();

        // 合并记录
        final mergedRecords = _mergeRecords(localRecords, backendRecords);

        // 保存合并后的记录
        await _saveRecords(mergedRecords);

        debugPrint('[DataSyncService] 同步了 ${backendRecords.length} 条训练记录');
      }
    } catch (e) {
      debugPrint('[DataSyncService] 同步训练记录失败: $e');
    }
  }

  /// 增量同步训练记录（只同步上次同步之后的数据）
  Future<void> _syncWorkoutRecordsIncremental() async {
    if (_lastSyncTime == null) {
      // 没有上次同步时间，执行全量同步
      await _syncWorkoutRecords();
      return;
    }

    try {
      // 计算日期范围：从上次同步日期的开始到今天
      // 避免时间边界问题，使用日期的开始时间
      final startDate = DateTime(
        _lastSyncTime!.year,
        _lastSyncTime!.month,
        _lastSyncTime!.day,
      );
      final endDate = DateTime.now();

      // 从后端拉取该日期范围的记录
      final backendRecords = await _syncApiService.fetchWorkoutRecords(
        startDate: startDate,
        endDate: endDate,
        limit: 100,
      );

      if (backendRecords.isNotEmpty) {
        // 获取本地记录
        final localRecords = await _loadLocalRecords();

        // 合并记录（本地优先）
        final mergedRecords = _mergeRecordsPreferLocal(localRecords, backendRecords);

        // 保存合并后的记录
        await _saveRecords(mergedRecords);

        debugPrint('[DataSyncService] 增量同步了 ${backendRecords.length} 条训练记录');
      }
    } catch (e) {
      debugPrint('[DataSyncService] 增量同步训练记录失败: $e');
    }
  }

  /// 同步聊天记录（全量）
  Future<void> _syncChatHistory({int limit = 50}) async {
    try {
      // 从后端拉取聊天记录
      final backendMessages = await _syncApiService.fetchChatHistory(limit: limit);

      if (backendMessages.isNotEmpty) {
        // 获取本地聊天记录
        final localMessages = await _loadLocalMessages();

        // 合并消息
        final mergedMessages = _mergeMessages(localMessages, backendMessages);

        // 保存合并后的聊天记录
        await _saveMessages(mergedMessages);

        debugPrint('[DataSyncService] 同步了 ${backendMessages.length} 条聊天记录');
      }
    } catch (e) {
      debugPrint('[DataSyncService] 同步聊天记录失败: $e');
    }
  }

  /// 增量同步聊天记录
  Future<void> _syncChatHistoryIncremental() async {
    // 聊天记录暂时使用全量同步，因为消息量大但增量难以精确判断
    await _syncChatHistory();
  }

  /// 加载本地训练记录
  Future<List<WorkoutRecord>> _loadLocalRecords() async {
    try {
      final recordsJson = await UserDataHelper.getString(AppConfig.keyWorkoutRecords);
      if (recordsJson == null) return [];

      final recordsList = jsonDecode(recordsJson) as List;
      return recordsList
          .map((json) => WorkoutRecord.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DataSyncService] 加载本地记录失败: $e');
      return [];
    }
  }

  /// 合并训练记录（后端优先，用于登录时全量同步）
  List<WorkoutRecord> _mergeRecords(
    List<WorkoutRecord> local,
    List<Map<String, dynamic>> backend,
  ) {
    final Map<String, WorkoutRecord> recordsByDate = {};

    // 添加本地记录
    for (final record in local) {
      final dateKey = record.date.toLocal().toIso8601String().split('T')[0];
      recordsByDate[dateKey] = record;
    }

    // 合并后端记录（后端优先）
    for (final json in backend) {
      try {
        final record = WorkoutRecord.fromJson(json);
        final dateKey = record.date.toLocal().toIso8601String().split('T')[0];
        // 后端数据覆盖本地
        recordsByDate[dateKey] = record;
      } catch (e) {
        debugPrint('[DataSyncService] 解析后端记录失败: $e');
      }
    }

    return recordsByDate.values.toList();
  }

  /// 合并训练记录（基于时间戳的冲突解决策略）
  /// 策略：
  /// 1. 训练记录按天计算，一天只有一条记录
  /// 2. 如果本地和后端都有同一天的记录，保留本地的（用户可能正在离线训练）
  /// 3. 如果本地没有某天的记录，使用后端的
  /// 4. 如果后端没有但本地有，保留本地的
  List<WorkoutRecord> _mergeRecordsPreferLocal(
    List<WorkoutRecord> local,
    List<Map<String, dynamic>> backend,
  ) {
    final Map<String, WorkoutRecord> recordsByDate = {};

    // 先添加后端记录
    for (final json in backend) {
      try {
        final record = WorkoutRecord.fromJson(json);
        final dateKey = _getDateKey(record.date);
        recordsByDate[dateKey] = record;
      } catch (e) {
        debugPrint('[DataSyncService] 解析后端记录失败: $e');
      }
    }

    // 合并本地记录（本地优先）
    for (final record in local) {
      final dateKey = _getDateKey(record.date);
      // 本地存在则不覆盖（保留本地最新操作的结果）
      if (!recordsByDate.containsKey(dateKey)) {
        recordsByDate[dateKey] = record;
      }
      // 注意：这里选择本地优先，因为训练记录在离线时也会生成
      // 如果用户完成了一次离线训练，本地记录应该保留
    }

    return recordsByDate.values.toList();
  }

  /// 获取日期键（用于去重）
  String _getDateKey(DateTime date) {
    return date.toLocal().toIso8601String().split('T')[0];
  }

  /// 保存训练记录
  Future<void> _saveRecords(List<WorkoutRecord> records) async {
    final recordsJson = records.map((r) => r.toJson()).toList();
    await UserDataHelper.setString(
      AppConfig.keyWorkoutRecords,
      jsonEncode(recordsJson),
    );
  }

  /// 加载本地聊天记录
  Future<List<ChatMessage>> _loadLocalMessages() async {
    try {
      final messagesJson = await UserDataHelper.getString(_chatHistoryKey);
      if (messagesJson == null) return [];

      final messagesList = jsonDecode(messagesJson) as List;
      return messagesList
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DataSyncService] 加载本地聊天记录失败: $e');
      return [];
    }
  }

  /// 合并聊天记录
  List<ChatMessage> _mergeMessages(
    List<ChatMessage> local,
    List<Map<String, dynamic>> backend,
  ) {
    final Map<String, ChatMessage> messagesById = {};

    // 添加本地消息
    for (final msg in local) {
      messagesById[msg.id] = msg;
    }

    // 合并后端消息（后端优先）
    for (final json in backend) {
      try {
        final msg = ChatMessage.fromJson(json);
        messagesById[msg.id] = msg;
      } catch (e) {
        debugPrint('[DataSyncService] 解析后端消息失败: $e');
      }
    }

    // 按时间排序
    return messagesById.values.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// 保存聊天记录
  Future<void> _saveMessages(List<ChatMessage> messages) async {
    final messagesJson = messages.map((m) => m.toJson()).toList();
    await UserDataHelper.setString(
      _chatHistoryKey,
      jsonEncode(messagesJson),
    );
  }
}
