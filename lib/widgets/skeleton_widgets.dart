import 'package:flutter/material.dart';

/// 骨架屏 shimmer 效果包装器
class Shimmer extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const Shimmer({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  void _initAnimation() {
    if (!mounted) return;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeInOutSine),
    );

    // 只在加载状态下启动动画
    if (widget.isLoading) {
      _controller!.repeat();
    }
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 根据加载状态控制动画
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller?.repeat();
      } else {
        _controller?.stop();
      }
    }
  }

  @override
  void dispose() {
    // 先停止动画再释放
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
    _animation = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading || _animation == null) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation!,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(_animation!.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double percent;

  const _SlidingGradientTransform(this.percent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0, 0);
  }
}

/// 骨架条
class SkeletonBar extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBar({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// 骨架圆形
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 训练计划卡片骨架屏
class WorkoutCardSkeleton extends StatelessWidget {
  const WorkoutCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),

            // 标题骨架
            const SkeletonBar(width: 180, height: 28, borderRadius: 4),
            const SizedBox(height: 8),
            SkeletonBar(width: 120, height: 16, borderRadius: 4),

            const SizedBox(height: 24),

            // 统计信息骨架
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatSkeleton(),
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                _buildStatSkeleton(),
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                _buildStatSkeleton(),
              ],
            ),

            const SizedBox(height: 24),

            // 模块骨架
            _buildModuleSkeleton(),
            _buildModuleSkeleton(),
            _buildModuleSkeleton(),

            const SizedBox(height: 24),

            // AI 提示骨架
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SkeletonCircle(size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBar(
                          width: double.infinity,
                          height: 14,
                          borderRadius: 4,
                        ),
                        const SizedBox(height: 4),
                        SkeletonBar(width: 200, height: 14, borderRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 按钮骨架
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSkeleton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SkeletonCircle(size: 16),
        const SizedBox(width: 4),
        SkeletonBar(width: 50, height: 14, borderRadius: 4),
      ],
    );
  }

  Widget _buildModuleSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SkeletonCircle(size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBar(width: 100, height: 16, borderRadius: 4),
                const SizedBox(height: 4),
                SkeletonBar(width: 150, height: 12, borderRadius: 4),
              ],
            ),
          ),
          SkeletonBar(width: 40, height: 12, borderRadius: 4),
          const SizedBox(width: 8),
          const SkeletonCircle(size: 20),
        ],
      ),
    );
  }
}

/// 通用列表项骨架屏
class ListItemSkeleton extends StatelessWidget {
  final bool hasSubtitle;
  final bool hasTrailing;

  const ListItemSkeleton({
    super.key,
    this.hasSubtitle = true,
    this.hasTrailing = true,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            const SkeletonCircle(size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBar(width: double.infinity, height: 16),
                  if (hasSubtitle) ...[
                    const SizedBox(height: 8),
                    SkeletonBar(width: 150, height: 12),
                  ],
                ],
              ),
            ),
            if (hasTrailing) ...[
              const SizedBox(width: 16),
              SkeletonBar(width: 60, height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// 统计卡片骨架屏
class StatsCardSkeleton extends StatelessWidget {
  const StatsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonCircle(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBar(width: 80, height: 14),
                      const SizedBox(height: 4),
                      SkeletonBar(width: 120, height: 20),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SkeletonBar(
              width: double.infinity,
              height: 8,
              borderRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
