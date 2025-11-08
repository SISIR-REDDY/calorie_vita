import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../config/production_config.dart';
import 'dynamic_icon_service.dart';

/// Service for managing user tasks and to-do items
class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DynamicIconService _iconService = DynamicIconService();

  // Stream controllers for real-time updates
  final StreamController<List<Task>> _tasksController = StreamController<List<Task>>.broadcast();
  final StreamController<Task> _taskUpdateController = StreamController<Task>.broadcast();
  
  // Local tasks list for immediate UI updates
  List<Task> _localTasks = [];
  
  // Flag to prevent example tasks from being added multiple times
  bool _exampleTasksAdded = false;

  // Getters
  Stream<List<Task>> get tasksStream => _tasksController.stream;
  Stream<Task> get taskUpdateStream => _taskUpdateController.stream;
  
  /// Force emit current tasks to the stream
  void forceEmitTasks() {
    if (!_tasksController.isClosed) {
      _tasksController.add(List.from(_localTasks));
      if (ProductionConfig.enableDebugLogs) {
        debugPrint('📋 Force emitted ${_localTasks.length} tasks to stream');
      }
    } else {
      if (ProductionConfig.enableDebugLogs) {
        debugPrint('📋 Task stream controller is closed, cannot emit tasks');
      }
    }
  }
  
  /// Get current tasks from local list
  List<Task> getCurrentTasks() {
    return List.from(_localTasks);
  }
  
  /// Get a specific task by ID
  Task? getTaskById(String taskId) {
    try {
      return _localTasks.firstWhere((task) => task.id == taskId);
    } catch (e) {
      if (ProductionConfig.enableDebugLogs) {
        debugPrint('📋 Task not found with ID: $taskId');
      }
      return null;
    }
  }
  
  /// Clear all tasks (for testing/debugging)
  Future<void> clearAllTasks() async {
    if (_currentUserId == null) return;
    
    try {
      // Delete all tasks from Firestore
      final batch = _firestore.batch();
      for (final task in _localTasks) {
        batch.delete(_firestore.collection('tasks').doc(task.id));
      }
      await batch.commit();
      
      // Clear local list
      _localTasks.clear();
      _tasksController.add([]);
      
      // Reset example tasks flag
      _exampleTasksAdded = false;
      
      if (ProductionConfig.enableDebugLogs) {
        debugPrint('📋 All tasks cleared');
      }
    } catch (e) {
      // Always log errors
      debugPrint('Error clearing tasks: $e');
    }
  }

  /// Force delete all local tasks (for debugging)
  void forceClearLocalTasks() {
    _localTasks.clear();
    _tasksController.add([]);
    if (ProductionConfig.enableDebugLogs) {
      debugPrint('📋 All local tasks cleared');
    }
  }

  /// Force toggle first task (for debugging)
  bool forceToggleFirstTask() {
    if (_localTasks.isEmpty) {
      print('📋 No tasks to toggle');
      return false;
    }
    print('📋 Force toggling first task: ${_localTasks.first.title}');
    return _toggleTaskByIndex(0);
  }
  
  /// Test method to add a simple task for debugging
  Future<void> addTestTask() async {
    if (_currentUserId == null) {
      print('📋 No current user for test task');
      return;
    }
    
    final testTask = Task(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Test Task ${DateTime.now().hour}:${DateTime.now().minute}',
      emoji: '🧪',
      priority: TaskPriority.medium,
      category: 'personal',
      createdAt: DateTime.now(),
      userId: _currentUserId,
    );
    
    _localTasks.insert(0, testTask);
    _tasksController.add(List.from(_localTasks));
    print('📋 Test task added: ${testTask.title}, total tasks: ${_localTasks.length}');
  }
  
  /// Check if user has any tasks (excluding example tasks)
  bool hasUserTasks() {
    // Example tasks typically have specific titles or are added by the system
    // We can identify user tasks by checking if they're not example tasks
    return _localTasks.any((task) => !_isExampleTask(task));
  }
  
  /// Check if example tasks have been added
  bool get hasExampleTasksAdded => _exampleTasksAdded;
  
  /// Check if a task is an example task
  bool _isExampleTask(Task task) {
    // Example tasks typically have these characteristics:
    // 1. They're added by the addExampleTasks method
    // 2. They might have specific titles or patterns
    // For now, we'll assume all tasks are user tasks unless they have specific example patterns
    final exampleTitles = [
      'Complete your morning workout',
      'Log your breakfast',
      'Take a 10-minute walk',
      'Drink 8 glasses of water',
      'Review your daily goals',
    ];
    
    return exampleTitles.contains(task.title);
  }

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Initialize the task service
  Future<void> initialize() async {
    if (_currentUserId == null) {
      print('📋 Task service: No current user, cannot initialize');
      return;
    }
    
    print('📋 Task service: Initializing for user $_currentUserId');
    
    // Delete any existing example tasks first
    await _deleteAllExampleTasks();
    
    // Start listening to tasks changes
    _startTasksListener();
    
    // Load initial tasks
    await _loadInitialTasks();
  }
  
  /// Delete all example tasks from Firebase and local cache
  Future<void> _deleteAllExampleTasks() async {
    if (_currentUserId == null) return;
    
    try {
      // Get all tasks directly from Firestore (not using getTasks to avoid recursion)
      final snapshot = await _firestore
          .collection('tasks')
          .where('userId', isEqualTo: _currentUserId)
          .get();
      
      final allTasks = snapshot.docs
          .map((doc) => Task.fromFirestore(doc))
          .toList();
      
      // Find example tasks
      final exampleTasks = allTasks.where((task) => _isExampleTask(task)).toList();
      
      if (exampleTasks.isEmpty) {
        print('📋 No example tasks found to delete');
        return;
      }
      
      print('📋 Found ${exampleTasks.length} example tasks to delete');
      
      // Delete from Firestore
      final batch = _firestore.batch();
      for (final task in exampleTasks) {
        batch.delete(_firestore.collection('tasks').doc(task.id));
        // Also remove from local list
        _localTasks.removeWhere((t) => t.id == task.id);
      }
      
      await batch.commit();
      
      // Update UI to remove example tasks
      _tasksController.add(List.from(_localTasks));
      
      print('📋 Deleted ${exampleTasks.length} example tasks');
    } catch (e) {
      print('📋 Error deleting example tasks: $e');
    }
  }
  
  /// Load initial tasks from Firestore (excluding example tasks)
  Future<void> _loadInitialTasks() async {
    try {
      final allTasks = await getTasks();
      // Filter out example tasks
      final userTasks = allTasks.where((task) => !_isExampleTask(task)).toList();
      
      // CRITICAL: Preserve temp tasks when loading initial tasks
      // Don't overwrite temp tasks that might have been added before initialization completes
      final tempTasks = _localTasks.where((task) => task.id.startsWith('temp_')).toList();
      
      if (tempTasks.isNotEmpty) {
        // Merge Firestore tasks with temp tasks
        final merged = <Task>[];
        merged.addAll(userTasks);
        merged.addAll(tempTasks);
        merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _localTasks = merged;
        _tasksController.add(List.from(_localTasks));
        if (kDebugMode) {
          debugPrint('📋 Initial tasks loaded: ${userTasks.length} from Firestore, ${tempTasks.length} temp tasks preserved');
        }
      } else {
        _localTasks = userTasks;
        _tasksController.add(userTasks);
        if (kDebugMode) {
          debugPrint('📋 Tasks loaded: ${userTasks.length} user tasks');
        }
      }
    } catch (e) {
      print('📋 Task service: Error loading initial tasks: $e');
    }
  }

  /// Start listening to tasks changes in Firestore (excluding example tasks)
  void _startTasksListener() {
    if (_currentUserId == null) return;

    _firestore
        .collection('tasks')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .listen((snapshot) {
      // CRITICAL: Capture temp tasks FIRST before processing Firestore data
      // This prevents race conditions where _localTasks gets overwritten
      final tempTasks = _localTasks.where((task) => task.id.startsWith('temp_')).toList();
      
      // Reduced logging - only log when tasks actually change
      final allTasks = snapshot.docs
        .map((doc) => Task.fromFirestore(doc))
        .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by creation date descending
      
      // Filter out example tasks
      final tasks = allTasks.where((task) => !_isExampleTask(task)).toList();
      
      // If we found example tasks in the stream, delete them
      if (allTasks.length != tasks.length) {
        if (kDebugMode) {
          debugPrint('📋 Found example tasks in stream, deleting them...');
        }
        _deleteExampleTasksFromFirestore(allTasks.where((task) => _isExampleTask(task)).toList());
      }
      
      // CRITICAL FIX: Merge Firestore tasks with local optimistic updates
      // Preserve tasks with temp IDs (optimistic updates) until they're saved to Firestore
      
      // Merge: Start with Firestore tasks, then add temp tasks that aren't in Firestore yet
      final mergedTasks = <Task>[];
      
      // Add all Firestore tasks first
      mergedTasks.addAll(tasks);
      
      // Add temp tasks that haven't been saved to Firestore yet
      for (final tempTask in tempTasks) {
        // Check if this temp task has been saved to Firestore
        // Match by title and creation time (within 5 seconds) since IDs will be different
        final foundInFirestore = tasks.any((ft) => 
          ft.title == tempTask.title && 
          ft.createdAt.difference(tempTask.createdAt).inSeconds.abs() < 5 &&
          ft.userId == tempTask.userId
        );
        
        if (!foundInFirestore) {
          // Task hasn't been saved to Firestore yet, keep it in the list
          mergedTasks.insert(0, tempTask); // Insert at beginning for newest first
          if (kDebugMode) {
            debugPrint('📋 Keeping temp task in list: ${tempTask.title} (ID: ${tempTask.id})');
          }
        } else {
          // Task has been saved to Firestore, it will be in the merged list from Firestore
          if (kDebugMode) {
            debugPrint('📋 Temp task found in Firestore, will use Firestore version: ${tempTask.title}');
          }
        }
      }
      
      // Sort by creation date descending
      mergedTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // CRITICAL: Don't overwrite if we have temp tasks and Firestore is empty
      // This prevents the listener from clearing temp tasks before they're saved
      if (tempTasks.isNotEmpty && tasks.isEmpty && _localTasks.isNotEmpty) {
        // We have temp tasks that haven't been saved yet, and Firestore is empty
        // Keep the current _localTasks (which includes temp tasks) and don't overwrite
        if (kDebugMode) {
          debugPrint('📋 Preserving temp tasks: Firestore is empty but we have ${tempTasks.length} temp tasks');
          debugPrint('📋 Temp tasks: ${tempTasks.map((t) => t.title).join(", ")}');
        }
        // Don't update _localTasks or emit - keep existing state
        return;
      }
      
      // Check if tasks actually changed before emitting
      final tasksChanged = _localTasks.length != mergedTasks.length ||
          !_tasksAreEqual(_localTasks, mergedTasks);
      
      // Update local tasks with merged list
      _localTasks = mergedTasks;
      
      // Only emit to stream if tasks actually changed
      // This prevents unnecessary UI rebuilds
      if (tasksChanged) {
        _tasksController.add(List.from(_localTasks));
        
        // Log for debugging
        if (kDebugMode) {
          debugPrint('📋 Tasks updated: ${mergedTasks.length} tasks (${tasks.length} from Firestore, ${tempTasks.length} temp)');
          if (tempTasks.isNotEmpty) {
            debugPrint('📋 Temp tasks preserved: ${tempTasks.map((t) => t.title).join(", ")}');
          }
        }
      }
    });
  }
  
  /// Check if two task lists are equal (by ID and completion status)
  bool _tasksAreEqual(List<Task> list1, List<Task> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id || 
          list1[i].isCompleted != list2[i].isCompleted) {
        return false;
      }
    }
    return true;
  }
  
  /// Delete example tasks from Firestore
  Future<void> _deleteExampleTasksFromFirestore(List<Task> exampleTasks) async {
    if (exampleTasks.isEmpty) return;
    
    try {
      final batch = _firestore.batch();
      for (final task in exampleTasks) {
        batch.delete(_firestore.collection('tasks').doc(task.id));
      }
      await batch.commit();
      print('📋 Deleted ${exampleTasks.length} example tasks from Firestore');
    } catch (e) {
      print('📋 Error deleting example tasks from Firestore: $e');
    }
  }

  /// Get all tasks for the current user (excluding example tasks)
  Future<List<Task>> getTasks() async {
    if (_currentUserId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('tasks')
          .where('userId', isEqualTo: _currentUserId)
          .get();

      final allTasks = snapshot.docs
          .map((doc) => Task.fromFirestore(doc))
          .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by creation date descending
      
      // Filter out example tasks
      final userTasks = allTasks.where((task) => !_isExampleTask(task)).toList();
      
      // If we found example tasks, delete them
      if (allTasks.length != userTasks.length) {
        print('📋 Found example tasks in getTasks, deleting them...');
        _deleteExampleTasksFromFirestore(allTasks.where((task) => _isExampleTask(task)).toList());
      }
      
      return userTasks;
    } catch (e) {
      print('Error getting tasks: $e');
      return [];
    }
  }

  /// Get today's tasks
  Future<List<Task>> getTodaysTasks() async {
    final allTasks = await getTasks();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return allTasks.where((task) {
      return task.createdAt.isAfter(startOfDay) && 
             task.createdAt.isBefore(endOfDay);
    }).toList();
  }

  /// Get completed tasks count for today
  Future<int> getTodaysCompletedTasksCount() async {
    final todaysTasks = await getTodaysTasks();
    return todaysTasks.where((task) => task.isCompleted).length;
  }

  /// Get pending tasks count for today
  Future<int> getTodaysPendingTasksCount() async {
    final todaysTasks = await getTodaysTasks();
    return todaysTasks.where((task) => !task.isCompleted).length;
  }

  /// Add a new task - returns immediately for instant UI update
  Task? addTask({
    required String title,
    String? description,
    List<String>? tags,
  }) {
    if (_currentUserId == null) return null;

    try {
      // Generate emoji based on title
      final emoji = _iconService.generateIcon(title);
      print('📋 Generated emoji for "$title": $emoji');
      
      // Get best category automatically from title
      final bestCategory = _iconService.getBestCategory(title);
      String taskCategory;
      if (bestCategory == 'default') {
        taskCategory = 'personal';
      } else {
        // Check if the category exists in our valid categories
        final validCategories = ['health', 'fitness', 'nutrition', 'work', 'personal', 'study', 'shopping', 'cleaning', 'social', 'hobbies', 'pets'];
        taskCategory = validCategories.contains(bestCategory) ? bestCategory : 'personal';
      }

      // Create task with temporary ID for immediate UI update
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final task = Task(
        id: tempId,
        title: title,
        emoji: emoji,
        priority: TaskPriority.medium, // Default priority
        createdAt: DateTime.now(),
        category: taskCategory,
        description: description, // Can be null - that's fine
        tags: tags,
        userId: _currentUserId,
      );

      // INSTANTLY add to local list and notify UI (no delays at all)
      _localTasks.insert(0, task); // Insert at beginning for newest first
      
      // CRITICAL: Emit to stream IMMEDIATELY with a copy to ensure UI sees it
      // This must happen BEFORE any Firestore operations
      final tasksCopy = List<Task>.from(_localTasks);
      _tasksController.add(tasksCopy);
      
      print('📋 Task INSTANTLY added to UI: ${task.title}, description: ${description ?? "null"}, total tasks: ${_localTasks.length}');
      print('📋 Current _localTasks: ${_localTasks.map((t) => '${t.id}:${t.title}').join(", ")}');
      print('📋 Emitted to stream: ${tasksCopy.length} tasks');
      
      // Add to Firestore in background (completely separate from UI)
      _addTaskToFirestoreAsync(task);
      
      return task;
    } catch (e) {
      print('Error adding task: $e');
      return null;
    }
  }

  /// Add task to Firestore asynchronously (background operation)
  void _addTaskToFirestoreAsync(Task task) {
    _addTaskToFirestore(task).then((createdTask) {
      if (createdTask != null) {
        // Update local task with real ID
        final index = _localTasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _localTasks[index] = createdTask;
          _tasksController.add(List.from(_localTasks));
          print('📋 Task updated with real ID: ${createdTask.id} (was: ${task.id})');
        }
      }
    }).catchError((error) {
      // Remove task from local list if Firestore add failed
      _localTasks.removeWhere((t) => t.id == task.id);
      _tasksController.add(List.from(_localTasks));
      print('📋 Task removed due to Firestore error: $error');
    });
  }

  /// Add task to Firestore (background operation)
  Future<Task?> _addTaskToFirestore(Task task) async {
    try {
      // Ensure description is properly handled (can be null)
      final firestoreData = task.toFirestore();
      // Remove null description from Firestore data if it's null (optional field)
      if (firestoreData['description'] == null) {
        firestoreData.remove('description');
      }
      
      final docRef = await _firestore.collection('tasks').add(firestoreData);
      print('📋 Task added to Firestore with ID: ${docRef.id}, description: ${task.description ?? "null"}');
      
      // Update the task with the generated ID
      final createdTask = task.copyWith(id: docRef.id);
      
      // Update the document with the ID
      await docRef.update({'id': docRef.id});
      print('📋 Task document updated with ID');
      
      _taskUpdateController.add(createdTask);
      return createdTask;
    } catch (e) {
      print('Error adding task to Firestore: $e');
      print('📋 Task that failed: title=${task.title}, description=${task.description ?? "null"}');
      return null;
    }
  }

  /// Update an existing task
  Future<bool> updateTask(Task task) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore
          .collection('tasks')
          .doc(task.id)
          .update(task.toFirestore());
      
      _taskUpdateController.add(task);
      return true;
    } catch (e) {
      print('Error updating task: $e');
      return false;
    }
  }

  /// Toggle task completion status - returns immediately for instant UI update
  bool toggleTaskCompletion(String taskId) {
    if (_currentUserId == null) {
      print('📋 Toggle failed: No current user');
      return false;
    }

    try {
      print('📋 Attempting to toggle task with ID: $taskId');
      print('📋 Current tasks: ${_localTasks.map((t) => '${t.id}:${t.title}:${t.isCompleted}').toList()}');
      
      // Find task in local list first
      final index = _localTasks.indexWhere((t) => t.id == taskId);
      if (index == -1) {
        print('📋 Task not found in local list: $taskId');
        // Try partial match
        final partialMatch = _localTasks.where((t) => t.id.contains(taskId) || taskId.contains(t.id)).toList();
        if (partialMatch.isNotEmpty) {
          print('📋 Found partial match: ${partialMatch.map((t) => '${t.id}:${t.title}').toList()}');
          final actualTaskId = partialMatch.first.id;
          final actualIndex = _localTasks.indexWhere((t) => t.id == actualTaskId);
          if (actualIndex != -1) {
            print('📋 Using partial match with ID: $actualTaskId');
            return _toggleTaskByIndex(actualIndex);
          }
        }
        return false;
      }

      return _toggleTaskByIndex(index);
    } catch (e) {
      print('Error toggling task completion: $e');
      return false;
    }
  }

  /// Toggle task by index (helper method)
  bool _toggleTaskByIndex(int index) {
    try {
      final task = _localTasks[index];
      print('📋 Found task to toggle: ${task.title}, current status: ${task.isCompleted}');
      
      final updatedTask = task.copyWith(
        isCompleted: !task.isCompleted,
        completedAt: !task.isCompleted ? DateTime.now() : null,
      );
      print('📋 New status: ${updatedTask.isCompleted}');

      // INSTANTLY update local list and UI (no delays at all)
      _localTasks[index] = updatedTask;
      _tasksController.add(List.from(_localTasks));
      print('📋 Task completion INSTANTLY toggled in UI');
      
      // Update Firestore in background (completely separate from UI)
      _updateTaskInFirestoreAsync(updatedTask, task, index);
      
      _taskUpdateController.add(updatedTask);
      return true;
    } catch (e) {
      print('Error toggling task by index: $e');
      return false;
    }
  }

  /// Update task in Firestore asynchronously (background operation)
  void _updateTaskInFirestoreAsync(Task updatedTask, Task originalTask, int index) {
    _updateTaskInFirestore(updatedTask).catchError((error) {
      // Revert local change if Firestore update failed
      _localTasks[index] = originalTask;
      _tasksController.add(List.from(_localTasks));
      print('📋 Task completion reverted due to Firestore error: $error');
    });
  }

  /// Update task in Firestore (background operation)
  Future<void> _updateTaskInFirestore(Task task) async {
    try {
      await _firestore
          .collection('tasks')
          .doc(task.id)
          .update(task.toFirestore());
      print('📋 Task updated in Firestore: ${task.id}');
    } catch (e) {
      print('Error updating task in Firestore: $e');
      rethrow;
    }
  }

  /// Delete a task - returns immediately for instant UI update
  bool deleteTask(String taskId) {
    if (_currentUserId == null) {
      print('📋 Delete failed: No current user');
      return false;
    }

    try {
      print('📋 Attempting to delete task with ID: $taskId');
      print('📋 Current tasks: ${_localTasks.map((t) => '${t.id}:${t.title}').toList()}');
      
      // Check if task exists in local list
      final taskIndex = _localTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex == -1) {
        print('📋 Task not found in local list: $taskId');
        // Try to find by partial match (in case of ID mismatch)
        final partialMatch = _localTasks.where((t) => t.id.contains(taskId) || taskId.contains(t.id)).toList();
        if (partialMatch.isNotEmpty) {
          print('📋 Found partial match: ${partialMatch.map((t) => '${t.id}:${t.title}').toList()}');
          // Use the first partial match
          final actualTaskId = partialMatch.first.id;
          final actualIndex = _localTasks.indexWhere((t) => t.id == actualTaskId);
          if (actualIndex != -1) {
            print('📋 Using partial match with ID: $actualTaskId');
            return _deleteTaskByIndex(actualIndex);
          }
        }
        
        // Last resort: try to delete the first task (for debugging)
        if (_localTasks.isNotEmpty) {
          print('📋 ID not found, deleting first task as fallback: ${_localTasks.first.title}');
          return _deleteTaskByIndex(0);
        }
        return false;
      }
      
      return _deleteTaskByIndex(taskIndex);
    } catch (e) {
      print('Error deleting task: $e');
      return false;
    }
  }

  /// Delete task by index (helper method)
  bool _deleteTaskByIndex(int taskIndex) {
    try {
      final taskToDelete = _localTasks[taskIndex];
      print('📋 Found task to delete: ${taskToDelete.title} (ID: ${taskToDelete.id})');
      
      // INSTANTLY remove from local list and UI (no delays at all)
      _localTasks.removeAt(taskIndex);
      print('📋 Removed from local list. Remaining tasks: ${_localTasks.length}');
      
      // Emit updated list to stream
      _tasksController.add(List.from(_localTasks));
      print('📋 Task INSTANTLY deleted from UI');
      
      // Delete from Firestore in background (completely separate from UI)
      _deleteTaskFromFirestoreAsync(taskToDelete.id, taskToDelete);
      
      return true;
    } catch (e) {
      print('Error deleting task by index: $e');
      return false;
    }
  }

  /// Delete task from Firestore asynchronously (background operation)
  void _deleteTaskFromFirestoreAsync(String taskId, Task taskToDelete) {
    _deleteTaskFromFirestore(taskId).catchError((error) {
      // Revert local change if Firestore delete failed
      _localTasks.insert(0, taskToDelete); // Insert at beginning
      _tasksController.add(List.from(_localTasks));
      print('📋 Task deletion reverted due to Firestore error: $error');
    });
  }

  /// Delete task from Firestore (background operation)
  Future<void> _deleteTaskFromFirestore(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
      print('📋 Task deleted from Firestore: $taskId');
    } catch (e) {
      print('Error deleting task from Firestore: $e');
      rethrow;
    }
  }

  /// Add example tasks for new users (only if no tasks exist)
  Future<void> addExampleTasks() async {
    if (_currentUserId == null) return;

    // Prevent multiple additions
    if (_exampleTasksAdded) {
      print('📋 Example tasks already added, skipping');
      return;
    }

    try {
      // Check if user already has tasks (including local tasks)
      if (_localTasks.isNotEmpty) {
        print('📋 User already has tasks, skipping example tasks');
        return;
      }

      // Check Firestore for existing tasks
      final existingTasks = await getTasks();
      if (existingTasks.isNotEmpty) {
        print('📋 User already has tasks in Firestore, skipping example tasks');
        return;
      }

      print('📋 Adding ${ExampleTasks.tasks.length} example tasks for new user');
      
      // Set flag to prevent multiple additions
      _exampleTasksAdded = true;
      
      // Add example tasks
      for (final taskData in ExampleTasks.tasks) {
        final task = ExampleTasks.createExampleTask(taskData, _currentUserId!);
        final docRef = await _firestore.collection('tasks').add(task.toFirestore());
        final createdTask = task.copyWith(id: docRef.id);
        
        // Add to local list immediately
        _localTasks.add(createdTask);
      }
      
      // Update UI with example tasks
      _tasksController.add(List.from(_localTasks));
      print('📋 Example tasks added and UI updated');
    } catch (e) {
      print('Error adding example tasks: $e');
      _exampleTasksAdded = false; // Reset flag on error
    }
  }

  /// Get task statistics
  Future<Map<String, int>> getTaskStatistics() async {
    final tasks = await getTasks();
    
    return {
      'total': tasks.length,
      'completed': tasks.where((task) => task.isCompleted).length,
      'pending': tasks.where((task) => !task.isCompleted).length,
      'highPriority': tasks.where((task) => task.priority == TaskPriority.high).length,
      'overdue': tasks.where((task) => task.isOverdue).length,
    };
  }

  /// Get tasks by category
  Future<List<Task>> getTasksByCategory(String category) async {
    final tasks = await getTasks();
    return tasks.where((task) => task.category == category).toList();
  }

  /// Get tasks by priority
  Future<List<Task>> getTasksByPriority(TaskPriority priority) async {
    final tasks = await getTasks();
    return tasks.where((task) => task.priority == priority).toList();
  }

  /// Search tasks by title
  Future<List<Task>> searchTasks(String query) async {
    final tasks = await getTasks();
    return tasks.where((task) => 
        task.title.toLowerCase().contains(query.toLowerCase())).toList();
  }

  /// Mark all tasks as completed
  Future<bool> markAllTasksCompleted() async {
    if (_currentUserId == null) return false;

    try {
      final tasks = await getTasks();
      final pendingTasks = tasks.where((task) => !task.isCompleted);
      
      final batch = _firestore.batch();
      for (final task in pendingTasks) {
        final updatedTask = task.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );
        batch.update(
          _firestore.collection('tasks').doc(task.id),
          updatedTask.toFirestore(),
        );
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      print('Error marking all tasks as completed: $e');
      return false;
    }
  }

  /// Clear all completed tasks
  Future<bool> clearCompletedTasks() async {
    if (_currentUserId == null) return false;

    try {
      final tasks = await getTasks();
      final completedTasks = tasks.where((task) => task.isCompleted);
      
      final batch = _firestore.batch();
      for (final task in completedTasks) {
        batch.delete(_firestore.collection('tasks').doc(task.id));
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      print('Error clearing completed tasks: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _tasksController.close();
    _taskUpdateController.close();
  }
}
