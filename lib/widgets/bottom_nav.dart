import 'package:flutter/material.dart';

/// 底部导航栏
class BottomNav extends StatelessWidget {
  final String currentPage;
  final Function(String) onNavigate;

  const BottomNav({
    super.key,
    required this.currentPage,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.today,
                label: '今日',
                page: 'today',
              ),
              _buildNavItem(
                icon: Icons.calendar_view_week,
                label: '打卡',
                page: 'weekly',
              ),
              _buildNavItem(
                icon: Icons.smart_toy,
                label: 'AI',
                page: 'ai',
              ),
              _buildNavItem(
                icon: Icons.person,
                label: '我的',
                page: 'profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String page,
  }) {
    final isActive = currentPage == page;

    return GestureDetector(
      onTap: () => onNavigate(page),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2DD4BF).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF2DD4BF) : Colors.grey[500],
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? const Color(0xFF2DD4BF) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
