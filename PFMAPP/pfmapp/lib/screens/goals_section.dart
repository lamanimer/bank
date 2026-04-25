import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/goal.dart';
import '../../services/session.dart';

class GoalsSection extends StatelessWidget {
  final List<Goal> goals;
  final VoidCallback onGoalAdded;
  final VoidCallback onGoalsUpdated;

  const GoalsSection({
    super.key,
    required this.goals,
    required this.onGoalAdded,
    required this.onGoalsUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onGoalAdded,
                icon: const Icon(Icons.add, color: Color(0xFF1E1E1E)),
                label: Text(
                  'Add Goal',
                  style: GoogleFonts.baloo2(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFE06B),
                  foregroundColor: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (goals.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 48,
                  color: const Color(0xFF8F7BFF).withOpacity(0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  "No goals yet",
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF3A1B52).withOpacity(0.8),
                  ),
                ),
                Text(
                  "Tap 'Add Goal' to start saving towards your dreams ✨",
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    color: const Color(0xFF3A1B52).withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: goals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final goal = goals[index];
              return _GoalCard(
                goal: goal,
                onEdit: () {
                  onGoalsUpdated();
                },
                onDelete: () async {
                  final userId = Session.getUserId(await Session.loadUser());
                  if (userId != null) {
                    await Session.deleteGoal(userId: userId, goalId: goal.id);
                  }
                  onGoalsUpdated();
                },
              );
            },
          ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.onEdit,
    required this.onDelete,
  });

  String _getProgressText(Goal goal) {
    if (goal.isCompleted) return '🎉 Completed!';
    return '${(goal.progress * 100).toStringAsFixed(0)}%';
  }

  Color _getProgressColor(Goal goal) {
    if (goal.isCompleted) return Colors.green.shade400;
    if (goal.progress > 0.8) return Colors.orange.shade400;
    return const Color(0xFF8F7BFF);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _getProgressColor(goal).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              goal.isCompleted ? Icons.celebration : Icons.flag,
              color: _getProgressColor(goal),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2B103C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(goal.targetDate),
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    color: const Color(0xFF3A1B52).withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: goal.progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(goal),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getProgressText(goal),
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _getProgressColor(goal),
                      ),
                    ),
                    Text(
                      'AED ${goal.remaining.toStringAsFixed(0)} left',
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        color: const Color(0xFF3A1B52).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, color: Color(0xFF8F7BFF)),
                tooltip: 'Edit Goal',
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade400,
                ),
                tooltip: 'Delete Goal',
              ),
            ],
          ),
        ],
      ),
    );
  }
}