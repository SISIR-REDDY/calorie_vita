import 'package:flutter/material.dart';

/// Comprehensive input validation service for all user inputs
class InputValidationService {
  static final InputValidationService _instance = InputValidationService._internal();
  factory InputValidationService() => _instance;
  InputValidationService._internal();

  /// Validate water intake
  static ValidationResult validateWaterIntake(int glasses) {
    if (glasses < 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Water intake cannot be negative',
        suggestion: 'Please enter a positive number',
      );
    }
    
    if (glasses > 50) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Water intake seems too high',
        suggestion: 'Please enter a realistic number (max 50 glasses)',
      );
    }
    
    if (glasses > 20) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'That\'s a lot of water! Make sure you\'re not overhydrating',
        suggestion: 'Consider consulting a doctor if this is your daily intake',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate calories consumed
  static ValidationResult validateCalories(int calories) {
    if (calories < 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Calories cannot be negative',
        suggestion: 'Please enter a positive number',
      );
    }
    
    if (calories > 10000) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Calorie intake seems too high',
        suggestion: 'Please enter a realistic number (max 10,000 calories)',
      );
    }
    
    if (calories > 5000) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Very high calorie intake detected',
        suggestion: 'Consider consulting a nutritionist if this is your daily intake',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate calories burned
  static ValidationResult validateCaloriesBurned(int calories) {
    if (calories < 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Calories burned cannot be negative',
        suggestion: 'Please enter a positive number',
      );
    }
    
    if (calories > 5000) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Calories burned seems too high',
        suggestion: 'Please enter a realistic number (max 5,000 calories)',
      );
    }
    
    if (calories > 2000) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Very high calorie burn detected',
        suggestion: 'Make sure this is accurate for your activity level',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate steps
  static ValidationResult validateSteps(int steps) {
    if (steps < 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Steps cannot be negative',
        suggestion: 'Please enter a positive number',
      );
    }
    
    if (steps > 100000) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Step count seems too high',
        suggestion: 'Please enter a realistic number (max 100,000 steps)',
      );
    }
    
    if (steps > 50000) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Very high step count detected',
        suggestion: 'Make sure this is accurate for your activity level',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate sleep hours
  static ValidationResult validateSleepHours(double hours) {
    if (hours < 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Sleep hours cannot be negative',
        suggestion: 'Please enter a positive number',
      );
    }
    
    if (hours > 24) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Sleep hours cannot exceed 24',
        suggestion: 'Please enter a realistic number (max 24 hours)',
      );
    }
    
    if (hours < 3) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Very little sleep detected',
        suggestion: 'Consider getting more sleep for better health',
      );
    }
    
    if (hours > 12) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Very long sleep detected',
        suggestion: 'Consider consulting a doctor if you sleep this much regularly',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate weight
  static ValidationResult validateWeight(double weight) {
    if (weight <= 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Weight must be positive',
        suggestion: 'Please enter a valid weight',
      );
    }
    
    if (weight < 20) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Weight seems too low',
        suggestion: 'Please enter a realistic weight (min 20 kg)',
      );
    }
    
    if (weight > 500) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Weight seems too high',
        suggestion: 'Please enter a realistic weight (max 500 kg)',
      );
    }
    
    if (weight < 30 || weight > 200) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Unusual weight detected',
        suggestion: 'Please verify this is your current weight',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate BMI
  static ValidationResult validateBMI(double bmi) {
    if (bmi <= 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'BMI must be positive',
        suggestion: 'Please enter a valid BMI',
      );
    }
    
    if (bmi < 10) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'BMI seems too low',
        suggestion: 'Please enter a realistic BMI (min 10)',
      );
    }
    
    if (bmi > 100) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'BMI seems too high',
        suggestion: 'Please enter a realistic BMI (max 100)',
      );
    }
    
    if (bmi < 15 || bmi > 50) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Unusual BMI detected',
        suggestion: 'Consider consulting a healthcare professional',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate exercise duration
  static ValidationResult validateExerciseDuration(int minutes) {
    if (minutes < 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Exercise duration cannot be negative',
        suggestion: 'Please enter a positive number',
      );
    }
    
    if (minutes > 480) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Exercise duration seems too long',
        suggestion: 'Please enter a realistic duration (max 8 hours)',
      );
    }
    
    if (minutes > 240) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Very long exercise session detected',
        suggestion: 'Make sure you\'re taking adequate rest',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate food name
  static ValidationResult validateFoodName(String name) {
    if (name.trim().isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Food name cannot be empty',
        suggestion: 'Please enter a food name',
      );
    }
    
    if (name.trim().length < 2) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Food name too short',
        suggestion: 'Please enter a more descriptive name',
      );
    }
    
    if (name.trim().length > 100) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Food name too long',
        suggestion: 'Please enter a shorter name (max 100 characters)',
      );
    }
    
    // Check for suspicious characters
    if (RegExp(r'[<>{}[\]\\|`~!@#$%^&*()+=]').hasMatch(name)) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Unusual characters detected in food name',
        suggestion: 'Please use standard letters and numbers',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate portion size
  static ValidationResult validatePortionSize(double portion) {
    if (portion <= 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Portion size must be positive',
        suggestion: 'Please enter a valid portion size',
      );
    }
    
    if (portion > 1000) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Portion size seems too large',
        suggestion: 'Please enter a realistic portion (max 1000 units)',
      );
    }
    
    if (portion > 100) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Very large portion detected',
        suggestion: 'Please verify this is the correct portion size',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate age
  static ValidationResult validateAge(int age) {
    if (age < 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Age cannot be negative',
        suggestion: 'Please enter a valid age',
      );
    }
    
    if (age < 13) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Age too young for this app',
        suggestion: 'This app is for users 13 and older',
      );
    }
    
    if (age > 120) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Age seems too high',
        suggestion: 'Please enter a realistic age (max 120)',
      );
    }
    
    if (age > 100) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Very high age detected',
        suggestion: 'Please verify this is your correct age',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate height
  static ValidationResult validateHeight(double height) {
    if (height <= 0) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Height must be positive',
        suggestion: 'Please enter a valid height',
      );
    }
    
    if (height < 100) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Height seems too low',
        suggestion: 'Please enter a realistic height (min 100 cm)',
      );
    }
    
    if (height > 250) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Height seems too high',
        suggestion: 'Please enter a realistic height (max 250 cm)',
      );
    }
    
    if (height < 120 || height > 220) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Unusual height detected',
        suggestion: 'Please verify this is your correct height',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate goal values
  static ValidationResult validateCalorieGoal(int goal) {
    if (goal < 800) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Calorie goal too low',
        suggestion: 'Minimum safe calorie goal is 800 calories',
      );
    }
    
    if (goal > 5000) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Calorie goal too high',
        suggestion: 'Please enter a realistic goal (max 5,000 calories)',
      );
    }
    
    if (goal < 1200) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Very low calorie goal',
        suggestion: 'Consider consulting a nutritionist for such low goals',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate water goal
  static ValidationResult validateWaterGoal(int goal) {
    if (goal < 1) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Water goal too low',
        suggestion: 'Minimum water goal is 1 glass',
      );
    }
    
    if (goal > 20) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Water goal too high',
        suggestion: 'Please enter a realistic goal (max 20 glasses)',
      );
    }
    
    if (goal > 15) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Very high water goal',
        suggestion: 'Make sure this is appropriate for your needs',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate steps goal
  static ValidationResult validateStepsGoal(int goal) {
    if (goal < 1000) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Steps goal too low',
        suggestion: 'Minimum steps goal is 1,000 steps',
      );
    }
    
    if (goal > 50000) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Steps goal too high',
        suggestion: 'Please enter a realistic goal (max 50,000 steps)',
      );
    }
    
    if (goal > 30000) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Very high steps goal',
        suggestion: 'Make sure this is achievable for your lifestyle',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Validate sleep goal
  static ValidationResult validateSleepGoal(double goal) {
    if (goal < 4) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Sleep goal too low',
        suggestion: 'Minimum sleep goal is 4 hours',
      );
    }
    
    if (goal > 12) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Sleep goal too high',
        suggestion: 'Please enter a realistic goal (max 12 hours)',
      );
    }
    
    if (goal < 6 || goal > 10) {
      return ValidationResult(
        isValid: true,
        warningMessage: 'Unusual sleep goal',
        suggestion: 'Most adults need 7-9 hours of sleep',
      );
    }
    
    return ValidationResult(isValid: true);
  }

  /// Show validation result as snackbar
  static void showValidationResult(BuildContext context, ValidationResult result) {
    if (!result.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.errorMessage!),
              if (result.suggestion != null)
                Text(
                  result.suggestion!,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (result.warningMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.warningMessage!),
              if (result.suggestion != null)
                Text(
                  result.suggestion!,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Validation result model
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? warningMessage;
  final String? suggestion;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warningMessage,
    this.suggestion,
  });
}
