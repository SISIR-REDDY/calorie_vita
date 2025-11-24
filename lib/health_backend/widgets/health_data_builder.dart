import 'package:flutter/material.dart';
import '../core/health_data_hub.dart';
import '../models/health_data_model.dart';

/// Builder widget for easy health data access in UI
/// 
/// Automatically handles loading, error, and data states.
/// 
/// Usage:
/// ```dart
/// HealthDataBuilder(
///   hub: HealthDataHub(),
///   builder: (context, data) {
///     return Column(
///       children: [
///         Text('Steps: ${data.steps}'),
///         Text('Calories: ${data.calories}'),
///       ],
///     );
///   },
///   loading: () => CircularProgressIndicator(),
///   error: (error) => Text('Error: $error'),
/// )
/// ```
class HealthDataBuilder extends StatelessWidget {
  final HealthDataHub hub;
  final Widget Function(BuildContext context, HealthDataModel data) builder;
  final Widget Function()? loading;
  final Widget Function(String error)? error;
  final Widget Function()? noData;

  const HealthDataBuilder({
    super.key,
    required this.hub,
    required this.builder,
    this.loading,
    this.error,
    this.noData,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: hub,
      builder: (context, child) {
        // Show loading state
        if (hub.isLoading && !hub.hasData) {
          return loading?.call() ??
              const Center(child: CircularProgressIndicator());
        }

        // Show error state
        if (hub.hasError && !hub.hasData) {
          return error?.call(hub.errorMessage!) ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${hub.errorMessage}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
        }

        // Show no data state
        if (!hub.hasData) {
          return noData?.call() ??
              const Center(child: Text('No data available'));
        }

        // Show data
        return builder(context, hub.data!);
      },
    );
  }
}

/// Stream builder for real-time health data updates
/// 
/// Usage:
/// ```dart
/// HealthDataStreamBuilder(
///   hub: HealthDataHub(),
///   builder: (context, data) {
///     return Text('Steps: ${data.steps}');
///   },
/// )
/// ```
class HealthDataStreamBuilder extends StatelessWidget {
  final HealthDataHub hub;
  final Widget Function(BuildContext context, HealthDataModel data) builder;
  final Widget Function()? loading;
  final Widget Function(String error)? error;

  const HealthDataStreamBuilder({
    super.key,
    required this.hub,
    required this.builder,
    this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HealthDataModel?>(
      stream: hub.dataStream,
      initialData: hub.data,
      builder: (context, snapshot) {
        // Show loading state
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return loading?.call() ??
              const Center(child: CircularProgressIndicator());
        }

        // Show error state
        if (snapshot.hasError) {
          return error?.call(snapshot.error.toString()) ??
              Center(child: Text('Error: ${snapshot.error}'));
        }

        // Show no data state
        if (!snapshot.hasData) {
          return const Center(child: Text('No data available'));
        }

        // Show data
        return builder(context, snapshot.data!);
      },
    );
  }
}

/// Widget for displaying steps count
class StepsDisplay extends StatelessWidget {
  final HealthDataHub hub;
  final TextStyle? style;
  final String? label;

  const StepsDisplay({
    super.key,
    required this.hub,
    this.style,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: hub,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null)
              Text(label!, style: Theme.of(context).textTheme.bodySmall),
            Text(
              '${hub.steps}',
              style: style ?? Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        );
      },
    );
  }
}

/// Widget for displaying calories count
class CaloriesDisplay extends StatelessWidget {
  final HealthDataHub hub;
  final TextStyle? style;
  final String? label;
  final int decimalPlaces;

  const CaloriesDisplay({
    super.key,
    required this.hub,
    this.style,
    this.label,
    this.decimalPlaces = 1,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: hub,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null)
              Text(label!, style: Theme.of(context).textTheme.bodySmall),
            Text(
              '${hub.calories.toStringAsFixed(decimalPlaces)} kcal',
              style: style ?? Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        );
      },
    );
  }
}

/// Widget for displaying workout count
class WorkoutCountDisplay extends StatelessWidget {
  final HealthDataHub hub;
  final TextStyle? style;
  final String? label;

  const WorkoutCountDisplay({
    super.key,
    required this.hub,
    this.style,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: hub,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null)
              Text(label!, style: Theme.of(context).textTheme.bodySmall),
            Text(
              '${hub.workoutCount} sessions',
              style: style ?? Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        );
      },
    );
  }
}

