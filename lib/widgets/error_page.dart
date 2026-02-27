import 'package:flutter/material.dart';

/// 统一的错误页面组件
/// 可在各处复用，提供一致的错误展示体验
class ErrorPage extends StatelessWidget {
  /// 错误标题
  final String title;

  /// 错误描述
  final String? message;

  /// 错误图标
  final IconData icon;

  /// 重试回调
  final VoidCallback? onRetry;

  /// 重试按钮文字
  final String retryText;

  /// 次要操作按钮
  final Widget? secondaryAction;

  /// 是否显示返回首页按钮
  final bool showHomeButton;

  const ErrorPage({
    super.key,
    this.title = '出错了',
    this.message,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.retryText = '重试',
    this.secondaryAction,
    this.showHomeButton = true,
  });

  /// 网络错误预设
  factory ErrorPage.network({
    String? message,
    VoidCallback? onRetry,
  }) {
    return ErrorPage(
      title: '网络连接失败',
      message: message ?? '请检查网络连接后重试',
      icon: Icons.wifi_off_outlined,
      onRetry: onRetry,
    );
  }

  /// 数据加载错误预设
  factory ErrorPage.loadFailed({
    String? message,
    VoidCallback? onRetry,
  }) {
    return ErrorPage(
      title: '加载失败',
      message: message ?? '数据加载失败，请稍后重试',
      icon: Icons.cloud_off_outlined,
      onRetry: onRetry,
    );
  }

  /// 空数据预设
  factory ErrorPage.empty({
    String? title,
    String? message,
    VoidCallback? onRetry,
    String retryText = '刷新',
  }) {
    return ErrorPage(
      title: title ?? '暂无数据',
      message: message ?? '当前没有可显示的数据',
      icon: Icons.inbox_outlined,
      onRetry: onRetry,
      retryText: retryText,
      showHomeButton: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 图标
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 50,
                    color: const Color(0xFF2DD4BF),
                  ),
                ),
                const SizedBox(height: 24),

                // 标题
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115E59),
                  ),
                ),
                const SizedBox(height: 8),

                // 描述
                if (message != null)
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                const SizedBox(height: 32),

                // 重试按钮
                if (onRetry != null)
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(retryText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2DD4BF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                // 次要操作
                if (secondaryAction != null) ...[
                  const SizedBox(height: 12),
                  secondaryAction!,
                ],

                // 返回首页
                if (showHomeButton) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text(
                      '返回首页',
                      style: TextStyle(
                        color: Color(0xFF115E59),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 空状态组件（简化版）
class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF115E59),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
