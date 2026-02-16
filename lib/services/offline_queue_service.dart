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

  PendingOperation({
    required this.id,
    required this.type,
    required this.operation,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
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

  // 待同步操作列表
  final List<PendingOperation> _queue = [];

  // 流控制器
  final StreamController<List<PendingOperation>> _queueController =
      StreamController<List<PendingOperation>>.broadcast();

  // 是否正在同步
  bool _isSyncing = false;

  // 当前用户ID（用于数据隔离）
  String? _currentUserId;

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

  /// 获取队列流
  Stream<List<PendingOperation>> get onQueueChanged => _queueController.stream;

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
    debugPrint('[OfflineQueueService] 初始化完成，队列中有 ${_queue.length} 个待同步操作');
  }

  /// 添加待同步操作
  Future<void> add(PendingOperation operation) async {
    // 检查队列是否已满
    if (isFull) {
      debugPrint('[OfflineQueueService] 队列已满，移除最旧的操作');
      // 移除最旧的操作
      _queue.removeAt(0);
    }

    _queue.add(operation);
    await _saveQueueToStorage();
    _notifyQueueChanged();

    debugPrint('[OfflineQueueService] 添加操作: $operation');
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
    _notifyQueueChanged();
    debugPrint('[OfflineQueueService] 操作已完成: $operationId');
  }

  /// 清除所有已完成的操作
  Future<void> clearCompleted() async {
    _queue.clear();
    await _saveQueueToStorage();
    _notifyQueueChanged();
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
  List<PendingOperation> getOperationsNeedingRetry() {
    final now = DateTime.now();
    return _queue.where((op) {
      if (!_canRetry(op)) return false;

      final delay = _calculateBackoffDelay(op.retryCount);
      final lastAttempt = op.createdAt.add(Duration(milliseconds: delay));

      return now.isAfter(lastAttempt);
    }).toList();
  }

  /// 增加重试次数
  void incrementRetryCount(String operationId) {
    final index = _queue.indexWhere((op) => op.id == operationId);
    if (index != -1) {
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
      _notifyQueueChanged();
      debugPrint('[OfflineQueueService] 移除 ${failed.length} 个失败的操作');
    }
    return failed;
  }

  /// 设置同步状态
  void setSyncing(bool syncing) {
    _isSyncing = syncing;
    _notifyQueueChanged();
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

  /// 通知队列变化
  void _notifyQueueChanged() {
    _queueController.add(List.unmodifiable(_queue));
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
    _queueController.close();
  }
}
