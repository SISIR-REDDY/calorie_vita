import 'package:flutter/material.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import '../ui/app_colors.dart';

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
    
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: AnimatedBottomNavigationBar(
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
        activeColor: kPrimaryColor,
        inactiveColor: kTextTertiary,
        iconSize: 24,
        backgroundColor: kSurfaceColor,
        splashColor: kPrimaryColor.withValues(alpha: 0.1),
        splashSpeedInMilliseconds: 300,
        elevation: 0,
      ),
    );
  }
} 