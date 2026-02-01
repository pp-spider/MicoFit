import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'pages/today_plan_page.dart';
import 'pages/exercise_detail_page.dart';
import 'pages/feedback_page.dart';
import 'pages/weekly_view_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/profile_page.dart';
import 'pages/ai_chat_page.dart';
import 'models/exercise.dart';
import 'models/user_profile.dart';
import 'models/weekly_data.dart';
import 'providers/user_profile_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/monthly_stats_provider.dart';
import 'providers/workout_progress_provider.dart';
import 'providers/chat_provider.dart';
import 'utils/user_id_generator.dart';
import 'models/workout_progress.dart';

/// 微动 MicoFit - Flutter 应用入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 初始化 SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // 创建本地用户ID
  await UserIdGenerator.getOrCreateLocalUserId();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProfileProvider(prefs: prefs)..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkoutProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => MonthlyStatsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkoutProgressProvider()..loadTodayProgress(),
        ),
        ChangeNotifierProvider(
          create: (context) => ChatProvider(
            userProfileProvider: context.read<UserProfileProvider>(),
          )..loadHistory(),
        ),
      ],
      child: const MicoFitApp(),
    ),
  );
}

class MicoFitApp extends StatelessWidget {
  const MicoFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '微动 MicoFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2DD4BF),
          primary: const Color(0xFF2DD4BF),
          secondary: const Color(0xFF8B5CF6),
        ),
        fontFamily: 'System',
        scaffoldBackgroundColor: const Color(0xFFF5F5F0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5F0),
          foregroundColor: Color(0xFF115E59),
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2DD4BF),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF115E59),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF115E59),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2DD4BF)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
      home: const MainPage(),
    );
  }
}

