import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/achievement.dart';

/// 徽章解锁动画
class BadgeUnlockAnimation extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onComplete;

  const BadgeUnlockAnimation({
    super.key,
    required this.achievement,
    required this.onComplete,
  });

  @override
  State<BadgeUnlockAnimation> createState() => _BadgeUnlockAnimationState();
}

class _BadgeUnlockAnimationState extends State<BadgeUnlockAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _rotateAnimation = CurvedAnimation(
      parent: _rotateController,
      curve: Curves.easeInOut,
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await _scaleController.forward();
    _rotateController.repeat();
    _particleController.forward();

    // 3秒后自动关闭
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotateController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getLevelColor(widget.achievement.level),
              _getLevelColor(widget.achievement.level).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _getLevelColor(widget.achievement.level).withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 粒子效果背景
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(200, 200),
                  painter: ParticlePainter(
                    progress: _particleController.value,
                    color: Colors.white.withOpacity(0.3),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // 徽章图标动画
            ScaleTransition(
              scale: _scaleAnimation,
              child: AnimatedBuilder(
                animation: _rotateAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: math.sin(_rotateAnimation.value * math.pi * 2) * 0.1,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        _getIconData(widget.achievement.iconName),
                        size: 60,
                        color: _getLevelColor(widget.achievement.level),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // 解锁文本
            const Text(
              '解锁新成就！',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.achievement.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.achievement.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            // 等级标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              child: Text(
                '${widget.achievement.level.label}级 · +${widget.achievement.level.points}积分',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 关闭按钮
            TextButton(
              onPressed: widget.onComplete,
              child: const Text(
                '太棒了！',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(BadgeLevel level) {
    switch (level) {
      case BadgeLevel.bronze:
        return const Color(0xFFCD7F32);
      case BadgeLevel.silver:
        return const Color(0xFFC0C0C0);
      case BadgeLevel.gold:
        return const Color(0xFFFFD700);
      case BadgeLevel.platinum:
        return const Color(0xFFE5E4E2);
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'timer':
        return Icons.timer;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'nights_stay':
        return Icons.nights_stay;
      case 'explore':
        return Icons.explore;
      case 'feedback':
        return Icons.feedback;
      case 'directions_run':
        return Icons.directions_run;
      default:
        return Icons.star;
    }
  }
}

/// 粒子效果绘制器
class ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42);

    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * math.pi * 2;
      final distance = progress * 100;
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      final radius = (1 - progress) * 6;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
