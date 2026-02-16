import 'dart:async';
import 'package:flutter/foundation.dart';
import 'network_service.dart';
import 'offline_queue_service.dart';
import 'auth_api_service.dart';
import 'sync_api_service.dart';
import 'data_sync_service.dart';
import 'workout_api_service.dart';

/// 同步状态
enum SyncStatus {
  idle, // 空闲
  syncing, // 同步中
  offline, // 离线模式
  error, // 错误
}

/// 同步管理器
/// 监听网络状态，自动同步离线操作队列
/// 支持定期同步和增量同步
class SyncManager {
  // 单例模式
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  // 服务实例
  final NetworkService _networkService = NetworkService();
  final OfflineQueueService _offlineQueue = OfflineQueueService();
  final AuthApiService _authService = AuthApiService();
  final SyncApiService _syncApiService = SyncApiService();
  final WorkoutApiService _workoutApiService = WorkoutApiService();

  // 同步状态
  SyncStatus _status = SyncStatus.idle;
  int _syncedCount = 0;
  int _totalCount = 0;
  String? _lastError;

  // 流控制器
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();

  // 同步锁
  bool _isSyncing = false;

  // 定时同步
  Timer? _syncTimer;
  static const Duration _syncInterval = Duration(minutes: 5); // 每5分钟同步一次

  // 上次同步时间
  DateTime? _lastSyncTime;

  // 监听订阅
  StreamSubscription? _networkSubscription;
  StreamSubscription? _queueSubscription;

  /// 获取状态流
  Stream<SyncStatus> get onStatusChanged => _statusController.stream;

  /// 获取进度流
  Stream<SyncProgress> get onProgress => _progressController.stream;

  /// 当前状态
  SyncStatus get status => _status;

  /// 是否正在同步
  bool get isSyncing => _isSyncing;

  /// 已同步数量
  int get syncedCount => _syncedCount;

  /// 总数量
  int get totalCount => _totalCount;

  /// 同步进度 (0.0 - 1.0)
  double get progress {
    if (_totalCount == 0) return 0.0;
    return _syncedCount / _totalCount;
  }

  /// 最后错误
  String? get lastError => _lastError;

  /// 初始化同步管理器
  Future<void> init() async {
    debugPrint('[SyncManager] 初始化同步管理器');

    // 初始化网络服务
    await _networkService.init();

    // 初始化离线队列
    await _offlineQueue.init();

    // 监听网络状态变化
    _networkSubscription = _networkService.onConnectivityChanged.listen(_onNetworkChanged);

    // 监听队列变化
    _queueSubscription = _offlineQueue.onQueueChanged.listen(_onQueueChanged);

    // 检查当前网络状态
    final isConnected = await _networkService.isConnected;
    if (!isConnected) {
      _updateStatus(SyncStatus.offline);
    }

    // 启动定期同步
    _startPeriodicSync();

    debugPrint('[SyncManager] 同步管理器初始化完成');
  }

