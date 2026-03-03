import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/weekly_data.dart';
import '../widgets/charts/training_trend_chart.dart';
import '../widgets/charts/scene_distribution_chart.dart';
import '../services/ai_enhanced_service.dart';

/// 训练报告页面
class TrainingReportPage extends StatefulWidget {
  final MonthlyStats monthlyStats;
  final Map<String, int> sceneData;
  final VoidCallback onBack;

  const TrainingReportPage({
    super.key,
    required this.monthlyStats,
    required this.sceneData,
    required this.onBack,
  });

  @override
  State<TrainingReportPage> createState() => _TrainingReportPageState();
}

class _TrainingReportPageState extends State<TrainingReportPage> {
  final AIEnhancedService _aiService = AIEnhancedService();
  String? _aiReport;
  bool _isLoading = false;

  Future<void> _generateAIReport() async {
    setState(() => _isLoading = true);

    final report = await _aiService.generateSmartTrainingReport(
      monthlyStats: widget.monthlyStats,
      recentWorkouts: [], // 实际项目中传入最近训练计划
      sceneDistribution: widget.sceneData,
    );

    setState(() {
      _aiReport = report;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 头部
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),
            // 报告内容
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // AI 智能报告卡片
                  _buildAIReportCard(),
                  const SizedBox(height: 24),
                  // 关键指标卡片
                  _buildKeyMetrics(),
                  const SizedBox(height: 24),
                  // 趋势图
                  _buildCard(
                    child: TrainingTrendChart(
                      records: widget.monthlyStats.records,
                      type: ChartType.duration,
                      title: '训练时长趋势',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 完成率趋势
                  _buildCard(
                    child: TrainingTrendChart(
                      records: widget.monthlyStats.records,
                      type: ChartType.completionRate,
                      title: '完成率趋势',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 场景分布
                  if (widget.sceneData.isNotEmpty)
                    _buildCard(
                      child: SceneDistributionChart(
                        sceneData: widget.sceneData,
                        title: '训练场景分布',
                      ),
                    ),
                  const SizedBox(height: 16),
                  // 详细统计
                  _buildDetailedStats(),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  '月度训练报告',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.monthlyStats.year}年${widget.monthlyStats.month}月',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.fitness_center, color: Colors.white, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.monthlyStats.completedDays}天',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '本月训练天数',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIReportCard() {
    if (_aiReport != null) {
      return _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.psychology,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI 智能分析',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115E59),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _generateAIReport,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重新生成'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MarkdownBody(
              data: _aiReport!,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF115E59),
                  height: 1.6,
                ),
                strong: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2DD4BF),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _isLoading ? null : _generateAIReport,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '生成 AI 智能分析报告',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLoading
                        ? 'AI 正在分析你的训练数据...'
                        : '点击获取个性化训练建议和深度分析',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isLoading)
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetrics() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            (widget.monthlyStats.totalMinutes / 60).toStringAsFixed(1),
            '总时长(小时)',
            Icons.timer,
            const Color(0xFF2DD4BF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            widget.monthlyStats.avgDailyMinutes.toStringAsFixed(0),
            '日均(分钟)',
            Icons.trending_up,
            const Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            '${widget.monthlyStats.progressPercent.toInt()}%',
            '目标完成',
            Icons.emoji_events,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
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
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
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
      child: child,
    );
  }

  Widget _buildDetailedStats() {
    final validRecords = widget.monthlyStats.records.where((r) => r.duration > 0).toList();
    final maxDuration = validRecords.isEmpty
        ? 0
        : validRecords.map((r) => r.duration).reduce((a, b) => a > b ? a : b);
    final minDuration = validRecords.isEmpty
        ? 0
        : validRecords.map((r) => r.duration).reduce((a, b) => a < b ? a : b);

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '详细统计',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115E59),
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow('训练天数', '${widget.monthlyStats.completedDays}天'),
          _buildStatRow('总训练时长', '${widget.monthlyStats.totalMinutes}分钟'),
          _buildStatRow('日均训练时长', '${widget.monthlyStats.avgDailyMinutes.toStringAsFixed(1)}分钟'),
          _buildStatRow('目标分钟数', '${widget.monthlyStats.targetMinutes}分钟'),
          _buildStatRow('剩余分钟数', '${widget.monthlyStats.remainingMinutes}分钟'),
          _buildStatRow('单次最长训练', '$maxDuration分钟'),
          _buildStatRow('单次最短训练', '$minDuration分钟'),
          _buildStatRow('完成率', '${widget.monthlyStats.progressPercent.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF115E59),
            ),
          ),
        ],
      ),
    );
  }
}
