import 'package:flutter/material.dart';

// Modern, clean color palette
const Color kPrimaryColor = Color(0xFF6366F1); // Indigo primary
const Color kPrimaryLight = Color(0xFF818CF8); // Lighter indigo
const Color kPrimaryDark = Color(0xFF4F46E5); // Darker indigo

const Color kSecondaryColor = Color(0xFF10B981); // Emerald green
const Color kSecondaryLight = Color(0xFF34D399); // Lighter emerald

const Color kAccentColor = Color(0xFFF59E0B); // Amber accent
const Color kAccentLight = Color(0xFFFBBF24); // Lighter amber
const Color kAccentBlue = Color(0xFF3B82F6); // Blue accent
const Color kAccentGreen = Color(0xFF10B981); // Green accent
const Color kAccentGold = Color(0xFFF59E0B); // Gold accent
const Color kAccentPurple = Color(0xFF8B5CF6); // Purple accent

// Light Theme Colors
const Color kSurfaceColor = Color(0xFFFFFFFF); // Pure white surface
const Color kSurfaceLight = Color(0xFFF8FAFC); // Very light gray surface
const Color kSurfaceDark = Color(0xFFF1F5F9); // Light gray surface

const Color kTextPrimary = Color(0xFF1E293B); // Dark slate text
const Color kTextSecondary = Color(0xFF64748B); // Medium slate text
const Color kTextTertiary = Color(0xFF94A3B8); // Light slate text
const Color kTextDark = Color(0xFF0F172A); // Very dark text
const Color kTextGrey = Color(0xFF64748B); // Grey text

const Color kBorderColor = Color(0xFFE2E8F0); // Light gray border
const Color kDividerColor = Color(0xFFF1F5F9); // Very light gray divider

const Color kSuccessColor = Color(0xFF10B981); // Green success
const Color kWarningColor = Color(0xFFF59E0B); // Amber warning
const Color kErrorColor = Color(0xFFEF4444); // Red error
const Color kInfoColor = Color(0xFF3B82F6); // Blue info

// Additional colors
const Color kSoftWhite = Color(0xFFF8FAFC); // Soft white
const Color kSoftGray = Color(0xFFF1F5F9); // Soft gray

// Background colors
const Color kAppBackground = Color(0xFFF8FAFC); // App background

// Dark Theme Colors
const Color kDarkSurfaceColor = Color(0xFF0F172A); // Dark slate surface
const Color kDarkSurfaceLight = Color(0xFF1E293B); // Dark slate light
const Color kDarkSurfaceDark = Color(0xFF334155); // Dark slate dark

const Color kDarkTextPrimary = Color(0xFFF8FAFC); // Light text primary
const Color kDarkTextSecondary = Color(0xFFCBD5E1); // Light text secondary
const Color kDarkTextTertiary = Color(0xFF94A3B8); // Light text tertiary
const Color kDarkTextDark = Color(0xFFE2E8F0); // Light text dark
const Color kDarkTextGrey = Color(0xFF94A3B8); // Dark grey text

const Color kDarkBorderColor = Color(0xFF334155); // Dark border
const Color kDarkDividerColor = Color(0xFF475569); // Dark divider

const Color kDarkSuccessColor = Color(0xFF10B981); // Green success (same)
const Color kDarkWarningColor = Color(0xFFF59E0B); // Amber warning (same)
const Color kDarkErrorColor = Color(0xFFEF4444); // Red error (same)
const Color kDarkInfoColor = Color(0xFF3B82F6); // Blue info (same)

// Dark theme additional colors
const Color kDarkSoftWhite = Color(0xFF1E293B); // Dark soft white
const Color kDarkSoftGray = Color(0xFF334155); // Dark soft gray

// Dark background colors
const Color kDarkAppBackground = Color(0xFF0F172A); // Dark app background

/// App Colors class for easy access to color constants
class AppColors {
  // Primary colors
  static const Color primaryColor = kPrimaryColor;
  static const Color primaryLight = kPrimaryLight;
  static const Color primaryDark = kPrimaryDark;
  
  // Secondary colors
  static const Color secondaryColor = kSecondaryColor;
  static const Color secondaryLight = kSecondaryLight;
  
