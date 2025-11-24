# Dark Mode Implementation Guide

## Overview
This document describes the dark mode implementation in the CalorieVita app.

## What Was Implemented

### 1. Theme Service (`lib/services/theme_service.dart`)
- **Purpose**: Manages app theme state (light/dark mode)
- **Features**:
  - Persists user's theme preference using `SharedPreferences`
  - Provides methods to toggle and set theme mode
  - Uses ChangeNotifier for reactive updates
  - Singleton pattern for global access

### 2. Dark Theme Configuration (`lib/ui/app_theme.dart`)
- **Added**: Complete dark theme with all necessary styles
- **Includes**:
  - Dark color scheme for all UI elements
  - Dark text themes for all text styles
  - Dark card themes
  - Dark button themes
  - Dark input decoration themes
  - Dark app bar and navigation bar themes

### 3. Theme-Aware Colors Utility (`lib/ui/theme_aware_colors.dart`)
- **Purpose**: Extension methods for easy access to theme-aware colors
- **Usage**:
  ```dart
  // In any widget:
  final bgColor = context.backgroundColor;
  final textColor = context.textPrimary;
  final isDark = context.isDarkMode;
  ```

### 4. Main App Integration (`lib/main_app.dart`)
- **Changes**:
  - Integrated ThemeService
  - Added theme listener for reactive updates
  - Configured MaterialApp to support both light and dark themes
  - Added status bar color updates based on theme
  - Made loading screen theme-aware

### 5. Settings Screen Update (`lib/screens/settings_screen.dart`)
- **Changes**:
  - Added dark mode toggle below Google Fit section
  - Made all UI cards theme-aware
  - Updated colors dynamically based on theme
  - Professional toggle design with icons and descriptions

### 6. Color Definitions (`lib/ui/app_colors.dart`)
- **Status**: Already had dark theme colors defined (no changes needed)
- **Available Colors**:
  - Dark backgrounds, surfaces, texts, borders, etc.
  - All colors follow Material Design dark theme guidelines

## How Dark Mode Works

### User Experience
1. User opens Settings screen
2. Finds "Dark Mode" toggle below "Google Fit" section
3. Toggles switch to enable/disable dark mode
4. App immediately switches theme across all screens
5. Preference is saved and persists across app restarts
6. Status bar colors automatically adjust

### Technical Flow
```
User toggles switch
    ↓
ThemeService.setDarkMode() called
    ↓
Preference saved to SharedPreferences
    ↓
ThemeService notifies listeners
    ↓
MaterialApp rebuilds with new theme
    ↓
All screens automatically update colors
```

## Using Dark Mode in Your Code

### Method 1: Using Theme.of(context)
```dart
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  return Container(
    color: isDark ? kDarkSurfaceLight : kSurfaceColor,
    child: Text(
      'Hello',
      style: TextStyle(
        color: isDark ? kDarkTextPrimary : kTextPrimary,
      ),
    ),
  );
}
```

### Method 2: Using Extension (Recommended)
```dart
import '../ui/theme_aware_colors.dart';

@override
Widget build(BuildContext context) {
  return Container(
    color: context.surfaceColor,
    child: Text(
      'Hello',
      style: TextStyle(color: context.textPrimary),
    ),
  );
}
```

### Method 3: Using ThemeService Directly
```dart
final themeService = ThemeService();

// Check if dark mode is enabled
if (themeService.isDarkMode) {
  // Do something for dark mode
}

// Toggle theme
await themeService.toggleTheme();

// Set specific theme
await themeService.setDarkMode(true);
```

## Available Dark Colors

### Surfaces
- `kDarkAppBackground` - Main app background (very dark)
- `kDarkSurfaceLight` - Cards and elevated surfaces
- `kDarkSurfaceDark` - Slightly darker surfaces

### Text
- `kDarkTextPrimary` - Main text color (very light)
- `kDarkTextSecondary` - Secondary text (medium light)
- `kDarkTextTertiary` - Tertiary text (dimmer)
- `kDarkTextDark` - Brightest text variant

