import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/reward_system.dart';
import '../models/user_achievement.dart';
import '../models/daily_summary.dart';
import '../models/food_entry.dart';
import '../models/health_data.dart';

/// Comprehensive rewards and achievements service
class RewardsService {
  static final RewardsService _instance = RewardsService._internal();
  factory RewardsService() => _instance;
  RewardsService._internal();

  // Stream controllers for real-time updates
  final StreamController<UserProgress> _progressController = StreamController<UserProgress>.broadcast();
  final StreamController<List<UserReward>> _newRewardsController = StreamController<List<UserReward>>.broadcast();
  final StreamController<LevelUpEvent> _levelUpController = StreamController<LevelUpEvent>.broadcast();

  // Getters for streams
  Stream<UserProgress> get progressStream => _progressController.stream;
  Stream<List<UserReward>> get newRewardsStream => _newRewardsController.stream;
  Stream<LevelUpEvent> get levelUpStream => _levelUpController.stream;

  // Current user progress
  UserProgress _currentProgress = UserProgress.initial();
  
  // Activity tracking
  final Map<String, ActivityStreak> _activityStreaks = {};
  final Map<String, int> _lifetimeTotals = {};
  final Map<String, int> _yearlyTotals = {};
  
  // Challenge tracking
  final Map<String, ChallengeProgress> _challenges = {};
  
  // Anti-gaming measures
  final Map<String, List<DateTime>> _recentActivities = {};
  static const int maxRetroactiveEntries = 3;
  static const Duration maxRetroactiveTime = Duration(hours: 24);

  /// Initialize the rewards service
  Future<void> initialize() async {
    // Load user progress from storage
    await _loadUserProgress();
    
    // Initialize activity streaks
    _initializeActivityStreaks();
    
    // Initialize challenges
    _initializeChallenges();
    
    // Start daily reset timer
    _startDailyResetTimer();
  }

