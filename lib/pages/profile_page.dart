import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../models/exercise.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';
import '../services/avatar_service.dart';
import '../services/workout_api_service.dart';
import '../widgets/bottom_nav.dart';
import '../providers/workout_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/empty_state_widget.dart';

/// 个人资料页面
class ProfilePage extends StatefulWidget {
  final UserProfile? userProfile;
  final Function(String) onNavigate;
  final VoidCallback onReset;
  final Function(int weeklyDays, int timeBudget)? onSaveGoals; // 新增
  final VoidCallback? onLogout; // 退出登录回调

  const ProfilePage({
    super.key,
    required this.userProfile,
    required this.onNavigate,
    required this.onReset,
    this.onSaveGoals, // 新增
    this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 目标设置状态
  late int _weeklyDays;
  late int _timeBudget;

  // 头像服务
  final AvatarService _avatarService = AvatarService();
  String? _avatarPath;
  bool _isLocalAvatar = true; // 标记当前头像是否为本地头像
  bool _isLoadingAvatar = false;

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
    _loadHistoryPlans();
    _loadAvatar();
  }

  // 加载头像（优先本地，其次服务器）
  Future<void> _loadAvatar() async {
    // 1. 先尝试加载本地头像
    final localPath = await _avatarService.getLocalAvatarPath();
    if (mounted && localPath != null) {
      setState(() {
        _avatarPath = localPath;
        _isLocalAvatar = true;
      });
      return;
    }

    // 2. 如果没有本地头像，尝试从服务器获取
    final serverAvatarUrl = await _avatarService.getServerAvatarUrl();
    if (mounted && serverAvatarUrl != null) {
      // 服务器返回的是相对路径，需要拼接完整URL
      final fullUrl = '${AppConfig.apiBaseUrl}$serverAvatarUrl';
      setState(() {
        _avatarPath = fullUrl;
        _isLocalAvatar = false;
      });
    }
  }

  // 更换头像
  Future<void> _changeAvatar() async {
    setState(() => _isLoadingAvatar = true);

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '更换头像',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        color: Color(0xFF2DD4BF),
                      ),
                    ),
                    title: const Text(
                      '从相册选择',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Color(0xFF2DD4BF),
                      ),
                    ),
                    title: const Text(
                      '拍照',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (source == null) {
      setState(() => _isLoadingAvatar = false);
      return;
    }

    File? imageFile;
    if (source == ImageSource.gallery) {
      imageFile = await _avatarService.pickImageFromGallery();
    } else {
      imageFile = await _avatarService.takePhoto();
    }

    if (imageFile != null) {
      // 先保存到本地
      final savedPath = await _avatarService.saveAvatarLocally(imageFile);
      if (savedPath != null && mounted) {
        setState(() {
          _avatarPath = savedPath;
          _isLocalAvatar = true; // 标记为本地头像
        });
      }

      // 上传到服务器
      final serverAvatarUrl = await _avatarService.uploadAvatarToServer(imageFile);
      if (serverAvatarUrl != null) {
        debugPrint('[ProfilePage] 头像已上传到服务器: $serverAvatarUrl');
      }
    }

    if (mounted) {
      setState(() => _isLoadingAvatar = false);
    }
  }

  // 加载历史训练计划
  Future<void> _loadHistoryPlans() async {
    final workoutProvider = context.read<WorkoutProvider>();
    await workoutProvider.loadHistoryPlans();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 显示成功提示弹窗
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: Colors.green[600],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF115E59),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
    // 自动关闭弹窗
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
    });
  }

  // 显示计划详情弹窗（使用与AI聊天页面相同的UI风格）
  void _showPlanDetailDialog(WorkoutPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildPlanHeader(plan),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 计划统计信息
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPlanStats(plan),
            ),
            const SizedBox(height: 12),
            // 计划详情列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: plan.modules.length,
                itemBuilder: (context, index) {
                  final module = plan.modules[index];
                  return _buildModuleDetail(module, index + 1);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 计划标题（与AI聊天页面相同）
  Widget _buildPlanHeader(WorkoutPlan plan) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2DD4BF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '训练计划',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            plan.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115E59),
            ),
          ),
        ),
      ],
    );
  }

  // 计划统计信息（与AI聊天页面相同）
  Widget _buildPlanStats(WorkoutPlan plan) {
    return Row(
      children: [
        _buildPlanStatItem(Icons.access_time, '${plan.totalDuration}分钟'),
        const SizedBox(width: 16),
        _buildPlanStatItem(Icons.fitness_center, 'RPE ${plan.rpe}'),
        const SizedBox(width: 16),
        _buildPlanStatItem(Icons.location_on, plan.scene),
      ],
    );
  }

  Widget _buildPlanStatItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF115E59)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF115E59),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 模块详细内容（与AI聊天页面相同）
  Widget _buildModuleDetail(WorkoutModule module, int moduleNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '模块 $moduleNumber',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115E59),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  module.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115E59),
                  ),
                ),
              ),
              Text(
                '${module.duration}分钟',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...module.exercises.asMap().entries.map((entry) {
            final exIndex = entry.key;
            final exercise = entry.value;
            return _buildExerciseDetail(exercise, exIndex + 1);
          }),
        ],
      ),
    );
  }

  // 动作详细卡片（与AI聊天页面相同）
  Widget _buildExerciseDetail(Exercise exercise, int exerciseNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$exerciseNumber',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF115E59),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115E59),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${exercise.duration}秒',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115E59),
                  ),
                ),
              ),
            ],
          ),
          if (exercise.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.description_outlined, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exercise.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (exercise.steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.format_list_numbered, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '步骤: ${exercise.steps.join(' → ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (exercise.tips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exercise.tips,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (exercise.breathing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.air, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '呼吸: ${exercise.breathing}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 显示退出登录确认对话框
  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.logout,
              color: Color(0xFF115E59),
            ),
            SizedBox(width: 12),
            Text(
              '退出登录',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF115E59),
              ),
            ),
          ],
        ),
        content: const Text(
          '确定要退出登录吗？退出后需要重新登录才能使用。',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF115E59),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onLogout?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2DD4BF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
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
        body: SafeArea(
          child: EmptyStateWidget.profile(
            onComplete: () => widget.onNavigate('onboarding'),
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
                            color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _isLoadingAvatar ? null : _changeAvatar,
                            child: Stack(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    image: _avatarPath != null
                                        ? DecorationImage(
                                            image: _isLocalAvatar
                                                ? FileImage(File(_avatarPath!))
                                                : NetworkImage(_avatarPath!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _avatarPath == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 32,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                if (_isLoadingAvatar)
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                // 编辑图标
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Color(0xFF2DD4BF),
                                    ),
                                  ),
                                ),
                              ],
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
                                    color: Colors.white.withValues(alpha: 0.9),
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

                    // 成就徽章入口
                    _buildActionButton(
                      icon: Icons.emoji_events,
                      label: '我的成就',
                      onTap: () => widget.onNavigate('achievements'),
                    ),

                    const SizedBox(height: 12),

                    // 训练报告入口
                    _buildActionButton(
                      icon: Icons.bar_chart,
                      label: '训练报告',
                      onTap: () => widget.onNavigate('training_report'),
                    ),

                    const SizedBox(height: 12),

                    // 好友入口
                    _buildActionButton(
                      icon: Icons.people,
                      label: '我的好友',
                      onTap: () => widget.onNavigate('friends'),
                    ),

                    const SizedBox(height: 24),

                    // 历史训练计划卡片（放在修改个人信息之前）
                    _buildHistoryPlansCard(),

                    const SizedBox(height: 16),

                    // Actions
                    _buildActionButton(
                      icon: Icons.edit,
                      label: '修改个人信息',
                      onTap: () => widget.onNavigate('onboarding'),
                    ),

                    const SizedBox(height: 12),

                    const SizedBox(height: 16),

                    // 退出登录按钮
                    if (widget.onLogout != null)
                      _buildActionButton(
                        icon: Icons.logout,
                        label: '退出登录',
                        onTap: () => _showLogoutConfirmDialog(),
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
              color: Colors.black.withValues(alpha: 0.05),
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
            color: Colors.black.withValues(alpha: 0.05),
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
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                '运动目标',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF115E59),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 运动目标 - 静态展示（类似场景元素）
          Row(
            children: [
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.calendar_today,
                  label: '每周运动',
                  value: '$_weeklyDays 天',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGoalCard(
                  icon: Icons.timer,
                  label: '每次训练',
                  value: '$_timeBudget 分钟',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 提示文字
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '如需修改目标，请在信息录入中重新设置',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建目标卡片（静态展示）
  Widget _buildGoalCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF2DD4BF)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115E59),
            ),
          ),
        ],
      ),
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
            color: Colors.black.withValues(alpha: 0.05),
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
                  color: color.withValues(alpha: 0.1),
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

  // 构建历史训练计划卡片
  Widget _buildHistoryPlansCard() {
    return Consumer<WorkoutProvider>(
      builder: (context, workoutProvider, child) {
        final historyPlans = workoutProvider.historyPlans;
        final isLoadingHistory = workoutProvider.isLoadingHistory;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history, color: Color(0xFF2DD4BF), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '历史训练计划',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF115E59),
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (isLoadingHistory)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (historyPlans.isEmpty && !isLoadingHistory)
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.fitness_center, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text(
                          '暂无历史训练计划',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 235, // 固定高度，可完整展示3条记录
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: historyPlans.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final plan = historyPlans[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _showPlanDetailDialog(plan),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: plan.isCompleted
                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        plan.isCompleted ? Icons.check_circle : Icons.play_circle_outline,
                        color: plan.isCompleted
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      plan.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF115E59),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${plan.totalDuration}分钟 · ${plan.scene}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDate(plan.planDate ?? DateTime.now()),
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                      ],
                    ),
                  );
                },
              ),
            ),
            ],
          ),
        );
      },
    );
  }

  // 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
