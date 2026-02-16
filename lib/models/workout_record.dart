import 'feedback.dart';

/// 训练记录模型
class WorkoutRecord {
  final DateTime date;
  final int duration; // 分钟
  final WorkoutFeedback feedback;
  final bool completed;

  WorkoutRecord({
    required this.date,
    required this.duration,
    required this.feedback,
    this.completed = true,
  });

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) {
    // 兼容后端返回的扁平格式
    return WorkoutRecord(
      date: DateTime.parse(json['date'] as String? ?? json['record_date'] as String),
      duration: json['duration'] as int,
      feedback: WorkoutFeedback(
        completion: CompletionLevel.values.firstWhere(
          (e) => e.name == (json['completion'] as String? ?? json['feedback']?['completion'] as String?),
          orElse: () => CompletionLevel.smooth,
        ),
        feeling: FeelingLevel.values.firstWhere(
          (e) => e.name == (json['feeling'] as String? ?? json['feedback']?['feeling'] as String?),
          orElse: () => FeelingLevel.justRight,
        ),
        tomorrow: TomorrowPreference.values.firstWhere(
          (e) => e.name == (json['tomorrow'] as String? ?? json['feedback']?['tomorrow'] as String?),
          orElse: () => TomorrowPreference.maintain,
        ),
        painLocations: (json['pain_locations'] as List? ?? json['feedback']?['painLocations'] as List?)?.cast<String>() ?? [],
      ),
      completed: json['completed'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'duration': duration,
      'feedback': feedback.toJson(),
      'completed': completed,
    };
  }
}
