import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/workout.dart';
import '../models/agent_output.dart';
import '../services/chat_local_service.dart';
import '../services/ai_api_service.dart';
import '../services/chat_session_api_service.dart';
import '../services/data_sync_service.dart';
import '../services/workout_api_service.dart';
import '../utils/user_data_helper.dart';

/// AI 聊天流式生成状态
enum ChatStreamStatus {
  idle, // 空闲
  streaming, // 流式生成中
  completed, // 已完成
  error, // 发生错误
}

/// Agent 执行状态
class AgentExecutionStatus {
  final String agent;
  final String taskType;
  final bool isActive; // true = 执行中, false = 已完成
  final List<AgentContentItem> contentItems;
  final String? taskId; // 任务唯一标识，用于区分同名 agent 的不同实例

  AgentExecutionStatus({
    required this.agent,
    required this.taskType,
    required this.isActive,
    this.contentItems = const [],
    this.taskId,
  });

  /// 创建已完成状态
  AgentExecutionStatus copyWithCompleted() {
    return AgentExecutionStatus(
      agent: agent,
      taskType: taskType,
      isActive: false,
      contentItems: contentItems,
      taskId: taskId,
    );
  }

  /// 添加内容项
  AgentExecutionStatus addContentItem(AgentContentItem item) {
    return AgentExecutionStatus(
      agent: agent,
      taskType: taskType,
      isActive: isActive,
      contentItems: [...contentItems, item],
      taskId: taskId,
    );
  }

  /// 更新最后一个内容项
  AgentExecutionStatus updateLastContentItem(AgentContentItem item) {
    if (contentItems.isEmpty) return addContentItem(item);
    final newItems = [...contentItems];
    newItems[newItems.length - 1] = item;
    return AgentExecutionStatus(
      agent: agent,
      taskType: taskType,
      isActive: isActive,
      contentItems: newItems,
      taskId: taskId,
    );
  }

  /// 追加文本内容到最后一个 text 类型的内容项
  /// 如果没有 text 类型的内容项，则添加一个新的
  AgentExecutionStatus appendTextContent(String text) {
    if (contentItems.isEmpty) {
      return addContentItem(AgentContentItem.text(text));
    }

    final lastItem = contentItems.last;
    if (lastItem.type == AgentContentType.text && lastItem.text != null) {
      // 追加到最后一个 text 内容项
      final newItems = [...contentItems];
      newItems[newItems.length - 1] = AgentContentItem.text(lastItem.text! + text);
      return AgentExecutionStatus(
        agent: agent,
        taskType: taskType,
        isActive: isActive,
        contentItems: newItems,
        taskId: taskId,
      );
    } else {
      // 添加新的 text 内容项
      return addContentItem(AgentContentItem.text(text));
    }
  }

  /// 转换为AgentOutput（用于UI展示）
  AgentOutput toAgentOutput({bool isExpanded = false, String? messageContent}) {
    return AgentOutput(
      id: taskId ?? agent,  // 使用 taskId 作为唯一标识，如果没有则使用 agent 名称
      name: AgentOutput.getDisplayName(agent),
      icon: AgentOutput.getIcon(agent),
      status: isActive ? AgentStatus.running : AgentStatus.completed,
      taskType: taskType,
      contentItems: contentItems,
      isExpanded: isExpanded,
      messageContent: messageContent,
    );
  }
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

  /// 待确认的健身计划列表（支持多计划）
  final List<WorkoutPlan> _pendingWorkoutPlans = [];

  /// 流式生成中的内容缓冲
  StringBuffer? _streamingBuffer;

  /// 是否正在应用计划
  bool _isApplyingPlan = false;

  /// 用户是否已响应计划（确认或取消）- 单个计划场景（向后兼容）
  bool _isPlanResponded = false;

  /// 计划响应结果：null=未响应, true=已确认, false=已取消 - 单个计划场景（向后兼容）
  bool? _isPlanConfirmed;

  /// 多计划场景：每个计划的响应状态映射（key: plan.id）
  final Map<String, bool> _pendingPlanResponded = {};

  /// 多计划场景：每个计划的确认状态映射（key: plan.id, value: true=已确认, false=已取消）
  final Map<String, bool> _pendingPlanConfirmed = {};

  /// 存储后端生成的计划数据库ID (messageId -> dbPlanId)
  /// 使用 messageId 作为 key，与后端 chat_generated_plans 表的 message_id 字段对应
  final Map<String, String> _messagePlanDbIds = {};

  /// 消息ID到计划ID列表的映射（实现消息与计划的一对多绑定）
  final Map<String, List<String>> _messagePlanIds = {};

  /// 当前流式响应中生成的计划ID列表（用于区分本次生成 vs 历史遗留的计划）
  final List<String> _currentStreamPlanIds = [];

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

  /// 当前执行中的 Agent 列表
  final List<AgentExecutionStatus> _activeAgents = [];

  /// Agent 展开状态映射
  final Map<String, bool> _agentExpandedStates = {};

  /// Agent 内容累积映射（用于多Agent流式输出展示）
  final Map<String, StringBuffer> _agentContentBuffers = {};

  /// 是否有 summary_sub_agent 执行（用于区分单/多任务场景）
  bool _hasSummaryAgent = false;

  /// 切换Agent展开状态
  void toggleAgentExpanded(String agentId) {
    _agentExpandedStates[agentId] = !(_agentExpandedStates[agentId] ?? true);
    notifyListeners();
  }

  // ========== Getters ==========

  /// 获取会话列表
  List<ChatSession> get sessions => List.unmodifiable(_sessions);

  /// 是否正在加载会话列表
  bool get isLoadingSessions => _isLoadingSessions;

  /// 会话列表是否为空
  bool get hasNoSessions => _sessions.isEmpty;

  /// 当前执行中的 Agent 列表
  List<AgentExecutionStatus> get activeAgents =>
      List.unmodifiable(_activeAgents);

