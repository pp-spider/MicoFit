import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/agent_output.dart';

/// 多智能体手风琴组件
///
/// 展示多个Agent的执行状态和输出内容，支持展开/收起
class AgentAccordion extends StatelessWidget {
  final List<AgentOutput> agents;
  final Function(String agentId)? onToggle;
  final Function(String agentId)? onAgentTap;

  const AgentAccordion({
    super.key,
    required this.agents,
    this.onToggle,
    this.onAgentTap,
  });

  @override
  Widget build(BuildContext context) {
    if (agents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: agents.asMap().entries.map((entry) {
            final index = entry.key;
            final agent = entry.value;
            return AgentAccordionItem(
              agent: agent,
              isLast: index == agents.length - 1,
              onToggle: () => onToggle?.call(agent.id),
              onTap: () => onAgentTap?.call(agent.id),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// 单个Agent手风琴项
class AgentAccordionItem extends StatefulWidget {
  final AgentOutput agent;
  final bool isLast;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  const AgentAccordionItem({
    super.key,
    required this.agent,
    this.isLast = false,
    this.onToggle,
    this.onTap,
  });

  @override
  State<AgentAccordionItem> createState() => _AgentAccordionItemState();
}

class _AgentAccordionItemState extends State<AgentAccordionItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _heightAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    if (widget.agent.isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AgentAccordionItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.agent.isExpanded != oldWidget.agent.isExpanded) {
      if (widget.agent.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusConfig = _getStatusConfig(widget.agent.status);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Material(
          color: widget.agent.status == AgentStatus.running
              ? const Color(0xFFDBEAFE).withValues(alpha: 0.3)
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              widget.onToggle?.call();
              widget.onTap?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Icon
                  Text(widget.agent.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  // Name and Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.agent.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF115E59),
                          ),
                        ),
                        if (widget.agent.taskType != null)
                          Text(
                            widget.agent.taskType!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusConfig.bgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusConfig.borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.agent.status == AgentStatus.running)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 4),
                            child: _buildRunningIndicator(),
                          )
                        else
                          Icon(
                            statusConfig.icon,
                            size: 14,
                            color: statusConfig.textColor,
                          ),
                        const SizedBox(width: 2),
                        Text(
                          statusConfig.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: statusConfig.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Arrow
                  AnimatedRotation(
                    turns: widget.agent.isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[400],
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Content - 实时展示流式内容
        AnimatedBuilder(
          animation: _heightAnimation,
          builder: (context, child) {
            return ClipRect(
              child: Align(
                heightFactor: _heightAnimation.value,
                child: FadeTransition(opacity: _opacityAnimation, child: child),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: AgentContentRenderer(agent: widget.agent),
                ),
              ],
            ),
          ),
        ),
        // 收起时显示实时内容预览（简化视图）
        if (!widget.agent.isExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: StreamContentPreview(agent: widget.agent),
          ),
        // Divider
        if (!widget.isLast) Divider(height: 1, color: Colors.grey[100]),
      ],
    );
  }

  Widget _buildRunningIndicator() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse effect
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        // Core dot
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF3B82F6),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  StatusConfig _getStatusConfig(AgentStatus status) {
    switch (status) {
      case AgentStatus.completed:
        return StatusConfig(
          label: '完成',
          bgColor: const Color(0xFFD1FAE5),
          textColor: const Color(0xFF047857),
          borderColor: const Color(0xFFA7F3D0),
          icon: Icons.check,
        );
      case AgentStatus.running:
        return StatusConfig(
          label: '进行中',
          bgColor: const Color(0xFFDBEAFE),
          textColor: const Color(0xFF1D4ED8),
          borderColor: const Color(0xFFBFDBFE),
          icon: Icons.sync,
        );
      case AgentStatus.waiting:
        return StatusConfig(
          label: '等待',
          bgColor: const Color(0xFFF3F4F6),
          textColor: const Color(0xFF6B7280),
          borderColor: const Color(0xFFE5E7EB),
          icon: Icons.schedule,
        );
    }
  }
}

/// 状态配置
class StatusConfig {
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final IconData icon;

  StatusConfig({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    required this.icon,
  });
}

/// Agent内容渲染器
class AgentContentRenderer extends StatelessWidget {
  final AgentOutput agent;

  const AgentContentRenderer({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    final hasContentItems = agent.contentItems.isNotEmpty;
    final hasMessageContent =
        agent.messageContent != null && agent.messageContent!.isNotEmpty;

    if (!hasContentItems && !hasMessageContent) {
      return _buildWaitingWidget();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _getBorderColor(), width: 2)),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态内容项
          ...agent.contentItems.map((item) => _buildContentItem(item)),
          // Agent 生成的消息内容
          if (hasMessageContent) _buildMessageContent(agent.messageContent!),
        ],
      ),
    );
  }

  /// 构建 Agent 消息内容
  Widget _buildMessageContent(String content) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: MarkdownBody(
        data: content,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5),
          code: TextStyle(
            fontSize: 13,
            color: Colors.grey[800],
            backgroundColor: Colors.grey[200],
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          codeblockPadding: const EdgeInsets.all(8),
          blockquote: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: _getBorderColor(), width: 3),
            ),
          ),
          blockquotePadding: const EdgeInsets.only(left: 12),
          listBullet: TextStyle(color: _getDotColor()),
          h1: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
          h2: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
          h3: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ),
    );
  }

  Widget _buildContentItem(AgentContentItem item) {
    switch (item.type) {
      case AgentContentType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            item.text ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        );
      case AgentContentType.list:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: (item.items ?? []).map((i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      decoration: BoxDecoration(
                        color: _getDotColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        i,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      case AgentContentType.progress:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (item.percent ?? 0) / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2DD4BF),
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '处理进度: ${item.percent}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      case AgentContentType.typing:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                item.text ?? '处理中',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              _buildTypingIndicator(),
            ],
          ),
        );
      case AgentContentType.success:
        return Container(
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF047857),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.text ?? '完成',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
        );
      case AgentContentType.warning:
        return Container(
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Color(0xFFD97706), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.text ?? '警告',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
        );
      case AgentContentType.error:
        return Container(
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.error, color: Color(0xFFDC2626), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.text ?? '错误',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildWaitingWidget() {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '等待激活...',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        const SizedBox(width: 3),
        _buildDot(1),
        const SizedBox(width: 3),
        _buildDot(2),
      ],
    );
  }

  Widget _buildDot(int index) {
    return _TypingDot(delay: Duration(milliseconds: index * 200));
  }

  Color _getBorderColor() {
    switch (agent.colorName) {
      case 'emerald':
        return const Color(0xFF6EE7B7);
      case 'blue':
        return const Color(0xFF93C5FD);
      case 'amber':
        return const Color(0xFFFCA5A5);
      case 'purple':
        return const Color(0xFFC4B5FD);
      default:
        return const Color(0xFF5EEAD4);
    }
  }

  Color _getDotColor() {
    switch (agent.colorName) {
      case 'emerald':
        return const Color(0xFF10B981);
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'amber':
        return const Color(0xFFF59E0B);
      case 'purple':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF14B8A6);
    }
  }
}

