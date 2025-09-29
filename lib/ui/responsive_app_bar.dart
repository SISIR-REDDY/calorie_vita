import 'package:flutter/material.dart';
import 'responsive_utils.dart';
import 'responsive_widgets.dart';
import 'app_colors.dart';

/// Responsive AppBar widget that adapts to different screen sizes
class ResponsiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool automaticallyImplyLeading;
  
  const ResponsiveAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.automaticallyImplyLeading = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsiveHeight = ResponsiveUtils.getResponsiveAppBarHeight(context);
    final responsiveFontSize = ResponsiveUtils.getResponsiveFontSize(context, 20.0);
    final responsiveElevation = ResponsiveUtils.getResponsiveElevation(context, elevation ?? 1.0);
    
    return AppBar(
      title: ResponsiveText(
        title,
        fontSize: responsiveFontSize,
        fontWeight: FontWeight.bold,
        color: foregroundColor ?? kTextDark,
      ),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? kAppBackground,
      foregroundColor: foregroundColor ?? kTextDark,
      elevation: responsiveElevation,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: responsiveHeight,
      titleSpacing: ResponsiveUtils.getResponsiveSpacing(context, 16.0),
    );
  }
  
  @override
  Size get preferredSize {
    // This will be overridden by the actual responsive height in build
    return const Size.fromHeight(kToolbarHeight);
  }
}

/// Responsive Bottom Navigation Bar
class ResponsiveBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final List<BottomNavigationBarItem> items;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  
  const ResponsiveBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsiveHeight = ResponsiveUtils.getResponsiveTabBarHeight(context) + 20;
    final responsiveFontSize = ResponsiveUtils.getResponsiveFontSize(context, 12.0);
    
    return Container(
      height: responsiveHeight,
      decoration: BoxDecoration(
        color: backgroundColor ?? kAppBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: ResponsiveUtils.getResponsiveElevation(context, 8.0),
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        items: items,
        backgroundColor: backgroundColor ?? kAppBackground,
        selectedItemColor: selectedItemColor ?? kPrimaryColor,
        unselectedItemColor: unselectedItemColor ?? kTextSecondary,
        selectedFontSize: responsiveFontSize,
        unselectedFontSize: responsiveFontSize,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}

/// Responsive Floating Action Button
class ResponsiveFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final IconData? icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  
  const ResponsiveFAB({
    super.key,
    this.onPressed,
    this.child,
    this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsiveSize = ResponsiveUtils.getResponsiveIconSize(context, 56.0);
    final responsiveElevation = ResponsiveUtils.getResponsiveElevation(context, 6.0);
    
    return FloatingActionButton(
      onPressed: onPressed,
      child: child ?? ResponsiveIcon(
        icon ?? Icons.add,
        size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
        color: foregroundColor ?? Colors.white,
      ),
      tooltip: tooltip,
      backgroundColor: backgroundColor ?? kPrimaryColor,
      foregroundColor: foregroundColor ?? Colors.white,
      elevation: responsiveElevation,
      mini: responsiveSize < 48,
    );
  }
}

/// Responsive Scaffold with adaptive layout
class ResponsiveScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final Widget? endDrawer;
  final int? bottomNavBarIndex;
  final ValueChanged<int>? onBottomNavTap;
  final List<BottomNavigationBarItem>? bottomNavItems;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  
  const ResponsiveScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.drawer,
    this.endDrawer,
    this.bottomNavBarIndex,
    this.onBottomNavTap,
    this.bottomNavItems,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveUtils.getSafeAreaPadding(context);
    
    return Scaffold(
      backgroundColor: backgroundColor ?? kAppBackground,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: title != null ? ResponsiveAppBar(
        title: title!,
        actions: actions,
      ) : null,
      drawer: drawer,
      endDrawer: endDrawer,
      body: Padding(
        padding: EdgeInsets.only(
          top: extendBodyBehindAppBar ? responsivePadding.top : 0,
        ),
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavItems != null && bottomNavBarIndex != null
          ? ResponsiveBottomNavBar(
              currentIndex: bottomNavBarIndex!,
              items: bottomNavItems!,
              onTap: onBottomNavTap,
            )
          : null,
    );
  }
}

/// Responsive Drawer
class ResponsiveDrawer extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? header;
  final List<Widget>? items;
  
  const ResponsiveDrawer({
    super.key,
    required this.child,
    this.title,
    this.header,
    this.items,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
    final responsiveFontSize = ResponsiveUtils.getResponsiveFontSize(context, 24.0);
    final responsiveHeight = ResponsiveUtils.getResponsiveAppBarHeight(context);
    
    return Drawer(
      child: Column(
        children: [
          if (header != null)
            header!
          else if (title != null)
            Container(
              height: responsiveHeight + responsivePadding.top,
              padding: EdgeInsets.only(
                top: responsivePadding.top,
                left: responsivePadding.left,
                right: responsivePadding.right,
                bottom: responsivePadding.bottom,
              ),
              decoration: BoxDecoration(
                color: kPrimaryColor,
                gradient: LinearGradient(
                  colors: [kPrimaryColor, kPrimaryColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: ResponsiveText(
                  title!,
                  fontSize: responsiveFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}
