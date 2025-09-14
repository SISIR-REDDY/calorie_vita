import 'package:flutter/material.dart';
import '../models/reward_system.dart';
import '../services/reward_notification_service.dart';

/// Widget to display reward notifications with animations
class RewardNotificationWidget extends StatefulWidget {
  final Widget child;
  
  const RewardNotificationWidget({
    super.key,
    required this.child,
  });

  @override
  State<RewardNotificationWidget> createState() => _RewardNotificationWidgetState();
}

class _RewardNotificationWidgetState extends State<RewardNotificationWidget>
    with TickerProviderStateMixin {
  final RewardNotificationService _notificationService = RewardNotificationService();
  
  final List<RewardNotification> _notifications = [];
  final List<LevelUpNotification> _levelUpNotifications = [];
  
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _levelUpController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _levelUpScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _levelUpController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _levelUpScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _levelUpController,
      curve: Curves.elasticOut,
    ));
    
    _setupNotificationListeners();
  }

  void _setupNotificationListeners() {
    _notificationService.notificationStream.listen((notification) {
      setState(() {
        _notifications.add(notification);
      });
      _showNotification();
    });
    
    _notificationService.levelUpStream.listen((levelUpNotification) {
      setState(() {
        _levelUpNotifications.add(levelUpNotification);
      });
      _showLevelUpNotification();
    });
  }

  void _showNotification() async {
    _slideController.forward();
    _scaleController.forward();
    
    await Future.delayed(const Duration(seconds: 3));
    
    _slideController.reverse();
    _scaleController.reverse();
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted && _notifications.isNotEmpty) {
      setState(() {
        _notifications.removeAt(0);
      });
    }
  }

  void _showLevelUpNotification() async {
    _levelUpController.forward();
    
    await Future.delayed(const Duration(seconds: 4));
    
    _levelUpController.reverse();
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted && _levelUpNotifications.isNotEmpty) {
      setState(() {
        _levelUpNotifications.removeAt(0);
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _levelUpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Reward notifications
        if (_notifications.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 16,
            child: AnimatedBuilder(
              animation: Listenable.merge([_slideController, _scaleController]),
              builder: (context, child) {
                final notification = _notifications.first;
                return SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildRewardNotification(notification),
                  ),
                );
              },
            ),
          ),
        
        // Level up notifications
        if (_levelUpNotifications.isNotEmpty)
          Center(
            child: AnimatedBuilder(
              animation: _levelUpController,
              builder: (context, child) {
                final levelUpNotification = _levelUpNotifications.first;
                return ScaleTransition(
                  scale: _levelUpScaleAnimation,
                  child: _buildLevelUpNotification(levelUpNotification),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRewardNotification(RewardNotification notification) {
    final reward = notification.reward;
    
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            reward.color,
            reward.color.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: reward.color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Reward emoji
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                reward.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Reward details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Achievement Unlocked!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reward.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  reward.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Achievement Unlocked!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelUpNotification(LevelUpNotification notification) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFFA500),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Level up emoji
          const Text(
            '🎉',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          
          // Level up text
          const Text(
            'LEVEL UP!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          
          // Old level
          Text(
            notification.oldLevel.title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          
          // Arrow
          const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white,
            size: 24,
          ),
          
          // New level
          Text(
            notification.newLevel.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // New level emoji
          Text(
            notification.newLevel.emoji,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 16),
          
          // Total XP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${notification.totalXp} Total XP',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak notification widget
class StreakNotificationWidget extends StatelessWidget {
  final ActivityType activityType;
  final int streakDays;
  final VoidCallback? onTap;

  const StreakNotificationWidget({
    super.key,
    required this.activityType,
    required this.streakDays,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Colors.orange,
              Colors.red,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.local_fire_department,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_getActivityName(activityType)} Streak!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$streakDays days in a row',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$streakDays',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getActivityName(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.mealLogging:
        return 'Meal Logging';
      case ActivityType.exercise:
        return 'Exercise';
      case ActivityType.calorieGoal:
        return 'Calorie Goals';
      case ActivityType.steps:
        return 'Steps';
      case ActivityType.weightCheckIn:
        return 'Weight Tracking';
      case ActivityType.meditation:
        return 'Meditation';
      case ActivityType.dailyGoalCompletion:
        return 'Daily Goals';
    }
  }
}
