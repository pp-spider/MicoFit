import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../providers/sync_provider.dart';

/// 全局离线状态指示器
/// 当应用处于离线模式时，在页面顶部显示横幅提示
class OfflineIndicator extends StatelessWidget {
  final Widget child;

  const OfflineIndicator({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, networkProvider, _) {
        final isOffline = !networkProvider.isOnline;

        return Column(
          children: [
            // 离线状态横幅
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: isOffline ? 40 : 0,
              child: isOffline
                  ? _OfflineBannerContent()
                  : const SizedBox.shrink(),
            ),
            // 子内容
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// 离线横幅内容（内部使用 SyncProvider 获取同步状态）
class _OfflineBannerContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, _) {
        return Container(
          width: double.infinity,
          color: Colors.orange[600],
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '当前处于离线模式，数据将在联网后自动同步',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 同步状态指示
                if (syncProvider.isSyncing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 简化版离线指示器（用于内嵌到页面中）
class OfflineBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const OfflineBanner({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, networkProvider, _) {
        if (networkProvider.isOnline) {
          return const SizedBox.shrink();
        }

        return Consumer<SyncProvider>(
          builder: (context, syncProvider, _) {
            return GestureDetector(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.orange[200]!,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off,
                      color: Colors.orange[700],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '离线模式 - 数据将在联网后同步',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (syncProvider.isSyncing)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.orange[700]!,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 网络状态标签
class NetworkStatusBadge extends StatelessWidget {
  const NetworkStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, networkProvider, _) {
        return Consumer<SyncProvider>(
          builder: (context, syncProvider, _) {
            final isOnline = networkProvider.isOnline;
            final isSyncing = syncProvider.isSyncing;

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSyncing)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOnline
                              ? const Color(0xFF10B981)
                              : Colors.orange[700]!,
                        ),
                      ),
                    )
                  else
                    Icon(
                      isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      size: 14,
                      color: isOnline
                          ? const Color(0xFF10B981)
                          : Colors.orange[700],
                    ),
                  const SizedBox(width: 4),
                  Text(
                    isSyncing
                        ? '同步中'
                        : (isOnline ? '在线' : '离线'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isOnline
                          ? const Color(0xFF10B981)
                          : Colors.orange[700],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
