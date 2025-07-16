import 'package:flutter/material.dart';

class AITrainerScreen extends StatelessWidget {
  const AITrainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tips = [
      'Try a protein-rich breakfast tomorrow!',
      'Drink at least 2L of water today.',
      'Consider a 20-min walk after lunch.',
      'Log your meals for better tracking.',
      'Add more veggies to your dinner.',
    ];
    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: tips.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('AI Trainer', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            );
          }
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tips[i - 1], style: Theme.of(context).textTheme.bodyLarge),
            ),
          );
        },
      ),
    );
  }
} 