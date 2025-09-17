import 'package:cloud_firestore/cloud_firestore.dart';

/// Task model for managing user tasks and to-do items
class Task {
  final String id;
  final String title;
  final String emoji;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? category;
  final String? description;
  final List<String>? tags;
  final String? userId;

  const Task({
    required this.id,
    required this.title,
    required this.emoji,
    required this.priority,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.category,
    this.description,
    this.tags,
    this.userId,
  });

  /// Create a Task from Firestore document
  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      emoji: data['emoji'] ?? '📝',
      priority: TaskPriority.fromString(data['priority'] ?? 'medium'),
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
      category: data['category'],
      description: data['description'],
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      userId: data['userId'],
    );
  }

  /// Convert Task to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'emoji': emoji,
      'priority': priority.toString(),
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'category': category,
      'description': description,
      'tags': tags,
      'userId': userId,
    };
  }

  /// Create a copy of this task with updated fields
  Task copyWith({
    String? id,
    String? title,
    String? emoji,
    TaskPriority? priority,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    String? category,
    String? description,
    List<String>? tags,
    String? userId,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      category: category ?? this.category,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      userId: userId ?? this.userId,
    );
  }

  /// Get task priority color
  String get priorityColor {
    switch (priority) {
      case TaskPriority.high:
        return '#FF6B6B';
      case TaskPriority.medium:
        return '#FFD93D';
      case TaskPriority.low:
        return '#6BCF7F';
    }
  }

  /// Get task priority display name
  String get priorityDisplayName {
    switch (priority) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
    }
  }

  /// Check if task is overdue (for high priority tasks)
  bool get isOverdue {
    if (priority != TaskPriority.high || isCompleted) return false;
    final now = DateTime.now();
    final daysSinceCreated = now.difference(createdAt).inDays;
    return daysSinceCreated > 1; // High priority tasks overdue after 1 day
  }

  @override
  String toString() {
    return 'Task(id: $id, title: $title, priority: $priority, isCompleted: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Task priority levels
enum TaskPriority {
  high,
  medium,
  low;

  static TaskPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'high':
        return TaskPriority.high;
      case 'medium':
        return TaskPriority.medium;
      case 'low':
        return TaskPriority.low;
      default:
        return TaskPriority.medium;
    }
  }

  @override
  String toString() {
    switch (this) {
      case TaskPriority.high:
        return 'high';
      case TaskPriority.medium:
        return 'medium';
      case TaskPriority.low:
        return 'low';
    }
  }
}

/// Example tasks to show when user has no tasks
class ExampleTasks {
  static const List<Map<String, dynamic>> tasks = [
    {
      'title': 'Complete your morning workout',
      'emoji': '💪',
      'priority': 'high',
      'category': 'fitness',
      'description': 'Start your day with some exercise',
    },
    {
      'title': 'Log your breakfast',
      'emoji': '🍳',
      'priority': 'medium',
      'category': 'nutrition',
      'description': 'Track your first meal of the day',
    },
  ];

  static Task createExampleTask(Map<String, dynamic> taskData, String userId) {
    return Task(
      id: 'example_${DateTime.now().millisecondsSinceEpoch}',
      title: taskData['title'],
      emoji: taskData['emoji'],
      priority: TaskPriority.fromString(taskData['priority']),
      isCompleted: false,
      createdAt: DateTime.now(),
      category: taskData['category'],
      description: taskData['description'],
      userId: userId,
    );
  }
}
