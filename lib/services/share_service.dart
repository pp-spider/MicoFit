import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;

import '../models/achievement.dart';
import '../models/weekly_data.dart';

/// 分享服务类
/// 处理应用内各种分享功能
class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  /// 生成并分享成就卡片
  Future<void> shareAchievement({
    required Achievement achievement,
    required String userName,
  }) async {
    try {
      final imageBytes = await _captureWidget(
        _buildAchievementCard(achievement, userName),
      );

      if (imageBytes == null) {
        throw Exception('生成分享图片失败');
      }

      final file = await _saveImageToTemp(imageBytes, 'achievement.png');

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🎉 我在微动 MicoFit 解锁了「${achievement.name}」成就！\n\n'
            '一起来健身吧！💪',
      );
    } catch (e) {
      debugPrint('分享成就失败: $e');
      rethrow;
    }
  }

  /// 生成并分享月度报告
  Future<void> shareMonthlyReport({
    required MonthlyStats stats,
    required String userName,
  }) async {
    try {
      final imageBytes = await _captureWidget(
        _buildMonthlyReportCard(stats, userName),
      );

      if (imageBytes == null) {
        throw Exception('生成分享图片失败');
      }

      final file = await _saveImageToTemp(imageBytes, 'monthly_report.png');

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📊 我的${stats.month}月运动报告\n'
            '本月共完成${stats.completedDays}天训练\n'
            '总时长${stats.totalMinutes}分钟\n\n'
            '坚持运动，成就更好的自己！\n'
            '#微动MicoFit #健身打卡',
      );
    } catch (e) {
      debugPrint('分享月度报告失败: $e');
      rethrow;
    }
  }

  /// 生成并分享连续打卡里程碑
  Future<void> shareStreakMilestone({
    required int streakDays,
    required String userName,
  }) async {
    try {
      final imageBytes = await _captureWidget(
        _buildStreakMilestoneCard(streakDays, userName),
      );

      if (imageBytes == null) {
        throw Exception('生成分享图片失败');
      }

      final file = await _saveImageToTemp(imageBytes, 'streak_milestone.png');

      String milestoneText;
      if (streakDays >= 100) {
        milestoneText = '🏆 百炼成钢！';
      } else if (streakDays >= 30) {
        milestoneText = '🌟 月度打卡王！';
      } else if (streakDays >= 7) {
        milestoneText = '🔥 周打卡达成！';
      } else {
        milestoneText = '💪 坚持就是胜利！';
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$milestoneText 我在微动 MicoFit 已连续打卡 $streakDays 天！\n\n'
            '一起坚持运动，遇见更好的自己！\n'
            '#微动MicoFit #连续打卡',
      );
    } catch (e) {
      debugPrint('分享连续打卡失败: $e');
      rethrow;
    }
  }

  /// 通用分享文字
  Future<void> shareText(String text) async {
    await Share.share(text);
  }

  /// 捕获 Widget 为图片
  Future<Uint8List?> _captureWidget(Widget widget) async {
    final RenderRepaintBoundary boundary = RenderRepaintBoundary();

    final PipelineOwner pipelineOwner = PipelineOwner();
    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());

    final RenderObjectToWidgetElement<RenderBox> rootElement =
        RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 667),
            devicePixelRatio: 3.0,
          ),
          child: widget,
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.rootNode = boundary;
    boundary.scheduleInitialLayout();

    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  /// 保存图片到临时目录
  Future<File> _saveImageToTemp(Uint8List bytes, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// 构建成就卡片 Widget
  Widget _buildAchievementCard(Achievement achievement, String userName) {
    return Container(
      width: 375,
      height: 667,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fitness_center,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 32),

          // 徽章图标
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              _getIconFromName(achievement.iconName),
              size: 80,
              color: _getColorFromLevel(achievement.level),
            ),
          ),
          const SizedBox(height: 32),

          // 成就名称
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              achievement.name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 成就描述
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              achievement.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 48),

          // 用户名
          Text(
            userName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // 品牌
          Text(
            '微动 MicoFit',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建月度报告卡片 Widget
  Widget _buildMonthlyReportCard(MonthlyStats stats, String userName) {
    final completionRate =
        (stats.completedDays / stats.daysInMonth * 100).toInt();

    return Container(
      width: 375,
      height: 667,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F5F0), Colors.white],
        ),
      ),
      child: Column(
        children: [
          // 顶部装饰
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${stats.month}月运动报告',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 统计数据
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                value: '${stats.completedDays}',
                label: '打卡天数',
                color: const Color(0xFF2DD4BF),
              ),
              _buildStatItem(
                value: '${stats.totalMinutes}',
                label: '总时长(分)',
                color: const Color(0xFF8B5CF6),
              ),
              _buildStatItem(
                value: '$completionRate%',
                label: '完成率',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 日历热力图示意
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  '本月坚持打卡',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115E59),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSimpleCalendar(stats),
              ],
            ),
          ),

          const Spacer(),

          // 底部品牌
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fitness_center,
                color: const Color(0xFF2DD4BF).withOpacity(0.5),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '微动 MicoFit',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 构建简易日历
  Widget _buildSimpleCalendar(MonthlyStats stats) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stats.records.take(28).map((record) {
        final hasData = record.duration > 0;
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: hasData
                ? const Color(0xFF2DD4BF)
                : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(6),
          ),
          child: hasData
              ? const Center(
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              : null,
        );
      }).toList(),
    );
  }

  /// 构建连续打卡里程碑卡片
  Widget _buildStreakMilestoneCard(int streakDays, String userName) {
    return Container(
      width: 375,
      height: 667,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 火焰图标
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: 32),

          // 天数
          Text(
            '$streakDays',
            style: const TextStyle(
              fontSize: 120,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          const Text(
            '天',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),

          // 标题
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              '连续打卡',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // 用户名
          Text(
            userName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // 品牌
          Text(
            '微动 MicoFit',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// 从图标名称获取 IconData
  IconData _getIconFromName(String iconName) {
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
        return Icons.emoji_events;
    }
  }

  /// 从徽章等级获取颜色
  Color _getColorFromLevel(BadgeLevel level) {
    return switch (level) {
      BadgeLevel.bronze => const Color(0xFFCD7F32),
      BadgeLevel.silver => const Color(0xFFC0C0C0),
      BadgeLevel.gold => const Color(0xFFFFD700),
      BadgeLevel.platinum => const Color(0xFFE5E4E2),
    };
  }
}
