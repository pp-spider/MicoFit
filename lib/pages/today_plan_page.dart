import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../widgets/workout_card.dart';
import '../widgets/bottom_nav.dart';

/// 今日计划页面
class TodayPlanPage extends StatefulWidget {
  final WorkoutPlan workoutPlan;
  final VoidCallback onStartWorkout;
  final Function(String) onNavigate;
  final VoidCallback? onRefresh;  // 新增：刷新回调

  const TodayPlanPage({
    super.key,
    required this.workoutPlan,
    required this.onStartWorkout,
    required this.onNavigate,
    this.onRefresh,  // 新增
  });

  @override
  State<TodayPlanPage> createState() => _TodayPlanPageState();
}

class _TodayPlanPageState extends State<TodayPlanPage> {
  int refreshCount = 3;

  void handleRefresh() {
    // 调用外部提供的刷新回调
    widget.onRefresh?.call();
    if (refreshCount > 0) {
      setState(() {
        refreshCount--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayNames = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final dayName = dayNames[now.weekday % 7];
    final hour = now.hour;
    final timeOfDay = hour < 12 ? '早晨' : hour < 18 ? '下午' : '晚间';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(dayName, timeOfDay),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Workout Card
                    WorkoutCard(
                      workoutPlan: widget.workoutPlan,
                      refreshCount: refreshCount,
                      onRefresh: handleRefresh,
                      onStartWorkout: widget.onStartWorkout,
                    ),

                    const SizedBox(height: 24),

                    // Quick Stats
                    _buildQuickStats(),

                    const SizedBox(height: 100), // Space for bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom Navigation
      bottomNavigationBar: BottomNav(
        currentPage: 'today',
        onNavigate: widget.onNavigate,
      ),
    );
  }

  Widget _buildHeader(String dayName, String timeOfDay) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dayName$timeOfDay',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF115E59),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.wb_sunny, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '18°C',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          // Streak Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          value: 3 / 7,
                          strokeWidth: 3,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF2DD4BF),
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: Color(0xFF2DD4BF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '已坚持3天',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF115E59),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('12', '今日分钟', const Color(0xFF2DD4BF)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('3', '连续打卡', const Color(0xFF10B981)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('85%', '目标完成', const Color(0xFF8B5CF6)),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
