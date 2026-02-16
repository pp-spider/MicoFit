import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/weekly_data.dart';
import '../widgets/bottom_nav.dart';
import '../providers/monthly_stats_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
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
          // 可点击的日期选择器
          InkWell(
            onTap: () => _showDatePicker(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${_monthlyData.year}年${_monthlyData.month}月',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示年月选择器
  Future<void> _showDatePicker() async {
    // 使用自定义的年月选择器
    final DateTime? selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (context) => _YearMonthPickerDialog(
        initialDate: DateTime(_monthlyData.year, _monthlyData.month),
      ),
    );

    if (selectedDate != null) {
      // 加载选择月份的统计数据
      final provider = context.read<MonthlyStatsProvider>();
      await provider.loadMonthlyStats(selectedDate.year, selectedDate.month);
    }
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

/// 年月选择器对话框
class _YearMonthPickerDialog extends StatefulWidget {
  final DateTime initialDate;

  const _YearMonthPickerDialog({required this.initialDate});

  @override
  State<_YearMonthPickerDialog> createState() => _YearMonthPickerDialogState();
}

class _YearMonthPickerDialogState extends State<_YearMonthPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;

  // 生成年份列表（当前年份前后5年）
  List<int> get _years {
    final currentYear = DateTime.now().year;
    return List.generate(11, (index) => currentYear - 5 + index);
  }

  // 月份名称
  List<String> get _monthNames {
    return ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
  }

  // 获取初始年份索引
  int _getInitialYearIndex() {
    final currentYear = DateTime.now().year;
    return widget.initialDate.year - (currentYear - 5);
  }

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;

    // 初始化控制器并跳转到初始位置
    _yearController = FixedExtentScrollController(
      initialItem: _getInitialYearIndex(),
    );
    _monthController = FixedExtentScrollController(
      initialItem: widget.initialDate.month - 1,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        '选择年月',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF115E59),
        ),
      ),
      content: SizedBox(
        width: 280,
        height: 200,
        child: Row(
          children: [
            // 年份选择器
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListWheelScrollView(
                      controller: _yearController,
                      itemExtent: 50,
                      diameterRatio: 1.2,
                      useMagnifier: true,
                      magnification: 1.1,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedYear = _years[index];
                        });
                      },
                      children: _years.map((year) {
                        final isSelected = year == _selectedYear;
                        return Container(
                          alignment: Alignment.center,
                          child: Text(
                            '$year年',
                            style: TextStyle(
                              fontSize: isSelected ? 20 : 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? const Color(0xFF115E59) : Colors.grey[400],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // 月份选择器
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListWheelScrollView(
                      controller: _monthController,
                      itemExtent: 50,
                      diameterRatio: 1.2,
                      useMagnifier: true,
                      magnification: 1.1,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedMonth = index + 1;
                        });
                      },
                      children: _monthNames.asMap().entries.map((entry) {
                        final month = entry.key + 1;
                        final isSelected = month == _selectedMonth;
                        return Container(
                          alignment: Alignment.center,
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: isSelected ? 20 : 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? const Color(0xFF115E59) : Colors.grey[400],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(DateTime(_selectedYear, _selectedMonth));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2DD4BF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '确定',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
