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
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'models/exercise.dart';
import 'models/user_profile.dart';
import 'models/weekly_data.dart';
import 'config/app_config.dart';
import 'services/user_api_service.dart';
import 'services/workout_api_service.dart';
import 'services/record_api_service.dart';
import 'providers/user_profile_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/monthly_stats_provider.dart';
import 'providers/auth_provider.dart';

/// 微动 MicoFit - Flutter 应用入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 初始化 SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // 创建 API 服务实例
  final userApiService = UserApiService(baseUrl: AppConfig.apiBaseUrl);
  final workoutApiService = WorkoutApiService(baseUrl: AppConfig.apiBaseUrl);
  final recordApiService = RecordApiService(baseUrl: AppConfig.apiBaseUrl);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiBaseUrl: AppConfig.apiBaseUrl)
            ..init(prefs), // 初始化认证状态
        ),
        ChangeNotifierProvider(
          create: (_) => UserProfileProvider(
            apiService: userApiService,
            prefs: prefs,
          )..init(), // 自动初始化
        ),
        ChangeNotifierProvider(
          create: (_) => WorkoutProvider(
            apiService: workoutApiService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MonthlyStatsProvider(
            apiService: recordApiService,
          ),
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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // 加载用户画像
  Future<void> _loadUserProfile() async {
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<UserProfileProvider>();

    // 1. 检查认证状态
    if (!authProvider.isAuthenticated) {
      setState(() => _currentPage = 'login');
      return;
    }

    // 2. 获取画像状态
    var hasProfile = authProvider.hasProfile;

    // 3. 降级处理：如果登录响应未包含 hasProfile，则查询后端
    if (hasProfile == null && AppConfig.enableApi) {
      final userApiService = UserApiService(baseUrl: AppConfig.apiBaseUrl);
      await authProvider.checkProfileExists(userApiService);
      hasProfile = authProvider.hasProfile;
    }

    // 4. 根据画像状态初始化
    await profileProvider.init(hasProfile: hasProfile ?? false);

    // 5. 页面跳转
    if (hasProfile == true) {
      // 有画像：加载训练计划，跳转今日计划
      final userId = authProvider.userId ?? '';
      if (userId.isNotEmpty) {
        context.read<WorkoutProvider>().loadTodayWorkout(userId);
      }
      setState(() => _currentPage = 'today');
    } else if (hasProfile == false) {
      // 无画像：跳转 onboarding
      setState(() => _currentPage = 'onboarding');
    } else {
      // 未知状态：根据本地数据判断（兜底）
      setState(() => _currentPage = profileProvider.hasProfile ? 'today' : 'onboarding');
    }
  }

  // 页面导航
  void _navigateTo(String page) {
    setState(() {
      _currentPage = page;
    });
  }

  // 完成用户画像构建
  void _handleOnboardingComplete(String userId, UserProfile profile) async {
    await context.read<UserProfileProvider>().saveProfile(profile);

    // 加载训练计划
    final workoutProvider = context.read<WorkoutProvider>();
    if (userId.isNotEmpty && mounted) {
      await workoutProvider.loadTodayWorkout(userId);
    }

    if (mounted) {
      setState(() {
        _currentPage = 'today';
      });
    }
  }

  // 开始训练
  void _startWorkout() {
    final workoutProvider = context.read<WorkoutProvider>();
    final firstExercise = workoutProvider.todayWorkout?.modules.firstOrNull?.exercises.firstOrNull;
    if (firstExercise != null) {
      setState(() {
        _selectedExercise = firstExercise;
        _currentPage = 'exercise';
      });
    }
  }

  // 完成训练动作
  void _completeExercise() {
    setState(() {
      _currentPage = 'feedback';
    });
  }

  // 完成反馈
  void _completeFeedback() {
    setState(() {
      _currentPage = 'weekly';
    });

    // 加载月度数据
    final userId = context.read<AuthProvider>().userId ?? '';
    if (userId.isNotEmpty) {
      final now = DateTime.now();
      context.read<MonthlyStatsProvider>().loadMonthlyStats(
        userId,
        now.year,
        now.month,
      );
    }
  }

  // 返回上一页
  void _goBack() {
    setState(() {
      _currentPage = 'today';
    });
  }

  // 重置用户画像
  void _handleReset() async {
    await context.read<UserProfileProvider>().clearProfile();
    setState(() {
      _currentPage = 'onboarding';
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentPage) {
      case 'loading':
        return const Scaffold(
          backgroundColor: Color(0xFFF5F5F0),
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );

      case 'login':
        return Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return LoginPage(
              onLoginSuccess: () async {
                await _loadUserProfile();
              },
              onRegister: () {
                setState(() {
                  _currentPage = 'register';
                });
              },
              onSkip: AppConfig.enableApi
                  ? null
                  : () {
                      // 离线模式：直接跳过登录
                      setState(() {
                        _currentPage = 'onboarding';
                      });
                    },
            );
          },
        );

      case 'register':
        return RegisterPage(
          onRegisterSuccess: () async {
            await _loadUserProfile();
          },
          onBack: () {
            setState(() {
              _currentPage = 'login';
            });
          },
        );

      case 'onboarding':
        final authProvider = context.read<AuthProvider>();
        final profile = context.watch<UserProfileProvider>().profile;
        return OnboardingPage(
          onComplete: _handleOnboardingComplete,
          onCancel: profile != null ? () => _navigateTo('profile') : null,
          initialProfile: profile,
          userId: authProvider.userId ?? '',
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
                          final authProvider = context.read<AuthProvider>();
                          final userId = authProvider.userId ?? '';
                          if (userId.isNotEmpty) {
                            workoutProvider.loadTodayWorkout(userId);
                          }
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
                final authProvider = context.read<AuthProvider>();
                final userId = authProvider.userId ?? '';
                if (userId.isNotEmpty) {
                  workoutProvider.refreshWorkout(userId);
                }
              },
            );
          },
        );

      case 'exercise':
        if (_selectedExercise != null) {
          return ExerciseDetailPage(
            exercise: _selectedExercise!,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('目标已保存')),
                );
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
