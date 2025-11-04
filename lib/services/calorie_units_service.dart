import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_preferences.dart';

/// Global service for handling calorie unit conversions and display
/// This service ensures consistent calorie unit display across the entire app
class CalorieUnitsService {
  static final CalorieUnitsService _instance = CalorieUnitsService._internal();
  factory CalorieUnitsService() => _instance;
  CalorieUnitsService._internal();

  CalorieUnit _currentUnit = CalorieUnit.kcal;

  // Stream controller for notifying UI of unit changes
  final StreamController<CalorieUnit> _unitController =
      StreamController<CalorieUnit>.broadcast();

  // Stream for UI components to listen to unit changes
  Stream<CalorieUnit> get unitStream => _unitController.stream;

  /// Initialize the service with current user preferences
  Future<void> initialize() async {
    try {
      // Always use kcal as the default unit
      _currentUnit = CalorieUnit.kcal;
      _unitController.add(_currentUnit);
    } catch (e) {
      // Default to kcal if preferences can't be loaded
      _currentUnit = CalorieUnit.kcal;
      _unitController.add(_currentUnit);
    }
  }

  /// Update the current calorie unit
  void updateUnit(CalorieUnit unit) {
    _currentUnit = unit;
    _unitController.add(_currentUnit); // Notify listeners of unit change
  }

  /// Get the current calorie unit
  CalorieUnit get currentUnit => _currentUnit;

  /// Get the display name for the current unit
  String get currentUnitDisplay => _currentUnit.displayName;

  /// Convert calories from kcal to the current unit
  double convertFromKcal(double kcalValue) {
    return _currentUnit.convertFromKcal(kcalValue);
  }

  /// Convert calories to kcal from the current unit
  double convertToKcal(double value) {
    return _currentUnit.convertToKcal(value);
  }

  /// Format calories with the current unit
  String formatCalories(double kcalValue, {int? decimalPlaces}) {
    final convertedValue = convertFromKcal(kcalValue);

    if (decimalPlaces != null) {
      return '${convertedValue.toStringAsFixed(decimalPlaces)} ${_currentUnit.displayName}';
    }

    // Auto-determine decimal places based on unit
    switch (_currentUnit) {
      case CalorieUnit.kcal:
        return '${convertedValue.round()} ${_currentUnit.displayName}';
    }
  }

  /// Format calories for display in cards (shorter format)
  String formatCaloriesShort(double kcalValue) {
    final convertedValue = convertFromKcal(kcalValue);

    switch (_currentUnit) {
      case CalorieUnit.kcal:
        return '${convertedValue.round()}';
    }
  }

  /// Get the unit suffix for display
  String get unitSuffix => _currentUnit.displayName;

  /// Format calories with custom formatting
  String formatCaloriesCustom(
    double kcalValue, {
    bool showUnit = true,
    int? decimalPlaces,
    String? prefix,
    String? suffix,
  }) {
    final convertedValue = convertFromKcal(kcalValue);
    final unit = showUnit ? ' ${_currentUnit.displayName}' : '';

    String formattedValue;
    if (decimalPlaces != null) {
      formattedValue = convertedValue.toStringAsFixed(decimalPlaces);
    } else {
      switch (_currentUnit) {
        case CalorieUnit.kcal:
          formattedValue = convertedValue.round().toString();
          break;
      }
    }

    return '${prefix ?? ''}$formattedValue$unit${suffix ?? ''}';
  }

  /// Get conversion factor for the current unit
  double get conversionFactor {
    switch (_currentUnit) {
      case CalorieUnit.kcal:
        return 1.0;
    }
  }

  /// Check if the current unit is metric (kcal)
  bool get isMetricUnit {
    return _currentUnit == CalorieUnit.kcal;
  }

  /// Get a human-readable description of the current unit
  String get unitDescription {
    switch (_currentUnit) {
      case CalorieUnit.kcal:
        return 'Kilocalories (most common)';
    }
  }

  /// Dispose resources
  void dispose() {
    _unitController.close();
  }
}

/// Extension to make it easier to use the service
extension CalorieUnitsServiceExtension on BuildContext {
  CalorieUnitsService get calorieUnits => CalorieUnitsService();
}
