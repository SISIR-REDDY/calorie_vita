# Calorie Vita - UI Design Guide

## Overview
Calorie Vita has been redesigned with a clean, modern UI that focuses on usability, visual hierarchy, and a delightful user experience.

## Design Principles
- **Clean & Minimal**: Uncluttered interfaces with plenty of white space
- **Modern**: Contemporary design patterns and visual elements
- **Accessible**: High contrast and readable typography
- **Consistent**: Unified design language across all screens

## Color Palette

### Primary Colors
- **Primary**: `#6366F1` (Indigo) - Main brand color, buttons, links
- **Primary Light**: `#818CF8` (Lighter indigo) - Hover states, accents
- **Primary Dark**: `#4F46E5` (Darker indigo) - Active states

### Secondary Colors
- **Secondary**: `#10B981` (Emerald) - Success actions, positive elements
- **Secondary Light**: `#34D399` (Lighter emerald) - Hover states

### Accent Colors
- **Accent**: `#F59E0B` (Amber) - Warnings, highlights
- **Accent Light**: `#FBBF24` (Lighter amber) - Subtle accents

### Surface Colors
- **Surface**: `#FFFFFF` (Pure white) - Cards, modals
- **Surface Light**: `#F8FAFC` (Very light gray) - Background
- **Surface Dark**: `#F1F5F9` (Light gray) - Secondary backgrounds

### Text Colors
- **Text Primary**: `#1E293B` (Dark slate) - Main text
- **Text Secondary**: `#64748B` (Medium slate) - Secondary text
- **Text Tertiary**: `#94A3B8` (Light slate) - Captions, hints

### Semantic Colors
- **Success**: `#10B981` (Green) - Success messages, confirmations
- **Warning**: `#F59E0B` (Amber) - Warnings, alerts
- **Error**: `#EF4444` (Red) - Error messages, destructive actions
- **Info**: `#3B82F6` (Blue) - Information, tips

## Typography

### Font Family
- **Primary**: Inter (Google Fonts)
- **Fallback**: System default sans-serif

### Font Weights
- **Light**: 300
- **Regular**: 400
- **Medium**: 500
- **Semi-bold**: 600
- **Bold**: 700
- **Extra-bold**: 800

### Font Sizes
- **Display Large**: 32px (Hero titles)
- **Display Medium**: 28px (Page titles)
- **Display Small**: 24px (Section titles)
- **Headline Large**: 22px (Card titles)
- **Headline Medium**: 20px (Subsection titles)
- **Headline Small**: 18px (Component titles)
- **Title Large**: 16px (Button text, labels)
- **Title Medium**: 14px (Secondary labels)
- **Title Small**: 12px (Small labels)
- **Body Large**: 16px (Main content)
- **Body Medium**: 14px (Secondary content)
- **Body Small**: 12px (Captions)

## Spacing System

### Base Unit: 4px
- **4px**: Extra small spacing
- **8px**: Small spacing
- **12px**: Medium spacing
- **16px**: Standard spacing
- **20px**: Large spacing
- **24px**: Extra large spacing
- **32px**: Section spacing
- **48px**: Major section spacing

## Border Radius

### Standard Radii
- **4px**: Small elements (progress bars)
- **8px**: Medium elements (buttons)
- **12px**: Standard elements (inputs, small cards)
- **16px**: Cards, containers
- **20px**: Large cards, modals
- **24px**: Extra large elements
- **32px**: Hero elements

## Shadows

### Card Shadow
```dart
BoxShadow(
  color: Color(0x0A000000), // 4% black
  blurRadius: 10,
  offset: Offset(0, 2),
)
```

### Elevated Shadow
```dart
BoxShadow(
  color: Color(0x1A000000), // 10% black
  blurRadius: 20,
  offset: Offset(0, 4),
)
```

## Components

### Buttons

#### Primary Button
- Background: Primary color
- Text: White
- Border radius: 12px
- Padding: 16px vertical, 24px horizontal
- Elevation: 0 (flat design)

#### Secondary Button
- Background: Transparent
- Border: Primary color, 1.5px
- Text: Primary color
- Border radius: 12px
- Padding: 16px vertical, 24px horizontal

#### Text Button
- Background: Transparent
- Text: Primary color
- Border radius: 8px
- Padding: 12px vertical, 16px horizontal

### Cards
- Background: Surface color
- Border radius: 16px (standard) or 20px (elevated)
- Shadow: Card shadow or elevated shadow
- Padding: 20px (standard) or 24px (elevated)

### Input Fields
- Background: Surface light color
- Border: Border color, 1px
- Focus border: Primary color, 2px
- Border radius: 12px
- Padding: 16px

### Navigation
- Background: Surface color
- Active color: Primary color
- Inactive color: Text tertiary
- Shadow: Subtle top shadow

## Layout Guidelines

### Grid System
- Use consistent 24px margins on all sides
- Maintain 16px spacing between related elements
- Use 32px spacing between major sections

### Content Width
- Maximum content width: 400px for mobile
- Center content with equal margins
- Use full width for cards and containers

### Visual Hierarchy
1. **Primary**: Main content, calls-to-action
2. **Secondary**: Supporting information
3. **Tertiary**: Metadata, timestamps, hints

## Responsive Design

### Breakpoints
- **Mobile**: < 600px (default)
- **Tablet**: 600px - 1024px
- **Desktop**: > 1024px

### Adaptations
- Scale font sizes proportionally
- Adjust spacing for larger screens
- Use grid layouts for tablet/desktop

## Accessibility

### Contrast Ratios
- **Normal text**: Minimum 4.5:1
- **Large text**: Minimum 3:1
- **UI elements**: Minimum 3:1

### Touch Targets
- Minimum size: 44x44 points
- Adequate spacing between interactive elements

### Screen Reader Support
- Semantic labels for all interactive elements
- Descriptive alt text for images
- Logical tab order

## Animation Guidelines

### Duration
- **Fast**: 150ms (micro-interactions)
- **Normal**: 300ms (standard transitions)
- **Slow**: 500ms (page transitions)

### Easing
- **Standard**: `Curves.easeInOut`
- **Enter**: `Curves.easeOut`
- **Exit**: `Curves.easeIn`

## Implementation Notes

### Flutter Theme
The design system is implemented through Flutter's theme system in `lib/ui/app_theme.dart`

### Color Constants
All colors are defined in `lib/ui/app_colors.dart`

### Component Library
Reusable components are in `lib/widgets/`

### Usage Example
```dart
import 'package:calorie_vita/ui/app_colors.dart';

Container(
  decoration: const BoxDecoration(
    color: kSurfaceColor,
    borderRadius: BorderRadius.all(Radius.circular(16)),
    boxShadow: kCardShadow,
  ),
  child: // Your content
)
```

## Future Enhancements
- Dark mode support
- Custom illustration library
- Advanced animation system
- Accessibility improvements
- Internationalization support 