/// Health Backend - Complete backend architecture for Health Connect integration
/// 
/// This library provides a clean architecture implementation for loading
/// Google Fit data through Health Connect on Android.
/// 
/// ## Basic Usage with Hub (Recommended)
/// 
/// ```dart
/// import 'package:calorie_vita/health_backend/health_backend.dart';
/// 
/// // Get the hub instance (singleton)
/// final hub = HealthDataHub();
/// 
/// // Initialize (one time)
/// await hub.initialize();
/// 
/// // Access data anywhere in your app
/// print('Steps: ${hub.steps}');
/// print('Calories: ${hub.calories}');
/// print('Workouts: ${hub.workoutCount}');
/// 
/// // Refresh when needed
/// await hub.refresh();
/// 
/// // Listen to real-time updates
/// hub.dataStream.listen((data) {
///   print('Data updated: ${data?.steps}');
/// });
/// ```
/// 
/// ## Provider Integration
/// 
/// ```dart
/// // In main.dart
/// void main() {
///   runApp(
///     HealthDataProvider(
///       child: MyApp(),
///     ),
///   );
/// }
/// 
/// // In any widget
/// final hub = context.healthHub;
/// print('Steps: ${hub.steps}');
/// 
/// // Or with Consumer
/// Consumer<HealthDataHub>(
///   builder: (context, hub, child) {
///     return Text('Steps: ${hub.steps}');
///   },
/// )
/// ```
library health_backend;

// Core - Data Hub (Centralized data store)
export 'core/health_data_hub.dart';
export 'core/health_data_provider.dart';

// Widgets - UI Components
export 'widgets/health_data_builder.dart';

// Data Source Layer
export 'data_source/health_connect_service.dart';

// Models Layer
export 'models/steps_model.dart';
export 'models/calories_model.dart';
export 'models/workout_model.dart';
export 'models/health_data_model.dart';

// Repository Layer
export 'repository/health_repository.dart';

// Controller Layer
export 'controller/health_controller.dart';

