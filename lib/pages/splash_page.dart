import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// 启动页 - 处理自动登录
/// 优化后的加载逻辑：
/// - 最小显示时间：500ms（让用户看到启动页）
/// - 最大等待时间：3000ms（避免过长的加载）
/// - 智能判断：初始化完成后如果已过最小时间则立即跳转
class SplashPage extends StatefulWidget {
  final VoidCallback onNeedLogin;

  const SplashPage({
    super.key,
    required this.onNeedLogin,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  // 加载状态
  bool _isInitializing = true;
  String? _loadingText;

  // 时间控制
  static const Duration _minDisplayDuration = Duration(milliseconds: 500);
  static const Duration _maxWaitDuration = Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final stopwatch = Stopwatch()..start();
    final authProvider = context.read<AuthProvider>();

    // 设置最大等待时间的超时控制
    final maxWaitTimer = Timer(_maxWaitDuration, () {
      if (mounted && _isInitializing) {
        debugPrint('[SplashPage] 达到最大等待时间，强制继续');
        _finishInitialization();
      }
    });

    try {
      // 阶段1：初始化认证状态
      if (mounted) {
        setState(() => _loadingText = '正在初始化...');
      }
      await authProvider.init();

      // 计算已经过的时间
      final elapsed = stopwatch.elapsed;

      // 如果未达到最小显示时间，则等待
      if (elapsed < _minDisplayDuration) {
        final remaining = _minDisplayDuration - elapsed;
        debugPrint('[SplashPage] 初始化完成，等待 ${remaining.inMilliseconds}ms 达到最小显示时间');
        await Future.delayed(remaining);
      }

      // 取消最大等待计时器
      maxWaitTimer.cancel();

      // 完成初始化
      if (mounted) {
        _finishInitialization();
      }
    } catch (e) {
      debugPrint('[SplashPage] 初始化出错: $e');
      maxWaitTimer.cancel();

      // 出错时也确保达到最小显示时间
      final elapsed = stopwatch.elapsed;
      if (elapsed < _minDisplayDuration) {
        await Future.delayed(_minDisplayDuration - elapsed);
      }

      if (mounted) {
        _finishInitialization();
      }
    } finally {
      stopwatch.stop();
    }
  }

  void _finishInitialization() {
    if (!_isInitializing) return;

    setState(() => _isInitializing = false);

    final authProvider = context.read<AuthProvider>();

    // 如果未登录，通知 MainPage 显示登录页
    if (!authProvider.isAuthenticated && !authProvider.isLoading) {
      widget.onNeedLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // 应用名称
            const Text(
              '微动 MicoFit',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF115E59),
              ),
            ),

            const SizedBox(height: 48),

            // 加载指示器
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
            ),

            const SizedBox(height: 16),

            // 提示文本
            Text(
              _loadingText ?? '正在加载...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
