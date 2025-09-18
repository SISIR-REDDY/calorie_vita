// Fitness goal calculator service for calorie target calculations

/// Service for calculating calorie targets based on fitness goals
class FitnessGoalCalculator {
  /// Calculate daily calorie target based on fitness goal
  static int calculateDailyCalorieTarget({
    required String fitnessGoal,
    required int baseCalorieGoal,
    required int caloriesConsumed,
    required int caloriesBurned,
  }) {
    switch (fitnessGoal.toLowerCase()) {
      case 'weight_loss':
        // For weight loss: base goal - consumed (focus on eating less)
        return baseCalorieGoal - caloriesConsumed;
      
      case 'weight_gain':
        // For weight gain: base goal - consumed (focus on eating more)
        return baseCalorieGoal - caloriesConsumed;
      
      case 'muscle_building':
        // For muscle building: base goal - consumed (focus on eating more)
        return baseCalorieGoal - caloriesConsumed;
      
      case 'maintenance':
      default:
        // For maintenance: base goal - consumed (focus on balance)
        return baseCalorieGoal - caloriesConsumed;
    }
  }

  /// Calculate remaining calories to reach goal based on fitness goal
  static int calculateRemainingCalories({
    required String fitnessGoal,
    required int caloriesConsumed,
    required int caloriesBurned,
    required int baseCalorieGoal,
  }) {
    // Simple calculation: base goal - consumed calories
    return baseCalorieGoal - caloriesConsumed;
  }

  /// Get motivational message based on fitness goal and progress
  static String getMotivationalMessage({
    required String fitnessGoal,
    required int remainingCalories,
    required bool isGoalReached,
  }) {
    if (isGoalReached) {
      switch (fitnessGoal.toLowerCase()) {
        case 'weight_loss':
          return 'Great job! You\'ve reached your weight loss target! 🎯';
        case 'weight_gain':
          return 'Excellent! You\'ve hit your weight gain goal! 💪';
        case 'muscle_building':
          return 'Amazing! You\'ve achieved your muscle building target! 🏋️‍♂️';
        case 'maintenance':
        default:
          return 'Perfect! You\'ve maintained your calorie balance! ⚖️';
      }
    } else {
      switch (fitnessGoal.toLowerCase()) {
        case 'weight_loss':
          return 'Keep going! You\'re on track to reach your weight loss goal! 🔥';
        case 'weight_gain':
          return 'Stay consistent! You\'re building towards your weight gain target! 📈';
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
    
    switch (fitnessGoal.toLowerCase()) {
      case 'weight_loss':
        if (remainingCalories > 0) {
          return 'Eat $absRemaining more calories to reach your goal';
        } else {
          return 'Great! You\'ve reached your weight loss target!';
        }
      
      case 'weight_gain':
        if (remainingCalories > 0) {
          return 'Eat $absRemaining more calories to reach your goal';
        } else {
          return 'Excellent! You\'ve reached your weight gain target!';
        }
      
      case 'muscle_building':
        if (remainingCalories > 0) {
          return 'Eat $absRemaining more calories to fuel muscle growth';
        } else {
          return 'Amazing! You\'ve reached your muscle building target!';
        }
      
      case 'maintenance':
      default:
        if (remainingCalories > 0) {
          return 'Eat $absRemaining more calories to maintain balance';
        } else {
          return 'Perfect! You\'ve reached your maintenance target!';
        }
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
    switch (fitnessGoal.toLowerCase()) {
      case 'weight_loss':
        return 0xFFFF9800; // Orange for weight loss
      case 'weight_gain':
        return 0xFF2196F3; // Blue for weight gain
      case 'muscle_building':
        return 0xFF9C27B0; // Purple for muscle building
      case 'maintenance':
      default:
        return 0xFF4CAF50; // Green for maintenance
    }
  }
}
