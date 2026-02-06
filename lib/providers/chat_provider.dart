import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/workout.dart';
import '../models/tool_schemas.dart';
import '../services/chat_local_service.dart';
import '../services/ai_openai_service.dart';
import '../services/ai_response_parser.dart';
import '../models/ai_chat_context.dart';
import 'user_profile_provider.dart';

/// AI 聊天流式生成状态
enum ChatStreamStatus {
  idle,       // 空闲
  streaming,  // 流式生成中
  completed,  // 已完成
  error,      // 发生错误
}

/// 聊天状态管理
///
/// 职责：
/// 1. 管理聊天消息列表（持久化）
/// 2. 管理流式生成状态和进度
/// 3. 管理待确认的健身计划
/// 4. 处理 StreamSubscription 的生命周期
class ChatProvider extends ChangeNotifier {
  final ChatLocalService _localService = ChatLocalService();
  final UserProfileProvider _userProfileProvider;
  AIOpenAIService? _aiService;

  /// 构造函数
  ChatProvider({required UserProfileProvider userProfileProvider})
      : _userProfileProvider = userProfileProvider;

  // ========== 状态数据 ==========

  /// 消息列表
  final List<ChatMessage> _messages = [];

  /// 流式生成状态
  ChatStreamStatus _streamStatus = ChatStreamStatus.idle;

  /// 当前流式消息的ID（用于恢复流式状态）
  String? _streamingMessageId;

  /// 待确认的健身计划
  WorkoutPlan? _pendingWorkoutPlan;

  /// 流式生成中的内容缓冲（用于后台继续生成）
  StringBuffer? _streamingBuffer;

  /// 是否正在应用计划
  bool _isApplyingPlan = false;

  /// StreamSubscription（需要管理生命周期）
  StreamSubscription? _streamSubscription;

  /// 节流定时器
  Timer? _throttleTimer;

  /// 工具调用状态
  ToolCallState _toolCallState = ToolCallState.none;

  /// 待执行的工具调用数据
  List<Map<String, dynamic>>? _pendingToolCallData;

  /// 工具响应消息（用于发送给AI的下一轮请求）
  /// 使用 Map 格式以便完全控制序列化，避免 RequestFunctionMessage 的序列化问题
  List<Map<String, dynamic>>? _toolResponseMessages;

  /// 最后的用户消息（用于工具调用后继续对话）
  String? _lastUserMessage;

  // ========== Getters ==========

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatStreamStatus get streamStatus => _streamStatus;
  bool get isStreaming => _streamStatus == ChatStreamStatus.streaming;
  bool get isIdle => _streamStatus == ChatStreamStatus.idle;
  WorkoutPlan? get pendingWorkoutPlan => _pendingWorkoutPlan;
  bool get isApplyingPlan => _isApplyingPlan;
  bool get hasPendingPlan => _pendingWorkoutPlan != null;
  String? get streamingMessageId => _streamingMessageId;

  /// 工具调用状态
  ToolCallState get toolCallState => _toolCallState;
  bool get isProcessingToolCall => _toolCallState == ToolCallState.detected;

  /// 获取最后一条消息
  ChatMessage? get lastMessage => _messages.isNotEmpty ? _messages.last : null;

  /// 获取当前流式消息
  ChatMessage? get streamingMessage {
    if (_streamingMessageId == null) return null;
    try {
      return _messages.firstWhere((msg) => msg.id == _streamingMessageId);
    } catch (e) {
      return null;
    }
  }

  // ========== 初始化 ==========

  /// 加载聊天历史
  Future<void> loadHistory() async {
    final history = await _localService.loadChatHistory();
    _messages.clear();
    _messages.addAll(history);

    // 如果没有历史记录，添加欢迎消息
    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }

    // 恢复待确认计划
    _pendingWorkoutPlan = await _localService.loadPendingPlan();

