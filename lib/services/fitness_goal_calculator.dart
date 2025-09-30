// Fitness goal calculator service for calorie target calculations

/// Service for calculating calorie targets based on fitness goals
class FitnessGoalCalculator {
  /// Normalize goal labels to a canonical snake_case key
  static String _normalizeGoal(String fitnessGoal) {
    return fitnessGoal.trim().toLowerCase().replaceAll(' ', '_');
  }
  /// Calculate daily calorie target based on fitness goal
  static int calculateDailyCalorieTarget({
    required String fitnessGoal,
    required int baseCalorieGoal,
    required int caloriesConsumed,
    required int caloriesBurned,
  }) {
    // Return the configured target; upstream logic already adjusts base goal per goal
    return baseCalorieGoal;
  }

  /// Calculate remaining calories to reach goal based on fitness goal
  static int calculateRemainingCalories({
    required String fitnessGoal,
    required int caloriesConsumed,
    required int caloriesBurned,
    required int baseCalorieGoal,
  }) {
    // Groups/formulas:
    // Weight Loss Group (Target - Burned): Weight Loss, General Fitness
    // Weight Gain Group (Target - Consumed): Weight Gain, Muscle Building, Athletic Performance
    // Maintenance Group (Target + Consumed - Burned): Maintenance
    final goal = _normalizeGoal(fitnessGoal);
    switch (goal) {
      case 'weight_loss':
      case 'general_fitness':
        return baseCalorieGoal - caloriesBurned;
      case 'weight_gain':
      case 'muscle_building':
      case 'athletic_performance':
        return baseCalorieGoal - caloriesConsumed;
      case 'maintenance':
      default:
        return baseCalorieGoal + caloriesConsumed - caloriesBurned;
    }
  }

  /// Get motivational message based on fitness goal and progress
  static String getMotivationalMessage({
    required String fitnessGoal,
    required int remainingCalories,
    required bool isGoalReached,
  }) {
    final goal = _normalizeGoal(fitnessGoal);
    if (isGoalReached) {
      switch (goal) {
        case 'weight_loss':
        case 'general_fitness':
          return 'Great job! You\'ve reached your burn target! 🎯';
        case 'weight_gain':
        case 'athletic_performance':
          return 'Excellent! You\'ve hit your intake target! 💪';
        case 'muscle_building':
          return 'Amazing! You\'ve achieved your muscle building target! 🏋️‍♂️';
        case 'maintenance':
        default:
          return 'Perfect! You\'ve maintained your calorie balance! ⚖️';
      }
    } else {
      switch (goal) {
        case 'weight_loss':
        case 'general_fitness':
          return 'Keep going! You\'re on track to reach your burn goal! 🔥';
        case 'weight_gain':
        case 'athletic_performance':
          return 'Stay consistent! You\'re building towards your intake target! 📈';
        case 'muscle_building':
          return 'Keep pushing! You\'re building muscle and strength! 💪';
        case 'maintenance':
        default:
          return 'Stay balanced! You\'re maintaining your healthy lifestyle! ⚖️';
      }
    }
  }

  /// Get action guidance based on fitness goal
  static String getActionGuidance({
    required String fitnessGoal,
    required int remainingCalories,
  }) {
    final absRemaining = remainingCalories.abs();

    switch (_normalizeGoal(fitnessGoal)) {
      case 'weight_loss':
      case 'general_fitness':
        return remainingCalories > 0
            ? 'Burn $absRemaining more calories to reach your goal'
            : 'Great! You\'ve reached your burn target!';
      
      case 'weight_gain':
      case 'athletic_performance':
        return remainingCalories > 0
            ? 'Eat $absRemaining more calories to reach your goal'
            : 'Excellent! You\'ve reached your intake target!';
      
      case 'muscle_building':
        return remainingCalories > 0
            ? 'Eat $absRemaining more calories to fuel muscle growth'
            : 'Amazing! You\'ve reached your muscle building target!';
      
      case 'maintenance':
      default:
        return remainingCalories > 0
            ? 'Eat $absRemaining more calories to maintain balance'
            : 'Perfect! You\'ve reached your maintenance target!';
    }
  }

  /// Check if goal is reached based on fitness goal
  static bool isGoalReached({
    required String fitnessGoal,
    required int remainingCalories,
  }) {
    // Simple logic: goal is reached when remaining calories is 0 or negative
    return remainingCalories <= 0;
  }

  /// Get color for UI based on fitness goal and progress
  static int getProgressColor({
    required String fitnessGoal,
    required bool isGoalReached,
    required int remainingCalories,
  }) {
    if (isGoalReached) {
      return 0xFF4CAF50; // Green for success
    }
    
    // Use goal-specific colors for motivation
    switch (_normalizeGoal(fitnessGoal)) {
      case 'weight_loss':
      case 'general_fitness':
        return 0xFFFF9800; // Orange for weight loss
      case 'weight_gain':
      case 'athletic_performance':
        return 0xFF2196F3; // Blue for weight gain
      case 'muscle_building':
        return 0xFF9C27B0; // Purple for muscle building
      case 'maintenance':
      default:
        return 0xFF4CAF50; // Green for maintenance
    }
  }
}