/// 主页面 - 管理路由和状态
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // 当前页面
  String _currentPage = 'loading';

  // 数据
  Exercise? _selectedExercise;

  // 训练状态管理
  int _currentModuleIndex = 0;
  int _currentExerciseIndex = 0;
  List<Exercise>? _currentExerciseList; // 扁平化的动作列表

  // 主标签页列表（平级页面）
  final List<String> _mainTabs = ['today', 'weekly', 'ai', 'profile'];

  // 记录进入子页面前的父主页
  String? _parentMainTab;

  // 双击退出相关
  DateTime? _lastBackPressedTime;
  static const _exitTimeLimit = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // 加载用户画像
  Future<void> _loadUserProfile() async {
    final profileProvider = context.read<UserProfileProvider>();
    final workoutProvider = context.read<WorkoutProvider>();
    final statsProvider = context.read<MonthlyStatsProvider>();

    // 初始化并检查本地画像
    await profileProvider.init();

    if (profileProvider.hasProfile) {
      // 有画像：加载训练计划和月度统计，跳转今日计划
      workoutProvider.loadTodayWorkout();
      // 加载月度统计数据，用于坚持天数显示
      final now = DateTime.now();
      statsProvider.loadMonthlyStats(now.year, now.month);
      setState(() => _currentPage = 'today');
      _parentMainTab = 'today';
    } else {
      // 无画像：跳转 onboarding
      setState(() => _currentPage = 'onboarding');
    }
  }

  // 页面导航
  void _navigateTo(String page) {
    final previousPage = _currentPage;

    setState(() {
      _currentPage = page;
    });

    // 如果从主页导航到子页面，记录父主页
    if (_mainTabs.contains(previousPage) && !_mainTabs.contains(page)) {
      _parentMainTab = previousPage;
    }

    // 如果是主页之间的切换，清除父主页记录
    if (_mainTabs.contains(page)) {
      _parentMainTab = null;
    }

    // 当导航回today页面时，重新加载训练计划和月度统计
    if (page == 'today') {
      context.read<WorkoutProvider>().loadTodayWorkout();
      // 同时加载月度统计数据，用于坚持天数显示
      final now = DateTime.now();
      context.read<MonthlyStatsProvider>().loadMonthlyStats(
        now.year,
        now.month,
      );
    }

    // 当导航到weekly页面时，加载月度统计数据
    if (page == 'weekly') {
      final now = DateTime.now();
      context.read<MonthlyStatsProvider>().loadMonthlyStats(
        now.year,
        now.month,
      );
    }
  }

  // 处理返回手势
  Future<bool> _onWillPop() async {
    // 如果在加载页面，不允许返回
    if (_currentPage == 'loading') {
      return false;
    }

    // 如果在主标签页上，实现双击退出
    if (_mainTabs.contains(_currentPage)) {
      final now = DateTime.now();

      // 第一次按返回，显示提示
      if (_lastBackPressedTime == null ||
          now.difference(_lastBackPressedTime!) > _exitTimeLimit) {
        _lastBackPressedTime = now;

        // 显示"再按一次退出"提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '再按一次退出',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.grey.withValues(alpha: 0.8),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
        return false;
      }

      // 第二次按返回（在2秒内），允许退出
      return true;
    }

    // 子页面（exercise、feedback、onboarding）返回到父主页
    if (_parentMainTab != null) {
      // 返回到父主页
      final targetPage = _parentMainTab!;
      _parentMainTab = null;
      setState(() {
        _currentPage = targetPage;
      });
      if (targetPage == 'today') {
        context.read<WorkoutProvider>().loadTodayWorkout();
      }
    } else {
      // 如果没有记录父主页，返回到today
      setState(() {
        _currentPage = 'today';
      });
      context.read<WorkoutProvider>().loadTodayWorkout();
    }
    return false; // 阻止退出APP
  }

  // 完成用户画像构建
  void _handleOnboardingComplete(String userId, UserProfile profile) async {
    final profileProvider = context.read<UserProfileProvider>();
    final workoutProvider = context.read<WorkoutProvider>();

    await profileProvider.saveProfile(profile);

    // 加载训练计划
    await workoutProvider.loadTodayWorkout();

    if (mounted) {
      setState(() {
        _currentPage = 'today';
      });
    }
  }

  // 开始训练
  void _startWorkout() async {
    final workoutProvider = context.read<WorkoutProvider>();
    final progressProvider = context.read<WorkoutProgressProvider>();
    final modules = workoutProvider.todayWorkout?.modules ?? [];

    // 扁平化所有动作到一个列表
    _currentExerciseList = modules
        .expand((module) => module.exercises)
        .toList();

    // 检查是否有未完成的进度
    if (progressProvider.isInProgress) {
      final progress = progressProvider.progress!;

      // 显示恢复进度对话框
      final shouldResume = await _showResumeDialog(progress);
      if (shouldResume == false) {
        // 用户选择重新开始
        await progressProvider.resetProgress(workoutProvider.todayWorkout!);
      }
    }

    // 如果有进度，从进度处继续
    if (progressProvider.progress != null && progressProvider.isInProgress) {
      final progress = progressProvider.progress!;
      _currentModuleIndex = progress.currentModuleIndex;
      _currentExerciseIndex = progress.currentExerciseIndex;
    } else {
      _currentModuleIndex = 0;
      _currentExerciseIndex = 0;
    }

    if (_currentExerciseList!.isNotEmpty) {
      // 开始训练
      await progressProvider.startWorkout(workoutProvider.todayWorkout!);

      setState(() {
        _selectedExercise = _currentExerciseList![_currentExerciseIndex];
        _currentPage = 'exercise';
      });
    }
  }

  // 完成训练动作
  void _completeExercise() async {
    final progressProvider = context.read<WorkoutProgressProvider>();
    final currentExercise = _selectedExercise!;

    // 添加到已完成列表
    final List<String> completedIds = [
      ...(progressProvider.progress?.completedExerciseIds ?? []),
      currentExercise.id,
    ];

    _currentExerciseIndex++;

    // 保存进度
    await progressProvider.updateProgress(
      currentModuleIndex: _currentModuleIndex,
      currentExerciseIndex: _currentExerciseIndex,
      completedExerciseIds: completedIds,
    );

    // 检查是否还有下一个动作
    if (_currentExerciseIndex < _currentExerciseList!.length) {
      // 更新模块索引
      _updateModuleIndex();

      setState(() {
        _selectedExercise = _currentExerciseList![_currentExerciseIndex];
      });
    } else {
      // 所有动作完成，标记为完成
      await progressProvider.completeWorkout();

      setState(() {
        _currentPage = 'feedback';
        _selectedExercise = null;
      });
    }
  }

  // 完成反馈
  void _completeFeedback() {
    setState(() {
      _currentPage = 'weekly';
    });

    // 加载月度数据
    final now = DateTime.now();
    context.read<MonthlyStatsProvider>().loadMonthlyStats(
      now.year,
      now.month,
    );
  }

  // 更新模块索引（根据当前动作索引计算）
  void _updateModuleIndex() {
    final workoutProvider = context.read<WorkoutProvider>();
    final modules = workoutProvider.todayWorkout?.modules ?? [];
    int count = 0;

    for (int i = 0; i < modules.length; i++) {
      count += modules[i].exercises.length;
      if (_currentExerciseIndex < count) {
        _currentModuleIndex = i;
        break;
      }
    }
  }

  // 显示恢复进度对话框
  Future<bool?> _showResumeDialog(WorkoutProgress progress) async {
    final percent = (progress.progressPercent * 100).toInt();
    final completed = progress.completedExerciseIds.length;
    final total = progress.totalExercises;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_circle_outline,
                color: Color(0xFF2DD4BF),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '继续训练',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF115E59),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '检测到您有未完成的训练',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '已完成',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        '$completed / $total 个动作',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF115E59),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.progressPercent,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF2DD4BF),
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '完成度: $percent%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '重新开始',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2DD4BF),
              foregroundColor: Colors.white,
            ),
            child: const Text('继续训练'),
          ),
        ],
      ),
    );
  }

  // 返回上一页
  void _goBack() async {
    final progressProvider = context.read<WorkoutProgressProvider>();

    // 保存当前进度
    if (_currentPage == 'exercise' && _selectedExercise != null) {
      await progressProvider.updateProgress(
        currentModuleIndex: _currentModuleIndex,
        currentExerciseIndex: _currentExerciseIndex,
        completedExerciseIds: progressProvider.progress?.completedExerciseIds ?? [],
      );
    }

    setState(() {
      _currentPage = 'today';
      _selectedExercise = null;
      // 不重置索引，保留进度
    });
  }

  // 重置用户画像
  void _handleReset() async {
    await context.read<UserProfileProvider>().clearProfile();
    setState(() {
      _currentPage = 'onboarding';
    });
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: _buildCurrentPage(),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 'loading':
        return const Scaffold(
          backgroundColor: Color(0xFFF5F5F0),
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );

      case 'onboarding':
        final profile = context.watch<UserProfileProvider>().profile;
        return OnboardingPage(
          onComplete: _handleOnboardingComplete,
          onCancel: profile != null ? () => _navigateTo('profile') : null,
          initialProfile: profile,
          userId: 'local_user',
        );

      case 'today':
        return Consumer<WorkoutProvider>(
          builder: (context, workoutProvider, child) {
            if (workoutProvider.isLoading) {
              return const Scaffold(
                backgroundColor: Color(0xFFF5F5F0),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (workoutProvider.errorMessage != null) {
              return Scaffold(
                backgroundColor: Color(0xFFF5F5F0),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(workoutProvider.errorMessage!),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          workoutProvider.loadTodayWorkout();
                        },
                        child: Text('重试'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return TodayPlanPage(
              workoutPlan: workoutProvider.todayWorkout!,
              onStartWorkout: _startWorkout,
              onNavigate: _navigateTo,
              onRefresh: () {
                workoutProvider.refreshWorkout();
              },
            );
          },
        );

      case 'exercise':
        if (_selectedExercise != null) {
          return ExerciseDetailPage(
            exercise: _selectedExercise!,
            currentIndex: _currentExerciseIndex,
            totalCount: _currentExerciseList?.length ?? 1,
            onComplete: _completeExercise,
            onBack: _goBack,
          );
        }
        // Fallback to today page
        return Consumer<WorkoutProvider>(
          builder: (context, workoutProvider, child) {
            return TodayPlanPage(
              workoutPlan: workoutProvider.todayWorkout!,
              onStartWorkout: _startWorkout,
              onNavigate: _navigateTo,
            );
          },
        );

      case 'feedback':
        return Consumer<WorkoutProvider>(
          builder: (context, workoutProvider, child) {
            return FeedbackPage(
              workoutDuration: workoutProvider.todayWorkout?.totalDuration ?? 12,
              onComplete: _completeFeedback,
            );
          },
        );

      case 'weekly':
        return Consumer<MonthlyStatsProvider>(
          builder: (context, statsProvider, child) {
            if (statsProvider.isLoading) {
              return const Scaffold(
                backgroundColor: Color(0xFFF5F5F0),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return WeeklyViewPage(
              monthlyData: statsProvider.monthlyStats ?? MonthlyStats.createSample(),
              onNavigate: _navigateTo,
            );
          },
        );

      case 'ai':
        return AiChatPage(
          onNavigate: _navigateTo,
        );

      case 'profile':
        return Consumer<UserProfileProvider>(
          builder: (context, profileProvider, child) {
            return ProfilePage(
              userProfile: profileProvider.profile,
              onNavigate: _navigateTo,
              onReset: _handleReset,
              onSaveGoals: (weeklyDays, timeBudget) {
                profileProvider.updateGoals(
                  weeklyDays: weeklyDays,
                  timeBudget: timeBudget,
                );
                _showSuccessDialog('目标已保存');
              },
            );
          },
        );

      default:
        return Consumer<WorkoutProvider>(
          builder: (context, workoutProvider, child) {
            return TodayPlanPage(
              workoutPlan: workoutProvider.todayWorkout!,
              onStartWorkout: _startWorkout,
              onNavigate: _navigateTo,
            );
          },
        );
    }
  }
}
