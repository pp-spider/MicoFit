import 'dart:async';
import 'package:flutter/material.dart';
import '../services/offline_queue_service.dart';

/// 离线队列监控指示灯
/// 使用轮询机制显示当前待同步数据的数量和状态
class OfflineQueueIndicator extends StatefulWidget {
  /// 点击回调
  final VoidCallback? onTap;

  const OfflineQueueIndicator({
    super.key,
    this.onTap,
  });

  @override
  State<OfflineQueueIndicator> createState() => _OfflineQueueIndicatorState();
}

class _OfflineQueueIndicatorState extends State<OfflineQueueIndicator> {
  final OfflineQueueService _offlineQueue = OfflineQueueService();

  // 轮询定时器
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 2); // 2秒检查一次

  int _queueLength = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initQueue();
  }

  Future<void> _initQueue() async {
    await _offlineQueue.init();
    if (mounted) {
      setState(() {
        _queueLength = _offlineQueue.queueLength;
        _isSyncing = _offlineQueue.isSyncing;
      });

      // 启动轮询检查
      _startPolling();
    }
  }

  /// 启动轮询检查
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkQueueStatus());
    debugPrint('[OfflineQueueIndicator] 轮询已启动，间隔: ${_pollInterval.inSeconds}秒');
  }

  /// 停止轮询检查
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// 轮询检查队列状态
  void _checkQueueStatus() {
    if (!mounted) return;

    final newQueueLength = _offlineQueue.queueLength;
    final newIsSyncing = _offlineQueue.isSyncing;

    debugPrint('[OfflineQueueIndicator] [轮询] 检查: 队列=$newQueueLength, 同步中=$newIsSyncing');

    if (newQueueLength != _queueLength || newIsSyncing != _isSyncing) {
      debugPrint('[OfflineQueueIndicator] [轮询] 状态变化: 队列 $_queueLength->$newQueueLength, 同步 $_isSyncing->$newIsSyncing');
      setState(() {
        _queueLength = newQueueLength;
        _isSyncing = newIsSyncing;
      });
    }
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: _buildIndicator(),
    );
  }

  Widget _buildIndicator() {
    // 队列为空且不在同步中，不显示
    if (_queueLength == 0 && !_isSyncing) {
      return const SizedBox.shrink();
    }

    // 同步中状态
    if (_isSyncing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
              ),
            ),
            if (_queueLength > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$_queueLength',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2DD4BF),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // 有待同步数据（显示紫色徽章）
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$_queueLength',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
    );
  }
}
