import 'package:cloud_firestore/cloud_firestore.dart';
import 'macro_breakdown.dart';

class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final DateTime timestamp;
  final String? imageUrl;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.timestamp,
    this.imageUrl,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sugar,
  });

  factory FoodEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodEntry(
      id: doc.id,
      name: data['name'] ?? '',
      calories: data['calories'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'],
      protein: (data['protein'] ?? 0.0).toDouble(),
      carbs: (data['carbs'] ?? 0.0).toDouble(),
      fat: (data['fat'] ?? 0.0).toDouble(),
      fiber: (data['fiber'] ?? 0.0).toDouble(),
      sugar: (data['sugar'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'calories': calories,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
    };
  }

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'imageUrl': imageUrl,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
    };
  }

  /// Create from JSON
  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      calories: json['calories'] ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
      imageUrl: json['imageUrl'],
      protein: (json['protein'] ?? 0.0).toDouble(),
      carbs: (json['carbs'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? 0.0).toDouble(),
      fiber: (json['fiber'] ?? 0.0).toDouble(),
      sugar: (json['sugar'] ?? 0.0).toDouble(),
    );
  }

  /// Get macro breakdown from this food entry
  MacroBreakdown get macroBreakdown {
    return MacroBreakdown(
      carbs: carbs ?? 0.0,
      protein: protein ?? 0.0,
      fat: fat ?? 0.0,
      fiber: fiber ?? 0.0,
      sugar: sugar ?? 0.0,
    );
  }
}
