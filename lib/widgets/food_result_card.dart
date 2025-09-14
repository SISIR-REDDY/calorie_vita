import 'package:flutter/material.dart';
import '../ui/app_colors.dart';

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
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: kElevatedShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: kPrimaryGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (calories != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$calories kcal',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Macros section
                if (macros != null && macros!.isNotEmpty) ...[
                  _buildMacrosSection(macros!),
                  const SizedBox(height: 20),
                ],
                
                // Comment section
                if (comment != null && comment!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kInfoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kInfoColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: kInfoColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            comment!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: kTextPrimary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Action buttons
                Row(
                  children: [
                    if (onRetry != null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimaryColor,
                            side: const BorderSide(color: kPrimaryColor, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (onAskTrainer != null) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onAskTrainer,
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Ask Trainer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSecondaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosSection(Map<String, dynamic> macros) {
    final macroItems = <Widget>[];
    
    if (macros.containsKey('protein')) {
      macroItems.add(_buildMacroItem('Protein', macros['protein'], kSuccessColor, Icons.fitness_center));
    }
    if (macros.containsKey('carbs')) {
      macroItems.add(_buildMacroItem('Carbs', macros['carbs'], kAccentColor, Icons.grain));
    }
    if (macros.containsKey('fat')) {
      macroItems.add(_buildMacroItem('Fat', macros['fat'], kWarningColor, Icons.water_drop));
    }
    if (macros.containsKey('fiber')) {
      macroItems.add(_buildMacroItem('Fiber', macros['fiber'], kInfoColor, Icons.eco));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.pie_chart,
                color: kPrimaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Macronutrients',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: macroItems,
        ),
      ],
    );
  }

  Widget _buildMacroItem(String label, dynamic value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                '$value g',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 