import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/agent_output.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/agent_accordion.dart';
import '../providers/chat_provider.dart';
import '../services/network_service.dart';
import 'chat_sessions_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// AI聊天页面 - 精致美观设计
class AiChatPage extends StatefulWidget {
  final Function(String) onNavigate;

  const AiChatPage({super.key, required this.onNavigate});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

/// 快捷提示数据类
class _QuickPrompt {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;

  _QuickPrompt({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });
}

class _AiChatPageState extends State<AiChatPage> with TickerProviderStateMixin {
  // 输入控制器
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // 动画控制器
  late AnimationController _pulseController;
  late AnimationController _slideController;

  // Provider 引用（用于在 dispose 中移除监听器，避免在 dispose 中访问 context）
  ChatProvider? _chatProvider;

  // 跟踪已展开的训练计划卡片 (使用计划ID或消息索引)
  final Set<String> _expandedPlanCards = {};

  // Markdown 样式表缓存（避免重复创建）
  static final MarkdownStyleSheet
  _cachedMarkdownStyleSheet = MarkdownStyleSheet(
    p: TextStyle(
      color: const Color(0xFF1F2937),
      fontSize: 15,
      height: 1.5,
      fontFamily: null,
    ),
    h1: TextStyle(
      color: const Color(0xFF1F2937),
      fontSize: 24,
      fontWeight: FontWeight.bold,
      height: 1.3,
      fontFamily: null,
    ),
    h2: TextStyle(
      color: const Color(0xFF1F2937),
      fontSize: 20,
      fontWeight: FontWeight.bold,
      height: 1.3,
      fontFamily: null,
    ),
    h3: TextStyle(
      color: const Color(0xFF1F2937),
      fontSize: 18,
      fontWeight: FontWeight.bold,
      height: 1.3,
      fontFamily: null,
    ),
    h4: TextStyle(
      color: const Color(0xFF1F2937),
      fontSize: 16,
      fontWeight: FontWeight.bold,
      height: 1.3,
      fontFamily: null,
    ),
    listBullet: TextStyle(
      color: const Color(0xFF2DD4BF),
      fontSize: 15,
      fontFamily: null,
    ),
    listBulletPadding: const EdgeInsets.only(left: 4),
    code: TextStyle(
      color: const Color(0xFF1F2937),
      backgroundColor: const Color(0xFFF3F4F6).withValues(alpha: 0.5),
      fontFamily: null,
      fontSize: 13,
    ),
    codeblockDecoration: BoxDecoration(
      color: const Color(0xFFF3F4F6).withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockSpacing: 8,
    blockquote: TextStyle(
      color: const Color(0xFF6B7280),
      fontStyle: FontStyle.italic,
      fontFamily: null,
    ),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.5),
          width: 3,
        ),
      ),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: const Color(0xFFE5E7EB), width: 1)),
    ),
    strong: TextStyle(
      color: const Color(0xFF1F2937),
      fontWeight: FontWeight.bold,
      fontFamily: null,
    ),
    em: TextStyle(
      color: const Color(0xFF1F2937),
      fontStyle: FontStyle.italic,
      fontFamily: null,
    ),
    a: TextStyle(
      color: const Color(0xFF2DD4BF),
      decoration: TextDecoration.underline,
      fontFamily: null,
    ),
    tableHead: TextStyle(
      color: const Color(0xFF1F2937),
      fontWeight: FontWeight.bold,
      fontFamily: null,
    ),
    tableBody: TextStyle(color: const Color(0xFF1F2937), fontFamily: null),
    tableBorder: TableBorder(
      horizontalInside: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
      verticalInside: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
    ),
    tableCellsPadding: const EdgeInsets.all(8),
  );

  // 用于跟踪流式状态的变量
  bool _wasStreaming = false;
  // 用于确保 Provider 监听器只注册一次
  bool _chatProviderListenerAdded = false;
  // 用户是否正在手动滚动
  bool _isUserScrolling = false;
  // 恢复自动滚动的计时器
  Timer? _resumeAutoScrollTimer;
  // 用户停止滚动后多久恢复自动滚动（毫秒）
  static const int _autoResumeDelayMs = 3000;

  /// Provider 变更监听器 - 在流式输出期间自动滚动
  void _onChatProviderChanged() {
    // 检查 widget 是否仍然挂载，防止在 dispose 后访问 context
    if (!mounted) return;

    final chatProvider = context.read<ChatProvider>();
    final isStreaming = chatProvider.isStreaming;

    // 当流式状态从 false 变为 true 时（开始流式输出）
    if (isStreaming && !_wasStreaming) {
      _wasStreaming = true;
    }
    // 当处于流式状态时，滚动到底部
    else if (isStreaming && _wasStreaming) {
      _scrollToBottomDuringStreaming();
    }
    // 当流式状态从 true 变为 false 时（流式输出结束）
    else if (!isStreaming && _wasStreaming) {
      _wasStreaming = false;
      // 流式结束时确保滚动到底部
      _scrollToBottom();
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // 启动脉冲动画（用于流式生成时的光标效果）
    _pulseController.repeat(reverse: true);
    // 入场动画
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _slideController.forward();
      }
    });
    // 等待动画和布局完成后再滚动
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 添加 Provider 监听器以在流式输出期间自动滚动（只注册一次）
    if (!_chatProviderListenerAdded) {
      _chatProvider = context.read<ChatProvider>();
      _chatProvider!.addListener(_onChatProviderChanged);
      _chatProviderListenerAdded = true;
    }
  }

  @override
  void dispose() {
    // 取消恢复自动滚动的计时器
    _resumeAutoScrollTimer?.cancel();
    // 移除 Provider 监听器（使用保存的引用，避免在 dispose 中访问 context）
    if (_chatProvider != null) {
      _chatProvider!.removeListener(_onChatProviderChanged);
    }
    // 确保动画控制器先停止再释放
    _pulseController.stop();
    _slideController.stop();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// 发送消息（通过 Provider）
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 检查是否正在流式生成
    final chatProvider = context.read<ChatProvider>();
    if (chatProvider.isStreaming) return;

    _focusNode.unfocus();
    _textController.clear();

    // 重置用户滚动状态，确保发送新消息时自动滚动到底部
    _isUserScrolling = false;
    _resumeAutoScrollTimer?.cancel();

    // 通过 Provider 发送消息
    await chatProvider.sendMessage(text);

    _scrollToBottom();
  }

  /// 滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 检查 widget 是否仍然挂载且 ScrollController 有客户端
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// 流式输出期间滚动到底部（智能滚动）
  /// 如果用户正在手动滚动，暂停自动滚动，延迟后恢复
  void _scrollToBottomDuringStreaming() {
    // 如果用户正在手动滚动，不执行自动滚动
    if (_isUserScrolling) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 检查 widget 是否仍然挂载且 ScrollController 有客户端
      if (!mounted || !_scrollController.hasClients || _isUserScrolling) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      // 只有当用户位于底部附近时才自动滚动（200像素的阈值，更宽松）
      final distanceFromBottom = maxScroll - currentScroll;
      if (distanceFromBottom < 200) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 处理用户滚动开始
  void _onUserScrollStart() {
    if (!_isUserScrolling) {
      _isUserScrolling = true;
      // 取消之前的恢复计时器
      _resumeAutoScrollTimer?.cancel();
    }
  }

  /// 处理用户滚动结束
  void _onUserScrollEnd() {
    // 延迟一段时间后恢复自动滚动
    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(
      const Duration(milliseconds: _autoResumeDelayMs),
      () {
        if (mounted) {
          _isUserScrolling = false;
          // 恢复自动滚动到底部
          if (context.read<ChatProvider>().isStreaming) {
            _scrollToBottom();
          }
        }
      },
    );
  }

  /// 复制消息到剪贴板
  Future<void> _copyMessage(String content) async {
    await Clipboard.setData(ClipboardData(text: content));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Text('已复制到剪贴板'),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF115E59),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 移除消息中的JSON代码块
  String _removeJsonCodeBlocks(String content) {
    final jsonBlockRegex = RegExp(
      r'```(?:json)?\s*\n?[\s\S]*?\n?```',
      multiLine: true,
    );
    return content.replaceAll(jsonBlockRegex, '');
  }

  @override
  Widget build(BuildContext context) {
    // 离线模式检测
    final networkService = NetworkService();

    return FutureBuilder<bool>(
      future: networkService.isConnectedAsync(),
      builder: (context, snapshot) {
        final isOffline = snapshot.data == false;

        if (isOffline) {
          return _buildOfflineState();
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F0),
          body: Stack(
            children: [
              // 背景装饰
              _buildBackgroundDecoration(),

              SafeArea(
                child: Column(
                  children: [
                    // 顶部标题栏
                    _buildHeader(),
                    // Messages List
                    Expanded(child: _buildChatArea()),

                    // Input Area
                    _buildInputArea(),
                  ],
                ),
              ),
            ],
          ),
          // Bottom Navigation
          bottomNavigationBar: BottomNav(
            currentPage: 'ai',
            onNavigate: widget.onNavigate,
          ),
        );
      },
    );
  }

  /// 离线状态提示
  Widget _buildOfflineState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: Colors.orange.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'AI 教练暂不可用',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'AI 聊天功能需要联网使用\n请检查网络连接后重试',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  widget.onNavigate('today');
                },
                icon: const Icon(Icons.home_rounded),
                label: const Text('返回首页'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DD4BF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentPage: 'ai',
        onNavigate: widget.onNavigate,
      ),
    );
  }

  /// 顶部标题栏（包含会话管理入口）
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // 菜单按钮（会话列表）
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF115E59)),
            onPressed: () => _openSessionList(context),
            tooltip: '对话历史',
          ),
          // 标题
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 教练',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF115E59),
                      ),
                    ),
                    if (provider.currentSessionId != null)
                      Text(
                        '当前对话',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                );
              },
            ),
          ),
          // 新建对话按钮
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF115E59)),
            onPressed: () async {
              await context.read<ChatProvider>().createNewSession();
            },
            tooltip: '新建对话',
          ),
        ],
      ),
    );
  }

  /// 打开会话列表
  void _openSessionList(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatSessionsPage()));
  }

  /// 背景装饰
  Widget _buildBackgroundDecoration() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 350,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF2DD4BF).withValues(alpha: 0.10),
                  const Color(0xFFF5F5F0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -40,
          right: -40,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.08),
                width: 2,
              ),
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: -30,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.06),
                width: 1.5,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 200,
          right: -20,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.04),
            ),
          ),
        ),
      ],
    );
  }

  /// 聊天区域
  Widget _buildChatArea() {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
          .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
          ),
      child: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final messages = chatProvider.messages;
          // 没有选择会话时显示空状态
          if (chatProvider.currentSessionId == null) return _buildEmptyState();
          // 有消息时显示消息列表
          if (messages.isNotEmpty) {
            return _buildMessagesList(messages, chatProvider);
          }
          // 选择了会话但没有消息时显示空状态
          return _buildEmptyState();
        },
      ),
    );
  }

  /// 空状态 - 使用统一设计
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 60),
          EmptyStateWidget.chat(),
          const SizedBox(height: 32),
          // 快捷提示网格
          _buildQuickPromptsGrid(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 快捷提示网格（类似Kimi/DeepSeek）
  Widget _buildQuickPromptsGrid() {
    // 定义快捷提示卡片数据
    final prompts = [
      _QuickPrompt(
        icon: Icons.calendar_today,
        title: '今日训练',
        desc: '生成今天的训练计划',
        color: const Color(0xFF10B981),
      ),
      _QuickPrompt(
        icon: Icons.local_fire_department,
        title: '减脂建议',
        desc: '获取科学的减脂方案',
        color: const Color(0xFFF59E0B),
      ),
      _QuickPrompt(
        icon: Icons.fitness_center,
        title: '增肌训练',
        desc: '制定增肌计划',
        color: const Color(0xFFEF4444),
      ),
      _QuickPrompt(
        icon: Icons.self_improvement,
        title: '拉伸放松',
        desc: '缓解肌肉酸痛',
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '可以这样问我',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: prompts.length,
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              return _buildPromptCard(prompt);
            },
          ),
        ],
      ),
    );
  }

  /// 快捷提示卡片
  Widget _buildPromptCard(_QuickPrompt prompt) {
    return GestureDetector(
      onTap: () {
        _textController.text = prompt.desc;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: prompt.color.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: prompt.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(prompt.icon, size: 18, color: prompt.color),
            ),
            const SizedBox(height: 10),
            Text(
              prompt.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              prompt.desc,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 消息列表
  Widget _buildMessagesList(
    List<ChatMessage> messages,
    ChatProvider chatProvider,
  ) {
    // 过滤消息：流式输出期间，不显示当前正在生成的AI消息
    final displayMessages = messages.where((msg) {
      // 用户消息始终显示
      if (msg.type == ChatMessageType.user) return true;
      // AI消息：如果不是当前流式消息，则显示
      if (msg.id == chatProvider.streamingMessageId) return false;
      return true;
    }).toList();

    // 按时间戳排序，确保消息顺序正确（老消息在前，新消息在后）
    displayMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 构建消息列表项
    final List<Widget> messageWidgets = [];

    for (int i = 0; i < displayMessages.length; i++) {
      final message = displayMessages[i];

      // 添加普通消息气泡
      messageWidgets.add(
        _buildMessageBubble(message, i, displayMessages, chatProvider),
      );
    }

    // 流式输出期间，添加实时 AgentAccordion
    if (chatProvider.isStreaming && chatProvider.agentOutputs.isNotEmpty) {
      messageWidgets.add(_buildStreamingAgentAccordion(chatProvider));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollStartNotification) {
          // 用户开始滚动
          _onUserScrollStart();
        } else if (scrollNotification is ScrollEndNotification) {
          // 用户停止滚动
          _onUserScrollEnd();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: messageWidgets.length,
        itemBuilder: (context, index) => messageWidgets[index],
      ),
    );
  }

  /// 流式期间的 AgentAccordion 显示
  Widget _buildStreamingAgentAccordion(ChatProvider chatProvider) {
    final hasActiveAgents = chatProvider.agentOutputs.any(
      (agent) => agent.status == AgentStatus.running,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(isUser: false),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Agent状态标签
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: hasActiveAgents
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasActiveAgents)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue[600]!,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green[700],
                          ),
                        const SizedBox(width: 8),
                        Text(
                          hasActiveAgents
                              ? '⏳ 多Agent协同处理中...'
                              : '✅ Agent执行记录',
                          style: TextStyle(
                            fontSize: 13,
                            color: hasActiveAgents
                                ? Colors.blue[700]
                                : Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Agent手风琴组件
                  AgentAccordion(
                    agents: chatProvider.agentOutputs,
                    onToggle: (agentId) => chatProvider.toggleAgentExpanded(agentId),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 消息气泡
  Widget _buildMessageBubble(
    ChatMessage message,
    int index,
    List<ChatMessage> messages,
    ChatProvider chatProvider,
  ) {
    final isUser = message.type == ChatMessageType.user;
    final isStreaming = message.id == chatProvider.streamingMessageId;

    // 获取该消息关联的训练计划列表（消息与计划一对一绑定）
    final messagePlans = chatProvider.getPlansForMessage(message.id);

    // 检查是否包含健身计划
    // 只要消息有计划就显示，响应状态只影响按钮的可用性
    // 支持多计划场景
    final isPlanMessage =
        !isUser &&
        message.dataType == ChatMessageDataType.workoutPlan &&
        messagePlans.isNotEmpty;
    final hasWorkoutPlan = isPlanMessage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: !isStreaming && message.content.isNotEmpty
                      ? () => _copyMessage(message.content)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                              colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                            )
                          : null,
                      color: isUser ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: isStreaming && !isUser
                        ? _buildStreamingContent(message.content)
                        : _buildMessageContentWithAgentOutputs(
                            message,
                            isUser,
                            chatProvider,
                          ),
                  ),
                ),
                // 健身计划预览（支持多计划）- 使用消息关联的计划
                if (hasWorkoutPlan && messagePlans.isNotEmpty)
                  messagePlans.length == 1
                      ? _buildWorkoutPlanPreview(
                          messagePlans.first,
                          chatProvider,
                          chatProvider.isPlanRespondedById(messagePlans.first.id),
                          message.id,
                        )
                      : _buildMultipleWorkoutPlansPreview(
                          messagePlans,
                          chatProvider,
                          message.id,
                        ),
                // 时间戳和复制按钮
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                      if (!isStreaming && message.content.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _copyMessage(message.content),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 12,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '复制',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[const SizedBox(width: 8), _buildAvatar(isUser: true)],
        ],
      ),
    );
  }

  /// 头像
  Widget _buildAvatar({required bool isUser}) {
    if (isUser) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.person_rounded,
          color: Color(0xFF2DD4BF),
          size: 20,
        ),
      );
    } else {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.smart_toy_rounded,
          color: Colors.white,
          size: 18,
        ),
      );
    }
  }

  /// 流式内容（带光标动画）
  Widget _buildStreamingContent(String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildMarkdownBody(content, isStreaming: true)),
        const SizedBox(width: 4),
        _buildStreamingCursor(),
      ],
    );
  }

  /// 消息内容（支持 AgentAccordion 或 Markdown）
  Widget _buildMessageContentWithAgentOutputs(
    ChatMessage message,
    bool isUser,
    ChatProvider chatProvider,
  ) {
    if (isUser) {
      return Text(
        message.content,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.white,
          height: 1.5,
          fontWeight: FontWeight.w500,
          fontFamily: null,
        ),
      );
    }

    // 如果消息包含 Agent 输出，使用 AgentAccordion 显示
    if (message.agentOutputs != null && message.agentOutputs!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent 状态标签
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Colors.green[700],
                ),
                const SizedBox(width: 8),
                Text(
                  '✅ 多Agent协同已完成',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
          ),
          // AgentAccordion 组件（历史消息不需要保存展开状态）
          AgentAccordion(
            agents: message.agentOutputs!,
            onToggle: (_) {}, // 历史消息的展开状态不保存
          ),
          // 消息内容（总结）
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 12),
            _buildMarkdownBody(
              _removeJsonCodeBlocks(message.content),
              isStreaming: false,
            ),
          ],
        ],
      );
    }

    // 普通消息使用 Markdown 显示
    final cleanContent = _removeJsonCodeBlocks(message.content);
    return _buildMarkdownBody(cleanContent, isStreaming: false);
  }

  /// Markdown 内容渲染器
  Widget _buildMarkdownBody(String content, {required bool isStreaming}) {
    return SelectionArea(
      child: MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: _cachedMarkdownStyleSheet,
      ),
    );
  }

  /// 流式光标动画
  Widget _buildStreamingCursor() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_pulseController.value * 0.7),
          child: Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }

  /// 健身计划预览卡片
  Widget _buildWorkoutPlanPreview(
    WorkoutPlan plan,
    ChatProvider chatProvider,
    bool isResponded,
    String messageId,
  ) {
    final isConfirmed = chatProvider.isPlanConfirmedById(plan.id);
    final isExpanded = _expandedPlanCards.contains(messageId);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2DD4BF).withValues(alpha: 0.1),
            const Color(0xFF14B8A6).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 可点击的标题栏
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedPlanCards.remove(messageId);
                } else {
                  _expandedPlanCards.add(messageId);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlanHeader(plan),
                  const SizedBox(height: 12),
                  _buildPlanStats(plan),
                  const SizedBox(height: 8),
                  // 展开/收起指示器
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: const Color(0xFF2DD4BF),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isExpanded ? '点击收起' : '点击展开详情',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF2DD4BF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 可展开的内容
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...plan.modules.asMap().entries.map((entry) {
                    final index = entry.key;
                    final module = entry.value;
                    return _buildModuleDetail(module, index + 1);
                  }),
                  const SizedBox(height: 16),
                  if (!isResponded)
                    _buildActionButtons(plan, chatProvider, messageId)
                  else
                    _buildResponseStatus(isConfirmed),
                ],
              ),
            ),
            crossFadeState:
                isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  /// 多个健身计划预览卡片（多计划场景）
  Widget _buildMultipleWorkoutPlansPreview(
    List<WorkoutPlan> plans,
    ChatProvider chatProvider,
    String messageId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 计划数量提示
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fitness_center,
                size: 16,
                color: const Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 6),
              Text(
                '为您生成了 ${plans.length} 个训练计划',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ),
        // 计划列表
        ...plans.asMap().entries.map((entry) {
          final index = entry.key;
          final plan = entry.value;
          final isResponded = chatProvider.isPlanRespondedById(plan.id);
          final isConfirmed = chatProvider.isPlanConfirmedById(plan.id);
          // 使用组合key确保每个计划的展开状态独立
          final planKey = '${messageId}_plan_${plan.id}';

          return Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                  const Color(0xFF14B8A6).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 计划序号标识
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '计划 ${index + 1}/${plans.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF115E59),
                      ),
                    ),
                  ),
                ),
                // 单个计划预览（复用原有组件）
                _buildSingleWorkoutPlanCard(
                  plan,
                  chatProvider,
                  isResponded,
                  planKey,
                  messageId,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// 单个计划卡片（用于多计划列表中）
  Widget _buildSingleWorkoutPlanCard(
    WorkoutPlan plan,
    ChatProvider chatProvider,
    bool isResponded,
    String planKey,
    String messageId,
  ) {
    final isExpanded = _expandedPlanCards.contains(planKey);
    final isConfirmed = chatProvider.isPlanConfirmedById(plan.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 可点击的标题栏
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedPlanCards.remove(planKey);
              } else {
                _expandedPlanCards.add(planKey);
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPlanHeader(plan),
                const SizedBox(height: 12),
                _buildPlanStats(plan),
                const SizedBox(height: 8),
                // 展开/收起指示器
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: const Color(0xFF2DD4BF),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpanded ? '点击收起' : '点击展开详情',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF2DD4BF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 可展开的内容
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...plan.modules.asMap().entries.map((entry) {
                  final index = entry.key;
                  final module = entry.value;
                  return _buildModuleDetail(module, index + 1);
                }),
                const SizedBox(height: 16),
                if (!isResponded)
                  _buildMultiPlanActionButtons(plan, chatProvider, messageId)
                else
                  _buildResponseStatus(isConfirmed),
              ],
            ),
          ),
          crossFadeState:
              isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }

  /// 多计划场景的操作按钮（带计划ID和messageId）
  Widget _buildMultiPlanActionButtons(
    WorkoutPlan plan,
    ChatProvider chatProvider,
    String messageId,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => chatProvider.rejectWorkoutPlanById(plan.id, messageId: messageId),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[600],
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: chatProvider.isApplyingPlan
                ? null
                : () => chatProvider.applyWorkoutPlan(plan, messageId: messageId),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2DD4BF),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: chatProvider.isApplyingPlan
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '确认计划',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// 显示响应状态标签
  Widget _buildResponseStatus(bool? isConfirmed) {
    final confirmed = isConfirmed ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: confirmed ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            confirmed ? Icons.check_circle : Icons.cancel,
            color: confirmed ? Colors.green : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            confirmed ? '已确认' : '已取消',
            style: TextStyle(
              color: confirmed ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 计划标题
  Widget _buildPlanHeader(WorkoutPlan plan) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2DD4BF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '新计划',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            plan.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115E59),
            ),
          ),
        ),
      ],
    );
  }

  /// 计划统计信息
  Widget _buildPlanStats(WorkoutPlan plan) {
    return Row(
      children: [
        _buildPlanStat(Icons.access_time, '${plan.totalDuration}分钟'),
        const SizedBox(width: 16),
        _buildPlanStat(Icons.fitness_center, 'RPE ${plan.rpe}'),
        const SizedBox(width: 16),
        _buildPlanStat(Icons.location_on, plan.scene),
      ],
    );
  }

  /// 模块详细内容
  Widget _buildModuleDetail(WorkoutModule module, int moduleNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '模块 $moduleNumber',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115E59),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  module.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115E59),
                  ),
                ),
              ),
              Text(
                '${module.duration}分钟',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...module.exercises.asMap().entries.map((entry) {
            final exIndex = entry.key;
            final exercise = entry.value;
            return _buildExerciseDetail(exercise, exIndex + 1);
          }),
        ],
      ),
    );
  }

  /// 动作详细卡片
  Widget _buildExerciseDetail(Exercise exercise, int exerciseNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$exerciseNumber',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF115E59),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115E59),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${exercise.duration}秒',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115E59),
                  ),
                ),
              ),
            ],
          ),
          if (exercise.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exercise.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (exercise.steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.checklist_rounded,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '步骤: ${exercise.steps.join(' → ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (exercise.tips.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 14,
                  color: Colors.amber[700],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exercise.tips,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (exercise.breathing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.air, size: 14, color: Color(0xFF2DD4BF)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '呼吸: ${exercise.breathing}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ],
          if (exercise.targetMuscles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: exercise.targetMuscles.map((muscle) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF115E59).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF115E59).withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    muscle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF115E59),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButtons(WorkoutPlan plan, ChatProvider chatProvider, String messageId) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => chatProvider.rejectWorkoutPlan(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('取消', style: TextStyle(color: Colors.grey[700])),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: chatProvider.isApplyingPlan
                ? null
                : () => chatProvider.applyWorkoutPlan(plan, messageId: messageId),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2DD4BF),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: chatProvider.isApplyingPlan
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '确定应用',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  /// 输入区域
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Consumer<ChatProvider>(
          builder: (context, chatProvider, child) {
            return Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F0),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? const Color(0xFF2DD4BF).withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: '输入你的问题...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: chatProvider.isStreaming ? null : _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: chatProvider.isStreaming
                          ? LinearGradient(
                              colors: [Colors.grey[300]!, Colors.grey[400]!],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                            ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: chatProvider.isStreaming
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(
                                  0xFF2DD4BF,
                                ).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: chatProvider.isStreaming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
