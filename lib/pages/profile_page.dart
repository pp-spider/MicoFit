import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../widgets/bottom_nav.dart';
import '../providers/auth_provider.dart';

/// 个人资料页面
class ProfilePage extends StatefulWidget {
  final UserProfile? userProfile;
  final Function(String) onNavigate;
  final VoidCallback onReset;
  final Function(int weeklyDays, int timeBudget)? onSaveGoals;  // 新增

  const ProfilePage({
    super.key,
    required this.userProfile,
    required this.onNavigate,
    required this.onReset,
    this.onSaveGoals,  // 新增
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 目标设置状态
  late int _weeklyDays;
  late int _timeBudget;

  @override
  void initState() {
    super.initState();
    if (widget.userProfile != null) {
      _weeklyDays = widget.userProfile!.weeklyDays;
      _timeBudget = widget.userProfile!.timeBudget;
    } else {
      _weeklyDays = 3;
      _timeBudget = 12;
    }
  }

  // 健身等级映射
  String _getFitnessLevelLabel(FitnessLevel level) {
    switch (level) {
      case FitnessLevel.beginner:
        return '零基础';
      case FitnessLevel.occasional:
        return '偶尔运动';
      case FitnessLevel.regular:
        return '规律运动';
    }
  }

  // 场景映射
  String _getSceneLabel(String scene) {
    switch (scene) {
      case 'bed':
        return '床上';
      case 'office':
        return '办公室';
      case 'living':
        return '客厅';
      case 'outdoor':
        return '户外';
      case 'hotel':
        return '酒店';
      default:
        return scene;
    }
  }

  // 装备映射
  String _getEquipmentLabel(String equipment) {
    switch (equipment) {
      case 'none':
        return '仅徒手';
      case 'mat':
        return '有瑜伽垫';
      case 'chair':
        return '有椅子';
      default:
        return equipment;
    }
  }

  // 目标映射
  String _getGoalLabel(String goal) {
    switch (goal) {
      case 'fat-loss':
        return '减脂塑形';
      case 'sedentary':
        return '缓解久坐';
      case 'strength':
        return '增强体能';
      case 'sleep':
        return '改善睡眠';
      default:
        return goal;
    }
  }

  // 时间映射
  // String _getTimeLabel(int minutes) {
  //   switch (minutes) {
  //     case 5:
  //       return '3-5分钟';
  //     case 12:
  //       return '10-15分钟';
  //     case 20:
  //       return '15-20分钟';
  //     default:
  //       return '$minutes分钟';
  //   }
  // }

  // 限制映射
  String _getLimitationsLabels(List<String> limitations) {
    return limitations.map((l) {
      switch (l) {
        case 'waist':
          return '腰部';
        case 'knee':
          return '膝盖';
        case 'shoulder':
          return '肩颈';
        case 'wrist':
          return '手腕';
        default:
          return l;
      }
    }).join('、');
  }

  @override
  Widget build(BuildContext context) {
    // 未登录状态
    if (widget.userProfile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                '尚未完善个人信息',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => widget.onNavigate('onboarding'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DD4BF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('去录入'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  const Text(
                    '我的',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF115E59),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // User Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2DD4BF).withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.userProfile!.nickname,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getFitnessLevelLabel(widget.userProfile!.fitnessLevel),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 参数展示 - 改为2行2列布局
                    Row(
                      children: [
                        _buildMiniStat(
                          Icons.local_fire_department,
                          'BMI',
                          widget.userProfile!.bmi.toStringAsFixed(1),
                        ),
                        const SizedBox(width: 12),
                        _buildMiniStat(
                          Icons.height,
                          '身高',
                          '${widget.userProfile!.height.toInt()}cm',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildMiniStat(
                          Icons.monitor_weight,
                          '体重',
                          '${widget.userProfile!.weight.toInt()}kg',
                        ),
                        const SizedBox(width: 12),
                        _buildMiniStat(
                          Icons.emoji_events,
                          '核心目标',
                          _getGoalLabel(widget.userProfile!.goal),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Goal Setting Card - 从周历迁移过来的功能
                    _buildGoalSettingCard(),

                    const SizedBox(height: 16),

                    // Settings Card
                    _buildInfoCard(
                      icon: Icons.place,
                      title: '运动场景',
                      color: const Color(0xFF2DD4BF),
                      items: [
                        _buildInfoItem('常用场景', _getSceneLabel(widget.userProfile!.scene)),
                        _buildInfoItem('可用装备', _getEquipmentLabel(widget.userProfile!.equipment)),
                        if (widget.userProfile!.limitations.isNotEmpty)
                          _buildInfoItem('身体限制', _getLimitationsLabels(widget.userProfile!.limitations), isWarning: true),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    _buildActionButton(
                      icon: Icons.edit,
                      label: '修改个人信息',
                      onTap: () => widget.onNavigate('onboarding'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.logout,
                      label: '退出登录',
                      onTap: _showLogoutConfirmDialog,
                      isSecondary: true,
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.refresh,
                      label: '重新录入',
                      onTap: _showResetConfirmDialog,
                      isSecondary: true,
                    ),

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
        currentPage: 'profile',
        onNavigate: widget.onNavigate,
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value, {Color? iconColor}) {
    final effectiveIconColor = iconColor ?? const Color(0xFF2DD4BF);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: effectiveIconColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF115E59),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSettingCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                '运动目标设置',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF115E59),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Weekly Days Slider
          _buildSlider(
            label: '每周运动天数',
            value: _weeklyDays.toDouble(),
            min: 2,
            max: 7,
            unit: ' 天',
            onChanged: (value) {
              setState(() {
                _weeklyDays = value.toInt();
              });
            },
          ),

          const SizedBox(height: 20),

          // Duration Slider
          _buildSlider(
            label: '每次训练时长',
            value: _timeBudget.toDouble(),
            min: 5,
            max: 30,
            step: 5,
            unit: ' 分钟',
            onChanged: (value) {
              setState(() {
                _timeBudget = value.toInt();
              });
            },
          ),

          const SizedBox(height: 20),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // 调用外部保存回调
                widget.onSaveGoals?.call(_weeklyDays, _timeBudget);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2DD4BF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('保存目标'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required int min,
    required int max,
    int step = 1,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    final displayValue = value.toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            Text(
              '$displayValue$unit',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF115E59),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: const Color(0xFF2DD4BF),
            inactiveTrackColor: const Color(0xFFE5E7EB),
            thumbColor: const Color(0xFF2DD4BF),
            overlayColor: const Color(0xFF2DD4BF).withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: ((max - min) / step).ceil(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF115E59),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool isWarning = false}) {
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isWarning ? const Color(0xFFF59E0B) : const Color(0xFF115E59),
            ),
          ),
        ],
      ),
    );
  }

  // 显示重新录入确认对话框
  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '确认重新录入',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115E59),
            ),
          ),
          content: const Text(
            '重新录入将清除当前的所有个人信息，您需要重新完成信息录入流程。\n\n确定要继续吗？',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onReset();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 显示登出确认对话框
  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '退出登录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115E59),
            ),
          ),
          content: const Text(
            '确定要退出登录吗？',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final authProvider = context.read<AuthProvider>();
                final prefs = await SharedPreferences.getInstance();
                await authProvider.logout(prefs);
                widget.onNavigate('login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSecondary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSecondary ? Colors.grey[500] : const Color(0xFF115E59),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isSecondary ? Colors.grey[600] : const Color(0xFF115E59),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