  /// Process a new activity and calculate rewards
  Future<ActivityResult> processActivity({
    required ActivityType activityType,
    required Map<String, dynamic> activityData,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    
    // Anti-gaming validation
    if (!_validateActivity(activityType, activityData, now)) {
      return ActivityResult(
        success: false,
        message: 'Invalid activity data detected',
        xpEarned: 0,
        newRewards: [],
        levelUp: null,
      );
    }

    // Calculate base XP
    int baseXp = _calculateBaseXp(activityType, activityData);
    
    // Apply streak multipliers
    double streakMultiplier = _getStreakMultiplier(activityType);
    int totalXp = (baseXp * streakMultiplier).round();
    
    // Update streaks
    _updateStreak(activityType, now);
    
    // Update lifetime and yearly totals
    _updateTotals(activityType, activityData);
    
    // Update progress based on streaks (no points system)
    // Streaks are calculated separately in analytics service
    
    // Check for level up
    LevelUpEvent? levelUp = _checkLevelUp();
    
    // Check for new rewards
    List<UserReward> newRewards = _checkForNewRewards(activityType, activityData);
    
    // Update challenges
    _updateChallenges(activityType, activityData);
    
    // Emit updates
    _progressController.add(_currentProgress);
    if (newRewards.isNotEmpty) {
      _newRewardsController.add(newRewards);
    }
    if (levelUp != null) {
      _levelUpController.add(levelUp);
    }
    
    // Save progress
    await _saveUserProgress();
    
    return ActivityResult(
      success: true,
      message: 'Activity processed successfully',
      xpEarned: totalXp,
      newRewards: newRewards,
      levelUp: levelUp,
    );
  }

  /// Get current user progress
  UserProgress get currentProgress => _currentProgress;

  /// Get activity streak for specific activity
  ActivityStreak getActivityStreak(ActivityType activityType) {
    return _activityStreaks[activityType.name] ?? ActivityStreak.initial(activityType);
  }

  /// Get all unlocked rewards
  List<UserReward> getUnlockedRewards() {
    return _currentProgress.unlockedRewards;
  }

  /// Get available challenges
  List<Challenge> getAvailableChallenges() {
    return _challenges.values.map((cp) => cp.challenge).toList();
  }

  /// Get challenge progress
  ChallengeProgress? getChallengeProgress(String challengeId) {
    return _challenges[challengeId];
  }

  /// Calculate base XP for activity
  int _calculateBaseXp(ActivityType activityType, Map<String, dynamic> activityData) {
    switch (activityType) {
      case ActivityType.mealLogging:
        return 10; // +10 XP per meal
      case ActivityType.exercise:
        return 20; // +20 XP per workout
      case ActivityType.calorieGoal:
        return 20; // +20 XP for meeting calorie goal
      case ActivityType.steps:
        return 5; // +5 XP per 1000 steps
      case ActivityType.weightCheckIn:
        return 15; // +15 XP per weight log
      case ActivityType.meditation:
        return 15; // +15 XP per meditation session
      case ActivityType.dailyGoalCompletion:
        return 50; // +50 XP for completing all daily goals
    }
  }

  /// Get streak multiplier for activity
  double _getStreakMultiplier(ActivityType activityType) {
    final streak = getActivityStreak(activityType);
    if (streak.currentStreak >= 365) return 2.0; // +100% XP
    if (streak.currentStreak >= 100) return 1.5; // +50% XP
    if (streak.currentStreak >= 30) return 1.2; // +20% XP
    if (streak.currentStreak >= 7) return 1.1; // +10% XP
    return 1.0;
  }

  /// Update activity streak
  void _updateStreak(ActivityType activityType, DateTime timestamp) {
    final streakKey = activityType.name;
    final today = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (_activityStreaks.containsKey(streakKey)) {
      final streak = _activityStreaks[streakKey]!;
      final lastActivity = DateTime(
        streak.lastActivityDate.year,
        streak.lastActivityDate.month,
        streak.lastActivityDate.day,
      );
      
      if (today.difference(lastActivity).inDays == 1) {
        // Consecutive day - increment streak
        _activityStreaks[streakKey] = streak.copyWith(
          currentStreak: streak.currentStreak + 1,
          lastActivityDate: timestamp,
        );
      } else if (today.difference(lastActivity).inDays == 0) {
        // Same day - no change to streak
        _activityStreaks[streakKey] = streak.copyWith(
          lastActivityDate: timestamp,
        );
      } else if (today.difference(lastActivity).inDays == 2) {
        // One day gap - use grace period
        _activityStreaks[streakKey] = streak.copyWith(
          currentStreak: streak.currentStreak + 1,
          lastActivityDate: timestamp,
        );
      } else {
        // Streak broken - reset
        _activityStreaks[streakKey] = ActivityStreak.initial(activityType).copyWith(
          lastActivityDate: timestamp,
        );
      }
    } else {
      // First activity
      _activityStreaks[streakKey] = ActivityStreak.initial(activityType).copyWith(
        currentStreak: 1,
        lastActivityDate: timestamp,
      );
    }
  }

  /// Update lifetime and yearly totals
  void _updateTotals(ActivityType activityType, Map<String, dynamic> activityData) {
    final now = DateTime.now();
    final year = now.year.toString();
    
    // Update lifetime totals
    _lifetimeTotals[activityType.name] = 
        (_lifetimeTotals[activityType.name] ?? 0) + 1;
    
    // Update yearly totals
    _yearlyTotals['${activityType.name}_$year'] = 
        (_yearlyTotals['${activityType.name}_$year'] ?? 0) + 1;
  }

  /// Check for level up
  LevelUpEvent? _checkLevelUp() {
    final newLevel = RewardSystem.getCurrentLevel(_currentProgress.currentStreak);
    if (newLevel != _currentProgress.currentLevel) {
      final oldLevel = _currentProgress.currentLevel;
      _currentProgress = _currentProgress.copyWith(
        currentLevel: newLevel,
        daysToNextLevel: RewardSystem.getDaysToNextLevel(
          _currentProgress.currentStreak,
          newLevel,
        ),
        levelProgress: RewardSystem.getLevelProgress(
          _currentProgress.currentStreak,
          newLevel,
        ),
      );
      
      return LevelUpEvent(
        oldLevel: oldLevel,
        newLevel: newLevel,
        totalXp: 0, // No points system
      );
    }
    return null;
  }

  /// Check for new rewards
  List<UserReward> _checkForNewRewards(ActivityType activityType, Map<String, dynamic> activityData) {
    List<UserReward> newRewards = [];
    final allRewards = RewardSystem.getAllRewards();
    
    for (final reward in allRewards) {
      if (_currentProgress.unlockedRewards.any((r) => r.id == reward.id)) {
        continue; // Already unlocked
      }
      
      if (_shouldUnlockReward(reward, activityType, activityData)) {
        newRewards.add(reward.copyWith(
          isUnlocked: true,
          earnedAt: DateTime.now(),
        ));
      }
    }
    
    if (newRewards.isNotEmpty) {
      _currentProgress = _currentProgress.copyWith(
        unlockedRewards: [..._currentProgress.unlockedRewards, ...newRewards],
      );
    }
    
    return newRewards;
  }

  /// Check if reward should be unlocked
  bool _shouldUnlockReward(UserReward reward, ActivityType activityType, Map<String, dynamic> activityData) {
    switch (reward.id) {
      // Streak rewards
      case 'streak_7':
        return getActivityStreak(activityType).currentStreak >= 7;
      case 'streak_30':
        return getActivityStreak(activityType).currentStreak >= 30;
      case 'streak_100':
        return getActivityStreak(activityType).currentStreak >= 100;
      case 'streak_365':
        return getActivityStreak(activityType).currentStreak >= 365;
      
      // Milestone rewards
      case 'meals_10':
        return (_lifetimeTotals[ActivityType.mealLogging.name] ?? 0) >= 10;
      case 'meals_100':
        return (_lifetimeTotals[ActivityType.mealLogging.name] ?? 0) >= 100;
      case 'meals_500':
        return (_lifetimeTotals[ActivityType.mealLogging.name] ?? 0) >= 500;
      case 'meals_1000':
        return (_lifetimeTotals[ActivityType.mealLogging.name] ?? 0) >= 1000;
      
      case 'exercise_10':
        return (_lifetimeTotals[ActivityType.exercise.name] ?? 0) >= 10;
      case 'exercise_100':
        return (_lifetimeTotals[ActivityType.exercise.name] ?? 0) >= 100;
      case 'exercise_500':
        return (_lifetimeTotals[ActivityType.exercise.name] ?? 0) >= 500;
      
      case 'steps_10000':
        return (_lifetimeTotals[ActivityType.steps.name] ?? 0) >= 10000;
      case 'steps_100000':
        return (_lifetimeTotals[ActivityType.steps.name] ?? 0) >= 100000;
      case 'steps_1000000':
        return (_lifetimeTotals[ActivityType.steps.name] ?? 0) >= 1000000;
      
      // Special achievements
      case 'first_meal':
        return activityType == ActivityType.mealLogging && 
               (_lifetimeTotals[ActivityType.mealLogging.name] ?? 0) == 1;
      case 'perfect_week':
        return _checkPerfectWeek();
      case 'early_bird':
        return _checkEarlyBird();
      case 'night_owl_restraint':
        return _checkNightOwlRestraint();
      
      default:
        return false;
    }
  }

  /// Validate activity for anti-gaming
  bool _validateActivity(ActivityType activityType, Map<String, dynamic> activityData, DateTime timestamp) {
    final now = DateTime.now();
    final activityKey = activityType.name;
    
    // Check for unrealistic values
    if (activityType == ActivityType.exercise) {
      final calories = activityData['calories'] as int? ?? 0;
      if (calories > 5000) return false; // More than 5000 calories burned
    }
    
    // Check for mass backlogging
    if (!_recentActivities.containsKey(activityKey)) {
      _recentActivities[activityKey] = [];
    }
    
    final recentActivities = _recentActivities[activityKey]!;
    final recentCount = recentActivities.where(
      (time) => now.difference(time).inHours < 1
    ).length;
    
    if (recentCount > 10) return false; // More than 10 activities per hour
    
    // Check retroactive entries
    if (timestamp.isBefore(now.subtract(maxRetroactiveTime))) {
      final retroactiveCount = recentActivities.where(
        (time) => now.difference(time).inDays > 1
      ).length;
      
      if (retroactiveCount >= maxRetroactiveEntries) return false;
    }
    
    // Add to recent activities
    recentActivities.add(timestamp);
    if (recentActivities.length > 100) {
      recentActivities.removeRange(0, recentActivities.length - 100);
    }
    
    return true;
  }

  /// Check for perfect week achievement
  bool _checkPerfectWeek() {
    // Implementation for checking if user hit all goals for 7 consecutive days
    // This would require checking daily summaries for the past 7 days
    return false; // Placeholder
  }

  /// Check for early bird achievement
  bool _checkEarlyBird() {
    // Implementation for checking if user logged breakfast before 8 AM for 7 days
    return false; // Placeholder
  }

  /// Check for night owl restraint achievement
  bool _checkNightOwlRestraint() {
    // Implementation for checking if user avoided late-night snacking for 7 days
    return false; // Placeholder
  }

  /// Update challenges
  void _updateChallenges(ActivityType activityType, Map<String, dynamic> activityData) {
    for (final challengeProgress in _challenges.values) {
      if (challengeProgress.challenge.requiredActivity == activityType) {
        challengeProgress.updateProgress(activityData);
      }
    }
  }

  /// Initialize activity streaks
  void _initializeActivityStreaks() {
    for (final activityType in ActivityType.values) {
      _activityStreaks[activityType.name] = ActivityStreak.initial(activityType);
    }
  }

  /// Initialize challenges
  void _initializeChallenges() {
    // Daily challenges
    _challenges['daily_meal'] = ChallengeProgress(
      challenge: Challenge(
        id: 'daily_meal',
        title: 'Daily Meal Logger',
        description: 'Log at least 1 meal today',
        type: ChallengeType.daily,
        requiredActivity: ActivityType.mealLogging,
        targetValue: 1,
        xpReward: 25,
      ),
    );
    
    
    // Weekly challenges
    _challenges['weekly_calorie'] = ChallengeProgress(
      challenge: Challenge(
        id: 'weekly_calorie',
        title: 'Calorie Crusher',
        description: 'Stay within calorie goals for 5 days this week',
        type: ChallengeType.weekly,
        requiredActivity: ActivityType.calorieGoal,
        targetValue: 5,
        xpReward: 200,
      ),
    );
    
    // Monthly challenges
    _challenges['monthly_perfect'] = ChallengeProgress(
      challenge: Challenge(
        id: 'monthly_perfect',
        title: 'Perfect Month',
        description: 'Complete all daily goals for 20+ days this month',
        type: ChallengeType.monthly,
        requiredActivity: ActivityType.dailyGoalCompletion,
        targetValue: 20,
        xpReward: 1000,
      ),
    );
  }

  /// Start daily reset timer
  void _startDailyResetTimer() {
    Timer.periodic(const Duration(hours: 1), (timer) {
      final now = DateTime.now();
      if (now.hour == 0) {
        _performDailyReset();
      }
    });
  }

  /// Perform daily reset
  void _performDailyReset() {
    // Reset daily challenges
    for (final challengeProgress in _challenges.values) {
      if (challengeProgress.challenge.type == ChallengeType.daily) {
        challengeProgress.reset();
      }
    }
    
    // Clean up old recent activities
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    for (final activities in _recentActivities.values) {
      activities.removeWhere((time) => time.isBefore(cutoff));
    }
  }

  /// Load user progress from storage
  Future<void> _loadUserProgress() async {
    // Implementation would load from local storage or database
    // For now, using initial progress
  }

  /// Save user progress to storage
  Future<void> _saveUserProgress() async {
    // Implementation would save to local storage or database
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
    _newRewardsController.close();
    _levelUpController.close();
  }
}


/// Activity streak tracking
class ActivityStreak {
  final ActivityType activityType;
  final int currentStreak;
  final int longestStreak;
  final DateTime lastActivityDate;

