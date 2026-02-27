import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/friend.dart';
import '../providers/friend_provider.dart';
import '../widgets/empty_state_widget.dart';

/// 排行榜页面
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    // 加载默认排行榜
    _loadLeaderboard(0);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadLeaderboard(_tabController.index);
    }
  }

  Future<void> _loadLeaderboard(int index) async {
    final types = [
      LeaderboardType.weeklyStreak,
      LeaderboardType.monthlyDuration,
      LeaderboardType.totalDays,
      LeaderboardType.level,
    ];
    await context.read<FriendProvider>().loadLeaderboard(types[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Tab Bar
            _buildTabBar(),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  LeaderboardList(type: LeaderboardType.weeklyStreak),
                  LeaderboardList(type: LeaderboardType.monthlyDuration),
                  LeaderboardList(type: LeaderboardType.totalDays),
                  LeaderboardList(type: LeaderboardType.level),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF115E59)),
          ),
          const SizedBox(width: 8),
          const Text(
            '排行榜',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115E59),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          color: const Color(0xFF2DD4BF),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF115E59),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: '连续打卡'),
          Tab(text: '本月时长'),
          Tab(text: '总天数'),
          Tab(text: '等级'),
        ],
      ),
    );
  }
}

/// 排行榜列表组件
class LeaderboardList extends StatelessWidget {
  final LeaderboardType type;

  const LeaderboardList({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final leaderboard = provider.leaderboard;
        if (leaderboard == null) {
          return EmptyStateWidget(
            icon: Icons.emoji_events_outlined,
            title: '暂无数据',
            subtitle: '排行榜数据加载中...',
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadLeaderboard(type),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leaderboard.entries.length + 1,
            itemBuilder: (context, index) {
              if (index == leaderboard.entries.length) {
                // 我的排名
                return _buildMyRank(leaderboard);
              }
              return _buildRankItem(leaderboard.entries[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildRankItem(LeaderboardEntry entry) {
    // 前三名特殊样式
    final isTop3 = entry.rank <= 3;
    final rankColors = [
      const Color(0xFFFFD700), // 金牌
      const Color(0xFFC0C0C0), // 银牌
      const Color(0xFFCD7F32), // 铜牌
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? const Color(0xFF2DD4BF).withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: entry.isCurrentUser
            ? Border.all(color: const Color(0xFF2DD4BF), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 排名
          Container(
            width: 40,
            height: 40,
            decoration: isTop3
                ? BoxDecoration(
                    color: rankColors[entry.rank - 1].withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  )
                : null,
            child: Center(
              child: isTop3
                  ? Icon(
                      Icons.emoji_events,
                      color: rankColors[entry.rank - 1],
                      size: 24,
                    )
                  : Text(
                      '${entry.rank}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // 头像
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                  const Color(0xFF14B8A6).withValues(alpha: 0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.nickname.substring(0, 1),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF115E59),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.nickname,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF115E59),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2DD4BF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '我',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Lv.${entry.level}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // 数值
          Text(
            entry.formattedValue,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2DD4BF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRank(Leaderboard leaderboard) {
    if (leaderboard.myRank == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '我的排名',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            '第 ${leaderboard.myRank} 名',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
