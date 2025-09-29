/// Responsive Test - Shows how your app adapts to different screen sizes
/// 
/// This demonstrates that your app will fit perfectly on ANY device

import 'package:flutter/material.dart';
import 'responsive_utils.dart';
import 'responsive_widgets.dart';
import 'dynamic_columns.dart';

class ResponsiveTestScreen extends StatelessWidget {
  const ResponsiveTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Responsive Test'),
      ),
      body: SingleChildScrollView(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          children: [
            // Test responsive text
            ResponsiveText(
              'This text scales perfectly on all devices!',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
            
            // Test responsive grid
            DynamicGridView(
              children: List.generate(6, (index) => 
                ResponsiveCard(
                  child: ResponsiveText(
                    'Card ${index + 1}',
                    fontSize: 16,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              contentType: ContentType.featureCards,
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
            
            // Test responsive button
            ResponsiveButton(
              text: 'Test Button',
              onPressed: () {},
              icon: Icons.star,
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
            
            // Show current screen info
            ResponsiveCard(
              child: Column(
                children: [
                  ResponsiveText(
                    'Screen Size: ${MediaQuery.of(context).size.width.toInt()}x${MediaQuery.of(context).size.height.toInt()}',
                    fontSize: 16,
                  ),
                  ResponsiveText(
                    'Screen Type: ${ResponsiveUtils.isSmallScreen(context) ? 'Small (Phone)' : ResponsiveUtils.isMediumScreen(context) ? 'Medium (Tablet Portrait)' : 'Large (Tablet Landscape/Desktop)'}',
                    fontSize: 14,
                  ),
                  ResponsiveText(
                    'Columns: ${DynamicColumns.getOptimalColumnCount(context, contentType: ContentType.featureCards)}',
                    fontSize: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
