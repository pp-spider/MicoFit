import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/weekly_data.dart';

/// 训练趋势折线图
/// 展示训练时长或完成率的趋势
class TrainingTrendChart extends StatelessWidget {
  final List<DayRecord> records;
  final ChartType type;
  final String? title;

  const TrainingTrendChart({
    super.key,
    required this.records,
    this.type = ChartType.duration,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2DD4BF);
    const secondaryColor = Color(0xFF8B5CF6);

    // 过滤有效记录（已训练的天数）
    final validRecords = records.where((r) => r.duration > 0).toList();

    if (validRecords.isEmpty) {
      return _buildEmptyState();
    }

    // 准备数据点
    final spots = _prepareDataPoints();

    // 计算最大值用于Y轴
    final maxY = _calculateMaxY();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 16),
            child: Text(
              title!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF115E59),
              ),
            ),
          ),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[200],
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: maxY / 4,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        type == ChartType.duration
                            ? '${value.toInt()}分'
                            : '${value.toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: (records.length / 5).ceil().toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < records.length) {
                        final date = records[index].date.split('-');
                        return Text(
                          '${date[1]}/${date[2]}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (records.length - 1).toDouble(),
              minY: 0,
              maxY: maxY * 1.2,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: primaryColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: spots.length < 15,
                    getDotPainter: (spot, percent, bar, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: primaryColor,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: primaryColor.withValues(alpha: 0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => const Color(0xFF115E59),
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      final record = records[index];
                      return LineTooltipItem(
                        '${record.date}\n',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: type == ChartType.duration
                                ? '${spot.y.toInt()}分钟'
                                : '${spot.y.toInt()}%完成',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        // 图例和统计
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                '总训练',
                type == ChartType.duration
                    ? '${_calculateTotal()}分钟'
                    : '${_calculateAverage().toInt()}%',
                primaryColor,
              ),
              _buildStatItem(
                '平均每日',
                type == ChartType.duration
                    ? '${_calculateAverage().toInt()}分钟'
                    : '${_calculateTotal()}天',
                secondaryColor,
              ),
              _buildStatItem(
                '最高记录',
                type == ChartType.duration
                    ? '${_calculateMax().toInt()}分钟'
                    : '100%',
                Colors.orange,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              '暂无数据',
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

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF115E59),
          ),
        ),
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

  List<FlSpot> _prepareDataPoints() {
    final spots = <FlSpot>[];
    for (int i = 0; i < records.length; i++) {
      final value = type == ChartType.duration
          ? records[i].duration.toDouble()
          : _getCompletionRate(records[i]);
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }

  double _getCompletionRate(DayRecord record) {
    // 基于状态返回完成率
    switch (record.status) {
      case DayStatus.completed:
        return 100;
      case DayStatus.partial:
        return 50;
      default:
        return 0;
    }
  }

  double _calculateMaxY() {
    if (records.isEmpty) return 100;
    double max = 0;
    for (final record in records) {
      final value = type == ChartType.duration
          ? record.duration.toDouble()
          : _getCompletionRate(record);
      if (value > max) max = value;
    }
    return max > 0 ? max : 100;
  }

  double _calculateTotal() {
    if (type == ChartType.duration) {
      return records.fold(0, (sum, r) => sum + r.duration).toDouble();
    } else {
      return records.where((r) => r.status == DayStatus.completed).length.toDouble();
    }
  }

  double _calculateAverage() {
    final validRecords = records.where((r) => r.duration > 0).length;
    if (validRecords == 0) return 0;
    return _calculateTotal() / validRecords;
  }

  double _calculateMax() {
    double max = 0;
    for (final record in records) {
      final value = type == ChartType.duration
          ? record.duration.toDouble()
          : _getCompletionRate(record);
      if (value > max) max = value;
    }
    return max;
  }
}

enum ChartType {
  duration, // 训练时长
  completionRate, // 完成率
}
