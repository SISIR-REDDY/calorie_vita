import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for food history entries from camera scans
class FoodHistoryEntry {
  final String id;
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double weightGrams;
  final String? category;
  final String? brand;
  final String? notes;
  final String source; // 'camera_scan', 'barcode_scan', 'manual_entry'
  final DateTime timestamp;
  final String? imagePath; // Path to saved image if any
  final Map<String, dynamic>? scanData; // Additional scan data

  FoodHistoryEntry({
    required this.id,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.weightGrams,
    this.category,
    this.brand,
    this.notes,
    required this.source,
    required this.timestamp,
    this.imagePath,
    this.scanData,
  });

  /// Create from Map
  factory FoodHistoryEntry.fromMap(Map<String, dynamic> map) {
    return FoodHistoryEntry(
      id: map['id'] ?? '',
      foodName: map['foodName'] ?? '',
      calories: (map['calories'] ?? 0.0).toDouble(),
      protein: (map['protein'] ?? 0.0).toDouble(),
      carbs: (map['carbs'] ?? 0.0).toDouble(),
      fat: (map['fat'] ?? 0.0).toDouble(),
      fiber: (map['fiber'] ?? 0.0).toDouble(),
      sugar: (map['sugar'] ?? 0.0).toDouble(),
      weightGrams: (map['weightGrams'] ?? 0.0).toDouble(),
      category: map['category'],
      brand: map['brand'],
      notes: map['notes'],
      source: map['source'] ?? 'manual_entry',
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      imagePath: map['imagePath'],
      scanData: map['scanData'],
    );
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'foodName': foodName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'weightGrams': weightGrams,
      'category': category,
      'brand': brand,
      'notes': notes,
      'source': source,
      'timestamp': Timestamp.fromDate(timestamp),
      'imagePath': imagePath,
      'scanData': scanData,
    };
  }

  /// Create a copy with updated fields
  FoodHistoryEntry copyWith({
    String? id,
    String? foodName,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    double? weightGrams,
    String? category,
    String? brand,
    String? notes,
    String? source,
    DateTime? timestamp,
    String? imagePath,
    Map<String, dynamic>? scanData,
  }) {
    return FoodHistoryEntry(
      id: id ?? this.id,
      foodName: foodName ?? this.foodName,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      weightGrams: weightGrams ?? this.weightGrams,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      imagePath: imagePath ?? this.imagePath,
      scanData: scanData ?? this.scanData,
    );
  }

  /// Get display name with brand
  String get displayName {
    if (brand != null && brand!.isNotEmpty) {
      return '$brand $foodName';
    }
    return foodName;
  }

  /// Get formatted timestamp
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  /// Get source display name
  String get sourceDisplayName {
    switch (source) {
      case 'camera_scan':
        return 'Camera Scan';
      case 'barcode_scan':
        return 'Barcode Scan';
      case 'manual_entry':
        return 'Manual Entry';
      default:
        return 'Unknown';
    }
  }

  @override
  String toString() {
    return 'FoodHistoryEntry(id: $id, foodName: $foodName, calories: $calories, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoodHistoryEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
