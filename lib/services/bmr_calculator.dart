/// Fast BMR (Basal Metabolic Rate) Calculator
/// Calculates calories burned at rest to estimate active calories
/// Uses Mifflin-St Jeor Equation (most accurate formula)
library;

class BMRCalculator {
  // Cached values for performance
  static double? _cachedBMR;
  static DateTime? _lastCalculation;
  static const Duration _cacheExpiry = Duration(hours: 24);

  /// Calculate daily BMR (Basal Metabolic Rate)
  /// This is calories burned per day just by existing (breathing, heartbeat, etc.)
  /// 
  /// Formula: Mifflin-St Jeor Equation
  /// Men: BMR = (10 × weight kg) + (6.25 × height cm) - (5 × age) + 5
  /// Women: BMR = (10 × weight kg) + (6.25 × height cm) - (5 × age) - 161
  static double calculateDailyBMR({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender, // "Male" or "Female"
  }) {
    // Check cache first for performance
    if (_cachedBMR != null && _lastCalculation != null) {
      if (DateTime.now().difference(_lastCalculation!) < _cacheExpiry) {
        return _cachedBMR!;
      }
    }

    // Calculate BMR using Mifflin-St Jeor equation
    double bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age);

    if (gender.toLowerCase() == 'male') {
      bmr += 5;
    } else {
      bmr -= 161;
    }

    // Cache the result
    _cachedBMR = bmr;
    _lastCalculation = DateTime.now();

    return bmr;
  }

  /// Calculate BMR for current elapsed time today
  /// Returns calories burned at rest so far today
  static double calculateBMRForElapsedTime({
    required double dailyBMR,
  }) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final elapsedHours = now.difference(startOfDay).inMinutes / 60.0;

    // BMR per hour * hours elapsed
    final bmrPerHour = dailyBMR / 24.0;
    final bmrForToday = bmrPerHour * elapsedHours;

    return bmrForToday;
  }

  /// Estimate active calories from total calories
  /// Active Calories = Total Calories - Basal Calories
  static double estimateActiveCalories({
    required double totalCalories,
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
  }) {
    // Calculate daily BMR
    final dailyBMR = calculateDailyBMR(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
    );

    // Calculate BMR for elapsed time today
    final basalCalories = calculateBMRForElapsedTime(dailyBMR: dailyBMR);

    // Subtract basal from total to get active
    final activeCalories = totalCalories - basalCalories;

    // Ensure we don't return negative values
    return activeCalories > 0 ? activeCalories : 0;
  }

  /// Clear cache (call when user profile changes)
  static void clearCache() {
    _cachedBMR = null;
    _lastCalculation = null;
  }
}

