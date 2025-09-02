# Trainer Sisir Setup Guide

## Overview
The Trainer Sisir screen is now ready! This AI-powered fitness coach provides personalized advice based on user profile data and maintains conversation history.

## Files Created/Modified

### New Files:
- `lib/services/gemini_service.dart` - Google Gemini AI integration
- `lib/screens/trainer_sisir_screen.dart` - Main trainer screen with chat UI

### Modified Files:
- `lib/services/firebase_service.dart` - Added profile and chat management methods

## Setup Instructions

### 1. Google Gemini API Setup
1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key for Gemini
3. Replace `YOUR_GEMINI_API_KEY_HERE` in `lib/services/gemini_service.dart` with your actual API key

### 2. Firebase Configuration
The app expects user profile data in this structure:
```json
{
  "name": "John Doe",
  "age": 25,
  "height": 175,
  "weight": 70,
  "gender": "male",
  "fitnessGoals": "weight loss",
  "hobbies": "running, swimming",
  "activityLevel": "moderate"
}
```

### 3. Navigation Integration
To use the TrainerSisirScreen in your app, add it to your navigation:

```dart
// Example navigation
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const TrainerSisirScreen(),
  ),
);
```

## Features

### ✅ Implemented Features:
- **Personalized AI Responses**: Uses Google Gemini with user profile context
- **Chat UI**: Modern chat interface with user/Sisir message bubbles
- **Firebase Integration**: Stores chat history and user profiles
- **Profile Context**: AI considers age, weight, height, fitness goals, hobbies
- **Smart Suggestions**: BMI-based recommendations, hobby-specific advice
- **Dark/Light Mode**: Toggle between themes
- **Typing Indicator**: Shows when Sisir is "thinking"
- **Chat History**: Persistent conversation storage
- **Error Handling**: Graceful fallbacks when API fails

### 🎯 AI Behavior Examples:
- **High BMI**: Suggests weight loss plans and cardio exercises
- **Running Hobby**: Recommends HIIT runs and related exercises
- **Muscle Gain Goal**: Suggests strength training and protein advice
- **Motivational**: Always includes encouraging messages and emojis

## Usage Example

```dart
// The screen automatically:
// 1. Loads user profile from Firebase
// 2. Displays personalized welcome message
// 3. Maintains conversation context
// 4. Saves all messages to Firebase

// User types: "How can I lose weight?"
// Sisir responds with personalized advice based on:
// - User's current weight/height (BMI calculation)
// - Fitness goals
// - Activity level
// - Previous conversation context
```

## Firebase Collections Structure

```
users/{userId}/
├── profile/
│   └── userData/ (user profile information)
└── trainerChats/ (chat message history)
    ├── {messageId1}
    ├── {messageId2}
    └── ...
```

## Error Handling
- API failures show fallback responses
- Network issues are handled gracefully
- Firebase errors are logged and don't crash the app
- User gets feedback for all operations

## Customization
- Modify `GeminiService` to change AI personality
- Update prompt templates for different response styles
- Customize UI colors in `app_colors.dart`
- Add more profile fields as needed

## Next Steps
1. Add your Gemini API key
2. Ensure user profiles are properly set up in Firebase
3. Test the chat functionality
4. Customize the AI responses as needed

The Trainer Sisir is ready to provide personalized fitness coaching! 💪
