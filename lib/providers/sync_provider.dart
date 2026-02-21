import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sync_manager.dart';
import '../services/offline_queue_service.dart';

/// 同步状态 Provider
/// 使用轮询机制监听同步状态
class SyncProvider extends ChangeNotifier {
  final SyncManager _syncManager = SyncManager();
  final OfflineQueueService _offlineQueue = OfflineQueueService();

  SyncStatus _status = SyncStatus.idle;
  int _syncedCount = 0;
  int _totalCount = 0;
  String? _lastError;

  // 轮询定时器
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 2); // 2秒检查一次

  // 标记是否已初始化
  bool _isInitialized = false;

  SyncProvider() {
    debugPrint('[SyncProvider] 构造函数被调用');
  }

  /// 确保已初始化（如果未初始化则手动初始化）
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    debugPrint('[SyncProvider] 未初始化，开始初始化...');
    await init();
  }

  // Getters
  SyncStatus get status => _status;
  bool get isSyncing => _status == SyncStatus.syncing;
  bool get isOffline => _status == SyncStatus.offline;
  bool get hasError => _status == SyncStatus.error;
  int get syncedCount => _syncedCount;
  int get totalCount => _totalCount;
  double get progress => _totalCount == 0 ? 0.0 : _syncedCount / _totalCount;
  String? get lastError => _lastError;

  /// 获取当前待同步的记录数量（从离线队列）
  int get pendingCount => _offlineQueue.queueLength;

  /// 初始化同步管理器
  Future<void> init() async {
    try {
      debugPrint('[SyncProvider] 开始初始化');

      // 设置状态变化回调
      _syncManager.setOnStatusChangedCallback((status) {
        _status = status;
        notifyListeners();
      });

      // 设置进度变化回调
      _syncManager.setOnProgressCallback((progress) {
        _syncedCount = progress.synced;
        _totalCount = progress.total;
        notifyListeners();
      });

      await _syncManager.init();
      debugPrint('[SyncProvider] SyncManager 初始化完成');

      // 启动轮询检查
      _startPolling();

      // 监听应用生命周期，应用恢复时触发同步
      _setupAppLifecycleObserver();

      // 立即检查一次队列
      final initialQueueLength = _offlineQueue.queueLength;
      debugPrint('[SyncProvider] 初始化完成，初始队列长度: $initialQueueLength');

      if (initialQueueLength > 0) {
        debugPrint('[SyncProvider] 初始发现待同步数据，触发同步');
        await sync();
      }

      debugPrint('[SyncProvider] 轮询检查已启动');

      // 标记为已初始化
      _isInitialized = true;
    } catch (e, stack) {
      debugPrint('[SyncProvider] 初始化异常: $e');
      debugPrint('[SyncProvider] 堆栈: $stack');
    }
  }

  /// 启动轮询检查
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkStatus());
    debugPrint('[SyncProvider] 轮询检查已启动，间隔: ${_pollInterval.inSeconds}秒');
  }

  /// 停止轮询检查
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// 轮询检查状态变化
  void _checkStatus() {
    // 从 SyncManager 获取最新状态
    final newStatus = _syncManager.status;
    if (newStatus != _status) {
      debugPrint('[SyncProvider] [轮询] 状态变化: ${_status.name} -> ${newStatus.name}');
      _status = newStatus;
      notifyListeners();
    }

    final newSyncedCount = _syncManager.syncedCount;
    final newTotalCount = _syncManager.totalCount;
    if (newSyncedCount != _syncedCount || newTotalCount != _totalCount) {
      debugPrint('[SyncProvider] [轮询] 进度变化: $_syncedCount/$_totalCount -> $newSyncedCount/$newTotalCount');
      _syncedCount = newSyncedCount;
      _totalCount = newTotalCount;
      notifyListeners();
    }

    final newPendingCount = _offlineQueue.queueLength;
    if (newPendingCount != pendingCount) {
      debugPrint('[SyncProvider] [轮询] 待同步变化: $pendingCount -> $newPendingCount');
      notifyListeners();
    }
  }

  /// 设置应用生命周期监听
  void _setupAppLifecycleObserver() {
    debugPrint('[SyncProvider] 设置应用生命周期监听器');

    WidgetsBinding.instance.addObserver(
      _AppLifecycleObserver(
        onResumed: () async {
          debugPrint('[SyncProvider] 应用恢复，触发同步检查');
          // 确保离线队列已初始化
          await _offlineQueue.init();
          final queueLength = _offlineQueue.queueLength;
          debugPrint('[SyncProvider] 当前队列长度: $queueLength');

          if (queueLength > 0) {
            debugPrint('[SyncProvider] 发现待同步数据 ($queueLength 条)，触发同步');
            await sync();
          } else {
            debugPrint('[SyncProvider] 队列为空，跳过同步');
          }
        },
      ),
    );
  }

  /// 手动触发同步
  Future<void> sync() async {
    await _syncManager.sync();
  }

  /// 获取队列统计
  Map<String, int> getQueueStats() {
    return _syncManager.getQueueStats();
  }

  /// 获取待同步操作数量
  int getPendingCount() {
    return _syncManager.totalCount - _syncedCount;
  }

  @override
  void dispose() {
    _stopPolling();
    _syncManager.dispose();
    super.dispose();
  }
}

/// 应用生命周期观察者
class _AppLifecycleObserver with WidgetsBindingObserver {
  final VoidCallback onResumed;

  _AppLifecycleObserver({required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
