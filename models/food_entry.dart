import 'package:cloud_firestore/cloud_firestore.dart';

class FoodEntry {
  final String id;
  final String userId;
  final String foodName;
  final int calories;
  final DateTime timestamp;
  final String? imageUrl;
  final String? mealType; // breakfast, lunch, dinner, snack
  
  // New nutritional fields
  final double? protein; // grams
  final double? carbs; // grams
  final double? fat; // grams
  final double? fiber; // grams
  final double? sugar; // grams
  final double? sodium; // mg
  final double? potassium; // mg
  final double? vitaminA; // IU
  final double? vitaminC; // mg
  final double? calcium; // mg
  final double? iron; // mg
  final String? confidence; // AI detection confidence
  final List<String>? detectedFoods; // Multiple foods detected

  FoodEntry({
    required this.id,
    required this.userId,
    required this.foodName,
    required this.calories,
    required this.timestamp,
    this.imageUrl,
    this.mealType,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sugar,
    this.sodium,
    this.potassium,
    this.vitaminA,
    this.vitaminC,
    this.calcium,
    this.iron,
    this.confidence,
    this.detectedFoods,
  });

  factory FoodEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      foodName: data['foodName'] ?? '',
      calories: data['calories'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'],
      mealType: data['mealType'],
      protein: (data['protein'] as num?)?.toDouble(),
      carbs: (data['carbs'] as num?)?.toDouble(),
      fat: (data['fat'] as num?)?.toDouble(),
      fiber: (data['fiber'] as num?)?.toDouble(),
      sugar: (data['sugar'] as num?)?.toDouble(),
      sodium: (data['sodium'] as num?)?.toDouble(),
      potassium: (data['potassium'] as num?)?.toDouble(),
      vitaminA: (data['vitaminA'] as num?)?.toDouble(),
      vitaminC: (data['vitaminC'] as num?)?.toDouble(),
      calcium: (data['calcium'] as num?)?.toDouble(),
      iron: (data['iron'] as num?)?.toDouble(),
      confidence: data['confidence'],
      detectedFoods: data['detectedFoods'] != null 
          ? List<String>.from(data['detectedFoods'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'foodName': foodName,
      'calories': calories,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
      'mealType': mealType,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'sodium': sodium,
      'potassium': potassium,
      'vitaminA': vitaminA,
      'vitaminC': vitaminC,
      'calcium': calcium,
      'iron': iron,
      'confidence': confidence,
      'detectedFoods': detectedFoods,
    };
  }

  FoodEntry copyWith({
    String? id,
    String? userId,
    String? foodName,
    int? calories,
    DateTime? timestamp,
    String? imageUrl,
    String? mealType,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    double? sodium,
    double? potassium,
    double? vitaminA,
    double? vitaminC,
    double? calcium,
    double? iron,
    String? confidence,
    List<String>? detectedFoods,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      foodName: foodName ?? this.foodName,
      calories: calories ?? this.calories,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      mealType: mealType ?? this.mealType,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      sodium: sodium ?? this.sodium,
      potassium: potassium ?? this.potassium,
      vitaminA: vitaminA ?? this.vitaminA,
      vitaminC: vitaminC ?? this.vitaminC,
      calcium: calcium ?? this.calcium,
      iron: iron ?? this.iron,
      confidence: confidence ?? this.confidence,
      detectedFoods: detectedFoods ?? this.detectedFoods,
    );
  }
} 