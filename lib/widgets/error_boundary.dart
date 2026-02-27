import 'package:flutter/material.dart';

/// 全局错误边界组件
/// 捕获子组件树中的 Flutter 错误，防止应用崩溃
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallbackWidget;
  final VoidCallback? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallbackWidget,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
  }

  /// 捕获错误
  void _handleError(FlutterErrorDetails details) {
    if (mounted) {
      setState(() {
        _errorDetails = details;
      });
    }
    widget.onError?.call();
    // 这里可以添加错误上报逻辑
    debugPrint('ErrorBoundary caught error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  }

  /// 重置错误状态
  void _resetError() {
    setState(() {
      _errorDetails = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 如果有错误，显示错误页面
    if (_errorDetails != null) {
      return widget.fallbackWidget ??
          _DefaultErrorPage(
            error: _errorDetails!.exception.toString(),
            onRetry: _resetError,
          );
    }

    // 使用 Builder 来捕获构建过程中的错误
    return Builder(
      builder: (context) {
        try {
          return widget.child;
        } catch (error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'ErrorBoundary',
              ),
            );
          });
          return const SizedBox.shrink();
        }
      },
    );
  }
}

/// 默认错误页面
class _DefaultErrorPage extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _DefaultErrorPage({
    required this.error,
    required this.onRetry,
  });

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
                // 错误图标
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Color(0xFF2DD4BF),
                  ),
                ),
                const SizedBox(height: 24),

                // 错误标题
                const Text(
                  '出错了',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115E59),
                  ),
                ),
                const SizedBox(height: 12),

                // 错误描述
                Text(
                  '应用遇到了一些问题，请尝试重新加载',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // 错误详情（可折叠）
                ExpansionTile(
                  title: Text(
                    '查看错误详情',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        error,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // 重试按钮
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新加载'),
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
                const SizedBox(height: 12),

                // 返回首页按钮
                TextButton(
                  onPressed: () {
                    // 导航到首页
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
            ),
          ),
        ),
      ),
    );
  }
}
