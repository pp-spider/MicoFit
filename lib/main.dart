import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'pages/today_plan_page.dart';
import 'widgets/error_boundary.dart';
import 'widgets/offline_indicator.dart';
import 'widgets/skeleton_widgets.dart';
import 'pages/exercise_detail_page.dart';
import 'pages/feedback_page.dart';
import 'pages/weekly_view_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/profile_page.dart';
import 'pages/ai_chat_page.dart';
import 'pages/splash_page.dart';
import 'pages/login_page.dart';
import 'pages/achievements_page.dart';
import 'pages/training_report_page.dart';
import 'pages/friends_page.dart';
import 'models/achievement.dart';
import 'models/exercise.dart';
import 'models/user_profile.dart';
import 'models/weekly_data.dart';
import 'providers/user_profile_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/monthly_stats_provider.dart';
import 'providers/workout_progress_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/network_provider.dart';
import 'providers/friend_provider.dart';
import 'services/sync_manager.dart';
import 'utils/user_id_generator.dart';
import 'utils/user_data_helper.dart';
import 'models/workout_progress.dart';

/// 微动 MicoFit - Flutter 应用入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 创建本地用户ID
  await UserIdGenerator.getOrCreateLocalUserId();

  runApp(
    MultiProvider(
      providers: [
        // 认证 Provider - 必须最先初始化
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..init(),
        ),
        // 用户画像 Provider
        ChangeNotifierProvider(
          create: (_) => UserProfileProvider()..init(),
        ),
        // 其他 Provider
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
          create: (_) => ChatProvider(), // 不在此处加载历史，等登录后再加载
        ),
        // 同步状态 Provider
        ChangeNotifierProvider(
          create: (_) => SyncProvider()..init(),
        ),
        // 网络状态 Provider
        ChangeNotifierProvider(
          create: (_) => NetworkProvider()..init(),
        ),
        // 好友 Provider
        ChangeNotifierProvider(
          create: (_) => FriendProvider(),
        ),
      ],
      child: const MicoFitApp(),
    ),
  );
}

class MicoFitApp extends StatelessWidget {
  const MicoFitApp({super.key});