  // Accent colors
  static const Color accentColor = kAccentColor;
  static const Color accentLight = kAccentLight;
  static const Color accentBlue = kAccentBlue;
  static const Color accentGreen = kAccentGreen;
  static const Color accentGold = kAccentGold;
  static const Color accentPurple = kAccentPurple;
  
  // Surface colors
  static const Color surfaceColor = kSurfaceColor;
  static const Color surfaceLight = kSurfaceLight;
  static const Color surfaceDark = kSurfaceDark;
  
  // Text colors
  static const Color textPrimary = kTextPrimary;
  static const Color textSecondary = kTextSecondary;
  static const Color textTertiary = kTextTertiary;
  static const Color textDark = kTextDark;
  static const Color textGrey = kTextGrey;
  
  // Border and divider colors
  static const Color borderColor = kBorderColor;
  static const Color dividerColor = kDividerColor;
  
  // Status colors
  static const Color successColor = kSuccessColor;
  static const Color warningColor = kWarningColor;
  static const Color errorColor = kErrorColor;
  static const Color infoColor = kInfoColor;
  
  // Additional colors
  static const Color softWhite = kSoftWhite;
  static const Color softGray = kSoftGray;
  static const Color appBackground = kAppBackground;
  
  // Dark theme colors
  static const Color darkSurfaceColor = kDarkSurfaceColor;
  static const Color darkSurfaceLight = kDarkSurfaceLight;
  static const Color darkSurfaceDark = kDarkSurfaceDark;
  static const Color darkTextPrimary = kDarkTextPrimary;
  static const Color darkTextSecondary = kDarkTextSecondary;
  static const Color darkTextTertiary = kDarkTextTertiary;
  static const Color darkTextDark = kDarkTextDark;
  static const Color darkTextGrey = kDarkTextGrey;
  static const Color darkBorderColor = kDarkBorderColor;
  static const Color darkDividerColor = kDarkDividerColor;
  static const Color darkSuccessColor = kDarkSuccessColor;
  static const Color darkWarningColor = kDarkWarningColor;
  static const Color darkErrorColor = kDarkErrorColor;
  static const Color darkInfoColor = kDarkInfoColor;
  static const Color darkSoftWhite = kDarkSoftWhite;
  static const Color darkSoftGray = kDarkSoftGray;
  static const Color darkAppBackground = kDarkAppBackground;
}

// Light Theme Gradients
const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [kPrimaryColor, kPrimaryLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kSecondaryGradient = LinearGradient(
  colors: [kSecondaryColor, kSecondaryLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kAccentGradient = LinearGradient(
  colors: [kAccentColor, kAccentLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Dark Theme Gradients
const LinearGradient kDarkPrimaryGradient = LinearGradient(
  colors: [kPrimaryColor, kPrimaryLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kDarkSecondaryGradient = LinearGradient(
  colors: [kSecondaryColor, kSecondaryLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kDarkAccentGradient = LinearGradient(
  colors: [kAccentColor, kAccentLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Light Theme Shadows
const List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 10,
    offset: Offset(0, 2),
  ),
];

const List<BoxShadow> kElevatedShadow = [
  BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 20,
    offset: Offset(0, 4),
  ),
];

// Dark Theme Shadows
const List<BoxShadow> kDarkCardShadow = [
  BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 10,
    offset: Offset(0, 2),
  ),
];

const List<BoxShadow> kDarkElevatedShadow = [
  BoxShadow(
    color: Color(0x2A000000),
    blurRadius: 20,
    offset: Offset(0, 4),
  ),
];

// Light Theme Decorations
const BoxDecoration kCardDecoration = BoxDecoration(
  color: kSurfaceColor,
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: kCardShadow,
);

const BoxDecoration kElevatedCardDecoration = BoxDecoration(
  color: kSurfaceColor,
  borderRadius: BorderRadius.all(Radius.circular(20)),
  boxShadow: kElevatedShadow,
);

// Dark Theme Decorations
const BoxDecoration kDarkCardDecoration = BoxDecoration(
  color: kDarkSurfaceLight,
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: kDarkCardShadow,
);

const BoxDecoration kDarkElevatedCardDecoration = BoxDecoration(
  color: kDarkSurfaceLight,
  borderRadius: BorderRadius.all(Radius.circular(20)),
  boxShadow: kDarkElevatedShadow,
);
