import 'package:flutter/material.dart';
import '../models/weekly_data.dart';
import '../widgets/bottom_nav.dart';

/// 打卡记录页面 - 月度视图
class WeeklyViewPage extends StatefulWidget {
  final Function(String) onNavigate;

  const WeeklyViewPage({
    super.key,
    required this.onNavigate,
  });

  @override
  State<WeeklyViewPage> createState() => _WeeklyViewPageState();
}

class _WeeklyViewPageState extends State<WeeklyViewPage>
    with SingleTickerProviderStateMixin {
  late MonthlyStats _monthlyData;
  int? selectedDayIndex;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _monthlyData = MonthlyStats.createSample();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

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
            color: Colors.black.withOpacity(0.05),
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
                        ? const Color(0xFF2DD4BF).withOpacity(0.1)
                        : (isToday ? const Color(0xFF2DD4BF).withOpacity(0.05) : Colors.transparent),
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
            color: Colors.black.withOpacity(0.05),
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
    // final completionRate = (_monthlyData.completedDays / _monthlyData.daysInMonth * 100).toInt();
    final today = DateTime.now();
    final isCurrentMonth = today.year == _monthlyData.year && today.month == _monthlyData.month;
    final remainingDays = _monthlyData.daysInMonth - today.day;

    String insightText;
    if (!isCurrentMonth) {
      insightText = '${_monthlyData.month}月共完成${_monthlyData.completedDays}天训练，累计${_monthlyData.totalMinutes}分钟。';
    } else if (remainingDays > 0) {
      insightText = '本月还剩$remainingDays天，按当前进度预计可完成${_monthlyData.completedDays + remainingDays ~/ 2}天训练。';
    } else {
      insightText = '本月打卡完成！已完成${_monthlyData.completedDays}天训练，累计${_monthlyData.totalMinutes}分钟。';
    }

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
            color: Colors.black.withOpacity(0.05),
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
