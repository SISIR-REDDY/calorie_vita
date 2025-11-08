# CalorieVita App Structure

## 📁 Project Overview
Flutter-based calorie tracking application with Firebase backend, Health Connect integration, and AI-powered food recognition.

---

## 🗂️ Directory Structure

### Root Level
```
calorie/
├── android/                    # Android platform-specific code
├── assets/                     # Static assets and data files
├── build/                      # Build output (generated)
├── lib/                        # Main application code
├── test/                       # Test files
├── web/                        # Web platform files
├── windows/                    # Windows platform files
└── [Documentation files]       # Various .md documentation files
```

---

## 📱 lib/ - Main Application Code

### Core Files
```
lib/
├── main.dart                   # App entry point
├── main_app.dart              # Main app widget
├── firebase_options.dart      # Firebase configuration
```

### 📂 config/ - Configuration
```
lib/config/
├── ai_config.dart             # AI service configuration
└── production_config.dart     # Production settings
```

### 📂 models/ - Data Models
```
lib/models/
├── daily_summary.dart         # Daily nutrition summary
├── food_entry.dart            # Food entry data model
├── food_history_entry.dart    # Food history tracking
├── food_recognition_result.dart # AI recognition results
├── health_connect_data.dart   # Health Connect integration data
├── macro_breakdown.dart       # Macronutrient breakdown
├── nutrition_info.dart        # Nutrition information
├── portion_estimation_result.dart # Portion size estimation
├── reward_system.dart         # Reward system model
├── simple_streak_system.dart  # Streak tracking
├── task.dart                  # Task model
├── user_achievement.dart      # User achievements
├── user_goals.dart            # User goals
├── user_preferences.dart      # User preferences
└── weight_log.dart            # Weight tracking
```

### 📂 screens/ - UI Screens
```
lib/screens/
├── admin_notification_screen.dart  # Admin notifications
├── analytics_screen.dart           # Analytics dashboard
├── camera_screen.dart              # Camera for food capture
├── food_history_detail_screen.dart # Food history details
├── goals_screen.dart               # Goals management
├── home_screen.dart                # Main home screen
├── onboarding_screen.dart          # User onboarding
├── privacy_policy_screen.dart      # Privacy policy
├── profile_edit_screen.dart        # Profile editing
├── settings_screen.dart            # App settings
├── terms_conditions_screen.dart    # Terms and conditions
├── todays_food_screen.dart         # Today's food entries
├── trainer_screen.dart             # AI trainer/chat
├── weight_log_screen.dart          # Weight logging
└── welcome_screen.dart             # Welcome screen
```

### 📂 services/ - Business Logic & Services
```
lib/services/
├── ai_service.dart                        # AI/ML integration (OpenRouter)
├── analytics_service.dart                 # Analytics tracking
├── app_state_manager.dart                 # App state management
├── app_state_service.dart                 # State service
├── auth_service.dart                      # Authentication
├── barcode_scanning_service.dart          # Barcode scanning
├── calorie_units_service.dart             # Calorie unit conversions
├── chat_history_manager.dart              # Chat history management
├── daily_reset_service.dart               # Daily data reset
├── daily_summary_service.dart             # Daily summaries
├── dynamic_icon_service.dart              # Dynamic app icon
├── enhanced_streak_service.dart           # Enhanced streak tracking
├── error_handler.dart                     # Error handling
├── fast_data_refresh_service.dart         # Fast data refresh
├── firebase_service.dart                  # Firebase operations
├── firestore_config_service.dart          # Firestore configuration
├── fitness_goal_calculator.dart           # Fitness goal calculations
├── food_history_service.dart              # Food history management
├── global_goals_manager.dart              # Global goals management
├── goals_event_bus.dart                   # Goals event bus
├── health_connect_manager.dart            # Health Connect integration
├── image_processing_service.dart          # Image processing
├── input_validation_service.dart          # Input validation
├── logger_service.dart                    # Logging service
├── manual_food_entry_service.dart         # Manual food entry
├── network_service.dart                   # Network operations
├── optimized_food_scanner_pipeline.dart   # Food scanning pipeline
├── performance_monitor.dart               # Performance monitoring
├── push_notification_service.dart         # Push notifications
├── real_time_input_service.dart           # Real-time input handling
├── reward_notification_service.dart       # Reward notifications
├── rewards_service.dart                   # Rewards system
├── setup_check_service.dart               # Setup verification
├── simple_goals_notifier.dart             # Goals notifications
├── simple_streak_service.dart             # Simple streak service
├── task_service.dart                      # Task management
├── todays_food_data_service.dart          # Today's food data
└── weight_log_service.dart                # Weight logging service
```

### 📂 widgets/ - Reusable Widgets
```
lib/widgets/
├── enhanced_loading_widgets.dart    # Loading indicators
├── food_result_card.dart            # Food result display card
├── manual_food_entry_dialog.dart    # Manual entry dialog
├── profile_widgets.dart             # Profile-related widgets
├── reward_notification_widget.dart  # Reward notifications
├── setup_warning_popup.dart         # Setup warnings
├── task_card.dart                   # Task display card
└── task_popup.dart                  # Task popup dialog
```

### 📂 ui/ - UI Theme & Utilities
```
lib/ui/
├── app_colors.dart              # App color scheme
├── app_theme.dart               # App theme configuration
├── dynamic_columns.dart         # Responsive column layouts
├── responsive_utils.dart        # Responsive utilities
└── responsive_widgets.dart      # Responsive widgets
```

