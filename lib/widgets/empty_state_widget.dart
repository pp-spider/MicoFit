import 'package:flutter/material.dart';

/// 统一空状态组件
/// 提供一致的空状态视觉风格，支持多种预设类型
class EmptyStateWidget extends StatelessWidget {
  /// 主图标
  final IconData icon;

  /// 图标背景色
  final Color? iconBackgroundColor;

  /// 图标颜色
  final Color? iconColor;

  /// 主标题
  final String title;

  /// 副标题/描述
  final String? subtitle;

  /// 操作按钮文字
  final String? actionText;

  /// 操作按钮回调
  final VoidCallback? onAction;

  /// 次要操作文字
  final String? secondaryActionText;

  /// 次要操作回调
  final VoidCallback? onSecondaryAction;

  /// 是否显示品牌Logo
  final bool showBrandLogo;

  /// 自定义内容
  final Widget? customContent;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    this.iconBackgroundColor,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.secondaryActionText,
    this.onSecondaryAction,
    this.showBrandLogo = false,
    this.customContent,
  });

  /// 训练计划空状态预设
  factory EmptyStateWidget.workout({
    VoidCallback? onGenerate,
  }) {
    return EmptyStateWidget(
      icon: Icons.fitness_center_outlined,
      iconBackgroundColor: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
      iconColor: const Color(0xFF2DD4BF),
      title: '今日暂无训练计划',
      subtitle: '点击下方按钮生成今日训练计划',
      actionText: '生成训练计划',
      onAction: onGenerate,
    );
  }

  /// 个人资料空状态预设
  factory EmptyStateWidget.profile({
    VoidCallback? onComplete,
  }) {
    return EmptyStateWidget(
      icon: Icons.person_outline,
      iconBackgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
      iconColor: const Color(0xFF8B5CF6),
      title: '尚未完善个人信息',
      subtitle: '完善个人信息，获取更精准的训练计划',
      actionText: '去录入',
      onAction: onComplete,
    );
  }

  /// 历史记录空状态预设
  factory EmptyStateWidget.history({
    VoidCallback? onRefresh,
  }) {
    return EmptyStateWidget(
      icon: Icons.history,
      iconBackgroundColor: Colors.orange.withValues(alpha: 0.1),
      iconColor: Colors.orange,
      title: '暂无历史记录',
      subtitle: '完成训练后，这里会显示您的训练历史',
      actionText: '去训练',
      onAction: onRefresh,
    );
  }

  /// 聊天会话空状态预设
  factory EmptyStateWidget.chat({
    VoidCallback? onStartChat,
  }) {
    return EmptyStateWidget(
      icon: Icons.chat_bubble_outline,
      iconBackgroundColor: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
      iconColor: const Color(0xFF2DD4BF),
      title: '开始与 AI 教练对话',
      subtitle: '随时咨询健身问题，获取专业建议',
      actionText: '开始对话',
      onAction: onStartChat,
    );
  }

  /// 网络错误空状态预设
  factory EmptyStateWidget.networkError({
    VoidCallback? onRetry,
  }) {
    return EmptyStateWidget(
      icon: Icons.wifi_off_outlined,
      iconBackgroundColor: Colors.red.withValues(alpha: 0.1),
      iconColor: Colors.red,
      title: '网络连接失败',
      subtitle: '请检查网络设置后重试',
      actionText: '重试',
      onAction: onRetry,
    );
  }

  /// 数据加载失败空状态预设
  factory EmptyStateWidget.loadError({
    VoidCallback? onRetry,
  }) {
    return EmptyStateWidget(
      icon: Icons.error_outline,
      iconBackgroundColor: Colors.orange.withValues(alpha: 0.1),
      iconColor: Colors.orange,
      title: '数据加载失败',
      subtitle: '请检查网络连接或稍后重试',
      actionText: '重试',
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 品牌Logo（可选）
            if (showBrandLogo) ...[
              _buildBrandLogo(),
              const SizedBox(height: 32),
            ],

            // 主图标
            _buildIcon(),
            const SizedBox(height: 24),

            // 标题
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF115E59),
              ),
              textAlign: TextAlign.center,
            ),

            // 副标题
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // 自定义内容
            if (customContent != null) ...[
              const SizedBox(height: 24),
              customContent!,
            ],

            // 主要操作按钮
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DD4BF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionText!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            // 次要操作
            if (secondaryActionText != null && onSecondaryAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(
                  secondaryActionText!,
                  style: const TextStyle(
                    color: Color(0xFF115E59),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: iconBackgroundColor ?? const Color(0xFF2DD4BF).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 48,
        color: iconColor ?? const Color(0xFF2DD4BF),
      ),
    );
  }

  Widget _buildBrandLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.fitness_center,
        size: 36,
        color: Colors.white,
      ),
    );
  }
}

/// 快捷提示卡片（用于空状态下的快捷操作）
class QuickPromptCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const QuickPromptCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
