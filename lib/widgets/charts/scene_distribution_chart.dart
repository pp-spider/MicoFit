import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// 场景分布饼图
/// 展示不同训练场景的使用占比
class SceneDistributionChart extends StatelessWidget {
  final Map<String, int> sceneData;
  final String? title;

  const SceneDistributionChart({
    super.key,
    required this.sceneData,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (sceneData.isEmpty || _calculateTotal() == 0) {
      return _buildEmptyState();
    }

    final sections = _prepareSections();
    final colors = _getSceneColors();

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
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 35,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (event, response) {},
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildLegend(colors),
                ),
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
              Icons.pie_chart_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              '暂无场景数据',
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

  List<PieChartSectionData> _prepareSections() {
    final total = _calculateTotal();
    final colors = _getSceneColors();
    final sections = <PieChartSectionData>[];

    sceneData.forEach((scene, count) {
      final percentage = (count / total * 100).toDouble();
      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          color: colors[scene] ?? Colors.grey,
          radius: 60,
          title: '${percentage.toInt()}%',
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          badgeWidget: _buildBadge(scene, colors[scene] ?? Colors.grey),
          badgePositionPercentageOffset: 1.2,
        ),
      );
    });

    return sections;
  }

  Widget _buildBadge(String scene, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _getSceneIcon(scene),
        color: Colors.white,
        size: 12,
      ),
    );
  }

  Widget _buildLegend(Map<String, Color> colors) {
    final total = _calculateTotal();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sceneData.entries.map((entry) {
          final percentage = (entry.value / total * 100).toInt();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[entry.key] ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF115E59),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF115E59),
                      ),
                    ),
                    Text(
                      '${entry.value}次',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  int _calculateTotal() {
    return sceneData.values.fold(0, (sum, count) => sum + count);
  }

  Map<String, Color> _getSceneColors() {
    final colors = [
      const Color(0xFF2DD4BF), // 薄荷绿
      const Color(0xFF8B5CF6), // 紫色
      const Color(0xFFF59E0B), // 橙色
      const Color(0xFF10B981), // 绿色
      const Color(0xFF3B82F6), // 蓝色
      const Color(0xFFEC4899), // 粉色
      const Color(0xFF6366F1), // 靛蓝
      const Color(0xFF14B8A6), // 青绿
    ];

    final result = <String, Color>{};
    int index = 0;
    sceneData.forEach((scene, _) {
      result[scene] = colors[index % colors.length];
      index++;
    });
    return result;
  }

  IconData _getSceneIcon(String scene) {
    final sceneLower = scene.toLowerCase();
    if (sceneLower.contains('家') || sceneLower.contains('室内')) {
      return Icons.home;
    } else if (sceneLower.contains('办公室') || sceneLower.contains('公司')) {
      return Icons.business;
    } else if (sceneLower.contains('户外') || sceneLower.contains('室外')) {
      return Icons.park;
    } else if (sceneLower.contains('健身房')) {
      return Icons.fitness_center;
    } else if (sceneLower.contains('床')) {
      return Icons.bed;
    } else if (sceneLower.contains('椅')) {
      return Icons.chair;
    }
    return Icons.place;
  }
}
