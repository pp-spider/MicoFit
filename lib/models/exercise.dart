/// 动作数据模型
class Exercise {
  final String id;
  final String name;
  final int duration; // 秒
  final String description;
  final List<String> steps;
  final String tips;
  final String breathing;
  final String image;
  final List<String> targetMuscles;

  Exercise({
    required this.id,
    required this.name,
    required this.duration,
    required this.description,
    required this.steps,
    required this.tips,
    required this.breathing,
    required this.image,
    required this.targetMuscles,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      duration: json['duration'] as int,
      description: json['description'] as String,
      steps: List<String>.from(json['steps'] as List),
      tips: json['tips'] as String,
      breathing: json['breathing'] as String,
      image: json['image'] as String,
      targetMuscles: List<String>.from(json['targetMuscles'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'duration': duration,
      'description': description,
      'steps': steps,
      'tips': tips,
      'breathing': breathing,
      'image': image,
      'targetMuscles': targetMuscles,
    };
  }
}
