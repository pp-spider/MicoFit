import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/workout.dart';
import '../services/chat_local_service.dart';
import '../services/ai_api_service.dart';
import '../services/chat_session_api_service.dart';
import '../services/data_sync_service.dart';
import '../utils/user_data_helper.dart';

/// AI 聊天流式生成状态
enum ChatStreamStatus {
  idle, // 空闲
  streaming, // 流式生成中
  completed, // 已完成
  error, // 发生错误
}

/// 聊天状态管理（后端 API 版本）
///
/// 职责：
/// 1. 管理聊天消息列表
/// 2. 管理流式生成状态和进度
/// 3. 管理待确认的健身计划
/// 4. 通过后端 SSE API 与 AI 交互
/// 5. 管理会话列表和切换
/// 6. 处理应用生命周期变化（后台时保存状态）
class ChatProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ChatLocalService _localService = ChatLocalService();
  final AIApiService _aiApiService = AIApiService();
  final ChatSessionApiService _sessionApiService = ChatSessionApiService();

  /// 构造函数
  ChatProvider() {
    // 注册应用生命周期监听
    WidgetsBinding.instance.addObserver(this);
  }

  // ========== 状态数据 ==========

  /// 消息列表
  final List<ChatMessage> _messages = [];

  /// 流式生成状态
  ChatStreamStatus _streamStatus = ChatStreamStatus.idle;

  /// 当前流式消息的ID
  String? _streamingMessageId;

  /// 待确认的健身计划
  WorkoutPlan? _pendingWorkoutPlan;

  /// 流式生成中的内容缓冲
  StringBuffer? _streamingBuffer;

  /// 是否正在应用计划
  bool _isApplyingPlan = false;

  /// 当前会话ID
  String? _currentSessionId;

  /// 节流定时器
  Timer? _throttleTimer;

  /// 退到后台时保存的流式内容（用于恢复）
  String? _pausedStreamingContent;

  /// 退到后台时的消息ID（用于恢复流式状态）
  String? _pausedMessageId;

  /// 退到后台时是否正在流式生成
  bool _wasStreamingWhenPaused = false;

  // ========== 会话管理状态 ==========

  /// 会话列表
  List<ChatSession> _sessions = [];

  /// 是否正在加载会话列表
  bool _isLoadingSessions = false;

  // ========== Getters ==========

  /// 获取会话列表
  List<ChatSession> get sessions => List.unmodifiable(_sessions);

  /// 是否正在加载会话列表
  bool get isLoadingSessions => _isLoadingSessions;

  /// 会话列表是否为空
  bool get hasNoSessions => _sessions.isEmpty;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatStreamStatus get streamStatus => _streamStatus;
  bool get isStreaming => _streamStatus == ChatStreamStatus.streaming;
  bool get isIdle => _streamStatus == ChatStreamStatus.idle;
  WorkoutPlan? get pendingWorkoutPlan => _pendingWorkoutPlan;
  bool get isApplyingPlan => _isApplyingPlan;
  bool get hasPendingPlan => _pendingWorkoutPlan != null;
  String? get streamingMessageId => _streamingMessageId;
  String? get currentSessionId => _currentSessionId;

  /// 获取最后一条消息
  ChatMessage? get lastMessage =>
      _messages.isNotEmpty ? _messages.last : null;

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

  /// 加载聊天历史（根据当前登录用户）
  /// 首次进入显示空状态，等用户发送消息或选择会话时才加载内容
  Future<void> loadHistory() async {
    // 清除当前内存中的消息，重置为"未选择会话"状态
    _messages.clear();
    _currentSessionId = null;
    _pendingWorkoutPlan = null;

    // 检查用户是否已登录（用户数据隔离）
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      debugPrint('[ChatProvider] 用户未登录，显示空状态');
      // 不添加欢迎消息，显示空状态
      notifyListeners();
      return;
    }

    debugPrint('[ChatProvider] 用户已登录，保持空状态等待用户选择会话');

    // 同步后端数据（后台进行，不影响当前空状态）
    try {
      await DataSyncService().syncOnLogin();
    } catch (e) {
      debugPrint('[ChatProvider] 同步聊天历史失败: $e');
    }

    // 恢复待确认计划
    _pendingWorkoutPlan = await _localService.loadPendingPlan();

    // 注意：不加载历史消息到内存，保持空状态
    // 只有当用户选择某个会话时才加载该会话的消息（通过 switchSession）

    notifyListeners();
  }

  /// 清除内存中的聊天数据（登出时调用，不删除本地存储）
  void clearMemoryData() {
    _messages.clear();
    _currentSessionId = null;
    _pendingWorkoutPlan = null;
    _streamingMessageId = null;
    _streamingBuffer = null;
    _streamStatus = ChatStreamStatus.idle;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    notifyListeners();
  }

  /// 添加欢迎消息
  void _addWelcomeMessage() async {
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

    // 只有登录用户才保存到本地（用户数据隔离）
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId != null && userId.isNotEmpty) {
      await _localService.saveMessage(welcomeMessage);
    }
  }

  // ========== 消息发送 ==========

  /// 发送消息（流式）
  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty || isStreaming) return;

    // 检查用户是否已登录（用户数据隔离）
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      debugPrint('[ChatProvider] 用户未登录，无法发送消息');
      return;
    }

    // 1. 取消之前的流式请求
    await _cancelStream();

    // 2. 如果没有当前会话，先创建一个新会话（空状态首次发送消息）
    if (_currentSessionId == null) {
      debugPrint('[ChatProvider] 没有会话，创建新会话');
      try {
        final session = await _sessionApiService.createSession(title: '新对话');
        _currentSessionId = session.id;
        // 将新会话添加到列表
        _sessions.insert(0, session);
      } catch (e) {
        debugPrint('[ChatProvider] 创建会话失败: $e');
        // 继续尝试发送，后端也会创建会话
      }
    }

    // 3. 添加用户消息
    final userMsg = ChatMessage.user(userMessage.trim());
    _messages.add(userMsg);
    await _localService.saveMessage(userMsg);
    notifyListeners();

    // 4. 创建空的AI消息
    final aiMsg = ChatMessage.assistant('');
    _messages.add(aiMsg);
    _streamingMessageId = aiMsg.id;
    _streamStatus = ChatStreamStatus.streaming;
    _streamingBuffer = StringBuffer();
    notifyListeners();

    // 5. 开始流式生成
    await _startStreaming(userMessage.trim());
  }

  /// 开始流式生成
  Future<void> _startStreaming(String userMessage) async {
    try {
      // 使用后端 SSE API
      final stream = _aiApiService.sendMessageStream(
        sessionId: _currentSessionId,
        message: userMessage,
      );

      WorkoutPlan? receivedPlan;

      await for (final chunk in stream) {
        switch (chunk.type) {
          case AIStreamType.chunk:
            // 文本流块
            if (chunk.content != null) {
              _streamingBuffer!.write(chunk.content);
              _throttleUpdate();
            }
            break;

          case AIStreamType.sessionCreated:
            // 新会话创建
            if (chunk.sessionId != null) {
              _currentSessionId = chunk.sessionId;
              // 将新会话添加到列表
              final newSession = ChatSession(
                id: chunk.sessionId!,
                title: '新对话',
                messageCount: 0,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              _sessions.insert(0, newSession);
            }
            break;

          case AIStreamType.plan:
            // 收到训练计划
            final plan = chunk.plan;
            if (plan != null) {
              receivedPlan = plan;
              _pendingWorkoutPlan = plan;
              // 保存计划到本地（不等待）
              _localService.savePendingPlan(plan);
              // 通知UI更新显示计划预览
              notifyListeners();
            }
            break;

          case AIStreamType.done:
            // 完成
            await _handleStreamDone(receivedPlan);
            return;

          case AIStreamType.error:
            // 错误
            _handleStreamError(chunk.message ?? '未知错误');
            return;

          default:
            break;
        }
      }
    } catch (e) {
      _handleStreamError('连接后端服务失败: $e');
    }
  }

  /// 节流更新 UI
  void _throttleUpdate() {
    _throttleTimer?.cancel();
    _throttleTimer = Timer(const Duration(milliseconds: 16), () {
      // 只有在流式状态且消息ID有效时才更新
      if (_streamStatus != ChatStreamStatus.streaming ||
          _streamingMessageId == null) {
        return;
      }
      final index =
          _messages.indexWhere((msg) => msg.id == _streamingMessageId);
      if (index != -1) {
        // 保留原有的结构化数据（如健身计划）
        final originalMsg = _messages[index];
        _messages[index] = ChatMessage(
          id: originalMsg.id,
          type: ChatMessageType.assistant,
          content: _streamingBuffer.toString(),
          timestamp: originalMsg.timestamp,
          structuredData: originalMsg.structuredData,
          dataType: originalMsg.dataType,
        );
        notifyListeners();
      }
    });
  }

  /// 处理流式完成
  Future<void> _handleStreamDone(WorkoutPlan? plan) async {
    _throttleTimer?.cancel();
    _streamStatus = ChatStreamStatus.completed;

    final responseContent = _streamingBuffer.toString();

    if (responseContent.trim().isEmpty && plan == null) {
      // 空响应
      _updateMessageWithError('AI 未返回任何内容，请稍后重试');
      _streamStatus = ChatStreamStatus.error;
    } else {
      // 更新消息 - 如果有计划，使用 withWorkoutPlan 创建消息
      if (plan != null) {
        _updateMessage(ChatMessage.withWorkoutPlan(
          content: responseContent,
          workoutPlanJson: plan.toJson(),
        ));
      } else {
        _updateMessage(ChatMessage.assistant(responseContent));
      }
    }

    // 保存到本地（用户数据隔离）
    if (_messages.isNotEmpty) {
      final userId = await UserDataHelper.getCurrentUserId();
      if (userId != null && userId.isNotEmpty) {
        await _localService.saveMessage(_messages.last);
      }
    }

    // 自动生成会话标题（如果是新会话且有用户消息）
    await _autoGenerateSessionTitle();

    // 重置流式状态
    _resetStreamingState();
    notifyListeners();
  }

  /// 自动生成会话标题
  Future<void> _autoGenerateSessionTitle() async {
    // 检查是否是默认标题的新会话
    if (_currentSessionId == null) return;

    var sessionIndex = _sessions.indexWhere((s) => s.id == _currentSessionId);

    // 如果会话不在列表中，先加载会话列表
    if (sessionIndex == -1) {
      debugPrint('[ChatProvider] 会话不在列表中，尝试加载会话列表');
      try {
        await loadSessions();
        sessionIndex = _sessions.indexWhere((s) => s.id == _currentSessionId);
      } catch (e) {
        debugPrint('[ChatProvider] 加载会话列表失败: $e');
        return;
      }
    }

    if (sessionIndex == -1) {
      debugPrint('[ChatProvider] 仍然找不到会话');
      return;
    }

    final currentSession = _sessions[sessionIndex];
    if (currentSession.title != null && currentSession.title != '新对话') {
      return; // 已有自定义标题
    }

    // 获取用户的第一条消息
    final userMessages = _messages.where((m) => m.type == ChatMessageType.user).toList();
    if (userMessages.isEmpty) return;

    final firstUserMessage = userMessages.first.content;
    if (firstUserMessage.isEmpty) return;

    debugPrint('[ChatProvider] 正在生成标题: $firstUserMessage');

    try {
      final updatedSession = await _sessionApiService.generateTitle(
        _currentSessionId!,
        firstUserMessage,
      );
      _sessions[sessionIndex] = updatedSession;
      debugPrint('[ChatProvider] 标题生成成功: ${updatedSession.title}');
    } catch (e) {
      debugPrint('[ChatProvider] 自动生成标题失败: $e');
    }
  }

  /// 处理流式错误
  Future<void> _handleStreamError(String error) async {
    _throttleTimer?.cancel();
    _streamStatus = ChatStreamStatus.error;

    debugPrint('流式 API 错误: $error');

    _updateMessageWithError(
        '⚠️ **连接错误**\n\n$error\n\n💡 **建议**: 请检查网络连接或稍后重试');

    // 保存错误消息到本地（用户数据隔离）
    if (_messages.isNotEmpty) {
      final userId = await UserDataHelper.getCurrentUserId();
      if (userId != null && userId.isNotEmpty) {
        await _localService.saveMessage(_messages.last);
      }
    }

    _resetStreamingState();
    notifyListeners();
  }

  // ========== 消息更新辅助方法 ==========

  /// 更新当前流式消息
  void _updateMessage(ChatMessage newMessage) {
    if (_streamingMessageId != null) {
      final index =
          _messages.indexWhere((msg) => msg.id == _streamingMessageId);
      if (index != -1) {
        _messages[index] = newMessage;
      }
    }
  }

  /// 更新当前流式消息为错误信息
  void _updateMessageWithError(String errorContent) {
    if (_streamingMessageId != null) {
      final index =
          _messages.indexWhere((msg) => msg.id == _streamingMessageId);
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

  /// 重置流式状态
  void _resetStreamingState() {
    _streamingMessageId = null;
    _streamingBuffer = null;
    _streamStatus = ChatStreamStatus.idle;
  }

  /// 取消流式请求
  Future<void> _cancelStream() async {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _resetStreamingState();
  }

  // ========== 健身计划管理 ==========

  /// 应用健身计划
  Future<void> applyWorkoutPlan(WorkoutPlan plan) async {
    _isApplyingPlan = true;
    notifyListeners();

    // 检查用户是否已登录（用户数据隔离）
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      _isApplyingPlan = false;
      notifyListeners();
      debugPrint('[ChatProvider] 用户未登录，无法应用计划');
      return;
    }

    try {
      // 调用后端 API 将计划标记为已应用（如果 plan.id 存在）
      if (plan.id.isNotEmpty) {
        try {
          await _aiApiService.applyPlan(plan.id);
          debugPrint('[ChatProvider] 计划已应用到后端: ${plan.id}');
        } catch (e) {
          // 后端调用失败不影响本地保存，记录日志继续
          debugPrint('[ChatProvider] 后端应用计划失败（将仅保存本地）: $e');
        }
      }

      // 保存到本地缓存（使用用户隔离的key）
      final today = DateTime.now();
      final dateKey = 'workout_cache_${today.year}-${today.month}-${today.day}';
      await UserDataHelper.setString(
        dateKey,
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

    // 检查用户是否已登录（用户数据隔离）
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      debugPrint('[ChatProvider] 用户未登录，仅添加拒绝消息到内存');
      final rejectMessage = ChatMessage.assistant(
        '已取消。如果你有其他需求，随时告诉我！',
      );
      _messages.add(rejectMessage);
      notifyListeners();
      return;
    }

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

    // 检查用户是否已登录（用户数据隔离）
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId != null && userId.isNotEmpty) {
      await _localService.clearChatHistory();
    }

    _messages.clear();
    _pendingWorkoutPlan = null;
    _currentSessionId = null;
    _addWelcomeMessage();

    notifyListeners();
  }

  /// 删除单条消息
  Future<void> deleteMessage(String messageId) async {
    // 检查用户是否已登录（用户数据隔离）
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId != null && userId.isNotEmpty) {
      await _localService.deleteMessage(messageId);
    }
    _messages.removeWhere((msg) => msg.id == messageId);
    notifyListeners();
  }

  // ========== 会话管理方法 ==========

  /// 加载会话列表
  Future<void> loadSessions() async {
    // 检查用户是否已登录
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    _isLoadingSessions = true;
    notifyListeners();

    try {
      _sessions = await _sessionApiService.getSessions();
    } catch (e) {
      debugPrint('[ChatProvider] 加载会话列表失败: $e');
    } finally {
      _isLoadingSessions = false;
      notifyListeners();
    }
  }

  /// 创建新会话（点击新建按钮时）
  Future<void> createNewSession() async {
    // 检查用户是否已登录
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      debugPrint('[ChatProvider] 用户未登录，无法创建会话');
      return;
    }

    // 取消当前流式请求
    await _cancelStream();

    // 创建新会话并添加到列表
    try {
      final session = await _sessionApiService.createSession(title: '新对话');
      _sessions.insert(0, session);
      _currentSessionId = session.id;
      _messages.clear();
      _pendingWorkoutPlan = null;

      // 注意：不添加欢迎消息，显示空状态
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatProvider] 创建会话失败: $e');
    }
  }

  /// 切换会话
  Future<void> switchSession(String sessionId) async {
    // 取消当前流式请求
    await _cancelStream();

    _currentSessionId = sessionId;
    _messages.clear();

    // 从本地恢复待确认的计划（如果有）
    _pendingWorkoutPlan = await _localService.loadPendingPlan();

    // 检查用户是否已登录
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      _addWelcomeMessage();
      notifyListeners();
      return;
    }

    try {
      // 从后端加载会话消息
      final messages = await _sessionApiService.getMessages(sessionId);
      _messages.addAll(messages);

      // 如果没有消息，显示空状态（而不是欢迎消息）
      if (_messages.isEmpty) {
        // 不添加欢迎消息，显示空状态
      }
    } catch (e) {
      debugPrint('[ChatProvider] 加载会话消息失败: $e');
      // 失败时显示空状态
    }

    notifyListeners();
  }

  /// 重命名会话
  Future<void> renameSession(String sessionId, String newTitle) async {
    try {
      final updated = await _sessionApiService.renameSession(sessionId, newTitle);
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        _sessions[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ChatProvider] 重命名会话失败: $e');
    }
  }

  /// 删除会话
  Future<void> deleteSession(String sessionId) async {
    try {
      await _sessionApiService.deleteSession(sessionId);
      _sessions.removeWhere((s) => s.id == sessionId);

      // 如果删除的是当前会话，切换到第一个或创建新会话
      if (_currentSessionId == sessionId) {
        if (_sessions.isNotEmpty) {
          await switchSession(_sessions.first.id);
        } else {
          // 创建新会话
          await createNewSession();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatProvider] 删除会话失败: $e');
    }
  }

  // ========== 应用生命周期处理 ==========

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[ChatProvider] 生命周期状态变化: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // 应用进入后台或非活跃状态
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        // 应用恢复活跃
        _handleAppResumed();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // 应用被销毁或隐藏
        _handleAppPaused();
        break;
    }
  }

  /// 处理应用进入后台
  void _handleAppPaused() {
    debugPrint('[ChatProvider] 应用进入后台');

    // 如果正在流式生成，保存当前状态
    if (_streamStatus == ChatStreamStatus.streaming && _streamingBuffer != null) {
      _wasStreamingWhenPaused = true;
      final currentContent = _streamingBuffer.toString();
      if (currentContent.isNotEmpty) {
        _pausedStreamingContent = currentContent;
        _pausedMessageId = _streamingMessageId;
        debugPrint('[ChatProvider] 保存流式内容长度: ${currentContent.length}, messageId: $_pausedMessageId');
      }

      // 取消流式请求（不等待完成）
      _cancelStream();

      // 保存当前消息到本地（确保不丢失）
      _saveStreamingMessageToLocal();
    }
  }

  /// 处理应用恢复
  void _handleAppResumed() {
    debugPrint('[ChatProvider] 应用恢复前台');

    if (_wasStreamingWhenPaused && _pausedStreamingContent != null) {
      debugPrint('[ChatProvider] 检测到中断的流式生成，内容长度: ${_pausedStreamingContent!.length}');

      // 检查是否有内容可以继续
      if (_pausedStreamingContent!.isNotEmpty) {
        // 恢复显示之前的流式内容（保持流式状态）
        _resumeStreamingState();
      } else {
        // 没有内容，重置状态
        _wasStreamingWhenPaused = false;
        _pausedStreamingContent = null;
        _pausedMessageId = null;
      }
    }
  }

  /// 恢复流式状态（不显示提示，直接恢复流式展示）
  void _resumeStreamingState() {
    if (_pausedMessageId == null || _pausedStreamingContent == null) {
      _resetPausedState();
      return;
    }

    debugPrint('[ChatProvider] 恢复流式状态');

    // 恢复流式状态：保持原来的消息ID和内容
    _streamingMessageId = _pausedMessageId;
    _streamingBuffer = StringBuffer(_pausedStreamingContent!);
    _streamStatus = ChatStreamStatus.streaming;

    // 更新消息内容
    final index = _messages.indexWhere((msg) => msg.id == _pausedMessageId);
    if (index != -1) {
      _messages[index] = ChatMessage(
        id: _messages[index].id,
        type: ChatMessageType.assistant,
        content: _pausedStreamingContent!,
        timestamp: _messages[index].timestamp,
      );
    }

    // 继续向后端请求剩余内容
    _continueStreamingFromBackend();

    // 重置暂停状态（但内容保留）
    _pausedStreamingContent = null;
    _pausedMessageId = null;
    _wasStreamingWhenPaused = false;

    notifyListeners();
  }

  /// 从后端继续获取剩余的流式内容
  Future<void> _continueStreamingFromBackend() async {
    if (_currentSessionId == null) {
      debugPrint('[ChatProvider] 无法继续：缺少会话ID');
      _finishStreamingWithCurrentContent();
      return;
    }

    debugPrint('[ChatProvider] 请求继续生成剩余内容');

    try {
      // 调用后端继续生成的 API
      final stream = _aiApiService.continueStream(
        sessionId: _currentSessionId!,
        existingContent: _streamingBuffer.toString(),
      );

      await for (final chunk in stream) {
        switch (chunk.type) {
          case AIStreamType.chunk:
            if (chunk.content != null) {
              _streamingBuffer!.write(chunk.content);
              _throttleUpdate();
            }
            break;

          case AIStreamType.done:
            await _handleStreamDone(null);
            return;

          case AIStreamType.error:
            _handleStreamError(chunk.message ?? '继续生成失败');
            return;

          default:
            break;
        }
      }
    } catch (e) {
      debugPrint('[ChatProvider] 继续生成失败: $e');
      // 继续失败时，使用当前已有的内容作为最终回复
      _finishStreamingWithCurrentContent();
    }
  }

  /// 使用当前内容完成流式生成
  void _finishStreamingWithCurrentContent() {
    _streamStatus = ChatStreamStatus.completed;
    _resetStreamingState();
    notifyListeners();
  }

  /// 重置暂停状态
  void _resetPausedState() {
    _wasStreamingWhenPaused = false;
    _pausedStreamingContent = null;
    _pausedMessageId = null;
  }

  /// 保存流式消息到本地
  Future<void> _saveStreamingMessageToLocal() async {
    if (_streamingMessageId == null) return;

    try {
      final index = _messages.indexWhere((msg) => msg.id == _streamingMessageId);
      if (index != -1) {
        final userId = await UserDataHelper.getCurrentUserId();
        if (userId != null && userId.isNotEmpty) {
          await _localService.saveMessage(_messages[index]);
          debugPrint('[ChatProvider] 已保存中断的流式消息');
        }
      }
    } catch (e) {
      debugPrint('[ChatProvider] 保存流式消息失败: $e');
    }
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