/// 打字动画圆点
class _TypingDot extends StatefulWidget {
  final Duration delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // 延迟启动
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

/// 流式内容预览组件 - 收起时显示实时内容
class StreamContentPreview extends StatelessWidget {
  final AgentOutput agent;

  const StreamContentPreview({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    // 获取最新的内容项
    final contentItems = agent.contentItems;
    if (contentItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // 获取最后几个内容项的文本预览
    final previewTexts = <String>[];
    for (var i = contentItems.length - 1; i >= 0 && previewTexts.length < 2; i--) {
      final item = contentItems[i];
      final text = _extractPreviewText(item);
      if (text.isNotEmpty) {
        previewTexts.insert(0, text);
      }
    }

    if (previewTexts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _getBorderColor(agent.colorName), width: 2)),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 实时内容预览
          ...previewTexts.map((text) => _buildPreviewLine(text)),
          // 如果正在运行，显示实时指示器
          if (agent.status == AgentStatus.running)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '实时生成中...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _extractPreviewText(AgentContentItem item) {
    switch (item.type) {
      case AgentContentType.text:
        return item.text ?? '';
      case AgentContentType.success:
        return item.text ?? '完成';
      case AgentContentType.warning:
        return item.text ?? '警告';
      case AgentContentType.error:
        return item.text ?? '错误';
      case AgentContentType.progress:
        return '处理进度: ${item.percent}%';
      case AgentContentType.typing:
        return item.text ?? '处理中';
      case AgentContentType.list:
        final items = item.items;
        if (items != null && items.isNotEmpty) {
          return '• ${items.first}';
        }
        return '';
    }
  }

  Widget _buildPreviewLine(String text) {
    // 截断长文本
    final displayText = text.length > 60 ? '${text.substring(0, 60)}...' : text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          height: 1.4,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Color _getBorderColor(String colorName) {
    switch (colorName) {
      case 'emerald':
        return const Color(0xFF6EE7B7);
      case 'blue':
        return const Color(0xFF93C5FD);
      case 'amber':
        return const Color(0xFFFCA5A5);
      case 'purple':
        return const Color(0xFFC4B5FD);
      default:
        return const Color(0xFF5EEAD4);
    }
  }
}
