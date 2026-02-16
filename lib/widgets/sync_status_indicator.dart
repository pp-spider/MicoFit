import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../services/sync_manager.dart';

/// 同步状态指示器
/// 显示当前同步状态（同步中、离线、错误等）
class SyncStatusIndicator extends StatelessWidget {
  /// 是否显示详细进度信息
  final bool showDetails;

  const SyncStatusIndicator({
    super.key,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();

    // 如果没有待同步内容且不在同步中，不显示
    if (syncProvider.status == SyncStatus.idle &&
        syncProvider.totalCount == 0) {
      return const SizedBox.shrink();
    }

    return _buildIndicator(context, syncProvider);
  }

  Widget _buildIndicator(BuildContext context, SyncProvider syncProvider) {
    switch (syncProvider.status) {
      case SyncStatus.syncing:
        return _buildSyncingIndicator(context, syncProvider);

      case SyncStatus.offline:
        return _buildOfflineIndicator(context);

      case SyncStatus.error:
        return _buildErrorIndicator(context, syncProvider.lastError);

      case SyncStatus.idle:
        // 有待同步内容时显示小徽章
        if (syncProvider.totalCount > 0) {
          return _buildPendingBadge(context, syncProvider.totalCount);
        }
        return const SizedBox.shrink();
    }
  }

  /// 同步中指示器
  Widget _buildSyncingIndicator(BuildContext context, SyncProvider syncProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
            ),
          ),
          if (showDetails) ...[
            const SizedBox(width: 8),
            Text(
              '同步中 ${syncProvider.syncedCount}/${syncProvider.totalCount}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF115E59),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 离线指示器
  Widget _buildOfflineIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off,
            size: 14,
            color: Colors.orange[700],
          ),
          if (showDetails) ...[
            const SizedBox(width: 6),
            Text(
              '离线模式',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 错误指示器
  Widget _buildErrorIndicator(BuildContext context, String? error) {
    return Tooltip(
      message: error ?? '同步出错',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sync_problem,
              size: 14,
              color: Colors.red[700],
            ),
            if (showDetails) ...[
              const SizedBox(width: 6),
              Text(
                '同步失败',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 待同步徽章
  Widget _buildPendingBadge(BuildContext context, int count) {
    return GestureDetector(
      onTap: () {
        // 点击触发同步
        context.read<SyncProvider>().sync();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_upload,
              size: 12,
              color: const Color(0xFF8B5CF6),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 同步进度条
/// 用于显示详细的同步进度
class SyncProgressBar extends StatelessWidget {
  const SyncProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();

    if (syncProvider.status != SyncStatus.syncing) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '同步中...',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF115E59),
              ),
            ),
            Text(
              '${(syncProvider.progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF115E59),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: syncProvider.progress,
            minHeight: 4,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
          ),
        ),
      ],
    );
  }
}