### 📂 utils/ - Utility Functions
```
lib/utils/
└── feature_status_checker.dart  # Feature status checking
```

### 📂 mixins/ - Mixins
```
lib/mixins/
(Currently empty)
```

---

## 🤖 android/ - Android Platform

### Key Files
```
android/
├── app/
│   ├── build.gradle.kts                    # App build configuration
│   ├── google-services.json                # Firebase configuration
│   ├── proguard-rules.pro                  # ProGuard rules
│   └── src/
│       └── main/
│           ├── AndroidManifest.xml         # Android manifest
│           ├── kotlin/
│           │   └── com/sisirlabs/calorievita/
│           │       └── MainActivity.kt     # Main Android activity
│           └── res/                        # Android resources
│               ├── drawable/               # Drawable resources
│               ├── mipmap-*/               # App icons (various densities)
│               └── values/                 # Strings, colors, styles
├── build.gradle.kts                        # Project build config
├── gradle.properties                       # Gradle properties
└── key.properties                          # Signing keys
```

---

## 📦 assets/ - Static Assets

```
assets/
├── calorie_data.json                # Calorie database
├── comprehensive_indian_foods.json  # Comprehensive Indian foods
├── indian_foods.json                # Indian foods database
└── indian_packaged.json             # Packaged Indian foods
```

---

## 🌐 web/ - Web Platform

```
web/
├── index.html                  # Web entry point
├── manifest.json               # Web app manifest
├── privacy-policy.html         # Privacy policy page
├── terms-of-service.html       # Terms of service page
└── icons/                      # Web app icons
```

---

## 🧪 test/ - Tests

```
test/
└── widget_test.dart            # Widget tests
```

---

## 📚 Documentation Files

### Architecture & Integration
- `HEALTHCONNECT_ARCHITECTURE.md` - Health Connect integration architecture
- `FIREBASE_STRUCTURE.md` - Firebase structure and setup
- `DATABASE_SCHEMA_DIAGRAM.md` - Database schema documentation

### Guides & Checklists
- `COMPLETE_PLAY_STORE_LAUNCH_GUIDE.md` - Play Store launch guide
- `PLAYSTORE_LAUNCH_PROCESS.md` - Play Store launch process
- `PLAY_STORE_CHECKLIST.md` - Play Store checklist
- `PRODUCTION_READINESS_CHECKLIST.md` - Production readiness
- `PRODUCTION_STATUS.md` - Current production status
- `GOOGLE_FIT_VERIFICATION_GUIDE.md` - Google Fit verification
- `GOOGLE_FIT_ALTERNATIVES.md` - Google Fit alternatives

### Troubleshooting
- `HEALTH_CONNECT_TROUBLESHOOTING.md` - Health Connect troubleshooting
- `VERIFICATION_VS_PLAYSTORE.md` - Verification vs Play Store guide

### General
- `README.md` - Main README
- `PRODUCTION_README.md` - Production README
- `DOCUMENTATION_INDEX.md` - Documentation index
- `SIZE_OPTIMIZATION_CHANGES.md` - Size optimization notes
- `URLS_FOR_GOOGLE_CLOUD.md` - Google Cloud URLs

---

## 🔧 Key Dependencies

### Firebase
- `firebase_core` - Firebase core
- `firebase_auth` - Authentication
- `cloud_firestore` - Firestore database
- `firebase_storage` - Cloud storage
- `firebase_crashlytics` - Crash reporting
- `firebase_analytics` - Analytics
- `firebase_messaging` - Push notifications
- `firebase_remote_config` - Remote configuration

### Image & Camera
- `image_picker` - Image picking
- `mobile_scanner` - Barcode scanning
- `image` - Image processing

### UI & Utilities
- `google_fonts` - Google Fonts
- `provider` - State management
- `google_sign_in` - Google Sign-In
- `shared_preferences` - Local storage
- `url_launcher` - URL launching
- `flutter_local_notifications` - Local notifications

### Network & Connectivity
- `http` - HTTP requests
- `connectivity_plus` - Network connectivity

### Utilities
- `intl` - Internationalization
- `package_info_plus` - Package information
- `device_info_plus` - Device information
- `logger` - Logging

---

## 🏗️ Architecture Highlights

### State Management
- Uses `Provider` for state management
- Custom app state services (`app_state_manager.dart`, `app_state_service.dart`)

### Services Layer
- Comprehensive service layer for business logic
- Separation of concerns with dedicated services

### Firebase Integration
- Full Firebase suite integration
- Authentication, Firestore, Storage, Analytics, Messaging

### Health Connect Integration
- Native Android Health Connect integration
- Platform channel communication via `MainActivity.kt`

### AI Integration
- OpenRouter API integration for AI features
- Food recognition and portion estimation
- AI trainer/chat functionality

### Platform Support
- **Android** - Primary platform (fully implemented)
- **Web** - Web platform support
- **Windows** - Windows platform support

---

## 📊 App Features

### Core Features
- ✅ Food photo recognition
- ✅ Barcode scanning
- ✅ Manual food entry
- ✅ Calorie tracking
- ✅ Daily summaries
- ✅ Weight logging
- ✅ Goals management
- ✅ Streak tracking
- ✅ Rewards system
- ✅ Health Connect integration
- ✅ AI trainer/chat

### UI Features
- ✅ Responsive design
- ✅ Dynamic app icon
- ✅ Multiple themes
- ✅ Onboarding flow
- ✅ Analytics dashboard

---

*Last updated: Generated from current codebase structure*

