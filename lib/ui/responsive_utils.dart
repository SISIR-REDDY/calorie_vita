import 'package:flutter/material.dart';

/// Comprehensive responsive utility system for perfect UI across all screen sizes
class ResponsiveUtils {
  static const double _baseWidth = 375.0; // iPhone 12 Pro base width
  static const double _baseHeight = 812.0; // iPhone 12 Pro base height
  
  // Screen size breakpoints
  static const double _smallScreenBreakpoint = 600;
  static const double _mediumScreenBreakpoint = 900;
  static const double _largeScreenBreakpoint = 1200;
  
  /// Get screen width multiplier for responsive scaling
  static double getScreenWidthMultiplier(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth / _baseWidth;
  }
  
  /// Get screen height multiplier for responsive scaling
  static double getScreenHeightMultiplier(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return screenHeight / _baseHeight;
  }
  
  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final multiplier = getScreenWidthMultiplier(context);
    return EdgeInsets.symmetric(
      horizontal: (16.0 * multiplier).clamp(12.0, 24.0),
      vertical: (8.0 * multiplier).clamp(6.0, 16.0),
    );
  }
  
  /// Get responsive margin based on screen size
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final multiplier = getScreenWidthMultiplier(context);
    return EdgeInsets.all((8.0 * multiplier).clamp(4.0, 16.0));
  }
  
  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final multiplier = getScreenWidthMultiplier(context);
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    
    // Adjust for high DPI screens
    double adjustedMultiplier = multiplier;
    if (devicePixelRatio > 2.5) {
      adjustedMultiplier *= 0.95; // Slightly smaller for very high DPI
    } else if (devicePixelRatio < 2.0) {
      adjustedMultiplier *= 1.05; // Slightly larger for lower DPI
    }
    
    return (baseFontSize * adjustedMultiplier).clamp(
      baseFontSize * 0.8, 
      baseFontSize * 1.3
    );
  }
  
  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context, double baseIconSize) {
    final multiplier = getScreenWidthMultiplier(context);
    return (baseIconSize * multiplier).clamp(baseIconSize * 0.8, baseIconSize * 1.2);
  }
  
  /// Get responsive spacing
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final multiplier = getScreenWidthMultiplier(context);
    return (baseSpacing * multiplier).clamp(baseSpacing * 0.7, baseSpacing * 1.3);
  }
  
  /// Get responsive padding (common values)
  static EdgeInsets getResponsivePaddingAll(BuildContext context, double basePadding) {
    final padding = getResponsiveSpacing(context, basePadding);
    return EdgeInsets.all(padding);
  }
  
  /// Get responsive padding for small screens
  static EdgeInsets getResponsivePaddingSmall(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth < 360 ? 12.0 : (screenWidth < 600 ? 16.0 : 20.0);
    return EdgeInsets.all(padding);
  }
  
  /// Get responsive padding for medium screens
  static EdgeInsets getResponsivePaddingMedium(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth < 360 ? 16.0 : (screenWidth < 600 ? 20.0 : 24.0);
    return EdgeInsets.all(padding);
  }
  
  /// Get responsive padding for large screens
  static EdgeInsets getResponsivePaddingLarge(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth < 360 ? 20.0 : (screenWidth < 600 ? 24.0 : 28.0);
    return EdgeInsets.all(padding);
  }
  
  /// Get responsive border radius
  static double getResponsiveBorderRadius(BuildContext context, double baseRadius) {
    final multiplier = getScreenWidthMultiplier(context);
    return (baseRadius * multiplier).clamp(baseRadius * 0.8, baseRadius * 1.2);
  }
  
  /// Check if screen is small (phones in portrait)
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < _smallScreenBreakpoint;
  }
  
  /// Check if screen is medium (tablets in portrait, phones in landscape)
  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= _smallScreenBreakpoint && width < _mediumScreenBreakpoint;
  }
  
  /// Check if screen is large (tablets in landscape, desktops)
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= _mediumScreenBreakpoint;
  }
  
  /// Get responsive column count for grids
  static int getResponsiveColumnCount(BuildContext context, {int? baseColumns}) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < _smallScreenBreakpoint) {
      return baseColumns ?? 1; // Mobile portrait
    } else if (width < _mediumScreenBreakpoint) {
      return (baseColumns ?? 1) + 1; // Mobile landscape / small tablet
    } else if (width < _largeScreenBreakpoint) {
      return (baseColumns ?? 1) + 2; // Tablet portrait
    } else {
      return (baseColumns ?? 1) + 3; // Tablet landscape / desktop
    }
  }
  
  /// Get responsive card width
  static double getResponsiveCardWidth(BuildContext context, {double? maxWidth}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final multiplier = getScreenWidthMultiplier(context);
    
    if (isSmallScreen(context)) {
      return screenWidth - getResponsivePadding(context).horizontal;
    } else {
      final calculatedWidth = (300.0 * multiplier).clamp(250.0, 400.0);
      return maxWidth != null ? calculatedWidth.clamp(0, maxWidth) : calculatedWidth;
    }
  }
  
  /// Get responsive dialog width
  static double getResponsiveDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (isSmallScreen(context)) {
      return screenWidth * 0.9;
    } else if (isMediumScreen(context)) {
      return screenWidth * 0.7;
    } else {
      return screenWidth * 0.5;
    }
  }
  
  /// Get responsive bottom sheet height
  static double getResponsiveBottomSheetHeight(BuildContext context, double baseHeight) {
    final screenHeight = MediaQuery.of(context).size.height;
    final multiplier = getScreenHeightMultiplier(context);
    
    final calculatedHeight = baseHeight * multiplier;
    return calculatedHeight.clamp(
      screenHeight * 0.3, 
      screenHeight * 0.8
    );
  }
  
  /// Get responsive button height
  static double getResponsiveButtonHeight(BuildContext context) {
    final multiplier = getScreenWidthMultiplier(context);
    return (48.0 * multiplier).clamp(44.0, 56.0);
  }
  
  /// Get responsive input field height
  static double getResponsiveInputHeight(BuildContext context) {
    final multiplier = getScreenWidthMultiplier(context);
    return (56.0 * multiplier).clamp(48.0, 64.0);
  }
  
  /// Get responsive app bar height
  static double getResponsiveAppBarHeight(BuildContext context) {
    final multiplier = getScreenHeightMultiplier(context);
    return (56.0 * multiplier).clamp(48.0, 72.0);
  }
  
  /// Get responsive tab bar height
  static double getResponsiveTabBarHeight(BuildContext context) {
    final multiplier = getScreenWidthMultiplier(context);
    return (48.0 * multiplier).clamp(40.0, 56.0);
  }
  
  /// Check if device has notch or safe area
  static bool hasNotch(BuildContext context) {
    return MediaQuery.of(context).padding.top > 24;
  }
  
  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }
  
  /// Get responsive list tile height
  static double getResponsiveListTileHeight(BuildContext context) {
    final multiplier = getScreenWidthMultiplier(context);
    return (72.0 * multiplier).clamp(64.0, 88.0);
  }
  
  /// Get responsive chip height
  static double getResponsiveChipHeight(BuildContext context) {
    final multiplier = getScreenWidthMultiplier(context);
    return (32.0 * multiplier).clamp(28.0, 40.0);
  }
  
  /// Get responsive elevation
  static double getResponsiveElevation(BuildContext context, double baseElevation) {
    final multiplier = getScreenWidthMultiplier(context);
    return (baseElevation * multiplier).clamp(baseElevation * 0.5, baseElevation * 1.5);
  }
}

