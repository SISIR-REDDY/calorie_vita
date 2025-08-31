import 'package:flutter/material.dart';
import '../../ui/app_colors.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfaceLight,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: kSurfaceColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: kSecondaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.bar_chart,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Analytics 📊',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Track your progress',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weekly Overview
                  _buildSectionHeader('Weekly Overview', Icons.calendar_view_week),
                  const SizedBox(height: 16),
                  _buildWeeklyOverviewCard(),
                  const SizedBox(height: 24),
                  
                  // Monthly Stats
                  _buildSectionHeader('Monthly Stats', Icons.trending_up),
                  const SizedBox(height: 16),
                  _buildMonthlyStatsCard(),
                  const SizedBox(height: 24),
                  
                  // Achievements
                  _buildSectionHeader('Achievements', Icons.emoji_events),
                  const SizedBox(height: 16),
                  _buildAchievementsCard(),
                  const SizedBox(height: 100), // Bottom spacing
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: kPrimaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'This Week',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kSuccessColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+12%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kSuccessColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Simple bar chart representation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final height = [60, 80, 45, 90, 70, 85, 75][index];
              final isToday = index == 6;
              
              return Column(
                children: [
                  Container(
                    width: 24,
                    height: height.toDouble(),
                    decoration: BoxDecoration(
                      color: isToday ? kPrimaryColor : kPrimaryColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isToday ? kPrimaryColor : kTextTertiary,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Text(
                'Monthly Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Avg Daily', '1,850', 'kcal', kAccentColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem('Goal Met', '23', 'days', kSuccessColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem('Streak', '5', 'days', kInfoColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.trending_up,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: kTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAchievementsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Text(
                'Recent Achievements',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Achievement items
          _buildAchievementItem(
            '🔥 7-Day Streak',
            'You\'ve logged meals for 7 consecutive days!',
            kAccentColor,
            Icons.local_fire_department,
          ),
          const SizedBox(height: 16),
          _buildAchievementItem(
            '🎯 Goal Achiever',
            'You met your daily calorie goal 5 times this week!',
            kSuccessColor,
            Icons.emoji_events,
          ),
          const SizedBox(height: 16),
          _buildAchievementItem(
            '💧 Hydration Master',
            'You drank 8 glasses of water for 3 days in a row!',
            kInfoColor,
            Icons.water_drop,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(String title, String description, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: kTextSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 