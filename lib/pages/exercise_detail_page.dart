import 'dart:async';
import 'package:flutter/material.dart';
import '../models/exercise.dart';

/// 动作详情页面（带计时器）
class ExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  const ExerciseDetailPage({
    super.key,
    required this.exercise,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  bool showTimer = false;
  int timeLeft = 0;
  bool isPaused = false;
  bool isCompleted = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    timeLeft = widget.exercise.duration;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    setState(() {
      showTimer = true;
      timeLeft = widget.exercise.duration;
      isPaused = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused && timeLeft > 0) {
        setState(() {
          timeLeft--;
          if (timeLeft == 0) {
            isCompleted = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void togglePause() {
    setState(() {
      isPaused = !isPaused;
    });
    if (!isPaused) {
      _startTimer();
    }
  }

  void skipTimer() {
    _timer?.cancel();
    setState(() {
      showTimer = false;
      timeLeft = widget.exercise.duration;
      isPaused = false;
      isCompleted = false;
    });
  }

  String formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Exercise Image
                _buildExerciseImage(),

                // Exercise Info
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.exercise.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF115E59),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.exercise.duration}秒 × 2侧',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Points
                        _buildActionCard(),

                        const SizedBox(height: 16),

                        // Tips
                        _buildTipsCard(),

                        const SizedBox(height: 16),

                        // Breathing
                        _buildBreathingCard(),

                        const SizedBox(height: 120), // Space for buttons
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF5F5F0).withOpacity(0),
                    const Color(0xFFF5F5F0),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: startTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2DD4BF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow),
                          SizedBox(width: 8),
                          Text(
                            '开始计时',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: widget.onComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF115E59),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check, size: 20),
                        SizedBox(width: 6),
                        Text('已完成'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Timer Overlay
          if (showTimer) _buildTimerOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Color(0xFF115E59),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            '动作详情',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF115E59),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseImage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            widget.exercise.image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getExerciseIcon(),
                      size: 80,
                      color: const Color(0xFF2DD4BF).withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '动作示意图',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  IconData _getExerciseIcon() {
    final name = widget.exercise.name.toLowerCase();
    if (name.contains('颈') || name.contains('肩')) {
      return Icons.accessibility_new;
    } else if (name.contains('腹') || name.contains('核心')) {
      return Icons.circle_outlined;
    } else if (name.contains('腿') || name.contains('蹲')) {
      return Icons.directions_run;
    }
    return Icons.fitness_center;
  }

  Widget _buildActionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.format_list_numbered,
                    size: 14,
                    color: Color(0xFF2DD4BF),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '动作要领',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF115E59),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(
            widget.exercise.steps.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2DD4BF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.exercise.steps[index],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF59E0B),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '注意',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.exercise.tips,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.air,
            color: Color(0xFF2DD4BF),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '呼吸',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.exercise.breathing,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF14B8A6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerOverlay() {
    final progress = widget.exercise.duration - timeLeft;
    final progressPercent = progress / widget.exercise.duration;

    return GestureDetector(
      onTap: () {},
      child: Container(
        color: const Color(0xFF1F2937).withOpacity(0.95),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Timer Circle
              SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background Circle
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 8,
                        backgroundColor: const Color(0xFF374151),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF374151),
                        ),
                      ),
                    ),
                    // Progress Circle
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: progressPercent,
                        strokeWidth: 8,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2DD4BF),
                        ),
                      ),
                    ),
                    // Time Display
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            formatTime(timeLeft),
                            key: ValueKey(timeLeft),
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.exercise.name,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Controls
              if (isCompleted)
                ElevatedButton(
                  onPressed: widget.onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2DD4BF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '完成',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pause/Play Button
                    GestureDetector(
                      onTap: togglePause,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPaused ? Icons.play_arrow : Icons.pause,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Skip Button
                    GestureDetector(
                      onTap: skipTimer,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.skip_next,
                          size: 24,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 32),

              // Skip Text
              if (!isCompleted)
                TextButton(
                  onPressed: skipTimer,
                  child: Text(
                    '跳过',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