  const ActivityStreak({
    required this.activityType,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastActivityDate,
  });

  factory ActivityStreak.initial(ActivityType activityType) {
    return ActivityStreak(
      activityType: activityType,
      currentStreak: 0,
      longestStreak: 0,
      lastActivityDate: DateTime.now(),
    );
  }

  ActivityStreak copyWith({
    ActivityType? activityType,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActivityDate,
  }) {
    return ActivityStreak(
      activityType: activityType ?? this.activityType,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
    );
  }
}

/// Challenge types
enum ChallengeType {
  daily,
  weekly,
  monthly,
}

/// Challenge model
class Challenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final ActivityType requiredActivity;
  final int targetValue;
  final int xpReward;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.requiredActivity,
    required this.targetValue,
    required this.xpReward,
  });
}

/// Challenge progress tracking
class ChallengeProgress {
  final Challenge challenge;
  int currentProgress;
  bool isCompleted;
  DateTime? completedAt;

  ChallengeProgress({
    required this.challenge,
    this.currentProgress = 0,
    this.isCompleted = false,
    this.completedAt,
  });

  void updateProgress(Map<String, dynamic> activityData) {
    if (isCompleted) return;
    
    currentProgress++;
    if (currentProgress >= challenge.targetValue) {
      isCompleted = true;
      completedAt = DateTime.now();
    }
  }

  void reset() {
    currentProgress = 0;
    isCompleted = false;
    completedAt = null;
  }
}

/// Activity processing result
class ActivityResult {
  final bool success;
  final String message;
  final int xpEarned;
  final List<UserReward> newRewards;
  final LevelUpEvent? levelUp;

  const ActivityResult({
    required this.success,
    required this.message,
    required this.xpEarned,
    required this.newRewards,
    this.levelUp,
  });
}

/// Level up event
class LevelUpEvent {
  final UserLevel oldLevel;
  final UserLevel newLevel;
  final int totalXp;

  const LevelUpEvent({
    required this.oldLevel,
    required this.newLevel,
    required this.totalXp,
  });
}
