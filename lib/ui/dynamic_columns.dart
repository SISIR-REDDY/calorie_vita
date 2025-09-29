import 'package:flutter/material.dart';
import 'responsive_utils.dart';

/// Dynamic column system for adaptive layouts across different screen sizes
class DynamicColumns {
  
  /// Get optimal column count based on screen size and content type
  static int getOptimalColumnCount(BuildContext context, {
    required ContentType contentType,
    int? baseColumns,
    double? itemWidth,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final orientation = MediaQuery.of(context).orientation;
    
    // Base column calculation
    int columns = baseColumns ?? _getBaseColumnsForContentType(contentType);
    
    // Adjust based on screen size
    if (ResponsiveUtils.isSmallScreen(context)) {
      columns = _adjustForSmallScreen(columns, contentType, orientation);
    } else if (ResponsiveUtils.isMediumScreen(context)) {
      columns = _adjustForMediumScreen(columns, contentType, orientation);
    } else if (ResponsiveUtils.isLargeScreen(context)) {
      columns = _adjustForLargeScreen(columns, contentType, orientation);
    }
    
    // Adjust based on item width if provided
    if (itemWidth != null) {
      final availableWidth = screenWidth - (ResponsiveUtils.getResponsivePadding(context).horizontal * 2);
      final maxColumns = (availableWidth / itemWidth).floor();
      columns = columns.clamp(1, maxColumns);
    }
    
    return columns.clamp(1, 6); // Maximum 6 columns
  }
  
  /// Get base columns for different content types
  static int _getBaseColumnsForContentType(ContentType contentType) {
    switch (contentType) {
      case ContentType.featureCards:
        return 2;
      case ContentType.foodItems:
        return 1;
      case ContentType.analytics:
        return 1;
      case ContentType.goals:
        return 1;
      case ContentType.achievements:
        return 2;
      case ContentType.tasks:
        return 1;
      case ContentType.quickActions:
        return 4;
      case ContentType.stats:
        return 2;
      case ContentType.images:
        return 3;
      case ContentType.buttons:
        return 2;
    }
  }
  
  /// Adjust columns for small screens
  static int _adjustForSmallScreen(int baseColumns, ContentType contentType, Orientation orientation) {
    if (orientation == Orientation.portrait) {
      switch (contentType) {
        case ContentType.featureCards:
          return 2;
        case ContentType.quickActions:
          return 4;
        case ContentType.achievements:
          return 2;
        case ContentType.stats:
          return 2;
        case ContentType.images:
          return 2;
        default:
          return 1;
      }
    } else {
      // Landscape mode - can fit more columns
      return (baseColumns * 1.5).round();
    }
  }
  
  /// Adjust columns for medium screens
  static int _adjustForMediumScreen(int baseColumns, ContentType contentType, Orientation orientation) {
    if (orientation == Orientation.portrait) {
      return (baseColumns * 1.5).round();
    } else {
      return (baseColumns * 2).round();
    }
  }
  
  /// Adjust columns for large screens
  static int _adjustForLargeScreen(int baseColumns, ContentType contentType, Orientation orientation) {
    return (baseColumns * 2.5).round();
  }
  
  /// Get responsive grid delegate for different content types
  static SliverGridDelegate getResponsiveGridDelegate(
    BuildContext context, {
    required ContentType contentType,
    int? columns,
    double? spacing,
    double? runSpacing,
    double? childAspectRatio,
  }) {
    final columnCount = columns ?? getOptimalColumnCount(context, contentType: contentType);
    final responsiveSpacing = ResponsiveUtils.getResponsiveSpacing(context, spacing ?? 16.0);
    final responsiveRunSpacing = ResponsiveUtils.getResponsiveSpacing(context, runSpacing ?? 16.0);
    final aspectRatio = childAspectRatio ?? _getOptimalAspectRatio(context, contentType);
    
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columnCount,
      crossAxisSpacing: responsiveSpacing,
      mainAxisSpacing: responsiveRunSpacing,
      childAspectRatio: aspectRatio,
    );
  }
  
  /// Get optimal aspect ratio for different content types
  static double _getOptimalAspectRatio(BuildContext context, ContentType contentType) {
    switch (contentType) {
      case ContentType.featureCards:
        return ResponsiveUtils.isSmallScreen(context) ? 1.2 : 1.1;
      case ContentType.foodItems:
        return 2.5;
      case ContentType.analytics:
        return 1.8;
      case ContentType.goals:
        return 3.0;
      case ContentType.achievements:
        return 1.3;
      case ContentType.tasks:
        return 4.0;
      case ContentType.quickActions:
        return 1.0;
      case ContentType.stats:
        return 1.5;
      case ContentType.images:
        return 1.0;
      case ContentType.buttons:
        return 3.0;
    }
  }
}

/// Content type enum for dynamic column calculations
enum ContentType {
  featureCards,
  foodItems,
  analytics,
  goals,
  achievements,
  tasks,
  quickActions,
  stats,
  images,
  buttons,
}

