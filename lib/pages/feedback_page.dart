import 'package:flutter/material.dart';
import '../models/feedback.dart';
import '../services/record_local_service.dart';

/// 训练反馈页面
class FeedbackPage extends StatefulWidget {
  final int workoutDuration;
  final VoidCallback onComplete;

  const FeedbackPage({
    super.key,
    required this.workoutDuration,
    required this.onComplete,
  });

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage>
    with SingleTickerProviderStateMixin {
  CompletionLevel? _completion;
  FeelingLevel? _feeling;
  TomorrowPreference? _tomorrow;

  bool _showAIResponse = false;
  String _aiText = '';
  late AnimationController _animationController;

  final String _fullAiText = '''收到！明天已为你调整：
• 移除跳跃动作
• 增加腰背拉伸
• 强度维持RPE 6''';

  @override
  void initState() {
    super.initState();
    _completion = CompletionLevel.smooth;
    _feeling = FeelingLevel.justRight;
    _tomorrow = TomorrowPreference.maintain;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool get _allAnswered =>
      _completion != null && _feeling != null && _tomorrow != null;

  void _handleSubmit() {
    if (!_allAnswered) return;

    // 保存反馈到本地
    final feedback = WorkoutFeedback(
      completion: _completion!,
      feeling: _feeling!,
      tomorrow: _tomorrow!,
    );

    try {
      final recordService = RecordLocalService();
      recordService.saveFeedback(
        date: DateTime.now(),
        feedback: feedback,
        duration: widget.workoutDuration,
      );
    } catch (e) {
      debugPrint('保存反馈失败: $e');
    }

    setState(() {
      _showAIResponse = true;
    });

    // Typewriter effect
    int index = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 30));
      if (index <= _fullAiText.length) {
        setState(() {
          _aiText = _fullAiText.substring(0, index);
        });
        index++;
        return true;
      }
      return false;
    });
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

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _showAIResponse ? _buildAIResponse() : _buildForm(),
              ),
            ),

            // Submit Button
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Color(0xFF14B8A6),
                ),
                const SizedBox(width: 6),
                const Text(
                  '训练完成',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '辛苦了！今天训练完成',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115E59),
            ),
          ),
          Text(
            '${widget.workoutDuration}分钟',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115E59),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '快来告诉AI你的身体感受',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        // Completion
        _buildQuestion(
          number: 1,
          title: '完成度如何？',
          options: CompletionLevel.values,
          selected: _completion,
          onSelect: (value) => setState(() => _completion = value),
          isGrid: true,
        ),

        const SizedBox(height: 32),

        // Feeling
        _buildQuestion(
          number: 2,
          title: '身体感受？',
          options: FeelingLevel.values,
          selected: _feeling,
          onSelect: (value) => setState(() => _feeling = value),
          isGrid: true,
        ),

        const SizedBox(height: 32),

        // Tomorrow
        _buildQuestion(
          number: 3,
          title: '明天状态预测？',
          options: TomorrowPreference.values,
          selected: _tomorrow,
          onSelect: (value) => setState(() => _tomorrow = value),
          isGrid: false,
        ),

        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildQuestion<T extends Enum>({
    required int number,
    required String title,
    required List<T> options,
    required T? selected,
    required Function(T) onSelect,
    required bool isGrid,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF2DD4BF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF115E59),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (isGrid)
          _buildGridOptions(options, selected, onSelect)
        else
          Column(
            children: options.map((option) {
              final isSelected = selected == option;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildFullWidthOptionButton(
                  option: option,
                  isSelected: isSelected,
                  onSelect: () => onSelect(option),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildOptionButton<T extends Enum>({
    required T option,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    final icon = _getIcon(option);
    final label = _getLabel(option);

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCCFBF1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2DD4BF)
                : Colors.transparent,
            width: 2,
          ),
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
            Icon(
              icon,
              size: 28,
              color: isSelected ? const Color(0xFF0F766E) : Colors.grey[700],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF0F766E)
                    : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridOptions<T extends Enum>(
    List<T> options,
    T? selected,
    Function(T) onSelect,
  ) {
    final List<Widget> rows = [];
    final rowCount = (options.length + 1) ~/ 2;

    for (int row = 0; row < rowCount; row++) {
      rows.add(
        Row(
          children: [
            Expanded(
              child: options.length > row * 2
                  ? _buildOptionButton(
                      option: options[row * 2],
                      isSelected: selected == options[row * 2],
                      onSelect: () => onSelect(options[row * 2]),
                    )
                  : const SizedBox(),
            ),
            if (options.length > row * 2 + 1) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildOptionButton(
                  option: options[row * 2 + 1],
                  isSelected: selected == options[row * 2 + 1],
                  onSelect: () => onSelect(options[row * 2 + 1]),
                ),
              ),
            ],
          ],
        ),
      );

      // Add spacing between rows (except after the last row)
      if (row < rowCount - 1) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(children: rows);
  }

  Widget _buildFullWidthOptionButton<T extends Enum>({
    required T option,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    final icon = _getIcon(option);
    final label = _getLabel(option);
    final sublabel = _getSublabel(option);

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCCFBF1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2DD4BF)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF115E59),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF115E59),
                    ),
                  ),
                  if (sublabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '($sublabel)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF2DD4BF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIResponse() {
    return Column(
      children: [
        // AI Response
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC4B5FD)),
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
                  Icons.smart_toy,
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
                      'AI教练',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5B21B6),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Summary
        Container(
          padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '今日反馈总结',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF115E59),
                ),
              ),
              const SizedBox(height: 16),
              _buildSummaryItem('完成度', _completion?.icon, _completion?.label),
              _buildSummaryItem('身体感受', _feeling?.icon, _feeling?.label),
              _buildSummaryItem('明日计划', _tomorrow?.icon, _tomorrow?.label),
            ],
          ),
        ),

        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildSummaryItem(String? label, IconData? icon, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Row(
            children: [
              if (icon != null) Icon(icon, size: 18, color: const Color(0xFF115E59)),
              if (icon != null) const SizedBox(width: 6),
              Text(
                value ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF115E59),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF5F5F0).withValues(alpha: 0),
            const Color(0xFFF5F5F0),
          ],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _showAIResponse ? widget.onComplete : (_allAnswered ? _handleSubmit : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2DD4BF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_showAIResponse ? Icons.check : Icons.auto_awesome),
              const SizedBox(width: 8),
              Text(
                _showAIResponse ? '查看周历' : '生成明日计划',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon<T>(T option) {
    if (option is CompletionLevel) return option.icon;
    if (option is FeelingLevel) return option.icon;
    if (option is TomorrowPreference) return option.icon;
    return Icons.help_outline;
  }

  String _getLabel<T>(T option) {
    if (option is CompletionLevel) return option.label;
    if (option is FeelingLevel) return option.label;
    if (option is TomorrowPreference) return option.label;
    return '';
  }

  String _getSublabel<T>(T option) {
    if (option is TomorrowPreference) return option.sublabel;
    return '';
  }
}
