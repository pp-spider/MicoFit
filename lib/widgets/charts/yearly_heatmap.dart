import 'package:flutter/material.dart';
import '../../models/weekly_data.dart';

/// 年度训练热力图
/// GitHub 风格的年度活动热力图
class YearlyHeatmap extends StatelessWidget {
  final List<DayRecord> records;
  final int year;
  final String? title;

  const YearlyHeatmap({
    super.key,
    required this.records,
    required this.year,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    // 按日期分组记录
    final recordMap = <String, DayRecord>{};
    for (final record in records) {
      recordMap[record.date] = record;
    }

    // 生成年份的所有日期
    final allDates = _generateYearDates();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 16),
            child: Row(
              children: [
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115E59),
                  ),
                ),
                const Spacer(),
                _buildLegend(),
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 星期标签
              _buildWeekdayLabels(),
              const SizedBox(width: 8),
              // 热力图网格
              _buildHeatmapGrid(allDates, recordMap),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 统计信息
        _buildStats(),
      ],
    );
  }

  Widget _buildWeekdayLabels() {
    final weekdays = ['一', '三', '五', '日'];
    return Column(
      children: weekdays.map((day) {
        return Container(
          height: 14,
          margin: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            day,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeatmapGrid(List<DateTime> allDates, Map<String, DayRecord> recordMap) {
    // 将日期按周分组
    final weeks = <List<DateTime>>[];
    var currentWeek = <DateTime>[];

    for (final date in allDates) {
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
      currentWeek.add(date);
    }
    if (currentWeek.isNotEmpty) {
      // 填充剩余天数
      while (currentWeek.length < 7) {
        currentWeek.add(DateTime(0)); // 占位
      }
      weeks.add(currentWeek);
    }

    return Row(
      children: weeks.map((week) {
        return Column(
          children: week.map((date) {
            if (date.year == 0) {
              return Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.all(1),
              );
            }

            final dateStr =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final record = recordMap[dateStr];
            final intensity = _getIntensity(record);

            return Tooltip(
              message: '$dateStr\n${record?.duration ?? 0}分钟',
              child: Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: _getColorForIntensity(intensity),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        Text(
          '少',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        const SizedBox(width: 4),
        ...List.generate(4, (index) {
          return Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _getColorForIntensity(index),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        const SizedBox(width: 4),
        Text(
          '多',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final totalDays = records.where((r) => r.duration > 0).length;
    final totalMinutes = records.fold(0, (sum, r) => sum + r.duration);
    final maxStreak = _calculateMaxStreak();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('训练天数', '$totalDays天', const Color(0xFF2DD4BF)),
          _buildStatItem('总时长', '${(totalMinutes / 60).toStringAsFixed(1)}小时', const Color(0xFF8B5CF6)),
          _buildStatItem('最长连续', '$maxStreak天', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  List<DateTime> _generateYearDates() {
    final dates = <DateTime>[];
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31);

    // 调整到第一个周一
    var current = startDate;
    while (current.weekday != DateTime.monday) {
      current = current.subtract(const Duration(days: 1));
    }

    // 生成到年底的所有日期
    while (current.isBefore(endDate.add(const Duration(days: 1)))) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  int _getIntensity(DayRecord? record) {
    if (record == null || record.duration == 0) return 0;
    if (record.duration < 10) return 1;
    if (record.duration < 20) return 2;
    if (record.duration < 30) return 3;
    return 4;
  }

  Color _getColorForIntensity(int intensity) {
    final colors = [
      const Color(0xFFE5E7EB), // 0 - 浅灰
      const Color(0xFF99F6E4), // 1 - 浅薄荷
      const Color(0xFF5EEAD4), // 2 - 中薄荷
      const Color(0xFF2DD4BF), // 3 - 标准薄荷
      const Color(0xFF0D9488), // 4 - 深薄荷
    ];
    return colors[intensity.clamp(0, 4)];
  }

  int _calculateMaxStreak() {
    int maxStreak = 0;
    int currentStreak = 0;

    final sortedRecords = List<DayRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final record in sortedRecords) {
      if (record.duration > 0) {
        currentStreak++;
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }
    }

    return maxStreak;
  }
}
