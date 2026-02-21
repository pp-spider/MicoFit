import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/user_data_helper.dart';

/// 待同步操作类型
enum PendingOperationType {
  workoutRecord, // 训练记录
  feedback, // 训练反馈
  profile, // 用户画像更新
  chatMessage, // 聊天消息
  workoutPlan, // 健身计划
  workoutProgress, // 训练进度
}

/// 待同步操作
class PendingOperation {
  final String id; // 本地唯一ID
  final PendingOperationType type; // 操作类型
  final String operation; // 操作类型: CREATE, UPDATE, DELETE
  final Map<String, dynamic> data; // 操作数据
  final DateTime createdAt; // 创建时间
  int retryCount; // 重试次数
  DateTime? lastRetryTime; // 上次重试时间

  PendingOperation({
    required this.id,
    required this.type,
    required this.operation,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastRetryTime,
  });

  /// 转换为JSON存储
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'operation': operation,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'lastRetryTime': lastRetryTime?.toIso8601String(),
    };
  }

  /// 从JSON恢复
  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'] as String,
      type: PendingOperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PendingOperationType.workoutRecord,
      ),
      operation: json['operation'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastRetryTime: json['lastRetryTime'] != null
          ? DateTime.parse(json['lastRetryTime'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'PendingOperation(id=$id, type=${type.name}, operation=$operation, retry=$retryCount)';
  }
}

/// 离线操作队列服务
/// 管理待同步到后端的离线操作，支持指数退避重试
/// 注意：此类在初始化时会自动使用当前用户ID进行数据隔离
class OfflineQueueService {
  // 单例模式
  static final OfflineQueueService _instance =
      OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  // 存储键（用户隔离）
  static const String _keyPendingOperations = 'offline_queue_pending';

  // 最大重试次数
  static const int _maxRetries = 3;

  // 基础重试延迟（毫秒）
  static const int _baseDelayMs = 5000;

  // 最大待同步操作数量
  static const int _maxQueueSize = 100;

  // 轮询检查间隔（毫秒）
  static const int _pollIntervalMs = 2000; // 2秒检查一次

  // 待同步操作列表
  final List<PendingOperation> _queue = [];

  // 是否正在同步
  bool _isSyncing = false;

  // 当前用户ID（用于数据隔离）
  String? _currentUserId;

  // 轮询定时器
  Timer? _pollTimer;

  // 轮询回调
  Function()? _onQueueChangedCallback;

  /// 设置当前用户ID（用户切换时调用）
  Future<void> setUserId(String userId) async {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      // 用户切换时重新加载队列
      await init();
      debugPrint('[OfflineQueueService] 用户切换，重新加载队列');
    }
  }

  /// 获取当前用户隔离的存储键
  String _getUserKey(String key) {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      return 'user_${_currentUserId}_$key';
    }
    return key;
  }

  /// 启动轮询检查队列变化
  void startPolling({Function()? onQueueChanged}) {
    _onQueueChangedCallback = onQueueChanged;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(milliseconds: _pollIntervalMs),
      (_) => _checkQueueChanged(),
    );
    debugPrint('[OfflineQueueService] 轮询已启动，间隔: ${_pollIntervalMs}ms');
  }

  /// 停止轮询
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _onQueueChangedCallback = null;
    debugPrint('[OfflineQueueService] 轮询已停止');
  }

  /// 检查队列是否有待同步数据（供外部轮询调用）
  int getQueueLength() {
    return _queue.length;
  }

  /// 内部检查队列变化并触发回调
  void _checkQueueChanged() {
    debugPrint('[OfflineQueueService] [轮询] 检查队列，当前长度: ${_queue.length}');

    if (_queue.isNotEmpty) {
      // 输出队列统计
      final stats = getQueueStats();
      final statsStr = stats.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
      debugPrint('[OfflineQueueService] [轮询] 队列详情: $statsStr');
    }

    if (_onQueueChangedCallback != null && _queue.isNotEmpty) {
      debugPrint('[OfflineQueueService] [轮询] 检测到待同步数据，触发回调');
      _onQueueChangedCallback!();
    } else {
      debugPrint('[OfflineQueueService] [轮询] 队列为空，跳过');
    }
  }

  /// 获取当前队列长度
  int get queueLength => _queue.length;

  /// 是否正在同步
  bool get isSyncing => _isSyncing;

  /// 是否队列为空
  bool get isEmpty => _queue.isEmpty;

  /// 是否队列已满
  bool get isFull => _queue.length >= _maxQueueSize;

  /// 初始化（从本地加载队列）
  Future<void> init() async {
    // 获取当前用户ID
    _currentUserId = await UserDataHelper.getCurrentUserId();
    await _loadQueueFromStorage();
    debugPrint('[OfflineQueueService] 初始化完成，待同步操作: ${_queue.length} 条');
    _logQueueDetails();
  }

  /// 添加待同步操作
  /// 改进：如果队列满，优先保留重要操作，删除次要操作
  /// 同时触发同步检查（如果队列从空变为非空）
  Future<bool> add(PendingOperation operation) async {
    final wasEmpty = _queue.isEmpty;

    // 检查队列是否已满
    if (isFull) {
      // 尝试移除已完成但未清理的操作（理论上不应该有）
      await _cleanupCompletedOperations();

      // 如果仍然满，根据操作类型决定策略
      if (isFull) {
        // 优先保留关键操作：训练记录、反馈、进度
        // 可以删除次要操作：画像更新
        final removed = _removeLowPriorityOperation(operation.type);
        if (!removed) {
          debugPrint('[OfflineQueueService] 队列已满且无法清理，拒绝新操作: ${operation.type.name}');
          return false; // 返回 false 表示添加失败
        }
        debugPrint('[OfflineQueueService] 队列已满，移除低优先级操作以容纳新操作');
      }
    }

    _queue.add(operation);
    await _saveQueueToStorage();

    debugPrint('[OfflineQueueService] 添加操作: ${operation.type.name} (${operation.operation})');
    debugPrint('[OfflineQueueService] 添加后队列: ${_queue.length} 条');
    _logQueueDetails();

    // 如果队列从空变为非空，触发轮询回调
    if (wasEmpty && _queue.isNotEmpty) {
      _triggerSyncIfNeeded();
    }

    return true;
  }

  /// 检查队列是否有待同步数据（供外部调用）
  bool hasPendingOperations() {
    return _queue.isNotEmpty;
  }

  /// 触发同步（通过回调）
  void _triggerSyncIfNeeded() {
    debugPrint('[OfflineQueueService] 队列有新数据，触发同步检查');
    _logQueueDetails();
    // 轮询模式下，同步检查由 SyncManager 的轮询触发
  }

  /// 打印队列详细信息
  void _logQueueDetails() {
    if (_queue.isEmpty) {
      debugPrint('[OfflineQueueService] 队列详情: (空)');
      return;
    }

    final stats = getQueueStats();
    final details = <String>[];

    for (final entry in stats.entries) {
      if (entry.value > 0) {
        details.add('${entry.key}: ${entry.value}');
      }
    }

    debugPrint('[OfflineQueueService] 队列详情: ${details.join(', ')}');
    debugPrint('[OfflineQueueService] 队列总计: ${_queue.length} 条待同步');
  }

  /// 清理已完成的操作（从队列中移除成功的操作）
  Future<void> _cleanupCompletedOperations() async {
    // 实际上已完成的操作已经被移除了
    // 这里保留接口以便将来扩展
  }

  /// 移除低优先级操作以腾出空间
  /// 返回是否成功移除
  bool _removeLowPriorityOperation(PendingOperationType newOpType) {
    // 定义优先级（数字越小优先级越高）
    const priorityMap = {
      PendingOperationType.workoutRecord: 1,
      PendingOperationType.feedback: 1,
      PendingOperationType.workoutProgress: 1,
      PendingOperationType.workoutPlan: 2,
      PendingOperationType.chatMessage: 3,
      PendingOperationType.profile: 4,
    };

    final newPriority = priorityMap[newOpType] ?? 5;

    // 找到优先级最低的操作（数字最大的）
    int lowestPriorityIndex = -1;
    int lowestPriority = 0;

    for (int i = 0; i < _queue.length; i++) {
      final op = _queue[i];
      final priority = priorityMap[op.type] ?? 5;

      // 如果这个操作的优先级低于新操作，可以移除
      if (priority > newPriority && priority > lowestPriority) {
        lowestPriority = priority;
        lowestPriorityIndex = i;
      }
    }

    if (lowestPriorityIndex != -1) {
      final removed = _queue.removeAt(lowestPriorityIndex);
      debugPrint('[OfflineQueueService] 移除低优先级操作: ${removed.type.name}');
      return true;
    }

    return false;
  }

  /// 创建训练记录待同步操作
  Future<void> addWorkoutRecord(Map<String, dynamic> recordData) async {
    final operation = PendingOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: PendingOperationType.workoutRecord,
      operation: 'CREATE',
      data: recordData,
      createdAt: DateTime.now(),
    );
    await add(operation);
  }

  /// 创建反馈待同步操作
  Future<void> addFeedback(Map<String, dynamic> feedbackData) async {
    final operation = PendingOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: PendingOperationType.feedback,
      operation: 'CREATE',
      data: feedbackData,
      createdAt: DateTime.now(),
    );
    await add(operation);
  }

  /// 创建训练进度待同步操作
  Future<void> addWorkoutProgress(
    String operationType,
    Map<String, dynamic> progressData,
  ) async {
    final operation = PendingOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: PendingOperationType.workoutProgress,
      operation: operationType, // CREATE or UPDATE
      data: progressData,
      createdAt: DateTime.now(),
    );
    await add(operation);
  }

  /// 获取所有待同步操作
  List<PendingOperation> getPendingOperations() {
    return List.unmodifiable(_queue);
  }

  /// 获取指定类型的待同步操作
  List<PendingOperation> getOperationsByType(PendingOperationType type) {
    return _queue.where((op) => op.type == type).toList();
  }

  /// 标记操作已同步完成
  Future<void> markAsCompleted(String operationId) async {
    _queue.removeWhere((op) => op.id == operationId);
    await _saveQueueToStorage();
    debugPrint('[OfflineQueueService] 同步成功，剩余队列: ${_queue.length} 条');
    _logQueueDetails();
  }

  /// 清除所有已完成的操作
  Future<void> clearCompleted() async {
    _queue.clear();
    await _saveQueueToStorage();
    debugPrint('[OfflineQueueService] 已清除所有待同步操作');
  }

  /// 计算重试延迟（指数退避）
  int _calculateBackoffDelay(int retryCount) {
    // 指数退避: baseDelay * 2^retryCount，最大30秒
    final delay = _baseDelayMs * (1 << retryCount);
    return delay > 30000 ? 30000 : delay;
  }

  /// 检查是否可以重试
  bool _canRetry(PendingOperation operation) {
    return operation.retryCount < _maxRetries;
  }

  /// 获取需要重试的操作
  /// 修复：使用上次重试时间而非创建时间计算退避
  List<PendingOperation> getOperationsNeedingRetry() {
    final now = DateTime.now();
    return _queue.where((op) {
      if (!_canRetry(op)) return false;

      final delay = _calculateBackoffDelay(op.retryCount);
      // 使用上次重试时间，如果没有则使用创建时间
      final baseTime = op.lastRetryTime ?? op.createdAt;
      final nextAttemptTime = baseTime.add(Duration(milliseconds: delay));

      return now.isAfter(nextAttemptTime);
    }).toList();
  }

  /// 增加重试次数并记录重试时间
  void incrementRetryCount(String operationId) {
    final index = _queue.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      _queue[index].retryCount++;
      _queue[index].lastRetryTime = DateTime.now(); // 记录重试时间
      _saveQueueToStorage();
      _queue[index].retryCount++;
      _saveQueueToStorage();
    }
  }

  /// 移除超过最大重试次数的操作
  List<PendingOperation> removeFailedOperations() {
    final failed = _queue.where((op) => !_canRetry(op)).toList();
    _queue.removeWhere((op) => !_canRetry(op));
    if (failed.isNotEmpty) {
      _saveQueueToStorage();
      debugPrint('[OfflineQueueService] 移除 ${failed.length} 个失败的操作');
    }
    return failed;
  }

  /// 设置同步状态
  void setSyncing(bool syncing) {
    _isSyncing = syncing;
  }

  /// 从本地存储加载队列（用户隔离）
  Future<void> _loadQueueFromStorage() async {
    try {
      final userKey = _getUserKey(_keyPendingOperations);
      final jsonStr = await UserDataHelper.getString(userKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        _queue.clear();
        return;
      }

      final List<dynamic> jsonList = jsonDecode(jsonStr) as List;
      _queue.clear();
      for (final json in jsonList) {
        try {
          _queue.add(PendingOperation.fromJson(json as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[OfflineQueueService] 解析操作失败: $e');
        }
      }
    } catch (e) {
      debugPrint('[OfflineQueueService] 加载队列失败: $e');
      _queue.clear();
    }
  }

  /// 保存队列到本地存储（用户隔离）
  Future<void> _saveQueueToStorage() async {
    try {
      final userKey = _getUserKey(_keyPendingOperations);
      final jsonList = _queue.map((op) => op.toJson()).toList();
      await UserDataHelper.setString(
        userKey,
        jsonEncode(jsonList),
      );
    } catch (e) {
      debugPrint('[OfflineQueueService] 保存队列失败: $e');
    }
  }

  /// 获取队列统计信息
  Map<String, int> getQueueStats() {
    final stats = <String, int>{};
    for (final type in PendingOperationType.values) {
      stats[type.name] = _queue.where((op) => op.type == type).length;
    }
    return stats;
  }

  /// 释放资源
  void dispose() {
    stopPolling();
  }
}
