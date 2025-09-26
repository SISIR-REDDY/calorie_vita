import 'dart:io';
// import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
// import 'package:arkit_plugin/arkit_plugin.dart';
import '../models/portion_estimation_result.dart';

/// Service for portion estimation using ARCore/ARKit or manual input
class PortionEstimationService {
  static bool _isArCoreAvailable = false;
  static bool _isARKitAvailable = false;

  /// Initialize AR capabilities
  static Future<void> initialize() async {
    try {
      // AR capabilities temporarily disabled due to dependency issues
      _isArCoreAvailable = false;
      _isARKitAvailable = false;
      print('AR capabilities temporarily disabled');
    } catch (e) {
      print('Error checking AR availability: $e');
    }
  }

  /// Check if AR-based portion estimation is available
  static bool get isArAvailable => _isArCoreAvailable || _isARKitAvailable;

  /// Estimate portion size using AR
  static Future<PortionEstimationResult> estimatePortionWithAR() async {
    if (!isArAvailable) {
      return PortionEstimationResult(
        estimatedWeight: 0.0,
        confidence: 0.0,
        method: 'AR not available',
        error: 'ARCore/ARKit not available on this device',
      );
    }

    try {
      // This is a simplified implementation
      // In a real app, you would use AR to measure the food item
      // and calculate its volume/weight based on known food densities
      
      if (Platform.isAndroid && _isArCoreAvailable) {
        return await _estimateWithARCore();
      } else if (Platform.isIOS && _isARKitAvailable) {
        return await _estimateWithARKit();
      }
      
      return PortionEstimationResult(
        estimatedWeight: 0.0,
        confidence: 0.0,
        method: 'AR not available',
        error: 'AR not available on this platform',
      );
    } catch (e) {
      return PortionEstimationResult(
        estimatedWeight: 0.0,
        confidence: 0.0,
        method: 'AR error',
        error: 'AR estimation failed: $e',
      );
    }
  }

  /// Estimate portion using ARCore (Android)
  static Future<PortionEstimationResult> _estimateWithARCore() async {
    // Simplified implementation - in reality, you would:
    // 1. Start ARCore session
    // 2. Detect food item in 3D space
    // 3. Calculate volume using AR measurements
    // 4. Convert volume to weight using food density
    
    return PortionEstimationResult(
      estimatedWeight: 150.0, // Example weight in grams
      confidence: 0.8,
      method: 'ARCore',
      notes: 'Estimated using ARCore volume measurement',
    );
  }

  /// Estimate portion using ARKit (iOS)
  static Future<PortionEstimationResult> _estimateWithARKit() async {
    // Simplified implementation - in reality, you would:
    // 1. Start ARKit session
    // 2. Detect food item in 3D space
    // 3. Calculate volume using AR measurements
    // 4. Convert volume to weight using food density
    
    return PortionEstimationResult(
      estimatedWeight: 150.0, // Example weight in grams
      confidence: 0.8,
      method: 'ARKit',
      notes: 'Estimated using ARKit volume measurement',
    );
  }

  /// Get predefined portion options for manual selection
  static List<PortionOption> getPredefinedPortions() {
    return [
      PortionOption(
        name: 'Small',
        weight: 100.0,
        description: '100g - Small portion',
        icon: '🥄',
      ),
      PortionOption(
        name: 'Medium',
        weight: 200.0,
        description: '200g - Medium portion',
        icon: '🍽️',
      ),
      PortionOption(
        name: 'Large',
        weight: 300.0,
        description: '300g - Large portion',
        icon: '🍽️',
      ),
      PortionOption(
        name: 'Extra Large',
        weight: 400.0,
        description: '400g - Extra large portion',
        icon: '🍽️',
      ),
      PortionOption(
        name: 'Custom',
        weight: 0.0,
        description: 'Enter custom weight',
        icon: '✏️',
        isCustom: true,
      ),
    ];
  }

  /// Estimate portion based on food type and visual cues
  static PortionEstimationResult estimatePortionByFoodType(
    String foodName,
    String category,
    double confidence,
  ) {
    // Base portion estimates by food category
    final basePortions = {
      'Bread': 50.0,
      'Curry': 150.0,
      'Rice Dish': 200.0,
      'Dairy': 100.0,
      'Pancake': 120.0,
      'Steamed': 50.0,
      'Vegetable Curry': 150.0,
      'Non-Veg Curry': 200.0,
      'Grilled': 150.0,
      'Side Dish': 100.0,
      'Snack': 50.0,
      'Fried Snack': 60.0,
      'Beverage': 250.0,
      'Dessert': 100.0,
    };

    final baseWeight = basePortions[category] ?? 150.0;
    
    // Adjust based on confidence
    final adjustedWeight = baseWeight * (0.5 + confidence * 0.5);
    
    return PortionEstimationResult(
      estimatedWeight: adjustedWeight,
      confidence: confidence * 0.7, // Lower confidence for estimation
      method: 'Food type estimation',
      notes: 'Estimated based on food category: $category',
    );
  }

  /// Convert volume to weight using food density
  static double convertVolumeToWeight(double volumeCm3, String foodName) {
    // Food densities in g/cm³
    final densities = {
      'Roti': 0.6,
      'Dal': 1.0,
      'Biryani': 0.8,
      'Paneer': 1.1,
      'Dosa': 0.7,
      'Idli': 0.5,
      'Sambar': 1.0,
      'Rajma': 1.0,
      'Chole': 1.0,
      'Aloo Gobi': 0.8,
      'Palak Paneer': 0.9,
      'Butter Chicken': 1.0,
      'Tandoori Chicken': 1.1,
      'Naan': 0.6,
      'Raita': 1.0,
      'Samosa': 0.7,
      'Pakora': 0.8,
      'Lassi': 1.0,
      'Gulab Jamun': 1.2,
      'Kheer': 1.0,
    };

    final density = densities[foodName] ?? 1.0; // Default density
    return volumeCm3 * density;
  }

  /// Get portion estimation methods available
  static List<String> getAvailableMethods() {
    final methods = <String>['Manual selection'];
    
    if (isArAvailable) {
      methods.add('AR measurement');
    }
    
    methods.addAll(['Food type estimation', 'Visual estimation']);
    
    return methods;
  }
}

/// Model for portion options
class PortionOption {
  final String name;
  final double weight;
  final String description;
  final String icon;
  final bool isCustom;

  PortionOption({
    required this.name,
    required this.weight,
    required this.description,
    required this.icon,
    this.isCustom = false,
  });

  @override
  String toString() {
    return 'PortionOption(name: $name, weight: ${weight}g, description: $description)';
  }
}