    notifyListeners();
  }

  /// 添加欢迎消息
  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage.assistant(
      '你好！我是你的专属AI健身教练 💪\n\n'
      '我可以帮你：\n\n'
      '🎯 制定个性化运动计划\n\n'
      '💡 解答训练相关问题\n\n'
      '🥗 提供饮食和健康建议\n\n'
      '📊 调整训练强度和方案\n\n'
      '随时向我提问，我会尽力帮助你！',
    );
    _messages.add(welcomeMessage);
    _localService.saveMessage(welcomeMessage);
  }

  // ========== 消息发送 ==========

  /// 发送消息（流式）
  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty || isStreaming) return;

    // 1. 取消之前的流式请求
    await _cancelStream();

    // 2. 添加用户消息
    final userMsg = ChatMessage.user(userMessage.trim());
    _messages.add(userMsg);
    await _localService.saveMessage(userMsg);
    notifyListeners();

    // 3. 创建空的AI消息
    final aiMsg = ChatMessage.assistant('');
    _messages.add(aiMsg);
    _streamingMessageId = aiMsg.id;
    _streamStatus = ChatStreamStatus.streaming;
    _streamingBuffer = StringBuffer();
    notifyListeners();

    // 4. 开始流式生成
    await _startStreaming(userMessage.trim(), aiMsg);
  }

  /// 开始流式生成
  Future<void> _startStreaming(String userMessage, ChatMessage aiMessage) async {
    try {
      final aiService = _getAIService();

      // 获取用户画像
      final userProfile = _userProfileProvider.profile;

      // 从 UserProfile 创建上下文
      final chatContext = userProfile != null
          ? AIChatContext.fromUserProfile(
              userProfile,
              history: _messages,
            )
          : AIChatContext(recentHistory: _messages);

      // 保存用户消息用于可能的工具调用后续
      _lastUserMessage = userMessage;
      _toolCallState = ToolCallState.none;
      _pendingToolCallData = null;

      // 使用支持工具调用的流式方法
      final responseStream = aiService.sendMessageStreamWithTools(
        userMessage: userMessage,
        context: chatContext,
        additionalMessages: _toolResponseMessages,
      );

      // 清空工具响应消息（已使用）
      _toolResponseMessages = null;

      // 监听流式响应
      _streamSubscription = responseStream.listen(
        (chunk) {
          if (chunk.hasToolCalls) {
            _handleToolCalls(chunk.toolCallData!);
          } else if (chunk.hasTextContent) {
            _handleStreamChunk(chunk.textContent!);
          }
        },
        onDone: () {
          _handleStreamDone();
        },
        onError: (error) {
          _handleStreamError(error);
        },
      );

    } on AIServiceException catch (e) {
      _handleAIServiceError(e);
    } catch (e) {
      _handleUnknownError(e);
    }
  }

  /// 处理流式数据块
  void _handleStreamChunk(String chunk) {
    _streamingBuffer!.write(chunk);

    // 节流：每 16ms 最多更新一次 UI
    _throttleTimer?.cancel();
    _throttleTimer = Timer(const Duration(milliseconds: 16), () {
      if (_streamingMessageId != null) {
        final index = _messages.indexWhere((msg) => msg.id == _streamingMessageId);
        if (index != -1) {
          _messages[index] = ChatMessage(
            id: _messages[index].id,
            type: ChatMessageType.assistant,
            content: _streamingBuffer.toString(),
            timestamp: _messages[index].timestamp,
          );
          notifyListeners();
        }
      }
    });
  }

  /// 处理工具调用
  void _handleToolCalls(List<Map<String, dynamic>> toolCallData) {
    _toolCallState = ToolCallState.detected;
    _pendingToolCallData = toolCallData;
    notifyListeners();

    // 格式化输出工具调用信息
    debugPrint('===== 检测到工具调用 =====');
    for (int i = 0; i < toolCallData.length; i++) {
      final tc = toolCallData[i];
      debugPrint('工具调用 #${i + 1}:');
      debugPrint('  ID: ${tc['id']}');
      debugPrint('  Type: ${tc['type']}');
      if (tc['function'] != null) {
        final func = tc['function'] as Map<String, dynamic>;
        debugPrint('  Function Name: ${func['name']}');
        debugPrint('  Arguments: ${func['arguments']}');
      }
    }
    debugPrint('========================');
  }

  /// 处理流式完成
  Future<void> _handleStreamDone() async {
    _throttleTimer?.cancel();

    // 如果有待处理的工具调用，先执行工具
    if (_pendingToolCallData != null && _pendingToolCallData!.isNotEmpty) {
      await _executeToolCalls(_pendingToolCallData!);
      return;
    }

    _streamStatus = ChatStreamStatus.completed;

    final responseContent = _streamingBuffer.toString();

    if (responseContent.trim().isEmpty) {
      // 空响应
      _updateMessageWithError('AI 未返回任何内容，请检查配置');
      _streamStatus = ChatStreamStatus.error;
    } else {
      // 解析健身计划
      final enrichedMessage = AIResponseParser.enrichMessageWithWorkoutPlan(
        ChatMessage.assistant(responseContent),
      );

      // 更新消息
      _updateMessage(enrichedMessage);

      // 如果包含健身计划，缓存到待确认
      if (enrichedMessage.dataType == ChatMessageDataType.workoutPlan &&
          enrichedMessage.structuredData != null) {
        try {
          _pendingWorkoutPlan = WorkoutPlan.fromJson(enrichedMessage.structuredData!);
          // 持久化到本地
          await _localService.savePendingPlan(_pendingWorkoutPlan!);
        } catch (e) {
          debugPrint('健身计划对象创建失败: $e');
        }
      }
    }

    // 保存到本地
    await _saveLastMessage();

    // 重置流式状态
    _resetStreamingState();
    notifyListeners();
  }

  /// 处理流式错误
  Future<void> _handleStreamError(dynamic error) async {
    _throttleTimer?.cancel();
    _streamStatus = ChatStreamStatus.error;

    debugPrint('流式 API 错误: $error');
    final errorMessage = _formatDetailedError(error);

    _updateMessageWithError(errorMessage);
    await _saveLastMessage();
    _resetStreamingState();
    notifyListeners();
  }

  /// 处理 AI 服务异常
  void _handleAIServiceError(AIServiceException e) {
    _streamStatus = ChatStreamStatus.error;

    debugPrint('AI 服务异常: $e');
    final errorMessage = _formatAIServiceException(e);

    // 移除空的 AI 消息
    if (_messages.isNotEmpty &&
        _messages.last.type == ChatMessageType.assistant &&
        _messages.last.content.isEmpty) {
      _messages.removeLast();
    }

    _messages.add(ChatMessage.assistant(errorMessage));
    _resetStreamingState();
    notifyListeners();
  }

  /// 处理未知错误
  void _handleUnknownError(dynamic e) {
    _streamStatus = ChatStreamStatus.error;

    debugPrint('未知错误: $e');
    final errorMessage = '⚠️ **发生未知错误**\n\n💡 **建议**:\n'
        '1. 检查网络连接是否正常\n'
        '2. 验证 AI 配置\n'
        '3. 稍后重试';

    // 移除空的 AI 消息
    if (_messages.isNotEmpty &&
        _messages.last.type == ChatMessageType.assistant &&
        _messages.last.content.isEmpty) {
      _messages.removeLast();
    }

    _messages.add(ChatMessage.assistant(errorMessage));
    _resetStreamingState();
    notifyListeners();
  }

  // ========== 工具调用相关方法 ==========

  /// 执行工具调用
  Future<void> _executeToolCalls(List<Map<String, dynamic>> toolCallData) async {
    _toolCallState = ToolCallState.completed;
    _toolResponseMessages = [];

    // 1. 先添加包含 tool_calls 的 assistant 消息
    // OpenAI API 要求: assistant 消息（带 tool_calls）必须在 tool 响应消息之前
    final toolCallsMaps = toolCallData.map((tc) {
      final function = tc['function'] as Map<String, dynamic>;
      return {
        'id': tc['id'] as String,
        'type': tc['type'] as String? ?? 'function',
        'function': {
          'name': function['name'] as String,
          'arguments': function['arguments'] as String? ?? '',
        },
      };
    }).toList();

    _toolResponseMessages?.add({
      "role": "assistant",
      "content": [],  // 空数组表示无文本内容
      "tool_calls": toolCallsMaps,
    });

    // 2. 然后添加工具响应消息
    for (final toolCallMap in toolCallData) {
      final toolCall = ToolCallData.fromMap(toolCallMap);
      final functionName = toolCall.functionName;

      dynamic result;
      switch (functionName) {
        case 'get_user_profile':
          final profile = _userProfileProvider.profile;
          final response = UserProfileToolResponse.fromProfile(profile);
          result = response.toJson();
          break;
        // 未来可添加更多工具
        default:
          result = {'error': 'Unknown function: $functionName'};
      }

      debugPrint("result: ${jsonEncode(result)}");

      // 创建工具响应消息 Map（符合 OpenAI API 格式）
      _toolResponseMessages?.add({
        "role": "tool",
        "tool_call_id": toolCall.id,
        "content": jsonEncode(result),  // 字符串格式
      });
    }

    // 发送工具响应并继续对话
    await _continueAfterToolCall();
  }

  /// 工具调用后继续对话
  Future<void> _continueAfterToolCall() async {
    // 移除之前的空AI消息（因为我们要创建新的）
    if (_messages.isNotEmpty &&
        _messages.last.type == ChatMessageType.assistant &&
        _messages.last.content.isEmpty) {
      _messages.removeLast();
    }

    // 创建新的AI消息用于显示最终响应
    final aiMsg = ChatMessage.assistant('');
    _messages.add(aiMsg);
    _streamingMessageId = aiMsg.id;
    _streamStatus = ChatStreamStatus.streaming;
    _streamingBuffer = StringBuffer();
    notifyListeners();

    // 重新发起请求，带上工具响应
    await _startStreaming(_lastUserMessage ?? '', aiMsg);
  }

  // ========== 消息更新辅助方法 ==========

  /// 更新当前流式消息
  void _updateMessage(ChatMessage newMessage) {
    if (_streamingMessageId != null) {
      final index = _messages.indexWhere((msg) => msg.id == _streamingMessageId);
      if (index != -1) {
        _messages[index] = newMessage;
      }
    }
  }

  /// 更新当前流式消息为错误信息
  void _updateMessageWithError(String errorContent) {
    if (_streamingMessageId != null) {
      final index = _messages.indexWhere((msg) => msg.id == _streamingMessageId);
      if (index != -1) {
        _messages[index] = ChatMessage(
          id: _messages[index].id,
          type: ChatMessageType.assistant,
          content: errorContent,
          timestamp: DateTime.now(),
        );
      }
    }
  }

  /// 保存最后一条消息到本地
  Future<void> _saveLastMessage() async {
    if (_messages.isNotEmpty) {
      await _localService.saveMessage(_messages.last);
    }
  }

  /// 重置流式状态
  void _resetStreamingState() {
    _streamingMessageId = null;
    _streamingBuffer = null;
    _streamStatus = ChatStreamStatus.idle;
  }

  // ========== 取消流式请求 ==========

  /// 取消流式请求
  Future<void> _cancelStream() async {
    _throttleTimer?.cancel();
    _throttleTimer = null;

    await _streamSubscription?.cancel();
    _streamSubscription = null;

    _resetStreamingState();
  }

  // ========== 健身计划管理 ==========

  /// 应用健身计划
  Future<void> applyWorkoutPlan(WorkoutPlan plan) async {
    _isApplyingPlan = true;
    notifyListeners();

    try {
      // 保存到本地缓存（与 WorkoutProvider 同步）
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month}-${today.day}';
      await prefs.setString(
        'workout_cache_$dateKey',
        jsonEncode(plan.toJson()),
      );

      // 清除待确认计划
      _pendingWorkoutPlan = null;
      await _localService.clearPendingPlan();
      _isApplyingPlan = false;

      // 添加确认消息
      final confirmMessage = ChatMessage.assistant(
        '✅ 计划已更新！在"今日"页面查看新计划，准备好就可以开始训练了！',
      );
      _messages.add(confirmMessage);
      await _localService.saveMessage(confirmMessage);

      notifyListeners();
    } catch (e) {
      _isApplyingPlan = false;

      final errorMessage = ChatMessage.assistant(
        '❌ 应用计划失败: $e\n\n请稍后重试或在"今日"页面手动刷新计划。',
      );
      _messages.add(errorMessage);
      await _localService.saveMessage(errorMessage);

      notifyListeners();
    }
  }

  /// 拒绝健身计划
  Future<void> rejectWorkoutPlan() async {
    _pendingWorkoutPlan = null;
    await _localService.clearPendingPlan();

    final rejectMessage = ChatMessage.assistant(
      '已取消。如果你有其他需求，随时告诉我！',
    );
    _messages.add(rejectMessage);
    await _localService.saveMessage(rejectMessage);

    notifyListeners();
  }

  // ========== 聊天历史管理 ==========

  /// 清空聊天历史
  Future<void> clearHistory() async {
    await _cancelStream();
    await _localService.clearChatHistory();

    _messages.clear();
    _pendingWorkoutPlan = null;
    _addWelcomeMessage();

    notifyListeners();
  }

  /// 删除单条消息
  Future<void> deleteMessage(String messageId) async {
    await _localService.deleteMessage(messageId);
    _messages.removeWhere((msg) => msg.id == messageId);
    notifyListeners();
  }

  // ========== 资源释放 ==========

  /// 获取 AI 服务（懒加载）
  AIOpenAIService _getAIService() {
    _aiService ??= AIOpenAIService();
    return _aiService!;
  }

  @override
  void dispose() {
    // 取消流式请求和定时器
    _throttleTimer?.cancel();
    _streamSubscription?.cancel();
    super.dispose();
  }

  // ========== 错误格式化（从 AiChatPage 迁移） ==========

  String _formatAIServiceException(AIServiceException e) {
    final buffer = StringBuffer();
    buffer.writeln('⚠️ **AI 服务错误**\n');

    if (e.statusCode == 0) {
      buffer.writeln('AI 配置不完整，无法连接服务\n');
      buffer.writeln('💡 **解决方法**:\n');
      buffer.writeln('请前往"我的"页面，检查以下配置是否完整：\n');
      buffer.writeln('• Base URL (API地址)\n• API Key (API密钥)\n• Model (模型名称)');
    } else if (e.statusCode == 401) {
      buffer.writeln('API 密钥无效或已过期\n');
      buffer.writeln('💡 **解决方法**:\n请检查 API Key 是否正确，或重新生成有效的密钥');
    } else if (e.statusCode == 429) {
      buffer.writeln('请求过于频繁，已达速率限制\n');
      buffer.writeln('💡 **解决方法**:\n请稍等片刻后再试，或考虑升级 API 套餐');
    } else if (e.statusCode == 500 || e.statusCode == 502 || e.statusCode == 503) {
      buffer.writeln('AI 服务暂时不可用\n');
      buffer.writeln('💡 **解决方法**:\n请稍后再试，或检查 API 服务状态');
    } else {
      buffer.writeln('API 调用失败\n');
      buffer.writeln('💡 **解决方法**:\n请检查网络连接和 API 配置是否正确');
    }

    return buffer.toString();
  }

  String _formatDetailedError(dynamic error) {
    final buffer = StringBuffer();
    final errorStr = error.toString();

    if (errorStr.contains('timeout') || errorStr.contains('TimeoutException')) {
      buffer.writeln('⚠️ **网络连接超时**\n');
      buffer.writeln('💡 **解决方法**:\n请检查网络连接，稍后重试');
    } else if (errorStr.contains('Connection refused') || errorStr.contains('SocketException')) {
      buffer.writeln('⚠️ **无法连接到服务器**\n');
      buffer.writeln('💡 **解决方法**:\n请检查网络设置和 API 地址配置');
    } else if (errorStr.contains('Network') || errorStr.contains('HttpException')) {
      buffer.writeln('⚠️ **网络连接异常**\n');
      buffer.writeln('💡 **解决方法**:\n请检查网络连接状态');
    } else {
      buffer.writeln('⚠️ **连接错误**\n');
      buffer.writeln('💡 **解决方法**:\n请稍后重试，或检查 API 配置是否正确');
    }

    return buffer.toString();
  }
}
