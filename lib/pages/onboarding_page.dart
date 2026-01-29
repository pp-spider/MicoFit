import 'package:flutter/material.dart';
import '../models/user_profile.dart';

/// 用户画像构建页面 - 3步流程
class OnboardingPage extends StatefulWidget {
  final Function(String userId, UserProfile) onComplete;
  final VoidCallback? onCancel;
  final UserProfile? initialProfile; // 新增：初始用户数据，用于编辑模式
  final String userId; // 用户ID（必填）

  const OnboardingPage({
    super.key,
    required this.onComplete,
    this.onCancel,
    this.initialProfile,
    required this.userId,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 1;
  bool _showResult = false;

  // 文本编辑控制器
  late TextEditingController _nicknameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  // 用户画像数据
  String _nickname = '';
  double _height = 0;
  double _weight = 0;
  double _bmi = 0;
  FitnessLevel _fitnessLevel = FitnessLevel.beginner;
  String _scene = 'office';
  int _timeBudget = 12;
  final List<String> _limitations = [];
  String _equipment = 'none';
  String _goal = 'sedentary';
  int _weeklyDays = 3;
  final List<String> _preferredTime = ['morning'];

  // 健身等级选项
  final List<Map<String, dynamic>> _fitnessLevels = [
    {'value': 'beginner', 'label': '零基础', 'icon': Icons.eco, 'desc': '很少运动'},
    {'value': 'occasional', 'label': '偶尔运动', 'icon': Icons.eco, 'desc': '每周1-2次'},
    {'value': 'regular', 'label': '规律运动', 'icon': Icons.park, 'desc': '每周3次以上'},
  ];

  // 场景选项
  final List<Map<String, dynamic>> _scenes = [
    {'value': 'bed', 'label': '床上', 'icon': Icons.bed},
    {'value': 'office', 'label': '办公室', 'icon': Icons.work},
    {'value': 'living', 'label': '客厅', 'icon': Icons.weekend},
    {'value': 'outdoor', 'label': '户外', 'icon': Icons.park},
    {'value': 'hotel', 'label': '酒店', 'icon': Icons.hotel},
  ];

  // 时间预算选项
  final List<Map<String, dynamic>> _timeOptions = [
    {'value': 5, 'label': '3-5分钟', 'desc': '快速激活'},
    {'value': 12, 'label': '10-15分钟', 'desc': '标准训练'},
    {'value': 20, 'label': '15-20分钟', 'desc': '完整训练'},
  ];

  // 身体限制选项
  final List<Map<String, String>> _limitationOptions = [
    {'value': 'waist', 'label': '腰肌劳损'},
    {'value': 'knee', 'label': '膝盖不适'},
    {'value': 'shoulder', 'label': '肩颈僵硬'},
    {'value': 'wrist', 'label': '手腕不适'},
  ];

  // 装备选项
  final List<Map<String, dynamic>> _equipmentOptions = [
    {'value': 'none', 'label': '仅徒手', 'icon': Icons.back_hand},
    {'value': 'mat', 'label': '有瑜伽垫', 'icon': Icons.self_improvement},
    {'value': 'chair', 'label': '有椅子', 'icon': Icons.chair},
  ];

  // 目标选项
  final List<Map<String, dynamic>> _goals = [
    {'value': 'fat-loss', 'label': '减脂塑形', 'icon': Icons.local_fire_department, 'desc': '燃烧脂肪，塑造线条'},
    {'value': 'sedentary', 'label': '缓解久坐', 'icon': Icons.chair, 'desc': '改善久坐不适'},
    {'value': 'strength', 'label': '增强体能', 'icon': Icons.bolt, 'desc': '提升身体素质'},
    {'value': 'sleep', 'label': '改善睡眠', 'icon': Icons.bedtime, 'desc': '放松身心助眠'},
  ];

  // 偏好时段
  final List<Map<String, dynamic>> _preferredTimes = [
    {'value': 'morning', 'label': '早晨', 'icon': Icons.wb_sunny},
    {'value': 'noon', 'label': '午休', 'icon': Icons.free_breakfast},
    {'value': 'evening', 'label': '晚间', 'icon': Icons.nights_stay},
  ];

  double _calculateBMI(double height, double weight) {
    if (height > 0 && weight > 0) {
      final heightInM = height / 100;
      return (weight / (heightInM * heightInM));
    }
    return 0;
  }

  bool _canProceed() {
    switch (_step) {
      case 1:
        return _nickname.isNotEmpty && _height > 0 && _weight > 0;
      case 2:
        return _scene.isNotEmpty && _timeBudget > 0 && _equipment.isNotEmpty;
      case 3:
        return _goal.isNotEmpty && _weeklyDays > 0 && _preferredTime.isNotEmpty;
      default:
        return false;
    }
  }

  void _handleNext() {
    if (_step < 3) {
      setState(() {
        _step++;
      });
    } else {
      setState(() {
        _showResult = true;
      });
    }
  }

  void _handleBack() {
    if (_step > 1) {
      setState(() {
        _step--;
      });
    }
  }

  void _handleComplete() {
    if (_nickname.isNotEmpty && _height > 0 && _weight > 0) {
      final profile = UserProfile(
        userId: widget.userId,
        nickname: _nickname,
        height: _height,
        weight: _weight,
        bmi: _bmi,
        fitnessLevel: _fitnessLevel,
        scene: _scene,
        timeBudget: _timeBudget,
        limitations: _limitations,
        equipment: _equipment,
        goal: _goal,
        weeklyDays: _weeklyDays,
        preferredTime: _preferredTime,
      );
      widget.onComplete(widget.userId, profile);
    }
  }

  @override
  void initState() {
    super.initState();
    // 初始化控制器
    _nicknameController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();

    // 如果有初始用户数据（编辑模式），预填充表单
    if (widget.initialProfile != null) {
      final profile = widget.initialProfile!;
      _nickname = profile.nickname;
      _height = profile.height;
      _weight = profile.weight;
      _bmi = profile.bmi;
      _fitnessLevel = profile.fitnessLevel;
      _scene = profile.scene;
      _timeBudget = profile.timeBudget;
      _limitations.addAll(profile.limitations);
      _equipment = profile.equipment;
      _goal = profile.goal;
      _weeklyDays = profile.weeklyDays;
      _preferredTime.clear();
      _preferredTime.addAll(profile.preferredTime);

      // 填充控制器
      _nicknameController.text = _nickname;
      _heightController.text = _height > 0 ? _height.toInt().toString() : '';
      _weightController.text = _weight > 0 ? _weight.toInt().toString() : '';
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  IconData _getWeeklyIcon(int days) {
    if (days <= 2) return Icons.speed;
    if (days <= 3) return Icons.directions_walk;
    if (days <= 5) return Icons.directions_run;
    return Icons.local_fire_department;
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return _buildResultPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildStepContent(),
              ),
            ),

            // Footer Button
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ShaderGradient(
                    colors: const [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                    child: const Text(
                      'MicoFit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2DD4BF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '微动',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_step > 1)
                    TextButton(
                      onPressed: _handleBack,
                      child: const Text('返回'),
                    ),
                  // 退出按钮 - 从个人资料页进入时显示
                  if (widget.onCancel != null)
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                      ),
                      tooltip: '退出',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _step / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$_step/3',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 1: 基础信息
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '先认识一下',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF115E59),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '让我们为你定制专属训练计划',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),

        // 昵称
        TextField(
          controller: _nicknameController,
          decoration: const InputDecoration(
            labelText: '昵称',
            hintText: '怎么称呼你？',
          ),
          onChanged: (value) {
            setState(() {
              _nickname = value;
            });
          },
        ),
        const SizedBox(height: 20),

        // 身高体重
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '身高 (cm)',
                  hintText: '170',
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _height = double.tryParse(value) ?? 0;
                    _bmi = _calculateBMI(_height, _weight);
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Stack(
                children: [
                  TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '体重 (kg)',
                      hintText: '65',
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _weight = double.tryParse(value) ?? 0;
                        _bmi = _calculateBMI(_height, _weight);
                      });
                    },
                  ),
                  if (_bmi > 0)
                    Positioned(
                      right: 12,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'BMI ${_bmi.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0F766E),
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 健身基础
        Text(
          '健身基础',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_fitnessLevels.length, (index) {
          final level = _fitnessLevels[index];
          final isSelected = _fitnessLevel.name == level['value'];
          return _buildSelectionCard(
            icon: level['icon'] as IconData,
            label: level['label']!,
            desc: level['desc']!,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _fitnessLevel = FitnessLevel.values.firstWhere(
                  (e) => e.name == level['value'],
                );
              });
            },
          );
        }),

        const SizedBox(height: 100),
      ],
    );
  }

  // Step 2: 运动场景
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '你的运动场景',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF115E59),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '选择最适合你的运动环境',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),

        // 场景选择
        Text(
          '运动场景',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 32) / 5;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _scenes.map((scene) {
                final isSelected = _scene == scene['value'];
                return SizedBox(
                  width: itemWidth,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _scene = scene['value']!;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2DD4BF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            scene['icon'] as IconData,
                            size: 20,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scene['label']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 24),

        // 时间预算
        Text(
          '时间预算',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: List.generate(_timeOptions.length, (index) {
              final option = _timeOptions[index];
              final isSelected = _timeBudget == option['value'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _timeBudget = option['value'] as int;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF0FDFA)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2DD4BF)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['label'],
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF115E59),
                              ),
                            ),
                            Text(
                              option['desc'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        if (isSelected)
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2DD4BF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 18),

        // 身体限制
        Text(
          '身体限制（多选）',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_limitationOptions.length, (index) {
            final limit = _limitationOptions[index];
            final isSelected = _limitations.contains(limit['value']);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _limitations.remove(limit['value']);
                  } else {
                    _limitations.add(limit['value']!);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFFEDD5)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFED7AA)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  limit['label']!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFFC2410C)
                        : Colors.grey[700],
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 18),

        // 可用装备
        Text(
          '可用装备',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(_equipmentOptions.length, (index) {
            final equip = _equipmentOptions[index];
            final isSelected = _equipment == equip['value'];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < _equipmentOptions.length - 1 ? 12 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _equipment = equip['value']!;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2DD4BF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          equip['icon'] as IconData,
                          size: 24,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          equip['label']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 100),
      ],
    );
  }

  // Step 3: 运动目标
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '你的运动目标',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF115E59),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '让我们了解你的期望',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),

        // 核心目标
        Text(
          '核心目标',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemCount: _goals.length,
          itemBuilder: (context, index) {
            final goal = _goals[index];
            final isSelected = _goal == goal['value'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _goal = goal['value']!;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2DD4BF)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      goal['icon'] as IconData,
                      size: 28,
                      color: isSelected ? Colors.white : const Color(0xFF115E59),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      goal['label']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF115E59),
                      ),
                    ),
                    Text(
                      goal['desc']!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white70
                            : Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 18),

        // 每周运动天数
        Row(
          children: [
            Text(
              '每周运动天数',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 4),
            Icon(_getWeeklyIcon(_weeklyDays), size: 16, color: Colors.grey[700]),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                  activeTrackColor: const Color(0xFF2DD4BF),
                  inactiveTrackColor: const Color(0xFFE5E7EB),
                  thumbColor: const Color(0xFF2DD4BF),
                  overlayColor: const Color(0xFF2DD4BF).withOpacity(0.2),
                ),
                child: Slider(
                  value: _weeklyDays.toDouble(),
                  min: 2,
                  max: 7,
                  divisions: 5,
                  onChanged: (value) {
                    setState(() {
                      _weeklyDays = value.toInt();
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '2天',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    Text(
                      '$_weeklyDays天',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2DD4BF),
                      ),
                    ),
                    Text(
                      '7天',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 偏好时段
        Text(
          '偏好时段（多选）',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(_preferredTimes.length, (index) {
            final time = _preferredTimes[index];
            final isSelected = _preferredTime.contains(time['value']);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < _preferredTimes.length - 1 ? 12 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _preferredTime.remove(time['value']);
                      } else {
                        _preferredTime.add(time['value']!);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2DD4BF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          time['icon'] as IconData,
                          size: 24,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          time['label']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required String label,
    required String desc,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCCFBF1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2DD4BF) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF115E59)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF115E59),
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF2DD4BF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 12,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 结果页面
  Widget _buildResultPage() {
    final tags = [
      _scene == 'office' ? '久坐办公族' : '运动爱好者',
      _fitnessLevel == FitnessLevel.beginner
          ? '初级'
          : _fitnessLevel == FitnessLevel.occasional
              ? '中级'
              : '高级',
      _timeBudget <= 5 ? '碎片型' : '标准型',
      '#${_equipment == 'none' ? '徒手' : _equipment == 'mat' ? '瑜伽垫' : '椅子'}',
      ..._limitations.map((l) {
            switch (l) {
              case 'waist':
                return '#腰部重点';
              case 'knee':
                return '#膝盖保护';
              case 'shoulder':
                return '#肩颈重点';
              case 'wrist':
                return '#手腕注意';
              default:
                return '';
            }
          }),
      ..._preferredTime.map((t) {
            switch (t) {
              case 'morning':
                return '#晨间偏好';
              case 'noon':
                return '#午休偏好';
              case 'evening':
                return '#晚间偏好';
              default:
                return '';
            }
          }),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2DD4BF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 40,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                const Text(
                  '你的专属画像生成完毕',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115E59),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI已为你定制个性化训练方案',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 32),

                // Profile Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_nickname的专属画像',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF115E59),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: List.generate(tags.length, (index) {
                          final tag = tags[index];
                          final isHashtag = tag.startsWith('#');
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300 + index * 50),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isHashtag
                                  ? const Color(0xFFEDE9FE)
                                  : const Color(0xFFCCFBF1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isHashtag
                                    ? const Color(0xFFC4B5FD)
                                    : const Color(0xFF99F6E4),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isHashtag
                                    ? const Color(0xFF6D28D9)
                                    : const Color(0xFF0F766E),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Start Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2DD4BF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '开启首日微动',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF5F5F0).withOpacity(0),
            const Color(0xFFF5F5F0),
          ],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canProceed() ? _handleNext : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2DD4BF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _step == 3 ? '生成我的画像' : '继续',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }
}

// ShaderGradient helper widget
class ShaderGradient extends StatelessWidget {
  final Widget child;
  final List<Color> colors;

  const ShaderGradient({
    super.key,
    required this.child,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
      ).createShader(bounds),
      child: child,
    );
  }
}
