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
/// 使用轮询机制检测网络状态和离线队列变化，自动同步
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

  // 同步锁
  bool _isSyncing = false;

  // 定时同步（轮询间隔）
  Timer? _syncTimer;
  static const Duration _syncInterval = Duration(minutes: 5); // 每5分钟同步一次

  // 轮询检查定时器
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 3); // 每3秒检查一次

  // 上次同步时间
  DateTime? _lastSyncTime;

  // 上次网络状态（用于检测变化）
  bool _lastKnownNetworkConnected = false;

  // 上次队列长度（用于检测变化）
  int _lastKnownQueueLength = 0;

  // 状态/进度变化回调
  Function(SyncStatus)? _onStatusChangedCallback;
  Function(SyncProgress)? _onProgressCallback;

  /// 设置状态变化回调
  void setOnStatusChangedCallback(Function(SyncStatus)? callback) {
    _onStatusChangedCallback = callback;
  }

  /// 设置进度变化回调
  void setOnProgressCallback(Function(SyncProgress)? callback) {
    _onProgressCallback = callback;
  }

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
    debugPrint('[SyncManager] ===== 开始初始化 =====');

    // 初始化网络服务
    debugPrint('[SyncManager] 初始化网络服务...');
    await _networkService.init();
    // 启动 NetworkService 的轮询，定期更新缓存的网络状态
    _networkService.startPolling();
    _lastKnownNetworkConnected = await _networkService.checkConnectivity();

    // 初始化离线队列
    debugPrint('[SyncManager] 初始化离线队列...');
    await _offlineQueue.init();
    _lastKnownQueueLength = _offlineQueue.queueLength;

    // 初始化数据同步服务（加载持久化的同步时间）
    debugPrint('[SyncManager] 初始化数据同步服务...');
    await DataSyncService().init();

    // 检查当前网络状态
    debugPrint('[SyncManager] 当前网络状态: $_lastKnownNetworkConnected');
    if (!_lastKnownNetworkConnected) {
      _updateStatus(SyncStatus.offline);
    }

    // 启动轮询检查（网络状态和队列变化）
    debugPrint('[SyncManager] 启动轮询检查...');
    _startPolling();

    // 启动定期同步
    debugPrint('[SyncManager] 启动定期同步...');
    _startPeriodicSync();

    // 立即检查一次队列（需要网络连接、服务器可达、队列有数据）
    if (_lastKnownQueueLength > 0 && _lastKnownNetworkConnected) {
      debugPrint('[SyncManager] 初始发现待同步数据，检查服务器可达性...');
      // 这里不等待，让轮询机制来处理实际的同步
      // 轮询会检查服务器可达性后再触发同步
    }

    debugPrint('[SyncManager] ===== 初始化完成 =====');
  }

  /// 启动轮询检查（网络状态和队列变化）
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkAndSync());
    debugPrint('[SyncManager] 轮询检查已启动，间隔: ${_pollInterval.inSeconds}秒');
  }

  /// 停止轮询检查
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    debugPrint('[SyncManager] 轮询检查已停止');
  }

  /// 轮询检查并触发同步
  /// 同时检查网络状态和离线队列状态
  /// 同步触发条件：网络在线 AND 队列有数据
  Future<void> _checkAndSync() async {
    if (_isSyncing) {
      return;
    }

    try {
      // ========== 同时检查网络状态和离线队列状态 ==========

      // 检查网络状态（使用异步方法实时检查，而不是缓存）
      final currentNetworkConnected = await _networkService.checkConnectivity();

      // 检查队列状态
      final currentQueueLength = _offlineQueue.queueLength;
      final stats = _offlineQueue.getQueueStats();
      final statsStr = stats.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');

      // 检测网络状态变化
      if (currentNetworkConnected != _lastKnownNetworkConnected) {
        _lastKnownNetworkConnected = currentNetworkConnected;
      }

      // 检测队列变化
      if (currentQueueLength != _lastKnownQueueLength) {
        _lastKnownQueueLength = currentQueueLength;
      }

      // ========== 同步触发条件：网络在线 AND 服务器可达 AND 队列有数据 ==========
      if (!currentNetworkConnected) {
        return;
      }

      if (currentQueueLength == 0) {
        return;
      }

      // 网络已连接且队列有数据，检查服务器可达性
      final isServerReachable = await _syncApiService.healthCheck();

      if (!isServerReachable) {
        return;
      }

      // 所有条件满足，触发同步
      await sync();

    } catch (e) {
      debugPrint('[SyncManager] [轮询] 检查异常: $e');
    }
  }

  /// 启动定期同步
  /// 同步条件：网络在线 AND 服务器可达 AND 队列有数据
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      if (_isSyncing) return;

      // 检查网络状态和队列状态（使用异步方法实时检查）
      final isConnected = await _networkService.checkConnectivity();
      final queueLength = _offlineQueue.queueLength;

      debugPrint('[SyncManager] [定期] 检查: 网络=${isConnected ? "在线" : "离线"}, 队列=$queueLength 条');

      // 同步条件：网络在线 AND 队列有数据 AND 服务器可达
      if (!isConnected) {
        debugPrint('[SyncManager] [定期] 跳过：网络离线');
        return;
      }

      if (queueLength == 0) {
        debugPrint('[SyncManager] [定期] 跳过：队列为空');
        return;
      }

      // 网络已连接且队列有数据，检查服务器可达性
      debugPrint('[SyncManager] [定期] 检查服务器可达性...');
      final isServerReachable = await _syncApiService.healthCheck();
      debugPrint('[SyncManager] [定期] 服务器可达性: $isServerReachable');

      if (!isServerReachable) {
        debugPrint('[SyncManager] [定期] 跳过：服务器不可达');
        return;
      }

      debugPrint('[SyncManager] [定期] 条件满足，触发同步');
      await sync();
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
    debugPrint('[SyncManager] === sync() 方法被调用 ===');

    if (_isSyncing) {
      debugPrint('[SyncManager] 同步已在进行中，跳过');
      return;
    }

    // ========== 步骤1：检查网络连接状态 ==========
    final isConnected = await _networkService.checkConnectivity();
    debugPrint('[SyncManager] 网络连接状态 (WiFi/移动网络): $isConnected');
    if (!isConnected) {
      debugPrint('[SyncManager] 无网络连接 (WiFi/移动网络)，无法同步');
      _updateStatus(SyncStatus.offline);
      return;
    }

    // ========== 步骤2：检查服务器可达性（健康检查）==========
    debugPrint('[SyncManager] 网络已连接，检查服务器可达性...');
    final isServerReachable = await _syncApiService.healthCheck();
    debugPrint('[SyncManager] 服务器可达性: $isServerReachable');

    if (!isServerReachable) {
      debugPrint('[SyncManager] 网络已连接但服务器不可达，可能是网络受限或服务器问题');
      // 注意：这里不设置 offline 状态，因为网络本身是连接的
      // 只是服务器不可达，这种情况可能是暂时的
      return;
    }

    // ========== 步骤3：检查Token ==========
    final hasValidToken = await _authService.hasValidToken();
    debugPrint('[SyncManager] Token有效性: $hasValidToken');
    if (!hasValidToken) {
      debugPrint('[SyncManager] 未登录或Token已过期，跳过同步');
      return;
    }

    // 打印待同步队列信息
    final pendingCount = _offlineQueue.queueLength;
    debugPrint('[SyncManager] 开始同步，待同步操作数: $pendingCount');
    _offlineQueue.getQueueStats().forEach((key, value) {
      debugPrint('[SyncManager] 队列详情: $key = $value');
    });

    if (pendingCount == 0) {
      debugPrint('[SyncManager] 队列为空，无需同步');
      return;
    }

    // ========== 步骤4：先上传离线队列 ==========
    await _performSync();

    // 再次检查队列（同步后可能被清空）
    final remainingCount = _offlineQueue.queueLength;
    if (remainingCount > 0) {
      debugPrint('[SyncManager] 还有 $remainingCount 个操作未同步，继续尝试');
    } else {
      debugPrint('[SyncManager] 离线队列已全部同步');
    }

    // ========== 步骤5：获取本地已有记录日期 ==========
    final localRecordDates = await DataSyncService().getLocalRecordDates();

    // ========== 步骤6：增量同步（传入本地日期避免重复）==========
    await DataSyncService().syncIncremental(localRecordDates: localRecordDates);

    // 更新队列长度记录
    _lastKnownQueueLength = _offlineQueue.queueLength;

    // 记录同步时间
    _lastSyncTime = DateTime.now();
    debugPrint('[SyncManager] 同步完成');
  }

  /// 执行同步
  Future<void> _performSync() async {
    if (_isSyncing) return;

    final isConnected = await _networkService.checkConnectivity();
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
      _notifyProgress(SyncProgress(
        synced: 0,
        total: _totalCount,
        status: SyncStatus.syncing,
      ));

      // 逐个同步操作
      for (final op in pendingOps) {
        // 检查网络（使用异步方法实时检查）
        if (!await _networkService.checkConnectivity()) {
          _updateStatus(SyncStatus.offline);
          _isSyncing = false;
          return;
        }

        try {
          await _syncOperation(op);
          _offlineQueue.markAsCompleted(op.id);
          _syncedCount++;

          // 通知进度
          _notifyProgress(SyncProgress(
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
    // 根据操作类型调用不同的API
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
      // 更新进度（传入 planId 以支持离线同步）
      final result = await _workoutApiService.updateProgress(
        planId: planId,
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
    if (_onStatusChangedCallback != null) {
      _onStatusChangedCallback!(newStatus);
    }

    // 同时更新进度状态
    _notifyProgress(SyncProgress(
      synced: _syncedCount,
      total: _totalCount,
      status: newStatus,
    ));
  }

  /// 通知进度变化
  void _notifyProgress(SyncProgress progress) {
    if (_onProgressCallback != null) {
      _onProgressCallback!(progress);
    }
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
    _stopPolling();
    stopPeriodicSync();
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
