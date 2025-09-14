import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for storing individual weight log entries
class WeightLog {
  final String id;
  final String userId;
  final double weight;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WeightLog({
    required this.id,
    required this.userId,
    required this.weight,
    required this.date,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create WeightLog from Firestore document
  factory WeightLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeightLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      weight: (data['weight'] ?? 0.0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert WeightLog to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'weight': weight,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy of WeightLog with updated fields
  WeightLog copyWith({
    String? id,
    String? userId,
    double? weight,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeightLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      weight: weight ?? this.weight,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'WeightLog(id: $id, weight: $weight, date: $date, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeightLog &&
        other.id == id &&
        other.userId == userId &&
        other.weight == weight &&
        other.date == date &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        weight.hashCode ^
        date.hashCode ^
        notes.hashCode;
  }
}

/// Model for weight log statistics
class WeightLogStats {
  final double currentWeight;
  final double? previousWeight;
  final double? weightChange;
  final double? averageWeight;
  final int totalEntries;
  final DateTime? firstEntryDate;
  final DateTime? lastEntryDate;

  const WeightLogStats({
    required this.currentWeight,
    this.previousWeight,
    this.weightChange,
    this.averageWeight,
    required this.totalEntries,
    this.firstEntryDate,
    this.lastEntryDate,
  });

  /// Calculate weight change percentage
  double? get weightChangePercentage {
    if (previousWeight == null || previousWeight == 0) return null;
    return ((weightChange ?? 0) / previousWeight!) * 100;
  }

  /// Get weight change trend
  String get trend {
    if (weightChange == null) return 'No change';
    if (weightChange! > 0) return 'Gaining';
    if (weightChange! < 0) return 'Losing';
    return 'Stable';
  }
}
