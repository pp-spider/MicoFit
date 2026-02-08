import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/workout.dart';
import 'http_client.dart';

/// AI 流式响应块
class AIStreamChunk {
  final AIStreamType type;
  final String? content;
  final WorkoutPlan? plan;
  final String? sessionId;
  final String? planId;
  final bool? hasPlan;
  final String? message;

  AIStreamChunk({
    required this.type,
    this.content,
    this.plan,
    this.sessionId,
    this.planId,
    this.hasPlan,
    this.message,
  });

  factory AIStreamChunk.fromJson(Map<String, dynamic> json) {
    return AIStreamChunk(
      type: AIStreamType.fromString(json['type'] as String),
      content: json['content'] as String?,
      plan: json['plan'] != null
          ? WorkoutPlan.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
      sessionId: json['session_id'] as String?,
      planId: json['plan_id'] as String?,
      hasPlan: json['has_plan'] as bool?,
      message: json['message'] as String?,
    );
  }
}

/// AI 流式响应类型
enum AIStreamType {
  chunk, // 文本流块
  plan, // 训练计划
  done, // 完成
  error, // 错误
  sessionCreated, // 新会话创建
  saved, // 计划已保存
  unknown;

  factory AIStreamType.fromString(String type) {
    switch (type) {
      case 'chunk':
        return AIStreamType.chunk;
      case 'plan':
        return AIStreamType.plan;
      case 'done':
        return AIStreamType.done;
      case 'error':
        return AIStreamType.error;
      case 'session_created':
        return AIStreamType.sessionCreated;
      case 'saved':
        return AIStreamType.saved;
      default:
        return AIStreamType.unknown;
    }
  }
}

/// AI API 服务
/// 通过后端 LangGraph Agent 调用 AI 功能
class AIApiService {
  final ApiHttpClient _httpClient;

  AIApiService({ApiHttpClient? httpClient})
      : _httpClient = httpClient ?? ApiHttpClient();

  /// 流式聊天（SSE）
  ///
  /// [sessionId] - 会话ID，为空则创建新会话
  /// [message] - 用户消息
  Stream<AIStreamChunk> sendMessageStream({
    String? sessionId,
    required String message,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}/api/v1/ai/chat/stream'),
    );

    // 添加认证头
    final token = await _httpClient.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';

    request.body = jsonEncode({
      'session_id': sessionId,
      'message': message,
    });

    try {
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('聊天请求失败: ${response.statusCode} - $body');
      }

      // 解析 SSE 流
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          try {
            final data =
                jsonDecode(line.substring(6)) as Map<String, dynamic>;
            yield AIStreamChunk.fromJson(data);
          } catch (e) {
            // 忽略解析错误，继续处理下一行
            continue;
          }
        }
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败，请检查网络设置: $e');
    } catch (e) {
      throw Exception('聊天流异常: $e');
    }
  }

  /// 流式生成训练计划（SSE）
  Stream<AIStreamChunk> generateWorkoutPlanStream({
    Map<String, dynamic>? preferences,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}/api/v1/ai/workouts/generate/stream'),
    );

    // 添加认证头
    final token = await _httpClient.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';

    request.body = jsonEncode(preferences ?? {});

    try {
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('生成计划请求失败: ${response.statusCode} - $body');
      }

      // 解析 SSE 流
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          try {
            final data =
                jsonDecode(line.substring(6)) as Map<String, dynamic>;
            yield AIStreamChunk.fromJson(data);
          } catch (e) {
            continue;
          }
        }
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败，请检查网络设置: $e');
    } catch (e) {
      throw Exception('生成计划流异常: $e');
    }
  }

  /// 非流式生成训练计划
  Future<Map<String, dynamic>> generateWorkoutPlan({
    Map<String, dynamic>? preferences,
  }) async {
    final response = await _httpClient.post(
      '/api/v1/ai/workouts/generate',
      body: jsonEncode(preferences ?? {}),
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    return ApiHttpClient.parseResponse(response) ?? {};
  }

  /// 获取今日训练计划
  Future<WorkoutPlan?> getTodayPlan() async {
    final response = await _httpClient.get('/api/v1/workouts/today');

    if (response.statusCode == 404) {
      return null;
    }

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = ApiHttpClient.parseResponse(response);
    if (data == null) return null;

    return WorkoutPlan.fromJson(data);
  }

  /// 应用训练计划到今日
  Future<void> applyPlan(String planId) async {
    final response = await _httpClient.post(
      '/api/v1/workouts/apply',
      body: jsonEncode({'plan_id': planId}),
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }
  }

  /// 标记计划为已完成
  Future<void> completePlan(String planId) async {
    final response = await _httpClient.post(
      '/api/v1/workouts/$planId/complete',
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }
  }
}