  /// 启动定期同步
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      final isConnected = await _networkService.isConnected;
      if (isConnected && !_isSyncing) {
        debugPrint('[SyncManager] 定期同步触发');
        await sync();
      }
    });
    debugPrint('[SyncManager] 定期同步已启动，间隔: ${_syncInterval.inMinutes}分钟');
  }

  /// 停止定期同步
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('[SyncManager] 定期同步已停止');
  }

  /// 设置用户ID（用户切换时调用）
  Future<void> setUserId(String userId) async {
    await _offlineQueue.setUserId(userId);
  }

  /// 手动触发同步
  Future<void> sync() async {
    if (_isSyncing) {
      debugPrint('[SyncManager] 同步已在进行中，跳过');
      return;
    }

    // 检查网络连接
    final isConnected = await _networkService.isConnected;
    if (!isConnected) {
      debugPrint('[SyncManager] 无网络连接，无法同步');
      _updateStatus(SyncStatus.offline);
      return;
    }

    // 检查Token
    final hasValidToken = await _authService.hasValidToken();
    if (!hasValidToken) {
      debugPrint('[SyncManager] 未登录或Token已过期，跳过同步');
      return;
    }

    await _performSync();

    // 增量同步：拉取后端新数据
    await DataSyncService().syncIncremental();

    // 记录同步时间
    _lastSyncTime = DateTime.now();
  }

  /// 网络状态变化处理
  Future<void> _onNetworkChanged(List<dynamic> results) async {
    final isConnected = _networkService.hasConnection(results.cast());

    if (isConnected) {
      debugPrint('[SyncManager] 网络已恢复，触发同步');
      _updateStatus(SyncStatus.idle);
      // 延迟一下再同步，确保网络稳定
      await Future.delayed(const Duration(seconds: 1));
      await sync();
    } else {
      debugPrint('[SyncManager] 网络已断开');
      _updateStatus(SyncStatus.offline);
    }
  }

  /// 队列变化处理
  void _onQueueChanged(List<dynamic> queue) {
    // 通知UI更新
    _progressController.add(SyncProgress(
      synced: _syncedCount,
      total: queue.length,
      status: _status,
    ));
  }

  /// 执行同步
  Future<void> _performSync() async {
    if (_isSyncing) return;

    final isConnected = await _networkService.isConnected;
    if (!isConnected) {
      _updateStatus(SyncStatus.offline);
      return;
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);
    _syncedCount = 0;
    _lastError = null;

    debugPrint('[SyncManager] 开始同步');

    try {
      // 获取所有待同步操作
      final pendingOps = _offlineQueue.getPendingOperations();
      _totalCount = pendingOps.length;

      if (_totalCount == 0) {
        debugPrint('[SyncManager] 没有待同步的操作');
        _isSyncing = false;
        _updateStatus(SyncStatus.idle);
        return;
      }

      // 通知进度
      _progressController.add(SyncProgress(
        synced: 0,
        total: _totalCount,
        status: SyncStatus.syncing,
      ));

      // 逐个同步操作
      for (final op in pendingOps) {
        // 检查网络
        if (!await _networkService.isConnected) {
          _updateStatus(SyncStatus.offline);
          _isSyncing = false;
          return;
        }

        try {
          await _syncOperation(op);
          _offlineQueue.markAsCompleted(op.id);
          _syncedCount++;

          // 通知进度
          _progressController.add(SyncProgress(
            synced: _syncedCount,
            total: _totalCount,
            status: SyncStatus.syncing,
          ));

          debugPrint('[SyncManager] 同步完成: ${op.type.name} ($_syncedCount/$_totalCount)');
        } catch (e) {
          debugPrint('[SyncManager] 同步操作失败: $op, 错误: $e');
          _offlineQueue.incrementRetryCount(op.id);
          _lastError = e.toString();
        }
      }

      // 移除失败的超过最大重试次数的操作
      _offlineQueue.removeFailedOperations();

      debugPrint('[SyncManager] 同步完成，成功: $_syncedCount');
    } catch (e) {
      debugPrint('[SyncManager] 同步过程出错: $e');
      _lastError = e.toString();
      _updateStatus(SyncStatus.error);
    } finally {
      _isSyncing = false;
      _updateStatus(SyncStatus.idle);
    }
  }

  /// 同步单个操作
  Future<void> _syncOperation(PendingOperation op) async {
    // 这里需要根据操作类型调用不同的API
    // 目前是占位实现，后续根据实际API补充
    switch (op.type) {
      case PendingOperationType.workoutRecord:
        await _syncWorkoutRecord(op);
        break;
      case PendingOperationType.feedback:
        await _syncFeedback(op);
        break;
      case PendingOperationType.profile:
        await _syncProfile(op);
        break;
      case PendingOperationType.chatMessage:
        // 聊天消息通常实时同步，不需要离线队列
        break;
      case PendingOperationType.workoutPlan:
        // 健身计划通常实时同步
        break;
      case PendingOperationType.workoutProgress:
        await _syncWorkoutProgress(op);
        break;
    }
  }

  /// 同步训练记录
  Future<void> _syncWorkoutRecord(PendingOperation op) async {
    final success = await _syncApiService.syncWorkoutRecord(op.data);
    if (!success) {
      throw Exception('训练记录同步失败');
    }
    debugPrint('[SyncManager] 训练记录同步成功');
  }

  /// 同步反馈
  Future<void> _syncFeedback(PendingOperation op) async {
    final success = await _syncApiService.syncFeedback(op.data);
    if (!success) {
      throw Exception('反馈同步失败');
    }
    debugPrint('[SyncManager] 反馈同步成功');
  }

  /// 同步用户画像
  Future<void> _syncProfile(PendingOperation op) async {
    final success = await _syncApiService.syncProfile(op.data);
    if (!success) {
      throw Exception('用户画像同步失败');
    }
    debugPrint('[SyncManager] 用户画像同步成功');
  }

  /// 同步训练进度
  Future<void> _syncWorkoutProgress(PendingOperation op) async {
    final data = op.data;
    final planId = data['planId'] as String?;

    if (planId == null) {
      throw Exception('训练进度同步失败: 缺少planId');
    }

    bool success = false;

    if (op.operation == 'CREATE') {
      // 创建进度
      final totalExercises = data['totalExercises'] as int? ?? 0;
      final result = await _workoutApiService.createProgress(
        planId: planId,
        totalExercises: totalExercises,
      );
      success = result != null;
    } else {
      // 更新进度
      final result = await _workoutApiService.updateProgress(
        status: data['status'] as String? ?? 'inProgress',
        currentModuleIndex: data['currentModuleIndex'] as int? ?? 0,
        currentExerciseIndex: data['currentExerciseIndex'] as int? ?? 0,
        completedExerciseIds: (data['completedExerciseIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        actualDuration: data['actualDuration'] as int? ?? 0,
      );
      success = result != null;
    }

    if (!success) {
      throw Exception('训练进度同步失败');
    }
    debugPrint('[SyncManager] 训练进度同步成功');
  }

  /// 更新状态
  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);

    // 同时更新进度状态
    _progressController.add(SyncProgress(
      synced: _syncedCount,
      total: _totalCount,
      status: newStatus,
    ));
  }

  /// 获取队列统计
  Map<String, int> getQueueStats() {
    return _offlineQueue.getQueueStats();
  }

  /// 清除同步队列（谨慎使用）
  Future<void> clearQueue() async {
    await _offlineQueue.clearCompleted();
  }

  /// 释放资源
  void dispose() {
    _syncTimer?.cancel();
    _networkSubscription?.cancel();
    _queueSubscription?.cancel();
    _statusController.close();
    _progressController.close();
  }

  /// 获取上次同步时间
  DateTime? get lastSyncTime => _lastSyncTime;
}

/// 同步进度信息
class SyncProgress {
  final int synced;
  final int total;
  final SyncStatus status;

  SyncProgress({
    required this.synced,
    required this.total,
    required this.status,
  });

  /// 进度百分比 (0.0 - 1.0)
  double get percentage {
    if (total == 0) return 0.0;
    return synced / total;
  }

  /// 是否完成
  bool get isComplete => synced >= total && total > 0;
}
