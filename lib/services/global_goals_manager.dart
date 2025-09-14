import '../models/user_goals.dart';

/// Global goals manager for immediate UI updates
class GlobalGoalsManager {
  static final GlobalGoalsManager _instance = GlobalGoalsManager._internal();
  factory GlobalGoalsManager() => _instance;
  GlobalGoalsManager._internal();

  // Callback function to notify home screen
  Function(UserGoals)? _onGoalsUpdated;

  /// Set callback for goals updates
  void setGoalsUpdateCallback(Function(UserGoals) callback) {
    _onGoalsUpdated = callback;
  }

  /// Notify goals update
  void notifyGoalsUpdate(UserGoals goals) {
    if (_onGoalsUpdated != null) {
      _onGoalsUpdated!(goals);
    }
  }

  /// Clear callback
  void clearCallback() {
    _onGoalsUpdated = null;
  }
}
