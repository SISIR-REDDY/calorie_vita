import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'health_data_hub.dart';

/// Provider wrapper for HealthDataHub
/// 
/// Makes the hub easily accessible throughout the widget tree.
/// 
/// Usage:
/// 
/// 1. Wrap your app with HealthDataProvider:
/// ```dart
/// void main() {
///   runApp(
///     HealthDataProvider(
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
/// 
/// 2. Access in widgets:
/// ```dart
/// // With Provider.of
/// final hub = Provider.of<HealthDataHub>(context);
/// print('Steps: ${hub.steps}');
/// 
/// // With Consumer
/// Consumer<HealthDataHub>(
///   builder: (context, hub, child) {
///     return Text('Steps: ${hub.steps}');
///   },
/// )
/// 
/// // With context extension
/// final hub = context.healthHub;
/// print('Steps: ${hub.steps}');
/// ```
class HealthDataProvider extends StatefulWidget {
  final Widget child;
  final bool autoInitialize;
  final bool autoRefresh;

  const HealthDataProvider({
    Key? key,
    required this.child,
    this.autoInitialize = true,
    this.autoRefresh = true,
  }) : super(key: key);

  @override
  State<HealthDataProvider> createState() => _HealthDataProviderState();
}

class _HealthDataProviderState extends State<HealthDataProvider> {
  final HealthDataHub _hub = HealthDataHub();

  @override
  void initState() {
    super.initState();
    if (widget.autoInitialize) {
      _initializeHub();
    }
  }

  Future<void> _initializeHub() async {
    try {
      await _hub.initialize(autoRefresh: widget.autoRefresh);
    } catch (e) {
      print('Failed to initialize HealthDataHub: $e');
    }
  }

  @override
  void dispose() {
    // Don't dispose the hub as it's a singleton
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HealthDataHub>.value(
      value: _hub,
      child: widget.child,
    );
  }
}

/// Extension on BuildContext for easy access to HealthDataHub
extension HealthDataHubContext on BuildContext {
  /// Get HealthDataHub instance
  /// 
  /// Usage:
  /// ```dart
  /// final hub = context.healthHub;
  /// print('Steps: ${hub.steps}');
  /// ```
  HealthDataHub get healthHub => Provider.of<HealthDataHub>(this, listen: false);

  /// Watch HealthDataHub for changes
  /// 
  /// Usage:
  /// ```dart
  /// final hub = context.watchHealthHub;
  /// // Widget will rebuild when hub notifies
  /// ```
  HealthDataHub get watchHealthHub => Provider.of<HealthDataHub>(this);
}

