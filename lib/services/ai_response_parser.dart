import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import '../models/chat_message.dart';

/// AI 响应解析异常
class AIResponseParseException implements Exception {
  final String message;
  final String? rawContent;

  AIResponseParseException(this.message, {this.rawContent});

  @override
  String toString() => message;
}

/// AI 响应解析器
class AIResponseParser {
  /// 从 AI 响应内容中提取并解析健身计划
  static WorkoutPlan? parseWorkoutPlan(String content) {
    try {
      // 尝试提取 JSON 代码块
      final jsonContent = _extractJsonFromCodeBlock(content);
      if (jsonContent == null) return null;

      // 解析 JSON
      final jsonMap = jsonDecode(jsonContent) as Map<String, dynamic>;

      // 转换为 WorkoutPlan 对象
      return WorkoutPlan.fromJson(jsonMap);
    } catch (e) {
      throw AIResponseParseException(
        '无法解析健身计划: $e',
        rawContent: content,
      );
    }
  }

  /// 从内容中提取 JSON 代码块
  static String? _extractJsonFromCodeBlock(String content) {
    // 方法1: 正则匹配 ```json ... ``` 或 ``` ... ``` 代码块
    // 改进版：允许代码块内有额外文字，从中提取 JSON 对象
    final codeBlockRegex = RegExp(
      r'```(?:json)?\s*\n?([\s\S]*?)\n?```',
      multiLine: true,
    );

    final matches = codeBlockRegex.allMatches(content);
    for (final match in matches) {
      if (match.groupCount >= 1) {
        String blockContent = match.group(1)!.trim();

        // 从代码块内容中提取 JSON 对象
        // 查找第一个 { 和最后一个 }
        final startIndex = blockContent.indexOf('{');
        final endIndex = blockContent.lastIndexOf('}');

        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          final jsonString = blockContent.substring(startIndex, endIndex + 1);
          debugPrint('提取到的 JSON: ${jsonString.substring(0, jsonString.length > 100 ? 100 : jsonString.length)}...');
          return jsonString;
        }
      }
    }

    // 方法2: 尝试直接解析整个内容为 JSON
    final trimmed = content.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    // 方法3: 查找内容中任意 {...} 格式的 JSON
    final startIndex = trimmed.indexOf('{');
    final endIndex = trimmed.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      final potentialJson = trimmed.substring(startIndex, endIndex + 1);
      debugPrint('尝试提取内容中的 JSON: ${potentialJson.substring(0, potentialJson.length > 100 ? 100 : potentialJson.length)}...');
      // 尝试解析验证是否是有效 JSON
      try {
        jsonDecode(potentialJson);
        return potentialJson;
      } catch (e) {
        // 不是有效 JSON，继续
      }
    }

    debugPrint('未能提取到 JSON 代码块');
    return null;
  }

  /// 验证 WorkoutPlan 数据完整性
  static bool validateWorkoutPlan(WorkoutPlan plan) {
    // 基本字段验证
    if (plan.id.isEmpty || plan.title.isEmpty) return false;
    if (plan.totalDuration <= 0 || plan.totalDuration > 60) return false;
    if (plan.rpe < 1 || plan.rpe > 10) return false;
    if (plan.modules.isEmpty) return false;

    // 模块验证
    for (final module in plan.modules) {
      if (module.id.isEmpty || module.name.isEmpty) return false;
      if (module.duration <= 0) return false;
      if (module.exercises.isEmpty) return false;

      // 动作验证
      for (final exercise in module.exercises) {
        if (exercise.id.isEmpty || exercise.name.isEmpty) return false;
        if (exercise.duration <= 0 || exercise.duration > 300) return false;
        if (exercise.steps.isEmpty) return false;
      }
    }

    return true;
  }

  /// 从 AI 消息中提取健身计划，返回解析后的消息
  static ChatMessage enrichMessageWithWorkoutPlan(ChatMessage originalMessage) {
    if (originalMessage.type != ChatMessageType.assistant) {
      return originalMessage;
    }

    try {
      final plan = parseWorkoutPlan(originalMessage.content);
      if (plan != null && validateWorkoutPlan(plan)) {
        // 创建包含结构化数据的新消息
        debugPrint('✅ 健身计划解析成功: ${plan.title}');
        return ChatMessage.withWorkoutPlan(
          content: originalMessage.content,
          workoutPlanJson: plan.toJson(),
        );
      } else if (plan != null) {
        debugPrint('⚠️ 健身计划验证失败: ${plan.title}, modules: ${plan.modules.length}');
      } else {
        debugPrint('ℹ️ 未找到健身计划 JSON');
      }
    } catch (e) {
      // 解析失败，返回原消息
      debugPrint('❌ 健身计划解析失败: $e');
      debugPrint('响应内容预览: ${originalMessage.content.substring(0, originalMessage.content.length > 200 ? 200 : originalMessage.content.length)}...');
    }

    return originalMessage;
  }
}
