import 'package:flutter/material.dart';
import '../services/sync_manager.dart';

/// 同步状态 Provider
class SyncProvider extends ChangeNotifier {
  final SyncManager _syncManager = SyncManager();

  SyncStatus _status = SyncStatus.idle;
  int _syncedCount = 0;
  int _totalCount = 0;
  String? _lastError;

  // Getters
  SyncStatus get status => _status;
  bool get isSyncing => _status == SyncStatus.syncing;
  bool get isOffline => _status == SyncStatus.offline;
  bool get hasError => _status == SyncStatus.error;
  int get syncedCount => _syncedCount;
  int get totalCount => _totalCount;
  double get progress => _totalCount == 0 ? 0.0 : _syncedCount / _totalCount;
  String? get lastError => _lastError;

  /// 初始化同步管理器
  Future<void> init() async {
    await _syncManager.init();

    // 监听状态变化
    _syncManager.onStatusChanged.listen((status) {
      _status = status;
      notifyListeners();
    });

    // 监听进度变化
    _syncManager.onProgress.listen((progress) {
      _syncedCount = progress.synced;
      _totalCount = progress.total;
      notifyListeners();
    });

    debugPrint('[SyncProvider] 同步状态监听已初始化');
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
    _syncManager.dispose();
    super.dispose();
  }
}
