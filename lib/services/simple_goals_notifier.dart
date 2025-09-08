import '../models/user_goals.dart';

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
    print('SimpleGoalsNotifier: Goals updated to ${goals.toMap()}');
  }

  // Get goals with defaults
  UserGoals getGoalsWithDefaults() {
    return _currentGoals ?? UserGoals(
      calorieGoal: 2000,
      stepsPerDayGoal: 10000,
      waterGlassesGoal: 8,
    );
  }
}
