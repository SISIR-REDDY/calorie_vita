import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Extension to get theme-aware colors based on brightness
extension ThemeAwareColors on BuildContext {
  /// Check if dark mode is active
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Get theme-aware background color
  Color get backgroundColor => isDarkMode ? kDarkAppBackground : kAppBackground;

  /// Get theme-aware surface color
  Color get surfaceColor => isDarkMode ? kDarkSurfaceLight : kSurfaceColor;

  /// Get theme-aware surface light color
  Color get surfaceLightColor => isDarkMode ? kDarkSurfaceLight : kSurfaceLight;

  /// Get theme-aware surface dark color
  Color get surfaceDarkColor => isDarkMode ? kDarkSurfaceDark : kSurfaceDark;

  /// Get theme-aware text primary color
  Color get textPrimary => isDarkMode ? kDarkTextPrimary : kTextPrimary;

  /// Get theme-aware text secondary color
  Color get textSecondary => isDarkMode ? kDarkTextSecondary : kTextSecondary;

  /// Get theme-aware text tertiary color
  Color get textTertiary => isDarkMode ? kDarkTextTertiary : kTextTertiary;

  /// Get theme-aware text dark color
  Color get textDark => isDarkMode ? kDarkTextDark : kTextDark;

  /// Get theme-aware text grey color
  Color get textGrey => isDarkMode ? kDarkTextGrey : kTextGrey;

  /// Get theme-aware border color
  Color get borderColor => isDarkMode ? kDarkBorderColor : kBorderColor;

  /// Get theme-aware divider color
  Color get dividerColor => isDarkMode ? kDarkDividerColor : kDividerColor;

  /// Get theme-aware soft white color
  Color get softWhite => isDarkMode ? kDarkSoftWhite : kSoftWhite;

  /// Get theme-aware soft gray color
  Color get softGray => isDarkMode ? kDarkSoftGray : kSoftGray;

  /// Get theme-aware card decoration
  BoxDecoration get cardDecoration => isDarkMode ? kDarkCardDecoration : kCardDecoration;

  /// Get theme-aware elevated card decoration
  BoxDecoration get elevatedCardDecoration => isDarkMode ? kDarkElevatedCardDecoration : kElevatedCardDecoration;

  /// Get theme-aware card shadow
  List<BoxShadow> get cardShadow => isDarkMode ? kDarkCardShadow : kCardShadow;

  /// Get theme-aware elevated shadow
  List<BoxShadow> get elevatedShadow => isDarkMode ? kDarkElevatedShadow : kElevatedShadow;
}

