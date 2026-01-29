/// 用户画像
class UserProfile {
  final String userId; // 用户ID（外键关联）
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
  final DateTime? createdAt; // 创建时间
  final DateTime? updatedAt; // 更新时间

  UserProfile({
    required this.userId,
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
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String? ?? json['userId'] as String,
      nickname: json['nickname'] as String,
      height: (json['height'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble() ?? calculateBMI(
        (json['height'] as num).toDouble(),
        (json['weight'] as num).toDouble(),
      ),
      fitnessLevel: FitnessLevel.values.firstWhere(
        // 兼容驼峰和蛇形命名
        (e) => e.name == (json['fitness_level'] ?? json['fitnessLevel']),
        orElse: () => FitnessLevel.beginner,
      ),
      scene: json['scene'] as String,
      timeBudget: json['time_budget'] as int? ?? json['timeBudget'] as int? ?? 12,
      limitations: List<String>.from(json['limitations'] as List? ?? []),
      equipment: json['equipment'] as String,
      goal: json['goal'] as String,
      weeklyDays: json['weekly_days'] as int? ?? json['weeklyDays'] as int? ?? 3,
      preferredTime: List<String>.from(
        json['preferred_time'] as List? ?? json['preferredTime'] as List? ?? [],
      ),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId, // 后端使用蛇形命名
      'nickname': nickname,
      'height': height,
      'weight': weight,
      'bmi': bmi,
      'fitness_level': fitnessLevel.name, // 后端使用蛇形命名
      'scene': scene,
      'time_budget': timeBudget, // 后端使用蛇形命名
      'limitations': limitations,
      'equipment': equipment,
      'goal': goal,
      'weekly_days': weeklyDays, // 后端使用蛇形命名
      'preferred_time': preferredTime, // 后端使用蛇形命名
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  static double calculateBMI(double height, double weight) {
    return weight / ((height / 100) * (height / 100));
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.parse(value);
    return null;
  }
}

enum FitnessLevel {
  beginner, // 零基础
  occasional, // 偶尔运动
  regular, // 规律运动
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
