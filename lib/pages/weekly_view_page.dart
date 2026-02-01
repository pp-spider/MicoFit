import 'package:flutter/material.dart';
import '../models/weekly_data.dart';
import '../models/workout_record.dart';
import '../models/feedback.dart';
import '../widgets/bottom_nav.dart';
import '../services/record_local_service.dart';

/// 打卡记录页面 - 月度视图
class WeeklyViewPage extends StatefulWidget {
  final MonthlyStats monthlyData;  // 改为必需参数
  final Function(String) onNavigate;

  const WeeklyViewPage({
    super.key,
    required this.monthlyData,  // 必需
    required this.onNavigate,
  });

  @override
  State<WeeklyViewPage> createState() => _WeeklyViewPageState();
}

class _WeeklyViewPageState extends State<WeeklyViewPage>
    with SingleTickerProviderStateMixin {
  int? selectedDayIndex;
  late AnimationController _progressController;

  // 反馈统计数据
  List<WorkoutRecord> _monthlyRecords = [];
  double _avgCompletionScore = 0.0;
  String _commonFeeling = '';
  List<String> _issues = [];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _loadFeedbackData();
  }

  /// 加载本月的反馈数据
  Future<void> _loadFeedbackData() async {
    try {
      final service = RecordLocalService();
      final records = await service.getRecentRecords(limit: 100);

      // 筛选本月记录
      final monthlyRecords = records.where((r) =>
        r.date.year == _monthlyData.year &&
        r.date.month == _monthlyData.month
      ).toList();

      if (mounted) {
        setState(() {
          _monthlyRecords = monthlyRecords;
          _calculateFeedbackStats();
        });
      }
    } catch (e) {
      debugPrint('加载反馈数据失败: $e');
    }
  }

  /// 计算反馈统计数据
  void _calculateFeedbackStats() {
    if (_monthlyRecords.isEmpty) {
      _avgCompletionScore = 0.0;
      _commonFeeling = '暂无数据';
      _issues = [];
      return;
    }

    // 计算平均完成度分数
    double totalScore = 0;
    final feelingCounts = <FeelingLevel, int>{};

    for (final record in _monthlyRecords) {
      // 完成度评分: tooHard=0.3, barely=0.5, smooth=0.8, easy=1.0
      switch (record.feedback.completion) {
        case CompletionLevel.tooHard:
          totalScore += 0.3;
          break;
        case CompletionLevel.barely:
          totalScore += 0.5;
          break;
        case CompletionLevel.smooth:
          totalScore += 0.8;
          break;
        case CompletionLevel.easy:
          totalScore += 1.0;
          break;
      }

      // 统计感受
      final feeling = record.feedback.feeling;
      feelingCounts[feeling] = (feelingCounts[feeling] ?? 0) + 1;

      // 收集问题
      if (record.feedback.completion == CompletionLevel.tooHard) {
        _issues.add('训练强度过高');
      }
      if (record.feedback.feeling == FeelingLevel.uncomfortable) {
        _issues.add('身体不适需要关注');
      }
      if (record.feedback.tomorrow == TomorrowPreference.recovery) {
        _issues.add('需要更多恢复时间');
      }
    }

    // 计算平均值
    _avgCompletionScore = totalScore / _monthlyRecords.length;

    // 找出最常见的感受
    final mostCommonFeeling = feelingCounts.entries
        .reduce((a, b) => (a.value > b.value) ? a : b);
    _commonFeeling = mostCommonFeeling.key.label;
  }

  // Getter 方便访问数据
  MonthlyStats get _monthlyData => widget.monthlyData;

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Month Calendar
                    _buildMonthCalendar(),

                    const SizedBox(height: 24),

                    // Progress Card
                    _buildProgressCard(),

                    const SizedBox(height: 24),

                    // AI Insight
                    _buildAIInsight(),

                    const SizedBox(height: 24),

                    // Day Detail (if selected)
                    if (selectedDayIndex != null &&
                        _monthlyData.records[selectedDayIndex!].duration >
                            0) ...[
                      _buildDayDetail(),
                      const SizedBox(height: 24),
                    ],

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom Navigation
      bottomNavigationBar: BottomNav(
        currentPage: 'weekly',
        onNavigate: widget.onNavigate,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '打卡记录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115E59),
            ),
          ),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                '${_monthlyData.year}年${_monthlyData.month}月',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar() {
    final dayNames = ['日', '一', '二', '三', '四', '五', '六'];
    final firstDayOffset = _monthlyData.firstDayOfWeek;
    final daysInMonth = _monthlyData.daysInMonth;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Weekday Headers
          Row(
            children: dayNames.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )).toList(),
          ),

          const SizedBox(height: 8),

          // Calendar Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = (constraints.maxWidth - 32) / 7;
              final cellHeight = cellWidth * 0.85;

              return Column(
                children: _buildCalendarRows(firstDayOffset, daysInMonth, cellWidth, cellHeight),
              );
            },
          ),

          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(const Color(0xFF2DD4BF), '已完成'),
              const SizedBox(width: 12),
              _buildLegendItem(const Color(0xFFF59E0B), '部分完成'),
              const SizedBox(width: 12),
              _buildLegendItem(const Color(0xFFF3F4F6), '未完成'),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCalendarRows(int firstDayOffset, int daysInMonth, double cellWidth, double cellHeight) {
    final List<Widget> rows = [];
    int day = 1;
    final now = DateTime.now();
    final today = now.day;
    final isCurrentMonth = now.year == _monthlyData.year && now.month == _monthlyData.month;

    // 计算需要几行
    final totalCells = firstDayOffset + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    for (int row = 0; row < rowCount; row++) {
      final List<Widget> cells = [];

      for (int col = 0; col < 7; col++) {
        final index = row * 7 + col;

        if (index < firstDayOffset) {
          // 空白单元格
          cells.add(Expanded(child: SizedBox(height: cellHeight)));
        } else if (day <= daysInMonth) {
          final dayIndex = day - 1;
          final record = _monthlyData.records[dayIndex];
          final isToday = isCurrentMonth && day == today;
          final isSelected = selectedDayIndex == dayIndex;

          cells.add(
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedDayIndex = null;
                    } else {
                      selectedDayIndex = dayIndex;
                    }
                  });
                },
                child: Container(
                  height: cellHeight,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2DD4BF).withValues(alpha: 0.1)
                        : (isToday ? const Color(0xFF2DD4BF).withValues(alpha: 0.05) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(color: const Color(0xFF2DD4BF), width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? const Color(0xFF2DD4BF) : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: cellWidth * 0.5,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _getStatusColor(record.status),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          day++;
        } else {
          // 空白单元格
          cells.add(Expanded(child: SizedBox(height: cellHeight)));
        }
      }

      rows.add(Row(children: cells.map((e) => e).toList()));
    }

    return rows;
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Color _getStatusColor(DayStatus status) {
    switch (status) {
      case DayStatus.completed:
        return const Color(0xFF2DD4BF);
      case DayStatus.partial:
        return const Color(0xFFF59E0B);
      case DayStatus.planned:
        return const Color(0xFFE5E7EB);
      case DayStatus.none:
        return const Color(0xFFF3F4F6);
    }
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本月已积累',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_monthlyData.totalMinutes}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF115E59),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '分钟',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '月度目标',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_monthlyData.targetMinutes}分钟',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF115E59),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress Bar
          Column(
            children: [
              SizedBox(
                height: 12,
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: _monthlyData.progressPercent / 100 *
                              _progressController.value,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_monthlyData.progressPercent.toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2DD4BF),
                    ),
                  ),
                  Text(
                    '还剩 ${_monthlyData.remainingMinutes} 分钟',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Stats Grid
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_monthlyData.completedDays}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2DD4BF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '打卡天数',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_monthlyData.avgDailyMinutes.toInt()}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '日均分钟',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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

  Widget _buildAIInsight() {
    // 生成基于反馈的洞察文本
    final insightText = _generateInsightText();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF8B5CF6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI洞察',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5B21B6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  insightText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 生成基于反馈数据的洞察文本
  String _generateInsightText() {
    if (_monthlyRecords.isEmpty) {
      return '本月还没有训练记录，完成第一次训练后AI将为你生成个性化洞察！';
    }

    final buffer = StringBuffer();
    final score = (_avgCompletionScore * 100).toInt();

    // 开场总结
    buffer.writeln('💪 ${_monthlyData.month}月训练小结');
    buffer.writeln();

    // 评分
    buffer.writeln('**综合评分**: $score/100');
    buffer.writeln('完成度: ${_getCompletionLabel(_avgCompletionScore)}');
    buffer.writeln('身体感受: $_commonFeeling');
    buffer.writeln();

    // 建议部分
    if (_issues.isNotEmpty) {
      buffer.writeln('**需要关注**:');
      _issues.take(2).forEach((issue) {
        buffer.writeln('• $issue');
      });
      buffer.writeln();
    }

    // 鼓励语
    buffer.writeln(_getEncouragement(score));

    return buffer.toString().trim();
  }

  /// 获取完成度标签
  String _getCompletionLabel(double score) {
    if (score >= 0.8) return '优秀';
    if (score >= 0.6) return '良好';
    if (score >= 0.4) return '一般';
    return '需改进';
  }

  /// 根据分数获取鼓励语
  String _getEncouragement(int score) {
    if (score >= 80) {
      return '🎉 太棒了！你的训练状态非常好，继续保持！';
    } else if (score >= 60) {
      return '👍 表现不错！再接再厉，挑战更高目标！';
    } else if (score >= 40) {
      return '💪 继续坚持！每一次训练都在进步！';
    } else {
      return '🌱 不要气馁！科学训练，循序渐进！';
    }
  }

  Widget _buildDayDetail() {
    final record = _monthlyData.records[selectedDayIndex!];
    final dateParts = record.date.split('-');
    final day = int.parse(dateParts[2]);
    final month = int.parse(dateParts[1]);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$month月$day日',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF115E59),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.status.label,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor(record.status),
                  shape: BoxShape.circle,
                ),
                child: record.status == DayStatus.completed ||
                    record.status == DayStatus.partial
                    ? const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 24,
                )
                    : Center(
                  child: Text(
                    '-',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '训练时长',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                '${record.duration} 分钟',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF115E59),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {},
            icon: const Text('查看详细记录'),
            label: const Icon(Icons.chevron_right, size: 18),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2DD4BF),
            ),
          ),
        ],
      ),
    );
  }
}