/// Responsive text style extension
extension ResponsiveTextStyle on TextStyle {
  TextStyle responsive(BuildContext context) {
    return copyWith(
      fontSize: ResponsiveUtils.getResponsiveFontSize(context, fontSize ?? 14.0),
      height: height != null ? (height! * ResponsiveUtils.getScreenWidthMultiplier(context)).clamp(height! * 0.9, height! * 1.1) : null,
    );
  }
}

/// Responsive widget mixin for easy integration
mixin ResponsiveWidgetMixin<T extends StatefulWidget> on State<T> {
  
  /// Get responsive padding
  EdgeInsets get responsivePadding => ResponsiveUtils.getResponsivePadding(context);
  
  /// Get responsive margin
  EdgeInsets get responsiveMargin => ResponsiveUtils.getResponsiveMargin(context);
  
  /// Get responsive spacing
  double responsiveSpacing(double baseSpacing) => 
      ResponsiveUtils.getResponsiveSpacing(context, baseSpacing);
  
  /// Get responsive font size
  double responsiveFontSize(double baseFontSize) => 
      ResponsiveUtils.getResponsiveFontSize(context, baseFontSize);
  
  /// Get responsive icon size
  double responsiveIconSize(double baseIconSize) => 
      ResponsiveUtils.getResponsiveIconSize(context, baseIconSize);
  
  /// Check screen size
  bool get isSmallScreen => ResponsiveUtils.isSmallScreen(context);
  bool get isMediumScreen => ResponsiveUtils.isMediumScreen(context);
  bool get isLargeScreen => ResponsiveUtils.isLargeScreen(context);
  
  /// Get responsive column count
  int responsiveColumnCount({int? baseColumns}) => 
      ResponsiveUtils.getResponsiveColumnCount(context, baseColumns: baseColumns);
}

