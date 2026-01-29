/// 用户画像
class UserProfile {
  final String nickname;
  final double height; // cm
  final double weight; // kg
  final double bmi;
  final FitnessLevel fitnessLevel;
  final String scene;
  final int timeBudget; // 分钟
  final List<String> limitations;
  final String equipment;
  final String goal;
  final int weeklyDays;
  final List<String> preferredTime;

  UserProfile({
    required this.nickname,
    required this.height,
    required this.weight,
    required this.bmi,
    required this.fitnessLevel,
    required this.scene,
    required this.timeBudget,
    required this.limitations,
    required this.equipment,
    required this.goal,
    required this.weeklyDays,
    required this.preferredTime,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      nickname: json['nickname'] as String,
      height: (json['height'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      bmi: (json['bmi'] as num).toDouble(),
      fitnessLevel: FitnessLevel.values.firstWhere(
        (e) => e.name == json['fitnessLevel'],
        orElse: () => FitnessLevel.beginner,
      ),
      scene: json['scene'] as String,
      timeBudget: json['timeBudget'] as int,
      limitations: List<String>.from(json['limitations'] as List),
      equipment: json['equipment'] as String,
      goal: json['goal'] as String,
      weeklyDays: json['weeklyDays'] as int,
      preferredTime: List<String>.from(json['preferredTime'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'height': height,
      'weight': weight,
      'bmi': bmi,
      'fitnessLevel': fitnessLevel.name,
      'scene': scene,
      'timeBudget': timeBudget,
      'limitations': limitations,
      'equipment': equipment,
      'goal': goal,
      'weeklyDays': weeklyDays,
      'preferredTime': preferredTime,
    };
  }

  static double calculateBMI(double height, double weight) {
    return weight / ((height / 100) * (height / 100));
  }
}

enum FitnessLevel {
  beginner,    // 零基础
  occasional,  // 偶尔运动
  regular,     // 规律运动
}

extension FitnessLevelExtension on FitnessLevel {
  String get label {
    switch (this) {
      case FitnessLevel.beginner:
        return '零基础';
      case FitnessLevel.occasional:
        return '偶尔运动';
      case FitnessLevel.regular:
        return '规律运动';
    }
  }
}
