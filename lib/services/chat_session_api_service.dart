import 'dart:convert';
import '../services/http_client.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../models/agent_output.dart';

/// 聊天会话 API 服务
class ChatSessionApiService {
  final ApiHttpClient _httpClient = ApiHttpClient();

  /// 获取会话列表
  Future<List<ChatSession>> getSessions({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _httpClient.get(
      '/api/v1/chat-sessions?limit=$limit&offset=$offset',
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => ChatSession.fromJson(json)).toList();
  }

  /// 获取单个会话
  Future<ChatSession> getSession(String sessionId) async {
    final response = await _httpClient.get('/api/v1/chat-sessions/$sessionId');

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ChatSession.fromJson(data);
  }

  /// 获取会话消息
  Future<List<ChatMessage>> getMessages(
    String sessionId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await _httpClient.get(
      '/api/v1/chat-sessions/$sessionId/messages?limit=$limit&offset=$offset',
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => ChatMessage.fromApiJson(json)).toList();
  }

  /// 创建会话
  Future<ChatSession> createSession({String? title}) async {
    final response = await _httpClient.post(
      '/api/v1/chat-sessions',
      body: jsonEncode({'title': title}),
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ChatSession.fromJson(data);
  }

  /// 重命名会话
  Future<ChatSession> renameSession(String sessionId, String title) async {
    final response = await _httpClient.patch(
      '/api/v1/chat-sessions/$sessionId',
      body: jsonEncode({'title': title}),
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ChatSession.fromJson(data);
  }

  /// 删除会话
  Future<void> deleteSession(String sessionId) async {
    final response = await _httpClient.delete('/api/v1/chat-sessions/$sessionId');

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }
  }

  /// 基于首条消息自动生成会话标题
  Future<ChatSession> generateTitle(String sessionId, String firstMessage) async {
    final response = await _httpClient.post(
      '/api/v1/chat-sessions/$sessionId/generate-title',
      body: jsonEncode({'first_message': firstMessage}),
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ChatSession.fromJson(data);
  }

  /// 更新消息的 Agent 输出
  Future<void> updateMessageAgentOutputs(
    String sessionId,
    String messageId,
    List<Map<String, dynamic>> agentOutputs,
  ) async {
    final response = await _httpClient.patch(
      '/api/v1/chat-sessions/$sessionId/messages/$messageId/agent-outputs',
      body: jsonEncode({'agent_outputs': agentOutputs}),
    );

    if (!ApiHttpClient.isSuccess(response)) {
      throw Exception(ApiHttpClient.getErrorMessage(response));
    }
  }
}
