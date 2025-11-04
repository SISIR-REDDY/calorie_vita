# Calorie Vita 🍎

> AI-powered calorie tracking application with intelligent food recognition

A modern Flutter application for tracking daily calories, macros, and nutrition goals with advanced AI-powered food recognition, real-time analytics, and personalized recommendations.

## 🌟 Features

- 📸 **AI Food Recognition** - Automatically identify food from photos
- 📊 **Real-time Analytics** - Track calories, macros, and daily progress
- 💬 **AI Nutrition Trainer** - Get personalized advice and recommendations
- 🎯 **Goal Tracking** - Set and achieve fitness and nutrition goals
- 🏆 **Achievement System** - Gamified progress tracking
- ⚖️ **Weight Management** - Track weight and BMI over time
- 💧 **Hydration Tracking** - Monitor water intake
- 🚶 **Activity Integration** - Google Fit integration
- 🌙 **Dark Mode** - Beautiful UI with dark mode support

## 📚 Documentation

### Firebase Backend
- **[FIREBASE_STRUCTURE.md](FIREBASE_STRUCTURE.md)** - Complete Firebase structure and configuration
- **[DATABASE_SCHEMA_DIAGRAM.md](DATABASE_SCHEMA_DIAGRAM.md)** - Visual database schema and query patterns
- **[FIREBASE_QUICK_REFERENCE.md](FIREBASE_QUICK_REFERENCE.md)** - Quick reference card for common operations
- **[FIREBASE_README.md](FIREBASE_README.md)** - Firebase documentation navigation guide

### Production & Deployment
- **[PRODUCTION_README.md](PRODUCTION_README.md)** - Production deployment guide
- **[PLAY_STORE_CHECKLIST.md](PLAY_STORE_CHECKLIST.md)** - Play Store publishing checklist

## 🚀 Tech Stack

- **Framework:** Flutter (Dart 3.0+)
- **Backend:** Firebase (Auth, Firestore, Storage)
- **AI:** OpenRouter (GPT-3.5, Gemini Pro)
- **State Management:** Provider
- **Local Storage:** Shared Preferences
- **Image Processing:** Image, Mobile Scanner
- **Analytics:** Firebase Analytics

## 📋 Prerequisites

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- Firebase project configured
- Google Cloud credentials

## 🛠️ Setup

### 1. Clone Repository
```bash
git clone https://github.com/sisirlabs/calorie-vita.git
cd calorie-vita
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Firebase Configuration
- Add `google-services.json` to `android/app/`
- Configure Firebase in project settings
- Set up security rules (see `firestore.rules`, `storage.rules`)

### 4. Run Application
```bash
flutter run
```

## 🏗️ Project Structure

```
lib/
├── config/                # Configuration files
│   ├── production_config.dart
│   └── ai_config.dart
├── models/               # Data models
│   ├── food_entry.dart
│   ├── daily_summary.dart
│   ├── user_goals.dart
│   └── ...
├── services/            # Business logic
│   ├── auth_service.dart
│   ├── firebase_service.dart
│   └── ...
├── screens/            # UI screens
│   ├── home_screen.dart
│   ├── camera_screen.dart
│   └── ...
└── main.dart          # Entry point
```

## 🔐 Firebase Collections

### Main Collections
- `users/{userId}/entries` - Food entries
- `users/{userId}/profile` - User profile data
- `users/{userId}/dailySummary` - Daily analytics
- `users/{userId}/trainerChats` - AI chat messages
- `app_config/ai_settings` - AI configuration

See [FIREBASE_STRUCTURE.md](FIREBASE_STRUCTURE.md) for complete details.

## 📊 Key Features Implementation

### AI Food Recognition
- Vision model: Google Gemini Pro 1.5 EXP
- Fallback: Google Gemini Pro 1.5
- Analysis: Nutrition breakdown, calories, macros

### Real-time Analytics
- Live data synchronization
- Daily summaries with trends
- Macro breakdown
- Personalized insights

### Achievement System
- Streak tracking
- Goal-based achievements
- Gamification elements
- Progress visualization

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📄 License

Copyright (c) 2024 SISIR Labs. All rights reserved.

## 🆘 Support

For issues, questions, or contributions:
- GitHub Issues: [Create an issue](https://github.com/sisirlabs/calorie-vita/issues)
- Email: support@calorievita.com
- Documentation: See [FIREBASE_README.md](FIREBASE_README.md)

## 🔗 Links

- Website: [calorievita.com](https://calorievita.com)
- Firebase Console: [console.firebase.google.com](https://console.firebase.google.com/project/calorie-vita)
- Play Store: [Coming Soon]

---

**Built with ❤️ by SISIR Labs**
