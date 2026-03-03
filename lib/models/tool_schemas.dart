import 'package:dart_openai/dart_openai.dart';
import 'user_profile.dart';

/// 工具调用数据（简化格式，避免直接使用OpenAI类型）
class ToolCallData {
  final String id;
  final String type;
  final String functionName;
  final String arguments;

  ToolCallData({
    required this.id,
    required this.type,
    required this.functionName,
    required this.arguments,
  });

  /// 从Map创建
  factory ToolCallData.fromMap(Map<String, dynamic> map) {
    final function = map['function'] as Map<String, dynamic>? ?? {};
    return ToolCallData(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? 'function',
      functionName: function['name'] as String? ?? '',
      arguments: function['arguments'] as String? ?? '{}',
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'function': {
        'name': functionName,
        'arguments': arguments,
      },
    };
  }
}

/// AI Function Calling 工具Schema定义
class AIToolSchemas {
  /// 获取用户画像工具
  static OpenAIToolModel get getUserProfileTool {
    return OpenAIToolModel(
      type: 'function',
      function: OpenAIFunctionModel(
        name: 'get_user_profile',
        description: '【谨慎使用】仅在以下情况调用：1)用户明确要求查看其完整档案；2)需要验证系统提示词中的用户信息是否过时；3)生成健身计划时已知信息不完整。注意：系统提示词已包含用户画像数据，应优先使用。',
        parametersSchema: {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      ),
    );
  }
}

/// 用户画像工具响应
class UserProfileToolResponse {
  final bool hasProfile;
  final String? nickname;
  final String? fitnessLevel;
  final String? goal;
  final String? scene;
  final int? timeBudget;
  final List<String>? limitations;
  final String? equipment;
  final double? bmi;
  final int? weeklyDays;

  UserProfileToolResponse({
    required this.hasProfile,
    this.nickname,
    this.fitnessLevel,
    this.goal,
    this.scene,
    this.timeBudget,
    this.limitations,
    this.equipment,
    this.bmi,
    this.weeklyDays,
  });

  /// 从UserProfile创建
  factory UserProfileToolResponse.fromProfile(UserProfile? profile) {
    if (profile == null) {
      return UserProfileToolResponse(hasProfile: false);
    }

    return UserProfileToolResponse(
      hasProfile: true,
      nickname: profile.nickname,
      fitnessLevel: profile.fitnessLevel.name,
      goal: profile.goal,
      scene: profile.scene,
      timeBudget: profile.timeBudget,
      limitations: profile.limitations,
      equipment: profile.equipment,
      bmi: profile.bmi,
      weeklyDays: profile.weeklyDays,
    );
  }

  /// 转换为JSON供AI使用
  Map<String, dynamic> toJson() {
    if (!hasProfile) {
      return {
        'hasProfile': false,
        'message': '用户尚未设置画像信息',
      };
    }

    return {
      'hasProfile': true,
      'nickname': nickname,
      'fitnessLevel': fitnessLevel,
      'fitnessLevelLabel': _getFitnessLevelLabel(fitnessLevel),
      'goal': goal,
      'goalLabel': _getGoalLabel(goal),
      'scene': scene,
      'sceneLabel': _getSceneLabel(scene),
      'timeBudget': timeBudget,
      'limitations': limitations,
      'equipment': equipment,
      'bmi': bmi,
      'weeklyDays': weeklyDays,
    };
  }

  String _getFitnessLevelLabel(String? level) {
    switch (level) {
      case 'beginner':
        return '零基础';
      case 'occasional':
        return '偶尔运动';
      case 'regular':
        return '规律运动';
      default:
        return level ?? '未知';
    }
  }

  String _getGoalLabel(String? goal) {
    switch (goal) {
      case 'fat-loss':
        return '减脂塑形';
      case 'sedentary':
        return '缓解久坐';
      case 'strength':
        return '增强体能';
      case 'sleep':
        return '改善睡眠';
      default:
        return goal ?? '未知';
    }
  }

  String _getSceneLabel(String? scene) {
    switch (scene) {
      case 'bed':
        return '床上';
      case 'office':
        return '办公室';
      case 'living':
        return '客厅';
      case 'outdoor':
        return '户外';
      case 'hotel':
        return '酒店';
      default:
        return scene ?? '未知';
    }
  }
}

/// 流式响应数据块（包含工具调用信息）
class StreamResponseChunk {
  final String? textContent;
  final List<Map<String, dynamic>>? toolCallData;

  StreamResponseChunk({
    this.textContent,
    this.toolCallData,
  });

  /// 创建包含工具调用的chunk
  factory StreamResponseChunk.withToolCalls(List<Map<String, dynamic>> toolCalls) {
    return StreamResponseChunk(toolCallData: toolCalls);
  }

  /// 是否有工具调用
  bool get hasToolCalls => toolCallData != null && toolCallData!.isNotEmpty;

  /// 是否有文本内容
  bool get hasTextContent => textContent != null && textContent!.isNotEmpty;
}

/// 工具调用状态
enum ToolCallState {
  none,       // 无工具调用
  detected,   // 检测到工具调用
  completed,  // 工具调用完成
}
