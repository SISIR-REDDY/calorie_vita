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

// Gradients
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

// Shadows
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

// Decorations
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
