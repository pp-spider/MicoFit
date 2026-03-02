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

  AgentExecutionStatus({
    required this.agent,
    required this.taskType,
    required this.isActive,
    this.contentItems = const [],
  });

  /// 创建已完成状态
  AgentExecutionStatus copyWithCompleted() {
    return AgentExecutionStatus(
      agent: agent,
      taskType: taskType,
      isActive: false,
      contentItems: contentItems,
    );
  }

  /// 添加内容项
  AgentExecutionStatus addContentItem(AgentContentItem item) {
    return AgentExecutionStatus(
      agent: agent,
      taskType: taskType,
      isActive: isActive,
      contentItems: [...contentItems, item],
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
      );
    } else {
      // 添加新的 text 内容项
      return addContentItem(AgentContentItem.text(text));
    }
  }

  /// 转换为AgentOutput（用于UI展示）
  AgentOutput toAgentOutput({bool isExpanded = false, String? messageContent}) {
    return AgentOutput(
      id: agent,
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

  /// 待确认的健身计划
  WorkoutPlan? _pendingWorkoutPlan;

  /// 流式生成中的内容缓冲
  StringBuffer? _streamingBuffer;

  /// 是否正在应用计划
  bool _isApplyingPlan = false;

  /// 用户是否已响应计划（确认或取消）
  bool _isPlanResponded = false;

  /// 计划响应结果：null=未响应, true=已确认, false=已取消
  bool? _isPlanConfirmed;

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

  /// 总结 Agent 的内容（最终输出）- 保留用于兼容性
  StringBuffer? _summaryContentBuffer;

  /// 是否正在等待总结 - 保留用于兼容性
  bool _isWaitingForSummary = false;

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
      return agent.toAgentOutput(
        isExpanded:
            _agentExpandedStates[agent.agent] ??
            agent.isActive, // 正在运行的 Agent 默认展开
        messageContent: _agentContentBuffers[agent.agent]?.toString(),
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
  WorkoutPlan? get pendingWorkoutPlan => _pendingWorkoutPlan;
  bool get isApplyingPlan => _isApplyingPlan;
  bool get hasPendingPlan => _pendingWorkoutPlan != null;
  bool get isPlanResponded => _isPlanResponded;
  bool? get isPlanConfirmed => _isPlanConfirmed;
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
    _pendingWorkoutPlan = null;
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

    // 恢复待确认计划或已响应的计划
    _pendingWorkoutPlan = await _localService.loadPendingPlan();
    if (_pendingWorkoutPlan != null) {
      // 有待确认计划，状态为未响应
      _isPlanResponded = false;
      _isPlanConfirmed = null;
    } else {
      // 没有待确认计划，尝试加载已响应的计划
      _pendingWorkoutPlan = await _localService.loadRespondedPlan();
      if (_pendingWorkoutPlan != null) {
        // 有已响应的计划，恢复响应状态
        _isPlanResponded = true;
        _isPlanConfirmed = await _localService.loadIsPlanConfirmed();
      } else {
        // 没有任何计划
        _isPlanResponded = false;
        _isPlanConfirmed = null;
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
    _pendingWorkoutPlan = null;
    _isPlanResponded = false;
    _isPlanConfirmed = null;
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

    // 清理之前的 agent 状态（开始新的对话）
    _activeAgents.clear();
    _agentExpandedStates.clear();
    _agentContentBuffers.clear();
    _summaryContentBuffer = null;
    _isWaitingForSummary = false;

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

            debugPrint('[ChatProvider] Agent状态更新: agent=$agent, status=$status, taskType=$taskType');

            if (agent != null && status != null && taskType != null) {
              final existingIndex = _activeAgents.indexWhere(
                (a) => a.agent == agent,
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
              } else if (status == 'completed') {
                // Agent 执行完成，标记为已完成（不删除，保持显示）
                if (existingIndex != -1) {
                  final completed = _activeAgents[existingIndex]
                      .copyWithCompleted();
                  _activeAgents[existingIndex] = completed.addContentItem(
                    AgentContentItem.success('任务执行完成'),
                  );
                  // 自动收起该Agent
                  _agentExpandedStates[agent] = false;
                } else {
                  // 如果不存在，直接添加为已完成状态（收起）
                  _activeAgents.add(
                    AgentExecutionStatus(
                      agent: agent,
                      taskType: taskType,
                      isActive: false,
                      contentItems: [AgentContentItem.success('任务执行完成')],
                    ),
                  );
                  // 自动收起该Agent
                  _agentExpandedStates[agent] = false;
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
                  _isWaitingForSummary = true;
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
            // 文本流块 - 累积到消息buffer流式显示，同时添加到对应Agent的contentItems
            if (chunk.content != null) {
              _streamingBuffer!.write(chunk.content);

              // 将内容添加到对应Agent的contentItems中
              final agentId = chunk.agent;
              if (agentId != null && agentId.isNotEmpty) {
                final agentIndex = _activeAgents.indexWhere((a) => a.agent == agentId);
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
            // 收到训练计划
            final plan = chunk.plan;
            if (plan != null) {
              receivedPlan = plan;
              _pendingWorkoutPlan = plan;
              // 重置计划响应状态（新计划应该是未响应状态）
              _isPlanResponded = false;
              _isPlanConfirmed = null;
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
        _updateMessage(
          ChatMessage.withWorkoutPlan(
            content: responseContent,
            workoutPlanJson: plan.toJson(),
          ),
        );
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

    // 标记总结Agent为完成
    final summaryIndex = _activeAgents.indexWhere(
      (a) => a.agent == 'summary_agent',
    );
    if (summaryIndex != -1) {
      _activeAgents[summaryIndex] = _activeAgents[summaryIndex]
          .copyWithCompleted()
          .addContentItem(AgentContentItem.success('总结完成'));
    }
    _isWaitingForSummary = false;

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
    _summaryContentBuffer = null;
    _isWaitingForSummary = false;
    notifyListeners();
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
      await UserDataHelper.setString(dateKey, jsonEncode(plan.toJson()));

      // 标记计划已响应（保留计划在UI上显示）
      _isPlanResponded = true;
      _isPlanConfirmed = true;
      await _localService.clearPendingPlan();
      // 保存已响应的计划到本地，以便重启后恢复
      await _localService.saveRespondedPlan(plan, true);
      _isApplyingPlan = false;

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
    // 标记计划已响应（保留计划在UI上显示）
    _isPlanResponded = true;
    _isPlanConfirmed = false;
    await _localService.clearPendingPlan();
    // 保存已响应的计划到本地，以便重启后恢复
    if (_pendingWorkoutPlan != null) {
      await _localService.saveRespondedPlan(_pendingWorkoutPlan!, false);
    }

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
    _isPlanResponded = false;
    _isPlanConfirmed = null;
    _currentSessionId = null;
    _addWelcomeMessage();

    // 清除本地存储的计划
    await _localService.clearPendingPlan();
    await _localService.clearRespondedPlan();

    // 清除Agent状态
    _activeAgents.clear();
    _agentExpandedStates.clear();
    _agentContentBuffers.clear();
    _summaryContentBuffer = null;
    _isWaitingForSummary = false;

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
      _isPlanResponded = false;
      _isPlanConfirmed = null;

      // 清除已响应的计划（新会话不应该有之前的计划）
      await _localService.clearRespondedPlan();

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

    // 恢复待确认计划或已响应的计划
    _pendingWorkoutPlan = await _localService.loadPendingPlan();
    if (_pendingWorkoutPlan != null) {
      // 有待确认计划，状态为未响应
      _isPlanResponded = false;
      _isPlanConfirmed = null;
    } else {
      // 没有待确认计划，尝试加载已响应的计划
      _pendingWorkoutPlan = await _localService.loadRespondedPlan();
      if (_pendingWorkoutPlan != null) {
        // 有已响应的计划，恢复响应状态
        _isPlanResponded = true;
        _isPlanConfirmed = await _localService.loadIsPlanConfirmed();
      } else {
        // 没有任何计划
        _isPlanResponded = false;
        _isPlanConfirmed = null;
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
