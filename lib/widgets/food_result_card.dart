import 'package:flutter/material.dart';

class FoodResultCard extends StatelessWidget {
  final String title;
  final int? calories;
  final Map<String, dynamic>? macros;
  final String? comment;
  final String? imageUrl;
  final VoidCallback? onRetry;
  final VoidCallback? onAskTrainer;

  const FoodResultCard({
    super.key,
    required this.title,
    this.calories,
    this.macros,
    this.comment,
    this.imageUrl,
    this.onRetry,
    this.onAskTrainer,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Implement beautiful card UI
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (calories != null) ...[
              const SizedBox(height: 8),
              Text('$calories kcal', style: Theme.of(context).textTheme.titleLarge),
            ],
            if (macros != null) ...[
              const SizedBox(height: 8),
              Text('Macros: ${macros.toString()}'),
            ],
            if (comment != null) ...[
              const SizedBox(height: 12),
              Text(comment!, style: TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
            if (onAskTrainer != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onAskTrainer,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Ask Trainer Sisir'),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 