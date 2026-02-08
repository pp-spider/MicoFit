import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/workout.dart';
import '../services/chat_local_service.dart';
import '../services/ai_api_service.dart';
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
class ChatProvider extends ChangeNotifier {
  final ChatLocalService _localService = ChatLocalService();
  final AIApiService _aiApiService = AIApiService();

  /// 构造函数
  ChatProvider();

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

  // ========== Getters ==========

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
  Future<void> loadHistory() async {
    // 清除当前内存中的消息
    _messages.clear();
    _currentSessionId = null;
    _pendingWorkoutPlan = null;

    // 检查用户是否已登录（用户数据隔离）
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      debugPrint('[ChatProvider] 用户未登录，跳过加载聊天历史');
      // 添加欢迎消息（未登录状态）
      _addWelcomeMessage();
      notifyListeners();
      return;
    }

    debugPrint('[ChatProvider] 加载用户 $userId 的聊天历史');

    final history = await _localService.loadChatHistory();
    _messages.addAll(history);

    // 如果没有历史记录，添加欢迎消息
    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }

    // 恢复待确认计划
    _pendingWorkoutPlan = await _localService.loadPendingPlan();

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

    // 重置流式状态
    _resetStreamingState();
    notifyListeners();
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
      final userKey = await UserDataHelper.buildUserKey(dateKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        userKey,
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

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }
}