  /// 确保同步服务已初始化（启动轮询）
  void _ensureSyncInitialized() {
    // 直接调用 SyncManager 的初始化，启动轮询
    // 这样可以确保即使 SyncProvider 未被正确创建，轮询也能启动
    Future.microtask(() async {
      try {
        debugPrint('[MicoFitApp] 确保同步服务已初始化...');
        final syncManager = SyncManager();
        await syncManager.init();
        debugPrint('[MicoFitApp] 同步服务初始化完成');
      } catch (e) {
        debugPrint('[MicoFitApp] 同步服务初始化失败: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 确保同步服务已初始化（启动轮询）
    _ensureSyncInitialized();

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
      home: const ErrorBoundary(child: MainPage()),
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
  // 当前页面 - 默认显示启动页
  String _currentPage = 'splash';

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

  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();

    // 保存 provider 引用以便在 dispose 中使用
    _authProvider = context.read<AuthProvider>();
    _authProvider?.addListener(_onAuthStateChanged);

    // 检查当前认证状态（处理 AuthProvider.init() 已完成的情况）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthStateAndLoad();
    });
  }

  /// 检查认证状态并加载数据
  void _checkAuthStateAndLoad() {
    if (!mounted) return;

    final authProvider = _authProvider;
    if (authProvider == null) return;

    // 如果已经认证且不在加载中，加载用户数据
    if (authProvider.isAuthenticated && !authProvider.isLoading) {
      debugPrint('[MainPage] 初始化时检测到已登录用户，加载数据');
      _loadUserProfile();
    } else if (!authProvider.isAuthenticated && !authProvider.isLoading) {
      // 未登录，跳转到登录页
      setState(() => _currentPage = 'login');
    }
    // 如果正在加载中，等待监听器回调
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  /// 认证状态变化回调
  void _onAuthStateChanged() {
    if (!mounted) return;

    final authProvider = _authProvider;
    if (authProvider == null) return;

    // 如果正在加载中，不处理
    if (authProvider.isLoading) return;

    // 如果认证成功且当前在登录/启动页，加载用户数据
    if (authProvider.isAuthenticated &&
        (_currentPage == 'login' || _currentPage == 'splash')) {
      debugPrint('[MainPage] 认证状态变化：用户已登录，加载数据');
      _loadUserProfile();
    }

    // 如果认证失效且当前不在登录页，跳转到登录页
    if (!authProvider.isAuthenticated &&
        _currentPage != 'login' &&
        _currentPage != 'splash') {
      debugPrint('[MainPage] 认证状态变化：用户已登出，清除数据');
      // 清除聊天内存数据（用户数据隔离）
      context.read<ChatProvider>().clearMemoryData();
      setState(() => _currentPage = 'login');
    }
  }

  // 加载用户画像
  Future<void> _loadUserProfile() async {
    if (!mounted) return;

    final authProvider = _authProvider;
    final profileProvider = context.read<UserProfileProvider>();
    final progressProvider = context.read<WorkoutProgressProvider>();
    final workoutProvider = context.read<WorkoutProvider>();
    final statsProvider = context.read<MonthlyStatsProvider>();
    final chatProvider = context.read<ChatProvider>();

    if (authProvider == null || !authProvider.isAuthenticated) {
      // 未登录，跳转到登录页
      if (mounted) setState(() => _currentPage = 'login');
      return;
    }

    // 确保用户ID已设置（用户数据隔离）
    // 优先使用 authProvider.user?.id，离线模式下使用本地缓存
    String? userId = authProvider.user?.id;
    if (userId == null || userId.isEmpty) {
      userId = await UserDataHelper.getCurrentUserId();
    }

    if (userId != null && userId.isNotEmpty) {
      // 先设置当前用户ID，确保后续操作使用正确的用户隔离
      UserDataHelper.setCurrentUserId(userId);
      debugPrint('[MainPage] 已设置当前用户ID: $userId (${authProvider.isOfflineMode ? "离线" : "在线"})');

      // 如果内存中已有数据，先清除（防止用户切换时看到旧数据）
      if (chatProvider.messages.isNotEmpty) {
        chatProvider.clearMemoryData();
      }
      // 清理训练进度内存数据（不删除后端数据）
      await progressProvider.clearMemoryOnly();
      // 清理训练计划
      workoutProvider.clearTodayWorkout();
      // 清理月度统计
      statsProvider.clearStats();
    }

    // 已登录，初始化并检查用户画像
    await profileProvider.init();

    if (!mounted) return;

    // 加载当前用户的聊天历史（用户隔离）
    await chatProvider.loadHistory();

    if (profileProvider.hasProfile) {
      // 有画像：加载训练计划和月度统计，跳转今日计划
      workoutProvider.loadTodayWorkout();
      // 加载训练进度（恢复训练状态）
      progressProvider.loadTodayProgress();
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

    // 如果未登录且在登录页面，直接退出APP
    if (_currentPage == 'login') {
      final authProvider = _authProvider;
      if (authProvider == null || !authProvider.isAuthenticated) {
        // 未登录状态，允许退出APP
        return true;
      }
    }

    // 如果在信息录入页面且没有用户画像（新用户），阻止返回
    if (_currentPage == 'onboarding') {
      final profileProvider = context.read<UserProfileProvider>();
      final profile = profileProvider.profile;
      if (profile == null) {
        // 新用户，必须完成信息录入，显示提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请完成信息填写'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }
      // 有画像（编辑模式），允许返回到个人资料页
      setState(() {
        _currentPage = 'profile';
      });
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
    // 登出
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    // 清除本地画像
    await context.read<UserProfileProvider>().clearProfile();
    // 跳转到登录页
    if (mounted) {
      setState(() {
        _currentPage = 'login';
      });
    }
  }

  // 退出登录
  void _handleLogout() async {
    // 先获取 Provider 引用，避免跨异步调用问题
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<UserProfileProvider>();
    final progressProvider = context.read<WorkoutProgressProvider>();
    final workoutProvider = context.read<WorkoutProvider>();
    final statsProvider = context.read<MonthlyStatsProvider>();
    final chatProvider = context.read<ChatProvider>();

    // 显示加载指示器
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // 执行登出
    await authProvider.logout();

    // 清理其他 Provider 的内存数据，防止用户切换时串读
    await profileProvider.clearProfile();
    await progressProvider.clearMemoryOnly();
    // 清理训练计划（重新加载即可）
    workoutProvider.clearTodayWorkout();
    // 清理月度统计（重新加载即可）
    statsProvider.clearStats();
    // 清理聊天数据
    chatProvider.clearMemoryData();

    if (mounted) {
      // 关闭加载指示器
      Navigator.of(context).pop();
      // 跳转到登录页
      setState(() {
        _currentPage = 'login';
      });
    }
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
      child: OfflineIndicator(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          child: _buildCurrentPage(),
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 'loading':
        return const Scaffold(
          key: ValueKey('loading'),
          backgroundColor: Color(0xFFF5F5F0),
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );

      case 'splash':
        return SplashPage(
          key: const ValueKey('splash'),
          onNeedLogin: () {
            setState(() => _currentPage = 'login');
          },
        );

      case 'login':
        return const LoginPage(key: ValueKey('login'));

      case 'onboarding':
        final profile = context.watch<UserProfileProvider>().profile;
        return OnboardingPage(
          key: const ValueKey('onboarding'),
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
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: WorkoutCardSkeleton(),
                  ),
                ),
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

            // 处理 todayWorkout 为 null 的情况
            if (workoutProvider.todayWorkout == null) {
              return Scaffold(
                backgroundColor: Color(0xFFF5F5F0),
                appBar: AppBar(
                  title: Text('今日计划'),
                  backgroundColor: Color(0xFFF5F5F0),
                  elevation: 0,
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fitness_center_outlined,
                        size: 64,
                        color: Color(0xFF2DD4BF),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '今日暂无训练计划',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF115E59),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '点击下方按钮生成今日训练计划',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          workoutProvider.loadTodayWorkout();
                        },
                        icon: Icon(Icons.refresh),
                        label: Text('生成训练计划'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2DD4BF),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
            if (workoutProvider.isLoading) {
              return const Scaffold(
                backgroundColor: Color(0xFFF5F5F0),
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (workoutProvider.todayWorkout == null) {
              return Scaffold(
                backgroundColor: Color(0xFFF5F5F0),
                appBar: AppBar(
                  title: Text('今日计划'),
                  backgroundColor: Color(0xFFF5F5F0),
                  elevation: 0,
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fitness_center_outlined,
                        size: 64,
                        color: Color(0xFF2DD4BF),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '今日暂无训练计划',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF115E59),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '点击下方按钮生成今日训练计划',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          workoutProvider.loadTodayWorkout();
                        },
                        icon: Icon(Icons.refresh),
                        label: Text('生成训练计划'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2DD4BF),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
          key: const ValueKey('ai'),
          onNavigate: _navigateTo,
        );

      case 'profile':
        return Consumer<UserProfileProvider>(
          builder: (context, profileProvider, child) {
            return ProfilePage(
              key: const ValueKey('profile'),
              userProfile: profileProvider.profile,
              onNavigate: _navigateTo,
              onReset: _handleReset,
              onSaveGoals: (weeklyDays, timeBudget) async {
                try {
                  await profileProvider.updateGoals(
                    weeklyDays: weeklyDays,
                    timeBudget: timeBudget,
                  );
                  if (mounted) {
                    _showSuccessDialog('目标已保存');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('离线模式，修改失败'),
                        backgroundColor: Colors.red.shade400,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                }
              },
              onLogout: _handleLogout,
            );
          },
        );

      case 'achievements':
        return AchievementsPage(
          key: const ValueKey('achievements'),
          achievements: AchievementDefinitions.all,
          onBack: () => _navigateTo('profile'),
        );

      case 'training_report':
        return Consumer<MonthlyStatsProvider>(
          builder: (context, statsProvider, child) {
            return TrainingReportPage(
              key: const ValueKey('training_report'),
              monthlyStats: statsProvider.monthlyStats ?? MonthlyStats.createSample(),
              sceneData: const {
                '办公室': 45,
                '卧室': 30,
                '客厅': 40,
                '户外': 15,
                '健身房': 10,
              },
              onBack: () => _navigateTo('weekly'),
            );
          },
        );

      case 'friends':
        return FriendsPage(
          key: const ValueKey('friends'),
          onNavigate: _navigateTo,
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
