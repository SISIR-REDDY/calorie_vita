import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/simple_streak_system.dart';
import '../ui/app_colors.dart';

/// Main streak summary widget for home screen
class StreakSummaryWidget extends StatelessWidget {
  final UserStreakSummary streakSummary;
  final VoidCallback? onTap;

  const StreakSummaryWidget({
    super.key,
    required this.streakSummary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kPrimaryColor,
            kPrimaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Streaks',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${streakSummary.totalActiveStreaks} active goals',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              if (onTap != null)
                IconButton(
                  onPressed: onTap,
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Active streaks count
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Active Today',
                  '${streakSummary.totalActiveStreaks}',
                  Icons.local_fire_department,
                  Colors.white,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Best Streak',
                  '${streakSummary.longestOverallStreak}',
                  Icons.trending_up,
                  Colors.white,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Days',
                  '${streakSummary.totalDaysActive}',
                  Icons.calendar_today,
                  Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: color.withOpacity(0.8),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Individual goal streak card with enhanced empty state
class GoalStreakCard extends StatefulWidget {
  final GoalStreak streak;
  final VoidCallback? onTap;
  final bool isLoading;

  const GoalStreakCard({
    super.key,
    required this.streak,
    this.onTap,
    this.isLoading = false,
  });

  @override
  State<GoalStreakCard> createState() => _GoalStreakCardState();
}

class _GoalStreakCardState extends State<GoalStreakCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingCard(context);
    }

    final isEmpty = widget.streak.currentStreak == 0 && widget.streak.longestStreak == 0;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.streak.achievedToday 
                        ? widget.streak.goalType.color.withOpacity(0.3)
                        : isEmpty 
                            ? Colors.grey.withOpacity(0.15)
                            : Colors.grey.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.streak.achievedToday 
                          ? widget.streak.goalType.color.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with emoji and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.streak.goalType.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.streak.goalType.displayName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.streak.achievedToday 
                                ? widget.streak.goalType.color.withOpacity(0.1)
                                : isEmpty
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.streak.achievedToday 
                                ? 'Done' 
                                : isEmpty 
                                    ? 'Start'
                                    : 'Pending',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.streak.achievedToday 
                                  ? widget.streak.goalType.color
                                  : isEmpty
                                      ? Colors.orange
                                      : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Streak information
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Streak',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                isEmpty ? '0 days' : '${widget.streak.currentStreak} days',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isEmpty 
                                      ? Colors.grey.withOpacity(0.6)
                                      : widget.streak.goalType.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Best Streak',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                isEmpty ? '0 days' : '${widget.streak.longestStreak} days',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isEmpty
                                      ? Colors.grey.withOpacity(0.6)
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Status message with enhanced empty state
                    Text(
                      isEmpty 
                          ? 'Start your streak today!'
                          : widget.streak.statusMessage,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isEmpty
                            ? Colors.orange.withOpacity(0.8)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 100,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              Container(
                width: 50,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 60,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 60,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: 120,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Weekly streak calendar widget
class WeeklyStreakCalendar extends StatelessWidget {
  final Map<DailyGoalType, GoalStreak> goalStreaks;
  final DateTime weekStart;

  const WeeklyStreakCalendar({
    super.key,
    required this.goalStreaks,
    required this.weekStart,
  });

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (index) => weekStart.add(Duration(days: index)));
    final today = DateTime.now();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          // Calendar grid
          Row(
            children: days.map((day) {
              final isToday = day.day == today.day && day.month == today.month && day.year == today.year;
              final isPast = day.isBefore(today);
              final isFuture = day.isAfter(today);
              
              // Count how many goals were achieved on this day
              int achievedCount = 0;
              if (isPast || isToday) {
                for (final streak in goalStreaks.values) {
                  if (streak.lastAchievedDate.day == day.day && 
                      streak.lastAchievedDate.month == day.month && 
                      streak.lastAchievedDate.year == day.year) {
                    achievedCount++;
                  }
                }
              }
              
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      _getDayName(day.weekday),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _getDayColor(achievedCount, goalStreaks.length, isToday, isFuture),
                        borderRadius: BorderRadius.circular(8),
                        border: isToday ? Border.all(color: kPrimaryColor, width: 2) : null,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: _getDayTextColor(achievedCount, goalStreaks.length, isToday, isFuture),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$achievedCount/${goalStreaks.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  Color _getDayColor(int achievedCount, int totalGoals, bool isToday, bool isFuture) {
    if (isFuture) return Colors.grey.withOpacity(0.1);
    if (achievedCount == 0) return Colors.grey.withOpacity(0.2);
    if (achievedCount == totalGoals) return Colors.green;
    if (achievedCount >= totalGoals / 2) return Colors.orange;
    return Colors.red.withOpacity(0.3);
  }

  Color _getDayTextColor(int achievedCount, int totalGoals, bool isToday, bool isFuture) {
    if (isFuture) return Colors.grey;
    if (achievedCount == 0) return Colors.grey;
    return Colors.white;
  }
}

/// Streak motivation widget
class StreakMotivationWidget extends StatelessWidget {
  final UserStreakSummary streakSummary;

  const StreakMotivationWidget({
    super.key,
    required this.streakSummary,
  });

  @override
  Widget build(BuildContext context) {
    final mostImpressive = streakSummary.mostImpressiveStreak;
    
    if (mostImpressive == null || mostImpressive.currentStreak == 0) {
      return _buildStartMotivation(context);
    }
    
    return _buildStreakMotivation(context, mostImpressive);
  }

  Widget _buildStartMotivation(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kAccentColor.withOpacity(0.1),
            kAccentColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kAccentColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          const Text(
            '🌱',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            'Start Your Journey',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your first daily goal to start building streaks!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStreakMotivation(BuildContext context, GoalStreak streak) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            streak.goalType.color.withOpacity(0.1),
            streak.goalType.color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: streak.goalType.color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            streak.goalType.emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            '${streak.currentStreak} Day Streak!',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep up the great work with ${streak.goalType.displayName}!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
