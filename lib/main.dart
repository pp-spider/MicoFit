import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'pages/today_plan_page.dart';
import 'pages/exercise_detail_page.dart';
import 'pages/feedback_page.dart';
import 'pages/weekly_view_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/profile_page.dart';
import 'utils/sample_data.dart';
import 'models/exercise.dart';
import 'models/workout.dart';
import 'models/user_profile.dart';

/// 微动 MicoFit - Flutter 应用入口
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MicoFitApp());
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
  late WorkoutPlan _workoutPlan;
  Exercise? _selectedExercise;
  UserProfile? _userProfile;

  // SharedPreferences keys
  static const String _keyProfile = 'micofit_user_profile';
  static const String _keyOnboardingCompleted = 'micofit_onboarding_completed';

  @override
  void initState() {
    super.initState();
    _workoutPlan = getSampleWorkoutPlan();
    _loadUserProfile();
  }

  // 加载用户画像
  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompleted = prefs.getBool(_keyOnboardingCompleted) ?? false;

    if (hasCompleted) {
      final profileJson = prefs.getString(_keyProfile);
      if (profileJson != null) {
        try {
          final profileMap = jsonDecode(profileJson) as Map<String, dynamic>;
          setState(() {
            _userProfile = UserProfile.fromJson(profileMap);
            _currentPage = 'today';
          });
          return;
        } catch (e) {
          // 解析失败，重新开始
        }
      }
    }

    // 没有画像或解析失败，显示 onboarding
    setState(() {
      _currentPage = 'onboarding';
    });
  }

  // 保存用户画像
  Future<void> _saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
    await prefs.setBool(_keyOnboardingCompleted, true);
    setState(() {
      _userProfile = profile;
    });
  }

  // 清除用户画像
  Future<void> _clearUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfile);
    await prefs.remove(_keyOnboardingCompleted);
    setState(() {
      _userProfile = null;
      _currentPage = 'onboarding';
    });
  }

  // 页面导航
  void _navigateTo(String page) {
    setState(() {
      _currentPage = page;
    });
  }

  // 完成用户画像构建
  void _handleOnboardingComplete(UserProfile profile) {
    _saveUserProfile(profile);
    setState(() {
      _currentPage = 'today';
    });
  }

  // 开始训练
  void _startWorkout() {
    final firstExercise = _workoutPlan.modules.firstOrNull?.exercises.firstOrNull;
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
  }

  // 返回上一页
  void _goBack() {
    setState(() {
      _currentPage = 'today';
    });
  }

  // 重置用户画像
  void _handleReset() {
    _clearUserProfile();
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

      case 'onboarding':
        return OnboardingPage(
          onComplete: _handleOnboardingComplete,
          onCancel: _userProfile != null ? () => _navigateTo('profile') : null,
          initialProfile: _userProfile, // 传递现有用户数据用于编辑
        );

      case 'today':
        return TodayPlanPage(
          workoutPlan: _workoutPlan,
          onStartWorkout: _startWorkout,
          onNavigate: _navigateTo,
        );

      case 'exercise':
        if (_selectedExercise != null) {
          return ExerciseDetailPage(
            exercise: _selectedExercise!,
            onComplete: _completeExercise,
            onBack: _goBack,
          );
        }
        return TodayPlanPage(
          workoutPlan: _workoutPlan,
          onStartWorkout: _startWorkout,
          onNavigate: _navigateTo,
        );

      case 'feedback':
        return FeedbackPage(
          workoutDuration: _workoutPlan.totalDuration,
          onComplete: _completeFeedback,
        );

      case 'weekly':
        return WeeklyViewPage(
          onNavigate: _navigateTo,
        );

      case 'profile':
        return ProfilePage(
          userProfile: _userProfile,
          onNavigate: _navigateTo,
          onReset: _handleReset,
        );

      default:
        return TodayPlanPage(
          workoutPlan: _workoutPlan,
          onStartWorkout: _startWorkout,
          onNavigate: _navigateTo,
        );
    }
  }
}