/// Dynamic Grid View Widget with intelligent column adaptation
class DynamicGridView extends StatelessWidget {
  final List<Widget> children;
  final ContentType contentType;
  final int? columns;
  final double? spacing;
  final double? runSpacing;
  final double? childAspectRatio;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  
  const DynamicGridView({
    super.key,
    required this.children,
    required this.contentType,
    this.columns,
    this.spacing,
    this.runSpacing,
    this.childAspectRatio,
    this.padding,
    this.shrinkWrap = true,
    this.physics,
    this.scrollDirection = Axis.vertical,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final gridDelegate = DynamicColumns.getResponsiveGridDelegate(
      context,
      contentType: contentType,
      columns: columns,
      spacing: spacing,
      runSpacing: runSpacing,
      childAspectRatio: childAspectRatio,
    );
    
    return Padding(
      padding: padding ?? responsivePadding,
      child: GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics ?? (shrinkWrap ? const NeverScrollableScrollPhysics() : null),
        scrollDirection: scrollDirection,
        gridDelegate: gridDelegate,
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

/// Adaptive Column Layout Widget
class AdaptiveColumnLayout extends StatelessWidget {
  final List<Widget> children;
  final ContentType contentType;
  final int? maxColumns;
  final double? spacing;
  final EdgeInsets? padding;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  
  const AdaptiveColumnLayout({
    super.key,
    required this.children,
    required this.contentType,
    this.maxColumns,
    this.spacing,
    this.padding,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final responsiveSpacing = ResponsiveUtils.getResponsiveSpacing(context, spacing ?? 16.0);
    final columnCount = DynamicColumns.getOptimalColumnCount(
      context,
      contentType: contentType,
    ).clamp(1, maxColumns ?? 6);
    
    // Calculate items per column
    final itemsPerColumn = (children.length / columnCount).ceil();
    final columns = <Widget>[];
    
    for (int i = 0; i < columnCount; i++) {
      final startIndex = i * itemsPerColumn;
      final endIndex = (startIndex + itemsPerColumn).clamp(0, children.length);
      
      if (startIndex < children.length) {
        columns.add(
          Expanded(
            child: Column(
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
              children: children.sublist(startIndex, endIndex),
            ),
          ),
        );
      }
    }
    
    return Padding(
      padding: padding ?? responsivePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns.map((column) => 
          Padding(
            padding: EdgeInsets.only(
              right: columns.indexOf(column) < columns.length - 1 ? responsiveSpacing : 0,
            ),
            child: column,
          ),
        ).toList(),
      ),
    );
  }
}

/// Responsive Staggered Grid Widget for complex layouts
class ResponsiveStaggeredGrid extends StatelessWidget {
  final List<Widget> children;
  final ContentType contentType;
  final double? spacing;
  final EdgeInsets? padding;
  
  const ResponsiveStaggeredGrid({
    super.key,
    required this.children,
    required this.contentType,
    this.spacing,
    this.padding,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final responsiveSpacing = ResponsiveUtils.getResponsiveSpacing(context, spacing ?? 16.0);
    
    return Padding(
      padding: padding ?? responsivePadding,
      child: ResponsiveLayoutBuilder(
        builder: (context, constraints) {
          if (ResponsiveUtils.isSmallScreen(context)) {
            return _buildSingleColumn(children, responsiveSpacing);
          } else if (ResponsiveUtils.isMediumScreen(context)) {
            return _buildTwoColumn(children, responsiveSpacing);
          } else {
            return _buildThreeColumn(children, responsiveSpacing);
          }
        },
      ),
    );
  }
  
  Widget _buildSingleColumn(List<Widget> items, double spacing) {
    return Column(
      children: items.asMap().entries.map((entry) => 
        Padding(
          padding: EdgeInsets.only(bottom: entry.key < items.length - 1 ? spacing : 0),
          child: entry.value,
        ),
      ).toList(),
    );
  }
  
  Widget _buildTwoColumn(List<Widget> items, double spacing) {
    final leftColumn = <Widget>[];
    final rightColumn = <Widget>[];
    
    for (int i = 0; i < items.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(items[i]);
      } else {
        rightColumn.add(items[i]);
      }
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: leftColumn.asMap().entries.map((entry) =>
              Padding(
                padding: EdgeInsets.only(bottom: entry.key < leftColumn.length - 1 ? spacing : 0),
                child: entry.value,
              ),
            ).toList(),
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: Column(
            children: rightColumn.asMap().entries.map((entry) =>
              Padding(
                padding: EdgeInsets.only(bottom: entry.key < rightColumn.length - 1 ? spacing : 0),
                child: entry.value,
              ),
            ).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildThreeColumn(List<Widget> items, double spacing) {
    final columns = [[], [], []];
    
    for (int i = 0; i < items.length; i++) {
      columns[i % 3].add(items[i]);
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columns.map((column) => 
        Expanded(
          child: Column(
            children: column.asMap().entries.map((entry) =>
              Padding(
                padding: EdgeInsets.only(bottom: entry.key < column.length - 1 ? spacing : 0),
                child: entry.value,
              ),
            ).toList(),
          ),
        ),
      ).toList(),
    );
  }
}

/// Dynamic Column Mixin for easy integration
mixin DynamicColumnMixin<T extends StatefulWidget> on State<T> {
  
  /// Get optimal column count for content type
  int getOptimalColumnCount(ContentType contentType, {int? baseColumns}) {
    return DynamicColumns.getOptimalColumnCount(
      context,
      contentType: contentType,
      baseColumns: baseColumns,
    );
  }
  
  /// Get responsive grid delegate
  SliverGridDelegate getResponsiveGridDelegate(
    ContentType contentType, {
    int? columns,
    double? spacing,
    double? runSpacing,
    double? childAspectRatio,
  }) {
    return DynamicColumns.getResponsiveGridDelegate(
      context,
      contentType: contentType,
      columns: columns,
      spacing: spacing,
      runSpacing: runSpacing,
      childAspectRatio: childAspectRatio,
    );
  }
}
