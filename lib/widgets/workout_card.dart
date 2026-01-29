import 'package:flutter/material.dart';
import '../models/workout.dart';

/// 训练计划卡片
class WorkoutCard extends StatefulWidget {
  final WorkoutPlan workoutPlan;
  final int refreshCount;
  final VoidCallback onRefresh;
  final VoidCallback onStartWorkout;

  const WorkoutCard({
    super.key,
    required this.workoutPlan,
    required this.refreshCount,
    required this.onRefresh,
    required this.onStartWorkout,
  });

  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<WorkoutCard>
    with SingleTickerProviderStateMixin {
  String? expandedModuleId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void toggleModule(String moduleId) {
    setState(() {
      if (expandedModuleId == moduleId) {
        expandedModuleId = null;
      } else {
        expandedModuleId = moduleId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // AI Badge & Refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sync,
                        size: 16,
                        color: Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '根据昨日反馈自动优化',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.refreshCount > 0 ? widget.onRefresh : null,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text('换一组 (${widget.refreshCount})'),
                  style: TextButton.styleFrom(
                    foregroundColor: widget.refreshCount > 0
                        ? Colors.grey[600]
                        : Colors.grey[300],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              widget.workoutPlan.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF115E59),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.workoutPlan.subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),

            const SizedBox(height: 24),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatItem(
                  Icons.access_time,
                  '${widget.workoutPlan.totalDuration}分钟',
                ),
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                _buildStatItem(Icons.location_on, widget.workoutPlan.scene),
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                _buildStatItem(Icons.bolt, 'RPE ${widget.workoutPlan.rpe}'),
              ],
            ),

            const SizedBox(height: 24),

            // Modules
            ...widget.workoutPlan.modules.asMap().entries.map((entry) {
              final index = entry.key;
              final module = entry.value;
              return _buildModule(module, index);
            }),

            // AI Note
            if (widget.workoutPlan.aiNote != null) ...[
              const SizedBox(height: 24),
              _buildAIBubble(widget.workoutPlan.aiNote!),
            ],

            const SizedBox(height: 24),

            // Start Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onStartWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DD4BF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF2DD4BF).withOpacity(0.4),
                ),
                child: const Text(
                  '开始训练',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildModule(WorkoutModule module, int index) {
    final isExpanded = expandedModuleId == module.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => toggleModule(module.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2DD4BF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF115E59),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          module.exercises.map((e) => e.name).join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${module.duration}min',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: isExpanded ? 0.25 : 0,
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),

              // Expanded Content
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: isExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: module.exercises.map((exercise) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    exercise.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF115E59),
                                    ),
                                  ),
                                  Text(
                                    '${exercise.duration}秒',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIBubble(String note) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb,
            color: Color(0xFF8B5CF6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF5B21B6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