  /// 获取用于UI展示的AgentOutput列表（过滤掉总结Agent，总结内容单独展示）
  List<AgentOutput> get agentOutputs {
    // 如果正在流式生成但没有活跃的Agent，显示默认的PlannerAgent状态
    if (_activeAgents.isEmpty && _streamStatus == ChatStreamStatus.streaming) {
      return [
        AgentOutput(
          id: 'planner_agent',
          name: 'Planner Agent',
          icon: '📋',
          status: AgentStatus.running,
          taskType: '任务规划中...',
          contentItems: [AgentContentItem.typing('正在分析需求并规划任务')],
          isExpanded: true,
        ),
      ];
    }

    // 包含活跃的 PlannerAgent 和其他子Agent（排除 summary_agent）
    final outputs = _activeAgents.where((agent) {
      // 排除 summary_agent
      if (agent.agent == 'summary_agent') return false;
      // 包含所有活跃的 Agent
      if (agent.isActive) return true;
      // 包含已完成的非 planner_agent
      if (agent.agent != 'planner_agent') return true;
      // planner_agent 只有在活跃时才显示
      return false;
    }).map((agent) {
      // 使用 taskId 作为状态键，如果没有则使用 agent 名称
      final stateKey = agent.taskId ?? agent.agent;
      final bufferKey = agent.taskId ?? agent.agent;
      return agent.toAgentOutput(
        isExpanded:
            _agentExpandedStates[stateKey] ??
            agent.isActive, // 正在运行的 Agent 默认展开
        messageContent: _agentContentBuffers[bufferKey]?.toString(),
      );
    }).toList();

    return outputs;
  }

