import 'dart:async';
import '../models/user_goals.dart';

/// Simple event bus for goals updates
class GoalsEventBus {
  static final GoalsEventBus _instance = GoalsEventBus._internal();
  factory GoalsEventBus() => _instance;
  GoalsEventBus._internal();

  final StreamController<UserGoals> _goalsController =
      StreamController<UserGoals>.broadcast();

  /// Stream of goals updates
  Stream<UserGoals> get goalsStream => _goalsController.stream;

  /// Emit goals update
  void emitGoalsUpdate(UserGoals goals) {
    _goalsController.add(goals);
  }

  /// Dispose
  void dispose() {
    _goalsController.close();
  }
}
