import 'package:flutter/material.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';

class PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const PremiumNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.home_rounded,
      Icons.bar_chart_rounded,
      Icons.auto_awesome_rounded,
      Icons.settings_rounded,
    ];
    final labels = [
      'Home', 'Analytics', 'AI Trainer', 'Settings'
    ];
    return AnimatedBottomNavigationBar(
      icons: icons,
      activeIndex: currentIndex > 1 ? currentIndex - 1 : currentIndex,
      gapLocation: GapLocation.center,
      notchSmoothness: NotchSmoothness.softEdge,
      leftCornerRadius: 24,
      rightCornerRadius: 24,
      onTap: (index) {
        if (index >= 2) {
          onTabSelected(index + 1);
        } else {
          onTabSelected(index);
        }
      },
      activeColor: Theme.of(context).colorScheme.primary,
      inactiveColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      iconSize: 28,
      backgroundColor: Theme.of(context).colorScheme.surface,
      splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      shadow: const BoxShadow(
        color: Colors.black12,
        blurRadius: 8,
      ),
    );
  }
} 