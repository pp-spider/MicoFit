import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../widgets/bottom_nav.dart';
import '../providers/chat_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// AI聊天页面 - 精致美观设计
class AiChatPage extends StatefulWidget {
  final Function(String) onNavigate;

  const AiChatPage({
    super.key,
    required this.onNavigate,
  });

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> with TickerProviderStateMixin {
  // 输入控制器
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // 动画控制器
  late AnimationController _pulseController;
  late AnimationController _slideController;

  // 快捷问题列表
  final List<String> _quickQuestions = [
    '今天适合什么训练？',
    '如何缓解运动后的疲劳？',
    '有什么减脂建议吗？',
    '我想增强核心力量',
  ];

  // Markdown 样式表缓存（避免重复创建）
  static final MarkdownStyleSheet _cachedMarkdownStyleSheet = MarkdownStyleSheet(
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
      border: Border(
        top: BorderSide(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
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
    tableBody: TextStyle(
      color: const Color(0xFF1F2937),
      fontFamily: null,
    ),
    tableBorder: TableBorder(
      horizontalInside: BorderSide(
        color: const Color(0xFFE5E7EB),
        width: 1,
      ),
      verticalInside: BorderSide(
        color: const Color(0xFFE5E7EB),
        width: 1,
      ),
    ),
    tableCellsPadding: const EdgeInsets.all(8),
  );

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
    // 动画完成后滚动到底部
    Future.delayed(const Duration(milliseconds: 100), () {
      _slideController.forward();
    });
    // 等待动画和布局完成后再滚动
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// 发送快捷问题
  void _sendQuickQuestion(String question) {
    _textController.text = question;
    _sendMessage();
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

    // 通过 Provider 发送消息
    await chatProvider.sendMessage(text);

    _scrollToBottom();
  }

  /// 滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// 显示清空聊天记录确认对话框
  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 48,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              const Text(
                '清空聊天记录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF115E59),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '确定要清空所有聊天记录吗？\n此操作无法撤销',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                      onPressed: () async {
                        Navigator.pop(context);
                        await context.read<ChatProvider>().clearHistory();
                        _scrollToBottom();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('清空'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: Stack(
        children: [
          // 背景装饰
          _buildBackgroundDecoration(),

          SafeArea(
            child: Column(
              children: [
                // Messages List
                Expanded(
                  child: _buildChatArea(),
                ),

                // Quick Questions (仅当消息很少时显示)
                _buildQuickQuestions(),

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
      position: Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      )),
      child: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final messages = chatProvider.messages;
          if (messages.isEmpty) return _buildEmptyState();
          return _buildMessagesList(messages, chatProvider);
        },
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2DD4BF).withValues(alpha: 0.25),
                  const Color(0xFF14B8A6).withValues(alpha: 0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Color(0xFF2DD4BF),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '开始对话',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '选择下方快捷问题或直接输入',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// 消息列表
  Widget _buildMessagesList(List<ChatMessage> messages, ChatProvider chatProvider) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageBubble(message, index, messages, chatProvider);
      },
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
    final isEmptyAI = !isUser && message.content.trim().isEmpty;

    // 检查是否包含待确认的健身计划
    final hasWorkoutPlan = !isUser &&
        message.dataType == ChatMessageDataType.workoutPlan &&
        chatProvider.pendingWorkoutPlan != null &&
        index == messages.length - 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: !isStreaming && message.content.isNotEmpty
                      ? () => _copyMessage(message.content)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                    child: isEmptyAI && isStreaming
                        ? _buildTypingAnimationInline()
                        : (isStreaming && !isUser
                            ? _buildStreamingContent(message.content)
                            : _buildMessageContent(message.content, isUser)),
                  ),
                ),
                // 健身计划预览
                if (hasWorkoutPlan && chatProvider.pendingWorkoutPlan != null)
                  _buildWorkoutPlanPreview(chatProvider.pendingWorkoutPlan!, chatProvider),
                // 时间戳和复制按钮
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                      if (!isStreaming && message.content.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _copyMessage(message.content),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(isUser: true),
          ],
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
        Expanded(
          child: _buildMarkdownBody(content, isStreaming: true),
        ),
        const SizedBox(width: 4),
        _buildStreamingCursor(),
      ],
    );
  }

  /// 消息内容（支持 Markdown）
  Widget _buildMessageContent(String content, bool isUser) {
    if (isUser) {
      return Text(
        content,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.white,
          height: 1.5,
          fontWeight: FontWeight.w500,
          fontFamily: null,
        ),
      );
    } else {
      final cleanContent = _removeJsonCodeBlocks(content);
      return _buildMarkdownBody(cleanContent, isStreaming: false);
    }
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

  /// 消息气泡内联打字动画
  Widget _buildTypingAnimationInline() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final delay = index * 0.2;
            final value = ((_pulseController.value - delay + 1) % 1);
            return Container(
              margin: EdgeInsets.only(left: index > 0 ? 6 : 0),
              width: 8 + (value * 4),
              height: 8 + (value * 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.3 + (value * 0.7)),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }).toList(),
    );
  }

  /// 快捷问题
  Widget _buildQuickQuestions() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final messages = chatProvider.messages;
        if (messages.length > 2) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                child: Text(
                  '快捷提问',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickQuestions.length,
                  itemBuilder: (context, index) {
                    final question = _quickQuestions[index];
                    return Padding(
                      padding: EdgeInsets.only(right: index < _quickQuestions.length - 1 ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => _sendQuickQuestion(question),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2DD4BF).withValues(alpha: 0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flash_on_rounded,
                                size: 14,
                                color: Colors.amber[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                question,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF115E59),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 健身计划预览卡片
  Widget _buildWorkoutPlanPreview(WorkoutPlan plan, ChatProvider chatProvider) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
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
          _buildPlanHeader(plan),
          const SizedBox(height: 12),
          _buildPlanStats(plan),
          const SizedBox(height: 12),
          ...plan.modules.asMap().entries.map((entry) {
            final index = entry.key;
            final module = entry.value;
            return _buildModuleDetail(module, index + 1);
          }),
          const SizedBox(height: 16),
          _buildActionButtons(plan, chatProvider),
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
                Icon(Icons.description_outlined, size: 14, color: Colors.grey[600]),
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
                Icon(Icons.checklist_rounded, size: 14, color: Colors.grey[600]),
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
                Icon(Icons.lightbulb_outline_rounded, size: 14, color: Colors.amber[700]),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
  Widget _buildActionButtons(WorkoutPlan plan, ChatProvider chatProvider) {
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
            child: Text(
              '取消',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: chatProvider.isApplyingPlan
                ? null
                : () => chatProvider.applyWorkoutPlan(plan),
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
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
                        suffixIcon: chatProvider.messages.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_all_rounded,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                                onPressed: () => _showClearChatDialog(),
                                tooltip: '清空聊天记录',
                              )
                            : null,
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
                              colors: [
                                Colors.grey[300]!,
                                Colors.grey[400]!
                              ],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                            ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: chatProvider.isStreaming
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
