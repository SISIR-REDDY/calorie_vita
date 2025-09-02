import '../models/food_entry.dart';

/// Model for meal categories (Breakfast, Lunch, Dinner, Snacks)
class MealCategory {
  final String name;
  final String icon;
  final List<FoodEntry> entries;
  final bool isExpanded;
  final DateTime targetTime;

  MealCategory({
    required this.name,
    required this.icon,
    required this.entries,
    this.isExpanded = false,
    required this.targetTime,
  });

  /// Get total calories for this meal category
  int get totalCalories => entries.fold(0, (sum, entry) => sum + entry.calories);

  /// Get total protein for this meal category
  double get totalProtein => entries.fold(0.0, (sum, entry) => sum + (entry.protein ?? 0.0));

  /// Get total carbs for this meal category
  double get totalCarbs => entries.fold(0.0, (sum, entry) => sum + (entry.carbs ?? 0.0));

  /// Get total fat for this meal category
  double get totalFat => entries.fold(0.0, (sum, entry) => sum + (entry.fat ?? 0.0));

  /// Get number of entries
  int get entryCount => entries.length;

  /// Check if meal is completed (has entries)
  bool get isCompleted => entries.isNotEmpty;

  /// Get completion percentage based on recommended calories
  double get completionPercentage {
    final recommendedCalories = _getRecommendedCalories();
    if (recommendedCalories == 0) return 0.0;
    return (totalCalories / recommendedCalories).clamp(0.0, 1.0);
  }

  /// Get recommended calories for this meal category
  int _getRecommendedCalories() {
    switch (name.toLowerCase()) {
      case 'breakfast':
        return 400; // 20% of 2000 calories
      case 'lunch':
        return 600; // 30% of 2000 calories
      case 'dinner':
        return 500; // 25% of 2000 calories
      case 'snacks':
        return 300; // 15% of 2000 calories
      default:
        return 0;
    }
  }

  /// Get meal status message
  String get statusMessage {
    if (entries.isEmpty) {
      return 'No $name logged yet';
    }
    
    final percentage = completionPercentage;
    if (percentage < 0.5) {
      return 'Light $name (${percentage.toStringAsFixed(0)}% of goal)';
    } else if (percentage < 1.0) {
      return 'Good $name (${percentage.toStringAsFixed(0)}% of goal)';
    } else {
      return 'Complete $name (${percentage.toStringAsFixed(0)}% of goal)';
    }
  }

  /// Get meal color based on completion
  String get statusColor {
    final percentage = completionPercentage;
    if (percentage < 0.3) return 'red';
    if (percentage < 0.7) return 'orange';
    if (percentage < 1.0) return 'blue';
    return 'green';
  }

  /// Copy with new values
  MealCategory copyWith({
    String? name,
    String? icon,
    List<FoodEntry>? entries,
    bool? isExpanded,
    DateTime? targetTime,
  }) {
    return MealCategory(
      name: name ?? this.name,
      icon: icon ?? this.icon,
      entries: entries ?? this.entries,
      isExpanded: isExpanded ?? this.isExpanded,
      targetTime: targetTime ?? this.targetTime,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon': icon,
      'entries': entries.map((e) => e.toJson()).toList(),
      'isExpanded': isExpanded,
      'targetTime': targetTime.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON
  factory MealCategory.fromJson(Map<String, dynamic> json) {
    return MealCategory(
      name: json['name'] ?? '',
      icon: json['icon'] ?? '🍽️',
      entries: (json['entries'] as List<dynamic>?)
          ?.map((e) => FoodEntry.fromJson(e))
          .toList() ?? [],
      isExpanded: json['isExpanded'] ?? false,
      targetTime: DateTime.fromMillisecondsSinceEpoch(json['targetTime'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  String toString() {
    return 'MealCategory(name: $name, entries: ${entries.length}, calories: $totalCalories)';
  }
}

/// Predefined meal categories
class MealCategories {
  static final List<MealCategory> defaultCategories = [
    MealCategory(
      name: 'Breakfast',
      icon: '🌅',
      entries: [],
      targetTime: DateTime(2024, 1, 1, 8, 0), // 8:00 AM
    ),
    MealCategory(
      name: 'Lunch',
      icon: '☀️',
      entries: [],
      targetTime: DateTime(2024, 1, 1, 12, 30), // 12:30 PM
    ),
    MealCategory(
      name: 'Dinner',
      icon: '🌙',
      entries: [],
      targetTime: DateTime(2024, 1, 1, 19, 0), // 7:00 PM
    ),
    MealCategory(
      name: 'Snacks',
      icon: '🍎',
      entries: [],
      targetTime: DateTime(2024, 1, 1, 15, 0), // 3:00 PM
    ),
  ];

  /// Get meal category by name
  static MealCategory? getByName(String name) {
    try {
      return defaultCategories.firstWhere((category) => category.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Get current meal category based on time
  static MealCategory getCurrentMeal() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 5 && hour < 11) {
      return getByName('Breakfast')!;
    } else if (hour >= 11 && hour < 16) {
      return getByName('Lunch')!;
    } else if (hour >= 16 && hour < 21) {
      return getByName('Dinner')!;
    } else {
      return getByName('Snacks')!;
    }
  }
}
