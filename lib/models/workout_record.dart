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
    // 兼容旧数据，如果没有 painLocations 字段则使用空数组
    final feedbackData = json['feedback'] as Map<String, dynamic>?;

    return WorkoutRecord(
      date: DateTime.parse(json['date'] as String),
      duration: json['duration'] as int,
      feedback: WorkoutFeedback(
        completion: CompletionLevel.values.firstWhere(
          (e) => e.name == feedbackData?['completion'],
          orElse: () => CompletionLevel.smooth,
        ),
        feeling: FeelingLevel.values.firstWhere(
          (e) => e.name == feedbackData?['feeling'],
          orElse: () => FeelingLevel.justRight,
        ),
        tomorrow: TomorrowPreference.values.firstWhere(
          (e) => e.name == feedbackData?['tomorrow'],
          orElse: () => TomorrowPreference.maintain,
        ),
        painLocations: feedbackData?['painLocations'] != null
            ? List<String>.from(feedbackData!['painLocations'] as List)
            : const [],
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
