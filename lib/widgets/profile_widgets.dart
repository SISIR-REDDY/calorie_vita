import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/simple_streak_system.dart';
import '../models/reward_system.dart';
import '../ui/app_colors.dart';

/// Profile widgets for streaks and rewards
class ProfileWidgets {
  /// Build loading streak card
  static Widget buildLoadingStreakCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build goal streak card
  static Widget buildGoalStreakCard(BuildContext context, GoalStreak streak) {
    final isAchievedToday = streak.achievedToday;
    final currentStreak = streak.currentStreak;
    final longestStreak = streak.longestStreak;
    
    // Get goal-specific colors (same as home screen)
    final goalColor = _getGoalColor(streak.goalType);
    final progressColor = isAchievedToday ? kSuccessColor : goalColor;
    
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAchievedToday
              ? kSuccessColor.withValues(alpha: 0.4)
              : goalColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: goalColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Goal icon (same style as home screen)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: progressColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getGoalIcon(streak.goalType),
              color: progressColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Goal info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak.goalType.displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Current: $currentStreak days',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: progressColor,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Best: $longestStreak days',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: progressColor.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Achievement indicator (same as home screen)
          if (isAchievedToday)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kSuccessColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 14,
              ),
            ),
        ],
      ),
    );
  }

  /// Get icon for goal type
  static IconData _getGoalIcon(DailyGoalType goalType) {
    switch (goalType) {
      case DailyGoalType.calorieGoal:
        return Icons.local_fire_department;
      case DailyGoalType.steps:
        return Icons.directions_walk;
      case DailyGoalType.exercise:
        return Icons.fitness_center;
      case DailyGoalType.waterIntake:
        return Icons.water_drop;
      case DailyGoalType.sleep:
        return Icons.bedtime;
      case DailyGoalType.weightTracking:
        return Icons.monitor_weight;
    }
  }

  /// Build rewards section
  static Widget buildRewardsSection(BuildContext context, UserProgress? userProgress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.15),
            Colors.deepOrange.withValues(alpha: 0.12),
            Colors.amber.withValues(alpha: 0.08),
            Colors.orange.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange, 
                      Colors.deepOrange, 
                      Colors.amber
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.emoji_events,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rewards & Achievements',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (userProgress != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [userProgress.currentLevel.color, userProgress.currentLevel.color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: userProgress.currentLevel.color.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    userProgress.currentLevel.title,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Level progress
          if (userProgress != null) ...[
            _buildLevelProgress(context, userProgress),
            const SizedBox(height: 20),
          ],
          
          // Recent rewards
          _buildRecentRewards(context, userProgress),
        ],
      ),
    );
  }

  /// Build level progress
  static Widget _buildLevelProgress(BuildContext context, UserProgress userProgress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            userProgress.currentLevel.color.withValues(alpha: 0.15),
            userProgress.currentLevel.color.withValues(alpha: 0.08),
            userProgress.currentLevel.color.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: userProgress.currentLevel.color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: userProgress.currentLevel.color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                userProgress.currentLevel.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${userProgress.currentLevel.title}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: userProgress.currentLevel.color,
                      ),
                    ),
                    Text(
                      '${userProgress.currentStreak} day streak',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (userProgress.daysToNextLevel > 0)
                Text(
                  '${userProgress.daysToNextLevel} days to next level',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
            ],
          ),
          if (userProgress.daysToNextLevel > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: userProgress.levelProgress,
              backgroundColor: userProgress.currentLevel.color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(userProgress.currentLevel.color),
              minHeight: 8,
            ),
          ],
        ],
      ),
    );
  }

  /// Build recent rewards
  static Widget _buildRecentRewards(BuildContext context, UserProgress? userProgress) {
    if (userProgress == null || userProgress.unlockedRewards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.08),
            Colors.amber.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 28,
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            Text(
              'No rewards earned yet',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Keep building streaks to unlock achievements!',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show recent rewards (limit to 6)
    final recentRewards = userProgress.unlockedRewards.take(6).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Achievements',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recentRewards.map((reward) => _buildRewardBadge(reward)).toList(),
        ),
        if (userProgress.unlockedRewards.length > 6) ...[
          const SizedBox(height: 8),
            Text(
              '+${userProgress.unlockedRewards.length - 6} more achievements',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ],
    );
  }

  /// Build reward badge
  static Widget _buildRewardBadge(UserReward reward) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            reward.color.withValues(alpha: 0.15),
            reward.color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: reward.color.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: reward.color.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reward.emoji,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 6),
          Text(
            reward.title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: reward.color,
            ),
          ),
        ],
      ),
    );
  }

  /// Get goal-specific color (same as home screen)
  static Color _getGoalColor(DailyGoalType goalType) {
    switch (goalType) {
      case DailyGoalType.calorieGoal:
        return kAccentColor; // Amber #F59E0B (same as home screen)
      case DailyGoalType.steps:
        return kSecondaryColor; // Emerald green #10B981 (same as home screen)
      case DailyGoalType.exercise:
        return Colors.deepOrange; // Deep Orange #FF5722 (vibrant and energetic)
      case DailyGoalType.waterIntake:
        return Colors.blue; // Original blue (same as home screen)
      case DailyGoalType.sleep:
        return kPrimaryColor; // Indigo #6366F1
      case DailyGoalType.weightTracking:
        return kTextSecondary; // Medium slate #64748B
    }
  }
}
