import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_session.dart';

/// 聊天会话列表页面
class ChatSessionsPage extends StatefulWidget {
  final VoidCallback? onSessionSelected;

  const ChatSessionsPage({
    super.key,
    this.onSessionSelected,
  });

  @override
  State<ChatSessionsPage> createState() => _ChatSessionsPageState();
}

class _ChatSessionsPageState extends State<ChatSessionsPage> {
  bool _isMultiSelectMode = false;
  final Set<String> _selectedSessions = {};

  @override
  void initState() {
    super.initState();
    // 页面加载时获取会话列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadSessions();
    });
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedSessions.clear();
      }
    });
  }

  void _toggleSessionSelection(String sessionId) {
    setState(() {
      if (_selectedSessions.contains(sessionId)) {
        _selectedSessions.remove(sessionId);
      } else {
        _selectedSessions.add(sessionId);
      }
    });
  }

  void _selectAll() {
    final provider = context.read<ChatProvider>();
    setState(() {
      if (_selectedSessions.length == provider.sessions.length) {
        _selectedSessions.clear();
      } else {
        _selectedSessions.addAll(provider.sessions.map((s) => s.id));
      }
    });
  }

  void _deleteSelected() {
    if (_selectedSessions.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除选中的 ${_selectedSessions.length} 个对话吗？\n删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<ChatProvider>().deleteSessions(_selectedSessions.toList());
              if (context.mounted) {
                Navigator.of(context).pop();
                setState(() {
                  _selectedSessions.clear();
                  _isMultiSelectMode = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMultiSelectMode ? '已选择 ${_selectedSessions.length} 项' : '对话历史'),
        centerTitle: true,
        elevation: 0,
        leading: _isMultiSelectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleMultiSelectMode,
              )
            : null,
        actions: _isMultiSelectMode
            ? [
                IconButton(
                  icon: Icon(
                    _selectedSessions.length ==
                            context.read<ChatProvider>().sessions.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  onPressed: _selectAll,
                  tooltip: '全选',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _selectedSessions.isEmpty ? null : _deleteSelected,
                  tooltip: '删除选中',
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.playlist_add_check),
                  onPressed: _toggleMultiSelectMode,
                  tooltip: '管理',
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _createNewSession(context),
                  tooltip: '新建对话',
                ),
              ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingSessions) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.hasNoSessions) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无对话记录',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _createNewSession(context),
                    icon: const Icon(Icons.add),
                    label: const Text('开始新对话'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.sessions.length,
            itemBuilder: (context, index) {
              final session = provider.sessions[index];
              final isActive = session.id == provider.currentSessionId;
              final isSelected = _selectedSessions.contains(session.id);

              return _SessionListItem(
                session: session,
                isActive: isActive,
                isMultiSelectMode: _isMultiSelectMode,
                isSelected: isSelected,
                onTap: () {
                  if (_isMultiSelectMode) {
                    _toggleSessionSelection(session.id);
                  } else {
                    _selectSession(context, session);
                  }
                },
                onLongPress: () {
                  if (!_isMultiSelectMode) {
                    _toggleMultiSelectMode();
                    _toggleSessionSelection(session.id);
                  }
                },
                onRename: () => _showRenameDialog(context, session),
                onDelete: () => _showDeleteDialog(context, session),
              );
            },
          );
        },
      ),
    );
  }

  void _createNewSession(BuildContext context) async {
    final provider = context.read<ChatProvider>();
    await provider.createNewSession();

    if (widget.onSessionSelected != null) {
      widget.onSessionSelected!();
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _selectSession(BuildContext context, ChatSession session) async {
    final provider = context.read<ChatProvider>();
    await provider.switchSession(session.id);

    if (widget.onSessionSelected != null) {
      widget.onSessionSelected!();
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showRenameDialog(BuildContext context, ChatSession session) {
    final controller = TextEditingController(text: session.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '对话标题',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                await context
                    .read<ChatProvider>()
                    .renameSession(session.id, newTitle);
              }
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ChatSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除 "${session.title}" 吗？\n删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<ChatProvider>().deleteSession(session.id);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 会话列表项组件
class _SessionListItem extends StatelessWidget {
  final ChatSession session;
  final bool isActive;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SessionListItem({
    required this.session,
    required this.isActive,
    this.isMultiSelectMode = false,
    this.isSelected = false,
    required this.onTap,
    this.onLongPress,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: isMultiSelectMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onTap(),
              activeColor: Theme.of(context).primaryColor,
            )
          : Icon(
              isActive ? Icons.chat : Icons.chat_outlined,
              color: isActive
                  ? Theme.of(context).primaryColor
                  : Colors.grey[600],
            ),
      title: Text(
        session.title ?? '新对话',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        '${session.messageCount} 条消息 • ${_formatDate(session.updatedAt)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
      ),
      trailing: isMultiSelectMode
          ? null
          : PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 12),
                      Text('重命名'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('删除', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'rename') {
                  onRename();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
            ),
      selected: isActive,
      selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}分钟前';
      }
      return '${diff.inHours}小时前';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
