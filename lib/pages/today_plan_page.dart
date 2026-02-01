import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workout.dart';
import '../models/weekly_data.dart';
import '../models/workout_progress.dart';
import '../widgets/workout_card.dart';
import '../widgets/bottom_nav.dart';
import '../providers/monthly_stats_provider.dart';
import '../providers/workout_progress_provider.dart';

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
              child: Consumer<MonthlyStatsProvider>(
                builder: (context, monthlyStatsProvider, child) {
                  return SingleChildScrollView(
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

                        // Quick Stats - 使用真实数据
                        _buildQuickStats(monthlyStatsProvider.monthlyStats ?? MonthlyStats.createSample()),

                        const SizedBox(height: 100), // Space for bottom nav
                      ],
                    ),
                  );
                },
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
    return RepaintBoundary(
      child: Padding(
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
                      '微动时刻',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            // 徽章区域（包含连续打卡徽章和进度状态徽章）
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Streak Badge
                _StreakBadge(),
                const SizedBox(width: 8),
                // 进度状态徽章
                _ProgressBadge(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(MonthlyStats monthlyStats) {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 获取今日分钟数
    final todayRecord = monthlyStats.records.firstWhere(
      (r) => r.date == todayKey,
      orElse: () => DayRecord(
        date: todayKey,
        dayOfWeek: now.weekday % 7,
        duration: 0,
        status: DayStatus.none,
      ),
    );
    final todayMinutes = todayRecord.duration;

    // 计算连续打卡天数
    final streakDays = _calculateStreakDays(monthlyStats);

    // 计算目标完成百分比
    final progressPercent = monthlyStats.progressPercent.toInt();

    return Row(
      children: [
        Expanded(
          child: _buildStatCard('$todayMinutes', '今日分钟', const Color(0xFF2DD4BF)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('$streakDays', '连续打卡', const Color(0xFF10B981)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('$progressPercent%', '目标完成', const Color(0xFF8B5CF6)),
        ),
      ],
    );
  }

  /// 计算连续打卡天数（从今天往前推连续完成的天数）
  int _calculateStreakDays(MonthlyStats monthlyStats) {
    final now = DateTime.now();
    int streakDays = 0;

    // 从今天开始往前遍历，最多检查30天
    for (int i = 0; i < 30; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final dateKey = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';

      // 查找该日期的记录
      final record = monthlyStats.records.firstWhere(
        (r) => r.date == dateKey,
        orElse: () => DayRecord(
          date: dateKey,
          dayOfWeek: checkDate.weekday % 7,
          duration: 0,
          status: DayStatus.none,
        ),
      );

      // 如果已完成或部分完成，继续计数；否则中断
      if (record.status == DayStatus.completed || record.status == DayStatus.partial) {
        streakDays++;
      } else if (i == 0) {
        // 今天未完成不算中断，继续往前检查
        continue;
      } else {
        break;
      }
    }

    return streakDays;
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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

/// 连续打卡徽章 - 独立 widget 减少重建范围
class _StreakBadge extends StatelessWidget {
  const _StreakBadge();

  int _calculateStreakDays(MonthlyStats monthlyStats) {
    final now = DateTime.now();
    int streakDays = 0;

    for (int i = 0; i < 30; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final dateKey = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';

      final record = monthlyStats.records.firstWhere(
        (r) => r.date == dateKey,
        orElse: () => DayRecord(
          date: dateKey,
          dayOfWeek: checkDate.weekday % 7,
          duration: 0,
          status: DayStatus.none,
        ),
      );

      if (record.status == DayStatus.completed || record.status == DayStatus.partial) {
        streakDays++;
      } else if (i == 0) {
        continue;
      } else {
        break;
      }
    }

    return streakDays;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Consumer<MonthlyStatsProvider>(
        builder: (context, provider, child) {
          final streakDays = _calculateStreakDays(provider.monthlyStats ?? MonthlyStats.createSample());
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
                          value: (streakDays % 7) / 7,
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
                Text(
                  '已坚持$streakDays天',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF115E59),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 进度状态徽章 - 独立 widget 减少重建范围
class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Consumer<WorkoutProgressProvider>(
        builder: (context, provider, child) {
          if (!provider.hasProgress) {
            return const SizedBox.shrink();
          }

          final progress = provider.progress!;
          final status = progress.status;

          String label;
          Color color;
          IconData icon;

          switch (status) {
            case WorkoutStatus.notStarted:
              return const SizedBox.shrink();
            case WorkoutStatus.inProgress:
              final percent = (progress.progressPercent * 100).toInt();
              label = '进行中 $percent%';
              color = const Color(0xFF2DD4BF);
              icon = Icons.fitness_center;
              break;
            case WorkoutStatus.completed:
              label = '已完成';
              color = const Color(0xFF10B981);
              icon = Icons.check_circle;
              break;
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
