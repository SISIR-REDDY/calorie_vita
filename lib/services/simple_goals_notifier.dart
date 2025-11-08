import '../models/user_goals.dart';
import 'package:flutter/foundation.dart';
import '../config/production_config.dart';

/// Simple goals notifier for immediate UI updates
class SimpleGoalsNotifier {
  static final SimpleGoalsNotifier _instance = SimpleGoalsNotifier._internal();
  factory SimpleGoalsNotifier() => _instance;
  SimpleGoalsNotifier._internal();

  // Current goals
  UserGoals? _currentGoals;

  // Get current goals
  UserGoals? get currentGoals => _currentGoals;

  // Update goals and notify
  void updateGoals(UserGoals goals) {
    _currentGoals = goals;
    if (kDebugMode) debugPrint('SimpleGoalsNotifier: Goals updated to ${goals.toMap()}');
  }

  // Get goals with defaults
  UserGoals getGoalsWithDefaults() {
    return _currentGoals ??
        const UserGoals(
          calorieGoal: 2000,
          stepsPerDayGoal: 10000,
          waterGlassesGoal: 8,
        );
  }
}

