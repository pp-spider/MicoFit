import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../widgets/bottom_nav.dart';

/// 成就徽章展示页面
class AchievementsPage extends StatelessWidget {
  final List<Achievement> achievements;
  final VoidCallback onBack;

  const AchievementsPage({
    super.key,
    required this.achievements,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // 计算统计
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final totalPoints = achievements
        .where((a) => a.isUnlocked)
        .fold(0, (sum, a) => sum + a.level.points);

    // 按类型分组
    final groupedAchievements = <BadgeType, List<Achievement>>{};
    for (final achievement in achievements) {
      groupedAchievements.putIfAbsent(achievement.type, () => []);
      groupedAchievements[achievement.type]!.add(achievement);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 头部
            SliverToBoxAdapter(
              child: _buildHeader(unlockedCount, achievements.length, totalPoints),
            ),
            // 徽章列表
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  ...groupedAchievements.entries.map((entry) {
                    return _buildBadgeGroup(entry.key, entry.value);
                  }),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentPage: 'achievements',
        onNavigate: (page) {
          if (page != 'achievements') {
            onBack();
          }
        },
      ),
    );
  }

  Widget _buildHeader(int unlocked, int total, int points) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            '我的成就',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatCard('$unlocked', '已解锁', Icons.emoji_events),
              const SizedBox(width: 16),
              _buildStatCard('$total', '总徽章', Icons.military_tech),
              const SizedBox(width: 16),
              _buildStatCard('$points', '总积分', Icons.stars),
            ],
          ),
          const SizedBox(height: 16),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? unlocked / total : 0,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '已完成 ${((unlocked / total) * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeGroup(BadgeType type, List<Achievement> badges) {
    final typeLabel = _getTypeLabel(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                typeLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF115E59),
                ),
              ),
            ],
          ),
        ),
        ...badges.map((badge) => _buildBadgeCard(badge)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBadgeCard(Achievement badge) {
    final isUnlocked = badge.isUnlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: isUnlocked
            ? [
          BoxShadow(
            color: _getLevelColor(badge.level).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Row(
        children: [
          // 徽章图标
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: isUnlocked
                  ? LinearGradient(
                colors: [
                  _getLevelColor(badge.level),
                  _getLevelColor(badge.level).withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: isUnlocked ? null : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIconData(badge.iconName),
              color: isUnlocked ? Colors.white : Colors.grey[500],
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // 徽章信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        badge.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isUnlocked
                              ? const Color(0xFF115E59)
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                    // 等级标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? _getLevelColor(badge.level).withValues(alpha: 0.1)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge.level.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isUnlocked
                              ? _getLevelColor(badge.level)
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  badge.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isUnlocked ? Colors.grey[600] : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                // 进度条
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: badge.progressPercent,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isUnlocked
                                ? _getLevelColor(badge.level)
                                : Colors.grey[400]!,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      badge.progressText,
                      style: TextStyle(
                        fontSize: 11,
                        color: isUnlocked ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(BadgeType type) {
    switch (type) {
      case BadgeType.streak:
        return '连续打卡';
      case BadgeType.totalTime:
        return '累计时长';
      case BadgeType.totalDays:
        return '累计天数';
      case BadgeType.earlyBird:
        return '早起鸟';
      case BadgeType.nightOwl:
        return '夜猫子';
      case BadgeType.allScenes:
        return '场景探索';
      case BadgeType.perfectWeek:
        return '完美周';
      case BadgeType.feedbacker:
        return '反馈达人';
      case BadgeType.firstWorkout:
        return '首次成就';
      case BadgeType.consistency:
        return '持之以恒';
    }
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