### Borders & Dividers
- `kDarkBorderColor` - Border color for dark theme
- `kDarkDividerColor` - Divider lines color

### Status Colors (Same as light mode)
- `kDarkSuccessColor` - Green for success
- `kDarkWarningColor` - Amber for warnings
- `kDarkErrorColor` - Red for errors
- `kDarkInfoColor` - Blue for info

## Best Practices

### 1. Always Use Theme-Aware Colors
❌ **Bad:**
```dart
Text('Hello', style: TextStyle(color: kTextDark))
```

✅ **Good:**
```dart
Text('Hello', style: TextStyle(color: context.textPrimary))
```

### 2. Check Theme Before Using Fixed Colors
❌ **Bad:**
```dart
Container(
  color: Colors.white,
  child: Text('Hello', style: TextStyle(color: Colors.black)),
)
```

✅ **Good:**
```dart
Container(
  color: context.surfaceColor,
  child: Text('Hello', style: TextStyle(color: context.textPrimary)),
)
```

### 3. Test Both Themes
Always test your UI changes in both light and dark mode to ensure:
- Text is readable
- Colors don't merge or clash
- Icons are visible
- Shadows are appropriate

### 4. Use Material Theme Properties
Flutter's Material widgets automatically adapt to theme:
```dart
// These automatically use theme colors
Card()
ElevatedButton()
TextField()
AppBar()
```

## Updating Existing Screens

To make an existing screen support dark mode:

1. **Check if it uses hardcoded colors**
   - Search for `kTextDark`, `kSurfaceColor`, etc.
   - Replace with theme-aware equivalents

2. **Add theme check at top of build method**
   ```dart
   @override
   Widget build(BuildContext context) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     // ... rest of code
   }
   ```

3. **Update color usages**
   ```dart
   // Before
   backgroundColor: kAppBackground,
   
   // After
   backgroundColor: isDark ? kDarkAppBackground : kAppBackground,
   
   // Or better (using extension)
   backgroundColor: context.backgroundColor,
   ```

4. **Test the screen**
   - Toggle dark mode
   - Check all UI elements
   - Verify text visibility
   - Check cards, buttons, inputs

## Files Modified

### Core Files
- `lib/services/theme_service.dart` (NEW)
- `lib/ui/theme_aware_colors.dart` (NEW)
- `lib/ui/app_theme.dart` (UPDATED)
- `lib/main_app.dart` (UPDATED)
- `lib/screens/settings_screen.dart` (UPDATED)

### Existing Files (No changes needed)
- `lib/ui/app_colors.dart` (Already had dark colors)

## Dependencies
- `shared_preferences: ^2.5.3` (Already included)

## Future Enhancements

1. **Automatic Theme Switching**
   - Add system theme detection
   - Switch based on time of day
   - Follow device settings

2. **Theme Customization**
   - Allow users to choose accent colors
   - Multiple dark theme variants (AMOLED black, etc.)
   - Custom color schemes

3. **Smooth Transitions**
   - Add animated theme switching
   - Fade between light and dark
   - Ripple effect from toggle

## Troubleshooting

### Issue: Colors not updating after toggle
**Solution**: Ensure you're using `Theme.of(context)` or the extension, not direct color constants

### Issue: Some widgets still show light colors in dark mode
**Solution**: Check if the widget is using hardcoded colors. Update to use theme-aware colors

### Issue: Text not visible in dark mode
**Solution**: Use `context.textPrimary` or similar instead of fixed text colors

### Issue: Theme not persisting after app restart
**Solution**: Ensure ThemeService.initialize() is called in main_app.dart

## Testing Checklist

✅ Dark mode toggle visible in settings
✅ Toggle switches theme immediately
✅ Theme persists after app restart
✅ Status bar colors update with theme
✅ All screens support dark mode
✅ Text is readable in both themes
✅ Cards and surfaces are visible
✅ Icons are visible
✅ Buttons work in both themes
✅ Input fields are usable
✅ Dialogs support dark mode
✅ Navigation bars support dark mode

## Contact

For questions or issues with dark mode implementation, contact the development team.

---
**Last Updated**: November 23, 2025
**Version**: 1.0.0

