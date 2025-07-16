import 'package:cloud_firestore/cloud_firestore.dart';

class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final DateTime timestamp;
  final String? imageUrl;

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.timestamp,
    this.imageUrl,
  });

  factory FoodEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodEntry(
      id: doc.id,
      name: data['name'] ?? '',
      calories: data['calories'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'calories': calories,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
    };
  }
} 