import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// 启动页 - 处理自动登录
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
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final authProvider = context.read<AuthProvider>();

    // 初始化认证状态（尝试自动登录）
    await authProvider.init();

    // 等待一小段时间让用户看到启动页
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
    }

    // 如果未登录，通知 MainPage 显示登录页
    if (mounted && !authProvider.isAuthenticated && !authProvider.isLoading) {
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
              '正在加载...',
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
