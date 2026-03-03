import 'package:flutter/material.dart';

/// 动画管理混入
/// 帮助管理动画控制器的生命周期，自动处理 dispose
///
/// 使用示例：
/// ```dart
/// class _MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, AnimationManagerMixin {
///
///   @override
///   void initState() {
///     super.initState();
///     // 创建动画控制器
///     final controller = createAnimationController(
///       duration: const Duration(milliseconds: 300),
///     );
///     controller.forward();
///   }
/// }
/// ```
mixin AnimationManagerMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  /// 管理的动画控制器列表
  final List<AnimationController> _controllers = [];

  /// 是否正在 dispose
  bool _isDisposing = false;

  /// 创建一个动画控制器并自动管理其生命周期
  AnimationController createAnimationController({
    Duration? duration,
    Duration? reverseDuration,
    String? debugLabel,
    double initialValue = 0.0,
    double lowerBound = 0.0,
    double upperBound = 1.0,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
  }) {
    assert(!_isDisposing, 'Cannot create animation controller after dispose started');

    final controller = AnimationController(
      vsync: this,
      duration: duration,
      reverseDuration: reverseDuration,
      debugLabel: debugLabel,
      value: initialValue,
      lowerBound: lowerBound,
      upperBound: upperBound,
      animationBehavior: animationBehavior,
    );

    _controllers.add(controller);
    return controller;
  }

  /// 注册一个已存在的动画控制器
  void registerAnimationController(AnimationController controller) {
    assert(!_isDisposing, 'Cannot register animation controller after dispose started');
    if (!_controllers.contains(controller)) {
      _controllers.add(controller);
    }
  }

  /// 注销并释放一个动画控制器
  void unregisterAnimationController(AnimationController controller) {
    _stopAndDisposeController(controller);
    _controllers.remove(controller);
  }

  /// 停止所有动画
  void stopAllAnimations() {
    for (final controller in _controllers) {
      if (controller.isAnimating) {
        controller.stop();
      }
    }
  }

  /// 释放所有动画控制器
  void disposeAllControllers() {
    for (final controller in List<AnimationController>.from(_controllers)) {
      _stopAndDisposeController(controller);
    }
    _controllers.clear();
  }

  void _stopAndDisposeController(AnimationController controller) {
    try {
      if (controller.isAnimating) {
        controller.stop();
      }
      controller.dispose();
    } catch (e) {
      // 忽略已释放的控制器
      debugPrint('AnimationManager: Error disposing controller: $e');
    }
  }

  @mustCallSuper
  @override
  void dispose() {
    _isDisposing = true;
    disposeAllControllers();
    super.dispose();
  }
}

/// 安全的 AnimatedBuilder
/// 当动画控制器被释放后自动停止监听
class SafeAnimatedBuilder extends StatefulWidget {
  final AnimationController? animation;
  final Listenable? listenable;
  final TransitionBuilder builder;
  final Widget? child;

  const SafeAnimatedBuilder({
    super.key,
    this.animation,
    this.listenable,
    required this.builder,
    this.child,
  }) : assert(animation != null || listenable != null,
         'Either animation or listenable must be provided');

  @override
  State<SafeAnimatedBuilder> createState() => _SafeAnimatedBuilderState();
}

class _SafeAnimatedBuilderState extends State<SafeAnimatedBuilder> {
  Listenable? _effectiveAnimation;

  @override
  void initState() {
    super.initState();
    _effectiveAnimation = widget.animation ?? widget.listenable;
  }

  @override
  void didUpdateWidget(SafeAnimatedBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation ||
        widget.listenable != oldWidget.listenable) {
      _effectiveAnimation = widget.animation ?? widget.listenable;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_effectiveAnimation == null) {
      return widget.builder(context, widget.child);
    }

    return AnimatedBuilder(
      animation: _effectiveAnimation!,
      builder: widget.builder,
      child: widget.child,
    );
  }
}

/// 条件动画包装器
/// 只在条件满足时运行动画
class ConditionalAnimation extends StatefulWidget {
  final bool condition;
  final Widget child;
  final Duration duration;
  final Curve curve;

  const ConditionalAnimation({
    super.key,
    required this.condition,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });

  @override
  State<ConditionalAnimation> createState() => _ConditionalAnimationState();
}

class _ConditionalAnimationState extends State<ConditionalAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    if (widget.condition) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ConditionalAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.condition != oldWidget.condition) {
      if (widget.condition) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}