  /// 是否需要显示 AgentAccordion（多Agent情况）
  /// 有PlannerAgent规划阶段或子Agent执行时都显示Accordion
  /// 单Agent情况（只有summary_agent）不显示Accordion
  bool get shouldShowAgentAccordion {
    // 如果有任何活跃Agent，显示Accordion
    if (_activeAgents.isNotEmpty) {
      // 过滤掉已完成的planner_agent和summary_agent后还有内容，显示Accordion
      final activeSubAgents = _activeAgents.where((a) =>
          a.isActive ||
          (a.agent != 'summary_agent' && a.agent != 'planner_agent')
      ).toList();

      if (activeSubAgents.isNotEmpty) {
        return true;
      }

      // 有planner_agent且正在流式生成（规划阶段），显示Accordion
      final hasPlannerAgent = _activeAgents.any((a) =>
          a.agent == 'planner_agent' && a.isActive
      );
      if (hasPlannerAgent && _streamStatus == ChatStreamStatus.streaming) {
        return true;
      }
    }

    return false;
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatStreamStatus get streamStatus => _streamStatus;
  bool get isStreaming => _streamStatus == ChatStreamStatus.streaming;
  bool get isIdle => _streamStatus == ChatStreamStatus.idle;

  /// 待确认的训练计划列表（支持多计划）
  List<WorkoutPlan> get pendingWorkoutPlans => List.unmodifiable(_pendingWorkoutPlans);

  /// 向后兼容：获取第一个待确认计划（单计划场景）
  WorkoutPlan? get pendingWorkoutPlan =>
      _pendingWorkoutPlans.isNotEmpty ? _pendingWorkoutPlans.first : null;

  bool get isApplyingPlan => _isApplyingPlan;

  /// 是否有待确认的计划（支持多计划）
  bool get hasPendingPlan => _pendingWorkoutPlans.isNotEmpty;

  /// 向后兼容：单个计划的响应状态
  bool get isPlanResponded => _isPlanResponded;

  /// 向后兼容：单个计划的确认状态
  bool? get isPlanConfirmed => _isPlanConfirmed;

  /// 获取指定计划的响应状态（多计划场景）
  bool isPlanRespondedById(String planId) =>
      _pendingPlanResponded[planId] ?? false;

  /// 获取指定计划的确认状态（多计划场景）
  bool? isPlanConfirmedById(String planId) =>
      _pendingPlanConfirmed.containsKey(planId)
          ? _pendingPlanConfirmed[planId]
          : null;

  /// 获取指定消息关联的训练计划列表
  List<WorkoutPlan> getPlansForMessage(String messageId) {
    final planIds = _messagePlanIds[messageId];
    if (planIds == null || planIds.isEmpty) {
      return [];
    }

    return _pendingWorkoutPlans.where((plan) => planIds.contains(plan.id)).toList();
  }

  String? get streamingMessageId => _streamingMessageId;
  String? get currentSessionId => _currentSessionId;

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

  /// 加载聊天历史（根据当前登录用户）
  /// 首次进入显示空状态，等用户发送消息或选择会话时才加载内容
  Future<void> loadHistory() async {
    // 清除当前内存中的消息，重置为"未选择会话"状态
    _messages.clear();
    _currentSessionId = null;
    _pendingWorkoutPlans.clear();
    _pendingPlanResponded.clear();
    _pendingPlanConfirmed.clear();
    _isPlanResponded = false;
    _isPlanConfirmed = null;

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

    // 恢复待确认计划列表或已响应的计划列表（多计划支持）
    final pendingPlans = await _localService.loadPendingPlans();
    // 恢复 messageId -> planDbId 映射（用于后端 API 调用）
    final savedMessagePlanDbIds = await _localService.loadMessagePlanDbIds();
    _messagePlanDbIds.addAll(savedMessagePlanDbIds);
    if (_messagePlanDbIds.isNotEmpty) {
      debugPrint('[ChatProvider] 恢复了 ${_messagePlanDbIds.length} 个 messageId -> planDbId 映射');
    }

    if (pendingPlans.isNotEmpty) {
      // 有待确认计划，状态为未响应
      _pendingWorkoutPlans.addAll(pendingPlans);
      _isPlanResponded = false;
      _isPlanConfirmed = null;
    } else {
      // 没有待确认计划，尝试加载已响应的计划
      final respondedPlans = await _localService.loadRespondedPlans();
      if (respondedPlans.isNotEmpty) {
        _pendingWorkoutPlans.addAll(respondedPlans);
        // 加载各计划的响应状态
        final planStatuses = await _localService.loadRespondedPlanStatuses();
        for (final entry in planStatuses.entries) {
          _pendingPlanResponded[entry.key] = true;
          _pendingPlanConfirmed[entry.key] = entry.value;
        }
        // 向后兼容：整体状态
        _isPlanResponded = true;
        _isPlanConfirmed = planStatuses.values.isNotEmpty
            ? planStatuses.values.first
            : null;
      } else {
        // 向后兼容：尝试加载旧的单个计划格式
        final oldPendingPlan = await _localService.loadPendingPlan();
        if (oldPendingPlan != null) {
          _pendingWorkoutPlans.add(oldPendingPlan);
          _isPlanResponded = false;
          _isPlanConfirmed = null;
          // 迁移到新格式
          await _localService.savePendingPlans(_pendingWorkoutPlans);
          await _localService.clearPendingPlan();
        } else {
          final oldRespondedPlan = await _localService.loadRespondedPlan();
          if (oldRespondedPlan != null) {
            _pendingWorkoutPlans.add(oldRespondedPlan);
            final oldConfirmed = await _localService.loadIsPlanConfirmed();
            _pendingPlanResponded[oldRespondedPlan.id] = true;
            if (oldConfirmed != null) {
              _pendingPlanConfirmed[oldRespondedPlan.id] = oldConfirmed;
            }
            _isPlanResponded = true;
            _isPlanConfirmed = oldConfirmed;
            // 迁移到新格式
            await _localService.saveRespondedPlans(
              _pendingWorkoutPlans,
              {oldRespondedPlan.id: oldConfirmed ?? false},
            );
            await _localService.clearRespondedPlan();
          }
        }
      }
    }

    // 注意：不加载历史消息到内存，保持空状态
    // 只有当用户选择某个会话时才加载该会话的消息（通过 switchSession）

    notifyListeners();
  }

  /// 清除内存中的聊天数据（登出时调用，不删除本地存储）
  void clearMemoryData() {
    _messages.clear();
    _currentSessionId = null;
    _pendingWorkoutPlans.clear();
    _pendingPlanResponded.clear();
    _pendingPlanConfirmed.clear();
    _isPlanResponded = false;
    _isPlanConfirmed = null;
    _streamingMessageId = null;
    _streamingBuffer = null;
    _streamStatus = ChatStreamStatus.idle;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    notifyListeners();
  }

  /// 从历史消息中解析待确认的训练计划
  void _parseWorkoutPlansFromMessages() {
    debugPrint('[ChatProvider] 开始解析消息中的计划，当前已有 ${_pendingWorkoutPlans.length} 个计划');
    for (final message in _messages) {
      // 从消息的 planIds 字段恢复绑定关系（新数据格式）
      if (message.planIds != null && message.planIds!.isNotEmpty) {
        _messagePlanIds[message.id] = message.planIds!;
        debugPrint('[ChatProvider] 从消息 ${message.id} 恢复计划绑定: ${message.planIds}');
      }

      if (message.type == ChatMessageType.assistant &&
          message.dataType == ChatMessageDataType.workoutPlan &&
          message.structuredData != null) {
        final data = message.structuredData!;
        debugPrint('[ChatProvider] 消息 ${message.id} structuredData keys: ${data.keys.toList()}');

        // 检查是否是多计划格式 {"plans": [...], "primary_plan": ...}
        if (data.containsKey('plans') && data['plans'] is List) {
          final plansList = data['plans'] as List<dynamic>;
          debugPrint('[ChatProvider] 消息 ${message.id} 包含多计划格式，plans数量: ${plansList.length}');
          for (final planJson in plansList) {
            try {
              final plan = WorkoutPlan.fromJson(planJson as Map<String, dynamic>);
              debugPrint('[ChatProvider] 解析到计划: ${plan.id} - ${plan.title}');
              // 只添加未完成的计划，且避免重复添加相同ID的计划
              if (!plan.isCompleted && !_pendingWorkoutPlans.any((p) => p.id == plan.id)) {
                _pendingWorkoutPlans.add(plan);
              } else if (plan.isCompleted) {
                debugPrint('[ChatProvider] 计划 ${plan.id} 已完成，跳过');
              } else {
                debugPrint('[ChatProvider] 计划 ${plan.id} 已存在，跳过重复添加');
              }
            } catch (e) {
              debugPrint('[ChatProvider] 解析计划失败: $e');
            }
          }
        }
        // 单计划格式，直接解析整个 structuredData
        else if (data.containsKey('modules')) {
          try {
            final plan = WorkoutPlan.fromJson(data);
            debugPrint('[ChatProvider] 消息 ${message.id} 单计划格式: ${plan.id} - ${plan.title}');
            // 只添加未完成的计划，且避免重复添加相同ID的计划
            if (!plan.isCompleted && !_pendingWorkoutPlans.any((p) => p.id == plan.id)) {
              _pendingWorkoutPlans.add(plan);
            } else if (plan.isCompleted) {
              debugPrint('[ChatProvider] 计划 ${plan.id} 已完成，跳过');
            } else {
              debugPrint('[ChatProvider] 计划 ${plan.id} 已存在，跳过重复添加');
            }
          } catch (e) {
            debugPrint('[ChatProvider] 解析单计划失败: $e');
          }
        }

        // 兼容旧数据：如果消息有 structuredData 但没有 planIds，从数据中恢复计划ID
        if ((message.planIds == null || message.planIds!.isEmpty) &&
            data.containsKey('id')) {
          final planId = data['id'] as String;
          _messagePlanIds[message.id] = [planId];
          debugPrint('[ChatProvider] 兼容旧数据：消息 ${message.id} 绑定计划 $planId');
        }

        // 如果解析到了计划，设置为未响应状态
        if (_pendingWorkoutPlans.isNotEmpty) {
          _isPlanResponded = false;
          _isPlanConfirmed = null;
        }
      }
    }
    debugPrint('[ChatProvider] 消息解析完成，当前共有 ${_pendingWorkoutPlans.length} 个待确认计划');
    if (_pendingWorkoutPlans.isNotEmpty) {
      debugPrint('[ChatProvider] 计划列表: ${_pendingWorkoutPlans.map((p) => '${p.id}(${p.title})').toList()}');
    }
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

    // 清理之前的 agent 状态（开始新的对话）
    _activeAgents.clear();
    _agentExpandedStates.clear();
    _agentContentBuffers.clear();
    // 重置多任务场景标志
    _hasSummaryAgent = false;

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

    // 5. 立即显示 Planner Agent（用户发送消息后立即反馈）
    _activeAgents.add(
      AgentExecutionStatus(
        agent: 'planner_agent',
        taskType: '任务分析中...',
        isActive: true,
        contentItems: [AgentContentItem.typing('正在分析需求...')],
      ),
    );
    notifyListeners();

    // 6. 开始流式生成
    await _startStreaming(userMessage.trim());
  }

  /// 开始流式生成
  Future<void> _startStreaming(String userMessage) async {
    try {
      // 清空本次流式响应的计划ID列表，避免与历史计划混淆
      _currentStreamPlanIds.clear();

      // 使用后端 SSE API
      final stream = _aiApiService.sendMessageStream(
        sessionId: _currentSessionId,
        message: userMessage,
      );

      WorkoutPlan? receivedPlan;

      await for (final chunk in stream) {
        // 只记录非chunk类型的事件，避免日志过多
        if (chunk.type != AIStreamType.chunk) {
          debugPrint('[ChatProvider] 收到事件: type=${chunk.type}, agent=${chunk.agent}');
        }
        switch (chunk.type) {
          case AIStreamType.agentStatus:
            // Agent 执行状态事件
            final agent = chunk.agent;
            final status = chunk.agentStatus;
            final taskType = chunk.taskType;
            final taskId = chunk.taskId; // 任务唯一标识

            debugPrint('[ChatProvider] Agent状态更新: agent=$agent, taskId=$taskId, status=$status, taskType=$taskType');

            if (agent != null && status != null && taskType != null) {
              // 使用 taskId 作为唯一标识，如果没有则回退到 agent 名称（兼容旧逻辑）
              final agentKey = taskId ?? agent;
              final existingIndex = _activeAgents.indexWhere(
                (a) => a.taskId == agentKey || (taskId == null && a.agent == agent),
              );

              if (status == 'started') {
                // Agent 开始执行，添加到列表
                if (existingIndex == -1) {
                  _activeAgents.add(
                    AgentExecutionStatus(
                      agent: agent,
                      taskType: taskType,
                      isActive: true,
                      contentItems: [AgentContentItem.typing('正在初始化...')],
                      taskId: agentKey,
                    ),
                  );
                } else {
                  // 已存在，更新为执行中
                  final existing = _activeAgents[existingIndex];
                  _activeAgents[existingIndex] = AgentExecutionStatus(
                    agent: agent,
                    taskType: taskType,
                    isActive: true,
                    contentItems: existing.contentItems.isEmpty
                        ? [AgentContentItem.typing('正在处理...')]
                        : existing.contentItems,
                    taskId: existing.taskId ?? agentKey,
                  );
                }

                // 第一个子 Agent 开始执行时，标记 PlannerAgent 为完成
                if (agent != 'planner_agent' && agent != 'summary_agent') {
                  final plannerIndex = _activeAgents.indexWhere((a) => a.agent == 'planner_agent');
                  if (plannerIndex != -1 && _activeAgents[plannerIndex].isActive) {
                    _activeAgents[plannerIndex] = _activeAgents[plannerIndex]
                        .copyWithCompleted()
                        .addContentItem(AgentContentItem.success('规划完成'));
                  }
                }

                // 检测是否有 summary_sub_agent 参与（多任务场景）
                if (agent == 'summary_sub_agent') {
                  _hasSummaryAgent = true;
                  debugPrint('[ChatProvider] 检测到多任务场景，将只显示 summary_sub_agent 的输出');
                }
              } else if (status == 'completed') {
                // Agent 执行完成，标记为已完成（不删除，保持显示）
                if (existingIndex != -1) {
                  final completed = _activeAgents[existingIndex]
                      .copyWithCompleted();
                  _activeAgents[existingIndex] = completed.addContentItem(
                    AgentContentItem.success('任务执行完成'),
                  );
                  // 自动收起该Agent（使用 taskId 作为状态键）
                  final stateKey = _activeAgents[existingIndex].taskId ?? agent;
                  _agentExpandedStates[stateKey] = false;
                } else {
                  // 如果不存在，直接添加为已完成状态（收起）
                  _activeAgents.add(
                    AgentExecutionStatus(
                      agent: agent,
                      taskType: taskType,
                      isActive: false,
                      contentItems: [AgentContentItem.success('任务执行完成')],
                      taskId: agentKey,
                    ),
                  );
                  // 自动收起该Agent
                  _agentExpandedStates[agentKey] = false;
                }

                // 检查是否所有子Agent都已完成，如果是，添加总结Agent
                final hasActiveSubAgents = _activeAgents.any(
                  (a) =>
                      a.isActive &&
                      a.agent != 'planner_agent' &&
                      a.agent != 'summary_agent',
                );
                if (!hasActiveSubAgents &&
                    !_activeAgents.any((a) => a.agent == 'summary_agent')) {
                  // 添加总结Agent
                  _activeAgents.add(
                    AgentExecutionStatus(
                      agent: 'summary_agent',
                      taskType: '总结输出',
                      isActive: true,
                      contentItems: [AgentContentItem.typing('正在生成最终回复...')],
                    ),
                  );
                }
              }
              notifyListeners();
            }
            break;

          case AIStreamType.analysis:
            // PlannerAgent 任务分析阶段 - 显示规划中的提示
            debugPrint('[ChatProvider] ====== 收到任务分析事件 ======');
            debugPrint('[ChatProvider] chunk.type = ${chunk.type}');
            debugPrint('[ChatProvider] chunk.analysis = ${chunk.analysis}');
            final plannerIndex = _activeAgents.indexWhere((a) => a.agent == 'planner_agent');
            debugPrint('[ChatProvider] plannerIndex = $plannerIndex');
            final analysis = chunk.analysis;
            final complexity = analysis?['complexity'] as String?;
            final requiresPlanning = analysis?['requires_planning'] as bool? ?? false;
            debugPrint('[ChatProvider] complexity = $complexity, requiresPlanning = $requiresPlanning');

            if (plannerIndex == -1) {
              // 理论上不会走到这里，因为发送消息时已创建 PlannerAgent
              debugPrint('[ChatProvider] 添加新的 PlannerAgent（容错）');
              _activeAgents.add(
                AgentExecutionStatus(
                  agent: 'planner_agent',
                  taskType: requiresPlanning ? '复杂任务分析中...' : '任务分析中...',
                  isActive: true,
                  contentItems: [
                    AgentContentItem.text('识别意图: ${analysis?['primary_intent'] ?? '分析中'}'),
                    if (complexity != null) AgentContentItem.text('任务复杂度: $complexity'),
                    AgentContentItem.typing('正在规划执行方案'),
                  ],
                ),
              );
            } else {
              // 更新 PlannerAgent 内容
              debugPrint('[ChatProvider] 更新已有的 PlannerAgent');
              final existing = _activeAgents[plannerIndex];
              _activeAgents[plannerIndex] = existing.addContentItem(
                AgentContentItem.text('分析完成，识别意图: ${analysis?['primary_intent'] ?? '未知'}'),
              );
            }
            debugPrint('[ChatProvider] 通知UI更新，_activeAgents.length = ${_activeAgents.length}');
            notifyListeners();
            break;

          case AIStreamType.planInfo:
            // PlannerAgent 任务规划阶段 - 显示执行计划
            debugPrint('[ChatProvider] ====== 收到任务规划事件 ======');
            debugPrint('[ChatProvider] chunk.type = ${chunk.type}');
            debugPrint('[ChatProvider] executionOrder = ${chunk.executionOrder}');
            debugPrint('[ChatProvider] parallelGroups = ${chunk.parallelGroups}');
            final plannerIndex = _activeAgents.indexWhere((a) => a.agent == 'planner_agent');
            debugPrint('[ChatProvider] plannerIndex = $plannerIndex');
            final executionOrder = chunk.executionOrder;
            final parallelGroups = chunk.parallelGroups;

            if (plannerIndex != -1) {
              final existing = _activeAgents[plannerIndex];
              final newContentItems = [
                ...existing.contentItems.where((item) => item.type != AgentContentType.typing),
                AgentContentItem.success('任务规划完成'),
              ];

              // 添加执行计划信息
              if (executionOrder != null && executionOrder.isNotEmpty) {
                newContentItems.add(
                  AgentContentItem.text('执行顺序: ${executionOrder.join(' → ')}'),
                );
              }
              if (parallelGroups != null && parallelGroups.isNotEmpty) {
                final parallelInfo = parallelGroups.map((g) => (g as List).join(',')).join(' | ');
                newContentItems.add(
                  AgentContentItem.text('并行执行组: $parallelInfo'),
                );
              }

              _activeAgents[plannerIndex] = AgentExecutionStatus(
                agent: existing.agent,
                taskType: '任务规划完成，开始执行...',
                isActive: true,
                contentItems: newContentItems,
              );
            }
            notifyListeners();
            break;

          case AIStreamType.chunk:
            // 文本流块 - 根据是否为多任务场景决定是否累积到消息buffer
            if (chunk.content != null) {
              final agentId = chunk.agent;
              final taskId = chunk.taskId; // 任务唯一标识

              // 判断是否应该将内容写入 streamingBuffer（消息正文）
              // 1. 单任务场景（没有 summary_agent）：所有内容都写入
              // 2. 多任务场景：只有 summary_sub_agent 的内容写入
              final shouldWriteToBuffer = !_hasSummaryAgent || (agentId == 'summary_sub_agent');

              if (shouldWriteToBuffer) {
                _streamingBuffer!.write(chunk.content);
              }

              // 将内容添加到对应Agent的contentItems中（用于AgentAccordion显示）
              // 优先使用 taskId 查找，如果没有则使用 agent 名称（兼容旧逻辑）
              if (agentId != null && agentId.isNotEmpty) {
                final agentIndex = _activeAgents.indexWhere(
                  (a) => (taskId != null && a.taskId == taskId) || (taskId == null && a.agent == agentId),
                );
                if (agentIndex != -1) {
                  _activeAgents[agentIndex] = _activeAgents[agentIndex].appendTextContent(chunk.content!);
                }
              }

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
            // 收到训练计划（支持多计划）
            final plan = chunk.plan;
            debugPrint('[ChatProvider] ====== 收到训练计划事件 ======');
            debugPrint('[ChatProvider] planIndex: ${chunk.planIndex}, totalPlans: ${chunk.totalPlans}');
            debugPrint('[ChatProvider] plan.id: ${plan?.id}, plan.title: ${plan?.title}');
            if (plan != null) {
              receivedPlan = plan;
              // 记录本次流式响应生成的计划ID（用于消息绑定）
              if (!_currentStreamPlanIds.contains(plan.id)) {
                _currentStreamPlanIds.add(plan.id);
                debugPrint('[ChatProvider] 记录本次流式计划ID: ${plan.id}, 当前流式计划列表: $_currentStreamPlanIds');
              }
              // 添加到计划列表（避免重复）
              final existingIndex = _pendingWorkoutPlans.indexWhere(
                (p) => p.id == plan.id,
              );
              if (existingIndex >= 0) {
                // 更新已存在的计划
                debugPrint('[ChatProvider] 更新已存在的计划: ${plan.id}');
                _pendingWorkoutPlans[existingIndex] = plan;
              } else {
                // 添加新计划
                debugPrint('[ChatProvider] 添加新计划: ${plan.id}, 当前列表长度: ${_pendingWorkoutPlans.length}');
                _pendingWorkoutPlans.add(plan);
              }
              debugPrint('[ChatProvider] 当前待确认计划总数: ${_pendingWorkoutPlans.length}');
              debugPrint('[ChatProvider] 计划列表IDs: ${_pendingWorkoutPlans.map((p) => p.id).toList()}');
              // 初始化该计划的响应状态
              _pendingPlanResponded[plan.id] = false;
              _pendingPlanConfirmed.remove(plan.id);
              // 向后兼容：单个计划状态
              _isPlanResponded = false;
              _isPlanConfirmed = null;
              // 保存计划列表到本地（不等待）
              _localService.savePendingPlans(_pendingWorkoutPlans);
              // 记录 messageId 到 planId 的映射，用于后续确认/拒绝
              if (chunk.messageId != null && chunk.planId != null) {
                _messagePlanDbIds[chunk.messageId!] = chunk.planId!;
                // 持久化映射到本地存储，确保应用重启后仍能调用后端 API
                _localService.saveMessagePlanDbIds(Map<String, String>.from(_messagePlanDbIds));
                debugPrint('[ChatProvider] 记录 planId 映射: messageId=${chunk.messageId}, planId=${chunk.planId}');
              }
              // 通知UI更新显示计划预览
              notifyListeners();
            }
            break;

          case AIStreamType.done:
            // 完成，传递后端返回的消息ID和最终内容（summary_sub_agent的输出）
            await _handleStreamDone(
              receivedPlan,
              backendMessageId: chunk.messageId,
              finalContent: chunk.content,
            );
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
    _throttleTimer = Timer(const Duration(milliseconds: 8), () {
      // 只有在流式状态且消息ID有效时才更新
      if (_streamStatus != ChatStreamStatus.streaming ||
          _streamingMessageId == null) {
        return;
      }
      final index = _messages.indexWhere(
        (msg) => msg.id == _streamingMessageId,
      );
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
      }
      // 通知UI更新（包括AgentAccordion）
      notifyListeners();
    });
  }

  /// 处理流式完成
  Future<void> _handleStreamDone(WorkoutPlan? plan, {String? backendMessageId, String? finalContent}) async {
    _throttleTimer?.cancel();
    _streamStatus = ChatStreamStatus.completed;

    // 优先使用后端返回的 finalContent（summary_sub_agent 的输出），否则使用 buffer 内容
    final responseContent = finalContent ?? _streamingBuffer.toString();

    if (responseContent.trim().isEmpty && plan == null) {
      // 空响应
      _updateMessageWithError('AI 未返回任何内容，请稍后重试');
      _streamStatus = ChatStreamStatus.error;
    } else {
      // 构建 AgentOutput 列表（排除 summary_agent，因为它的内容就是最终回复）
      final agentOutputs = _activeAgents
          .where((agent) => agent.agent != 'summary_agent')
          .map((agent) {
                // 使用 taskId 作为状态键，如果没有则使用 agent 名称
                final stateKey = agent.taskId ?? agent.agent;
                final bufferKey = agent.taskId ?? agent.agent;
                return agent.toAgentOutput(
                  isExpanded: _agentExpandedStates[stateKey] ?? false,
                  messageContent: _agentContentBuffers[bufferKey]?.toString(),
                );
              })
          .toList();

      // 收集当前批次生成的所有计划ID（使用 _currentStreamPlanIds 确保只包含本次流式响应生成的计划）
      final currentPlanIds = List<String>.from(_currentStreamPlanIds);
      debugPrint('[ChatProvider] 流式完成，本次生成的计划IDs: $currentPlanIds');
      debugPrint('[ChatProvider] _pendingWorkoutPlans 中所有计划IDs: ${_pendingWorkoutPlans.map((p) => p.id).toList()}');

      // 确定消息ID（优先使用后端返回的ID）
      final messageId = backendMessageId ?? DateTime.now().millisecondsSinceEpoch.toString();

      // 更新消息 - 包含 Agent 输出和计划ID绑定
      _updateMessage(
        ChatMessage.withAgentOutputs(
          id: messageId,
          content: responseContent,
          agentOutputs: agentOutputs,
          workoutPlanJson: plan?.toJson(),
          planIds: currentPlanIds.isNotEmpty ? currentPlanIds : null,
        ),
      );

      // 记录消息与计划的绑定关系
      if (currentPlanIds.isNotEmpty) {
        _messagePlanIds[messageId] = currentPlanIds;
        debugPrint('[ChatProvider] 消息 $messageId 绑定了计划: $currentPlanIds');
      }

      // 关键：如果后端返回了消息ID且与当前ID不同，更新为后端ID
      if (backendMessageId != null && backendMessageId != messageId) {
        _updateMessageId(backendMessageId);
      }
    }

    // 保存到本地（用户数据隔离）
    if (_messages.isNotEmpty) {
      final userId = await UserDataHelper.getCurrentUserId();
      if (userId != null && userId.isNotEmpty) {
        await _localService.saveMessage(_messages.last);

        // 同时保存 agent_outputs 到后端
        final lastMessage = _messages.last;
        if (lastMessage.agentOutputs != null &&
            lastMessage.agentOutputs!.isNotEmpty &&
            _currentSessionId != null) {
          try {
            // 使用后端返回的消息ID（优先）或当前消息ID
            final messageId = backendMessageId ?? lastMessage.id;
            await _sessionApiService.updateMessageAgentOutputs(
              _currentSessionId!,
              messageId,
              lastMessage.agentOutputs!.map((e) => e.toJson()).toList(),
            );
            debugPrint('[ChatProvider] 成功保存 agent_outputs 到后端，消息ID: $messageId');
          } catch (e) {
            debugPrint('[ChatProvider] 保存 agent_outputs 到后端失败: $e');
          }
        }
      }
    }

    // 清空 Agent 状态（内容已保存到消息中）
    _activeAgents.clear();
    _agentExpandedStates.clear();
    _agentContentBuffers.clear();

    // 重置多任务场景标志
    _hasSummaryAgent = false;

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
    final userMessages = _messages
        .where((m) => m.type == ChatMessageType.user)
        .toList();
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

    _updateMessageWithError('⚠️ **连接错误**\n\n$error\n\n💡 **建议**: 请检查网络连接或稍后重试');

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
      final index = _messages.indexWhere(
        (msg) => msg.id == _streamingMessageId,
      );
      if (index != -1) {
        _messages[index] = newMessage;
      }
    }
  }

  /// 更新当前流式消息的ID（用于同步后端UUID）
  void _updateMessageId(String newId) {
    if (_streamingMessageId != null) {
      final index = _messages.indexWhere(
        (msg) => msg.id == _streamingMessageId,
      );
      if (index != -1) {
        final oldMessage = _messages[index];
        // 创建新消息对象，使用新的ID但保留其他所有字段
        _messages[index] = ChatMessage(
          id: newId,  // 新的后端ID
          type: oldMessage.type,
          content: oldMessage.content,
          timestamp: oldMessage.timestamp,
          structuredData: oldMessage.structuredData,
          dataType: oldMessage.dataType,
          sessionId: oldMessage.sessionId,
          agentOutputs: oldMessage.agentOutputs,
        );
        // 更新流式消息ID跟踪
        _streamingMessageId = newId;
        debugPrint('[ChatProvider] 消息ID已更新为后端UUID: $newId');
      }
    }
  }

  /// 更新当前流式消息为错误信息
  void _updateMessageWithError(String errorContent) {
    if (_streamingMessageId != null) {
      final index = _messages.indexWhere(
        (msg) => msg.id == _streamingMessageId,
      );
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
  /// 注意：不清理 _activeAgents 和 _agentContentBuffers，保持显示所有 agent 的状态和内容
  void _resetStreamingState() {
    _streamingMessageId = null;
    _streamingBuffer = null;
    _streamStatus = ChatStreamStatus.idle;
    // 注意：不清理 _activeAgents，保留作为会话历史的一部分显示
  }

  /// 清除所有 Agent 状态和内容（用于对话结束后清理）
  void clearAgentStates() {
    _activeAgents.clear();
    _agentExpandedStates.clear();
    _agentContentBuffers.clear();
    notifyListeners();
  }

  /// 取消流式请求
  Future<void> _cancelStream() async {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _resetStreamingState();
    // 重置多任务场景标志
    _hasSummaryAgent = false;
  }

  // ========== 健身计划管理 ==========

  /// 应用健身计划
  /// [plan] 训练计划
  /// [messageId] 关联的消息ID，用于与后端数据库关联
  /// 返回是否成功应用计划
  Future<bool> applyWorkoutPlan(WorkoutPlan plan, {String? messageId}) async {
    _isApplyingPlan = true;
    notifyListeners();

    // 检查用户是否已登录（用户数据隔离）
    final userId = await UserDataHelper.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      _isApplyingPlan = false;
      notifyListeners();
      debugPrint('[ChatProvider] 用户未登录，无法应用计划');
      return false;
    }

    try {
      // 保存到本地缓存（使用用户隔离的key）
      final today = DateTime.now();
      final dateKey = 'workout_cache_${today.year}-${today.month}-${today.day}';
      await UserDataHelper.setString(dateKey, jsonEncode(plan.toJson()));

      // 标记该计划已确认（多计划场景）
      _pendingPlanResponded[plan.id] = true;
      _pendingPlanConfirmed[plan.id] = true;

      // 更新后端响应状态（使用 messageId 获取数据库ID）
      String? workoutPlanId;
      if (messageId != null) {
        final planDbId = _messagePlanDbIds[messageId];
        if (planDbId != null) {
          try {
            final result = await _sessionApiService.updateGeneratedPlanResponse(planDbId, 'confirmed');
            workoutPlanId = result['applied_plan_id'] as String?;
            debugPrint('[ChatProvider] 后端计划状态已更新为 confirmed, messageId: $messageId, workoutPlanId: $workoutPlanId');

            // 调用后端 API 将计划应用到用户（保存到 workout_plan 表）
            if (workoutPlanId != null) {
              try {
                final workoutApiService = WorkoutApiService();
                await workoutApiService.applyPlan(workoutPlanId);
                debugPrint('[ChatProvider] 计划已成功应用到用户: $workoutPlanId');
              } catch (e) {
                debugPrint('[ChatProvider] 应用计划到后端失败: $e');
                // 继续执行，不阻止本地流程
              }
            }
          } catch (e) {
            debugPrint('[ChatProvider] 更新后端计划状态失败: $e');
          }
          // 删除已使用的映射（无论成功与否，都清理本地映射）
          _messagePlanDbIds.remove(messageId);
          await _localService.saveMessagePlanDbIds(Map<String, String>.from(_messagePlanDbIds));
        }
      }

      // 检查是否所有计划都已响应
      final allResponded = _pendingWorkoutPlans.every(
        (p) => _pendingPlanResponded[p.id] == true,
      );
      if (allResponded) {
        _isPlanResponded = true;
        _isPlanConfirmed = true;
        await _localService.clearPendingPlans();
        // 清除所有映射（所有计划都已处理完毕）
        _messagePlanDbIds.clear();
        await _localService.clearMessagePlanDbIds();
        // 保存已响应的计划列表
        final statusMap = <String, bool>{};
        for (final p in _pendingWorkoutPlans) {
          statusMap[p.id] = _pendingPlanConfirmed[p.id] ?? false;
        }
        await _localService.saveRespondedPlans(_pendingWorkoutPlans, statusMap);
      } else {
        // 部分计划已响应，更新存储
        await _localService.savePendingPlans(
          _pendingWorkoutPlans.where((p) => _pendingPlanResponded[p.id] != true).toList(),
        );
      }
      _isApplyingPlan = false;

      notifyListeners();
      return true;
    } catch (e) {
      _isApplyingPlan = false;

      final errorMessage = ChatMessage.assistant(
        '❌ 应用计划失败: $e\n\n请稍后重试或在"今日"页面手动刷新计划。',
      );
      _messages.add(errorMessage);
      await _localService.saveMessage(errorMessage);

      notifyListeners();
      return false;
    }
  }

  /// 拒绝指定ID的健身计划（多计划场景）
  /// [planId] 计划ID
  /// [messageId] 关联的消息ID，用于与后端数据库关联
  Future<void> rejectWorkoutPlanById(String planId, {String? messageId}) async {
    // 标记该计划已拒绝
    _pendingPlanResponded[planId] = true;
    _pendingPlanConfirmed[planId] = false;

    // 更新后端响应状态（使用 messageId 获取数据库ID）
    if (messageId != null) {
      final planDbId = _messagePlanDbIds[messageId];
      if (planDbId != null) {
        try {
          await _sessionApiService.updateGeneratedPlanResponse(planDbId, 'rejected');
          debugPrint('[ChatProvider] 后端计划状态已更新为 rejected, messageId: $messageId');
        } catch (e) {
          debugPrint('[ChatProvider] 更新后端计划状态失败: $e');
        }
        // 删除已使用的映射（无论成功与否，都清理本地映射）
        _messagePlanDbIds.remove(messageId);
        await _localService.saveMessagePlanDbIds(Map<String, String>.from(_messagePlanDbIds));
      }
    }

    // 检查是否所有计划都已响应
    final allResponded = _pendingWorkoutPlans.every(
      (p) => _pendingPlanResponded[p.id] == true,
    );
    if (allResponded) {
      _isPlanResponded = true;
      _isPlanConfirmed = false;
      await _localService.clearPendingPlans();
      // 清除所有映射（所有计划都已处理完毕）
      _messagePlanDbIds.clear();
      await _localService.clearMessagePlanDbIds();
      // 保存已响应的计划列表
      final respondedPlans = _pendingWorkoutPlans.where(
        (p) => _pendingPlanResponded[p.id] == true,
      ).toList();
      final statusMap = <String, bool>{};
      for (final p in respondedPlans) {
        statusMap[p.id] = _pendingPlanConfirmed[p.id] ?? false;
      }
      await _localService.saveRespondedPlans(respondedPlans, statusMap);
    } else {
      // 部分计划已响应，更新存储
      await _localService.savePendingPlans(
        _pendingWorkoutPlans.where((p) => _pendingPlanResponded[p.id] != true).toList(),
      );
    }

    notifyListeners();
  }

  /// 拒绝健身计划（向后兼容：拒绝所有未响应的计划）
  Future<void> rejectWorkoutPlan() async {
    // 标记所有未响应的计划为已拒绝
    for (final plan in _pendingWorkoutPlans) {
      if (_pendingPlanResponded[plan.id] != true) {
        _pendingPlanResponded[plan.id] = true;
        _pendingPlanConfirmed[plan.id] = false;
      }
    }
    _isPlanResponded = true;
    _isPlanConfirmed = false;

    await _localService.clearPendingPlans();
    // 清除所有映射（所有计划都已处理完毕）
    _messagePlanDbIds.clear();
    await _localService.clearMessagePlanDbIds();
    // 保存已响应的计划列表
    final statusMap = <String, bool>{};
    for (final plan in _pendingWorkoutPlans) {
      statusMap[plan.id] = _pendingPlanConfirmed[plan.id] ?? false;
    }
    await _localService.saveRespondedPlans(_pendingWorkoutPlans, statusMap);

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
    _pendingWorkoutPlans.clear();
    _pendingPlanResponded.clear();
    _pendingPlanConfirmed.clear();
    _isPlanResponded = false;
    _isPlanConfirmed = null;
    _currentSessionId = null;
    _addWelcomeMessage();

    // 清除本地存储的计划（新旧格式都清除）
    await _localService.clearPendingPlans();
    await _localService.clearRespondedPlans();
    await _localService.clearPlanStatuses();
    // 向后兼容：清除旧格式
    await _localService.clearPendingPlan();
    await _localService.clearRespondedPlan();
    // 清除 messageId -> planDbId 映射
    _messagePlanDbIds.clear();
    await _localService.clearMessagePlanDbIds();

    // 清除Agent状态
    _activeAgents.clear();
    _agentExpandedStates.clear();
    _agentContentBuffers.clear();

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
      _pendingWorkoutPlans.clear();
      _pendingPlanResponded.clear();
      _pendingPlanConfirmed.clear();
      _isPlanResponded = false;
      _isPlanConfirmed = null;

      // 清除已响应的计划（新会话不应该有之前的计划）
      await _localService.clearRespondedPlans();

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
    _pendingWorkoutPlans.clear();
    _pendingPlanResponded.clear();
    _pendingPlanConfirmed.clear();
    _messagePlanIds.clear();
    _messagePlanDbIds.clear();

    // 恢复待确认计划列表或已响应的计划列表（多计划支持）
    final pendingPlans = await _localService.loadPendingPlans();

    // 恢复 messageId -> planDbId 映射（用于后端 API 调用）
    final savedMessagePlanDbIds = await _localService.loadMessagePlanDbIds();
    _messagePlanDbIds.addAll(savedMessagePlanDbIds);
    if (_messagePlanDbIds.isNotEmpty) {
      debugPrint('[ChatProvider] 恢复了 ${_messagePlanDbIds.length} 个 messageId -> planDbId 映射');
    }
    if (pendingPlans.isNotEmpty) {
      _pendingWorkoutPlans.addAll(pendingPlans);
      _isPlanResponded = false;
      _isPlanConfirmed = null;
    } else {
      final respondedPlans = await _localService.loadRespondedPlans();
      if (respondedPlans.isNotEmpty) {
        _pendingWorkoutPlans.addAll(respondedPlans);
        final planStatuses = await _localService.loadRespondedPlanStatuses();
        for (final entry in planStatuses.entries) {
          _pendingPlanResponded[entry.key] = true;
          _pendingPlanConfirmed[entry.key] = entry.value;
        }
        _isPlanResponded = true;
        _isPlanConfirmed = planStatuses.values.isNotEmpty
            ? planStatuses.values.first
            : null;
      }
    }

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

      // 按时间戳排序，确保老消息在前，新消息在后
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _messages.addAll(messages);

      // 从历史消息中解析待确认的训练计划
      _parseWorkoutPlansFromMessages();

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
      final updated = await _sessionApiService.renameSession(
        sessionId,
        newTitle,
      );
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

  /// 批量删除会话
  Future<void> deleteSessions(List<String> sessionIds) async {
    for (final id in sessionIds) {
      await deleteSession(id);
    }
    notifyListeners();
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
    if (_streamStatus == ChatStreamStatus.streaming &&
        _streamingBuffer != null) {
      _wasStreamingWhenPaused = true;
      final currentContent = _streamingBuffer.toString();
      if (currentContent.isNotEmpty) {
        _pausedStreamingContent = currentContent;
        _pausedMessageId = _streamingMessageId;
        debugPrint(
          '[ChatProvider] 保存流式内容长度: ${currentContent.length}, messageId: $_pausedMessageId',
        );
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
      debugPrint(
        '[ChatProvider] 检测到中断的流式生成，内容长度: ${_pausedStreamingContent!.length}',
      );

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
      final index = _messages.indexWhere(
        (msg) => msg.id == _streamingMessageId,
      );
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