/// Responsive layout builder widget
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints) builder;
  final Widget Function(BuildContext context)? smallScreenBuilder;
  final Widget Function(BuildContext context)? mediumScreenBuilder;
  final Widget Function(BuildContext context)? largeScreenBuilder;
  
  const ResponsiveLayoutBuilder({
    super.key,
    required this.builder,
    this.smallScreenBuilder,
    this.mediumScreenBuilder,
    this.largeScreenBuilder,
  });
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (ResponsiveUtils.isSmallScreen(context) && smallScreenBuilder != null) {
          return smallScreenBuilder!(context);
        } else if (ResponsiveUtils.isMediumScreen(context) && mediumScreenBuilder != null) {
          return mediumScreenBuilder!(context);
        } else if (ResponsiveUtils.isLargeScreen(context) && largeScreenBuilder != null) {
          return largeScreenBuilder!(context);
        }
        
        return builder(context, constraints);
      },
    );
  }
}

/// Responsive grid view widget
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final int? baseColumns;
  final double spacing;
  final double runSpacing;
  final EdgeInsets padding;
  
  const ResponsiveGridView({
    super.key,
    required this.children,
    this.baseColumns,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
    this.padding = const EdgeInsets.all(16.0),
  });
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints) {
        final columnCount = ResponsiveUtils.getResponsiveColumnCount(context, baseColumns: baseColumns);
        final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
        final responsiveSpacing = ResponsiveUtils.getResponsiveSpacing(context, spacing);
        final responsiveRunSpacing = ResponsiveUtils.getResponsiveSpacing(context, runSpacing);
        
        return Padding(
          padding: responsivePadding,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              crossAxisSpacing: responsiveSpacing,
              mainAxisSpacing: responsiveRunSpacing,
              childAspectRatio: _getChildAspectRatio(context),
            ),
            itemCount: children.length,
            itemBuilder: (context, index) => children[index],
          ),
        );
      },
    );
  }
  
  double _getChildAspectRatio(BuildContext context) {
    if (ResponsiveUtils.isSmallScreen(context)) {
      return 1.2; // Slightly taller for mobile
    } else if (ResponsiveUtils.isMediumScreen(context)) {
      return 1.0; // Square for tablets
    } else {
      return 0.9; // Slightly wider for large screens
    }
  }
}

/// Responsive wrap widget for flexible layouts
class ResponsiveWrap extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final EdgeInsets padding;
  
  const ResponsiveWrap({
    super.key,
    required this.children,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.padding = const EdgeInsets.all(8.0),
  });
  
  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final responsiveSpacing = ResponsiveUtils.getResponsiveSpacing(context, spacing);
    final responsiveRunSpacing = ResponsiveUtils.getResponsiveSpacing(context, runSpacing);
    
    return Padding(
      padding: responsivePadding,
      child: Wrap(
        spacing: responsiveSpacing,
        runSpacing: responsiveRunSpacing,
        children: children,
      ),
    );
  }
}
