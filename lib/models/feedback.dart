import 'package:flutter/material.dart';

/// 训练反馈
class WorkoutFeedback {
  final CompletionLevel completion;
  final FeelingLevel feeling;
  final TomorrowPreference tomorrow;
  final List<String> painLocations;  // 疼痛部位列表

  WorkoutFeedback({
    required this.completion,
    required this.feeling,
    required this.tomorrow,
    this.painLocations = const [],  // 默认空数组
  });

  Map<String, dynamic> toJson() {
    return {
      'completion': completion.name,
      'feeling': feeling.name,
      'tomorrow': tomorrow.name,
      'painLocations': painLocations,
    };
  }

  factory WorkoutFeedback.fromJson(Map<String, dynamic> json) {
    return WorkoutFeedback(
      completion: CompletionLevel.values.firstWhere(
        (e) => e.name == json['completion'],
        orElse: () => CompletionLevel.smooth,
      ),
      feeling: FeelingLevel.values.firstWhere(
        (e) => e.name == json['feeling'],
        orElse: () => FeelingLevel.justRight,
      ),
      tomorrow: TomorrowPreference.values.firstWhere(
        (e) => e.name == json['tomorrow'],
        orElse: () => TomorrowPreference.maintain,
      ),
      painLocations: List<String>.from(json['painLocations'] as List? ?? []),
    );
  }
}

enum CompletionLevel {
  tooHard,   // 太难未完成
  barely,    // 勉强完成
  smooth,    // 顺利完成
  easy,      // 轻松有余力
}

extension CompletionLevelExtension on CompletionLevel {
  IconData get icon {
    switch (this) {
      case CompletionLevel.tooHard:
        return Icons.sentiment_very_dissatisfied;
      case CompletionLevel.barely:
        return Icons.sentiment_dissatisfied;
      case CompletionLevel.smooth:
        return Icons.sentiment_satisfied;
      case CompletionLevel.easy:
        return Icons.sentiment_very_satisfied;
    }
  }

  String get emoji {
    switch (this) {
      case CompletionLevel.tooHard:
        return '😰';
      case CompletionLevel.barely:
        return '😅';
      case CompletionLevel.smooth:
        return '😊';
      case CompletionLevel.easy:
        return '😄';
    }
  }

  String get label {
    switch (this) {
      case CompletionLevel.tooHard:
        return '太难未完成';
      case CompletionLevel.barely:
        return '勉强完成';
      case CompletionLevel.smooth:
        return '顺利完成';
      case CompletionLevel.easy:
        return '轻松有余力';
    }
  }
}

enum FeelingLevel {
  uncomfortable,  // 某部位不适
  tired,          // 有点累
  justRight,      // 刚刚好
  energized,      // 精力充沛
}

extension FeelingLevelExtension on FeelingLevel {
  IconData get icon {
    switch (this) {
      case FeelingLevel.uncomfortable:
        return Icons.cancel;
      case FeelingLevel.tired:
        return Icons.warning;
      case FeelingLevel.justRight:
        return Icons.check_circle;
      case FeelingLevel.energized:
        return Icons.bolt;
    }
  }

  String get emoji {
    switch (this) {
      case FeelingLevel.uncomfortable:
        return '❌';
      case FeelingLevel.tired:
        return '⚠️';
      case FeelingLevel.justRight:
        return '✅';
      case FeelingLevel.energized:
        return '⚡';
    }
  }

  String get label {
    switch (this) {
      case FeelingLevel.uncomfortable:
        return '某部位不适';
      case FeelingLevel.tired:
        return '有点累';
      case FeelingLevel.justRight:
        return '刚刚好';
      case FeelingLevel.energized:
        return '精力充沛';
    }
  }
}

enum TomorrowPreference {
  recovery,   // 需要恢复
  maintain,   // 保持即可
  intensify,  // 可以提高
}

extension TomorrowPreferenceExtension on TomorrowPreference {
  IconData get icon {
    switch (this) {
      case TomorrowPreference.recovery:
        return Icons.self_improvement;
      case TomorrowPreference.maintain:
        return Icons.directions_walk;
      case TomorrowPreference.intensify:
        return Icons.flash_on;
    }
  }

  String get emoji {
    switch (this) {
      case TomorrowPreference.recovery:
        return '🐻';
      case TomorrowPreference.maintain:
        return '🐰';
      case TomorrowPreference.intensify:
        return '🦁';
    }
  }

  String get label {
    switch (this) {
      case TomorrowPreference.recovery:
        return '需要恢复';
      case TomorrowPreference.maintain:
        return '保持即可';
      case TomorrowPreference.intensify:
        return '可以提高';
    }
  }

  String get sublabel {
    switch (this) {
      case TomorrowPreference.recovery:
        return '轻松版';
      case TomorrowPreference.maintain:
        return '';
      case TomorrowPreference.intensify:
        return '加点量';
    }
  }
}
