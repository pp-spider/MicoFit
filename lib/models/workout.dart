import 'exercise.dart';

/// 训练模块
class WorkoutModule {
  final String id;
  final String name;
  final int duration; // 分钟
  final List<Exercise> exercises;

  WorkoutModule({
    required this.id,
    required this.name,
    required this.duration,
    required this.exercises,
  });

  factory WorkoutModule.fromJson(Map<String, dynamic> json) {
    return WorkoutModule(
      id: json['id'] as String,
      name: json['name'] as String,
      duration: json['duration'] as int,
      exercises: (json['exercises'] as List)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'duration': duration,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }
}

/// 训练计划
class WorkoutPlan {
  final String id;
  final String title;
  final String subtitle;
  final int totalDuration; // 分钟
  final String scene;
  final int rpe; // 运动强度 1-10
  final List<WorkoutModule> modules;
  final String? aiNote;

  WorkoutPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.totalDuration,
    required this.scene,
    required this.rpe,
    required this.modules,
    this.aiNote,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      totalDuration: json['total_duration'] as int? ?? json['totalDuration'] as int? ?? 12,
      scene: json['scene'] as String,
      rpe: json['rpe'] as int,
      modules: (json['modules'] as List)
          .map((e) => WorkoutModule.fromJson(e as Map<String, dynamic>))
          .toList(),
      aiNote: json['ai_note'] as String? ?? json['aiNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'totalDuration': totalDuration,
      'scene': scene,
      'rpe': rpe,
      'modules': modules.map((e) => e.toJson()).toList(),
      'aiNote': aiNote,
    };
  }
}
