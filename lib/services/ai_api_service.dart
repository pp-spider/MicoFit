import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
  final String? messageId;  // 后端生成的消息ID（UUID）
  // Agent 状态相关字段
  final String? agent;
  final String? agentStatus;
  final String? taskType;
  // PlannerAgent 规划阶段字段
  final Map<String, dynamic>? analysis;
  final List<dynamic>? executionOrder;
  final List<dynamic>? parallelGroups;

  AIStreamChunk({
    required this.type,
    this.content,
    this.plan,
    this.sessionId,
    this.planId,
    this.hasPlan,
    this.message,
    this.messageId,  // 后端生成的消息ID
    this.agent,
    this.agentStatus,
    this.taskType,
    this.analysis,
    this.executionOrder,
    this.parallelGroups,
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
      messageId: json['message_id'] as String?,  // 后端消息ID
      agent: json['agent'] as String?,
      agentStatus: json['status'] as String?,
      taskType: json['task_type'] as String?,
      analysis: json['analysis'] as Map<String, dynamic>?,
      executionOrder: json['execution_order'] as List<dynamic>?,
      parallelGroups: json['parallel_groups'] as List<dynamic>?,
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
  agentStatus, // Agent 执行状态
  analysis, // 任务分析（PlannerAgent规划阶段）
  planInfo, // 任务规划信息（PlannerAgent规划阶段）
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
      case 'agent_status':
        return AIStreamType.agentStatus;
      case 'analysis':
        return AIStreamType.analysis;
      case 'plan_info':
        return AIStreamType.planInfo;
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
    request.headers['Accept-Encoding'] = 'gzip, deflate';

    request.body = jsonEncode({
      'session_id': sessionId,
      'message': message,
    });

    StringBuffer dataBuffer = StringBuffer();

    try {
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('聊天请求失败: ${response.statusCode} - $body');
      }

      // 解析 SSE 流 - 改进版，支持多行 data 和 event 事件
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        // 处理空行（消息分隔符）
        if (line.isEmpty) {
          if (dataBuffer.isNotEmpty) {
            final dataStr = dataBuffer.toString().trim();
            if (dataStr.startsWith('{')) {
              try {
                final data = jsonDecode(dataStr) as Map<String, dynamic>;
                // 只记录非chunk类型的日志，避免输出过多
                if (data['type'] != 'chunk') {
                  debugPrint('[AIApiService] 收到SSE: type=${data['type']}');
                }
                yield AIStreamChunk.fromJson(data);
              } catch (e) {
                debugPrint('[AIApiService] JSON解析错误: $e');
              }
            }
            dataBuffer = StringBuffer();
          }
          continue;
        }

        // 处理 event: 行（可以忽略，因为 data 中已包含 type）
        if (line.startsWith('event: ')) {
          continue;
        }

        // 处理 data: 行
        if (line.startsWith('data: ')) {
          final dataContent = line.substring(6);
          dataBuffer.write(dataContent);
          continue;
        }

        // 其他行忽略
      }

      // 处理最后剩余的数据
      if (dataBuffer.isNotEmpty) {
        final dataStr = dataBuffer.toString().trim();
        if (dataStr.startsWith('{')) {
          try {
            final data = jsonDecode(dataStr) as Map<String, dynamic>;
            yield AIStreamChunk.fromJson(data);
          } catch (e) {
            // 忽略解析错误
          }
        }
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败，请检查网络设置: $e');
    } catch (e) {
      throw Exception('聊天流异常: $e');
    }
  }

  /// 继续之前的流式生成（SSE）
  ///
  /// [sessionId] - 会话ID
  /// [existingContent] - 已有的内容（前端已接收的部分）
  Stream<AIStreamChunk> continueStream({
    required String sessionId,
    required String existingContent,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}/api/v1/ai/chat/continue'),
    );

    // 添加认证头
    final token = await _httpClient.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Accept-Encoding'] = 'gzip, deflate';

    request.body = jsonEncode({
      'session_id': sessionId,
      'existing_content': existingContent,
    });

    StringBuffer dataBuffer = StringBuffer();

    try {
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('继续生成请求失败: ${response.statusCode} - $body');
      }

      // 解析 SSE 流 - 改进版
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        // 处理空行（消息分隔符）
        if (line.isEmpty) {
          if (dataBuffer.isNotEmpty) {
            final dataStr = dataBuffer.toString().trim();
            if (dataStr.startsWith('{')) {
              try {
                final data = jsonDecode(dataStr) as Map<String, dynamic>;
                yield AIStreamChunk.fromJson(data);
              } catch (e) {
                // 忽略解析错误
              }
            }
            dataBuffer = StringBuffer();
          }
          continue;
        }

        if (line.startsWith('event: ')) {
          continue;
        }

        if (line.startsWith('data: ')) {
          final dataContent = line.substring(6);
          dataBuffer.write(dataContent);
          continue;
        }
      }

      // 处理最后剩余的数据
      if (dataBuffer.isNotEmpty) {
        final dataStr = dataBuffer.toString().trim();
        if (dataStr.startsWith('{')) {
          try {
            final data = jsonDecode(dataStr) as Map<String, dynamic>;
            yield AIStreamChunk.fromJson(data);
          } catch (e) {
            // 忽略解析错误
          }
        }
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败，请检查网络设置: $e');
    } catch (e) {
      throw Exception('继续生成流异常: $e');
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
    request.headers['Accept-Encoding'] = 'gzip, deflate';

    request.body = jsonEncode(preferences ?? {});

    StringBuffer dataBuffer = StringBuffer();

    try {
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('生成计划请求失败: ${response.statusCode} - $body');
      }

      // 解析 SSE 流 - 改进版
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        // 处理空行（消息分隔符）
        if (line.isEmpty) {
          if (dataBuffer.isNotEmpty) {
            final dataStr = dataBuffer.toString().trim();
            if (dataStr.startsWith('{')) {
              try {
                final data = jsonDecode(dataStr) as Map<String, dynamic>;
                yield AIStreamChunk.fromJson(data);
              } catch (e) {
                // 忽略解析错误
              }
            }
            dataBuffer = StringBuffer();
          }
          continue;
        }

        if (line.startsWith('event: ')) {
          continue;
        }

        if (line.startsWith('data: ')) {
          final dataContent = line.substring(6);
          dataBuffer.write(dataContent);
          continue;
        }
      }

      // 处理最后剩余的数据
      if (dataBuffer.isNotEmpty) {
        final dataStr = dataBuffer.toString().trim();
        if (dataStr.startsWith('{')) {
          try {
            final data = jsonDecode(dataStr) as Map<String, dynamic>;
            yield AIStreamChunk.fromJson(data);
          } catch (e) {
            // 忽略解析错误
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
