# Firestore Configuration Setup Guide

Since Remote Config is not available, we'll use Firestore to store your AI configuration.

## 🔧 **Step 1: Enable Firestore Database**

1. **Go to**: https://console.firebase.google.com/
2. **Select Project**: `calorie-vita`
3. **Navigate to**: Firestore Database
4. **Click**: "Create database"
5. **Choose**: "Start in production mode"
6. **Select Location**: us-central1 (or closest to your users)

## 🔧 **Step 2: Create Configuration Document**

1. **In Firestore Console**, click **"Start collection"**
2. **Collection ID**: `app_config`
3. **Document ID**: `ai_settings`
4. **Add these fields one by one**:

### **API Configuration**
```
Field: openrouter_api_key
Type: string
Value: sk-or-v1-your-actual-api-key-here

Field: openrouter_base_url
Type: string
Value: https://openrouter.ai/api/v1/chat/completions
```

### **AI Models**
```
Field: chat_model
Type: string
Value: openai/gpt-3.5-turbo

Field: vision_model
Type: string
Value: google/gemini-pro-1.5-exp

Field: backup_vision_model
Type: string
Value: google/gemini-pro-1.5
```

### **Token Limits**
```
Field: max_tokens
Type: number
Value: 100

Field: chat_max_tokens
Type: number
Value: 100

Field: analytics_max_tokens
Type: number
Value: 120

Field: vision_max_tokens
Type: number
Value: 300
```

### **Temperature Settings**
```
Field: temperature
Type: number
Value: 0.7

Field: vision_temperature
Type: number
Value: 0.1
```

### **App Information**
```
Field: app_name
Type: string
Value: Calorie Vita

Field: app_url
Type: string
Value: https://calorievita.com
```

### **Rate Limiting**
```
Field: max_requests_per_minute
Type: number
Value: 60

Field: request_timeout_seconds
Type: number
Value: 30
```

### **Feature Flags**
```
Field: enable_chat
Type: boolean
Value: true

Field: enable_analytics
Type: boolean
Value: true

Field: enable_recommendations
Type: boolean
Value: true

Field: enable_image_analysis
Type: boolean
Value: true

Field: enable_debug_logs
Type: boolean
Value: false

Field: enable_api_response_logging
Type: boolean
Value: false
```

## 🔧 **Step 3: Get Your OpenRouter API Key**

1. **Go to**: https://openrouter.ai/
2. **Sign up/Login**
3. **Go to**: https://openrouter.ai/keys
4. **Click "Create Key"**
5. **Copy the key** (starts with `sk-or-v1-`)
6. **Replace** `sk-or-v1-your-actual-api-key-here` with your real key in Firestore

## 🔧 **Step 4: Update Firestore Rules**

Make sure your Firestore rules allow reading the config:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // App configuration - read-only for authenticated users
    match /app_config/{document} {
      allow read: if request.auth != null;
      allow write: if false; // Only admins can write
    }
    
    // ... rest of your rules
  }
}
```

## 🔧 **Step 5: Test Configuration**

Run this command to test:
```bash
flutter run test_firebase_setup.dart
```

Look for:
- ✅ `Firestore: Available and accessible`
- ✅ `AI Configuration: Complete`

## 🚨 **Common Issues**

### **Issue 1: "Permission denied"**
```
❌ Problem: Can't read app_config
✅ Solution: Update Firestore rules to allow read access
```

### **Issue 2: "Document not found"**
```
❌ Problem: app_config/ai_settings doesn't exist
✅ Solution: Create the document with all required fields
```

### **Issue 3: "API key invalid"**
```
❌ Problem: AI requests failing
✅ Solution: 
- Check OpenRouter API key is correct
- Make sure you have credits in OpenRouter
- Verify key starts with "sk-or-v1-"
```

## 📋 **Quick Checklist**

- [ ] ✅ Firestore Database created
- [ ] ✅ Collection `app_config` created
- [ ] ✅ Document `ai_settings` created
- [ ] ✅ All 21 fields added to document
- [ ] ✅ OpenRouter API key obtained and set
- [ ] ✅ Firestore rules updated
- [ ] ✅ Configuration tested

## 🎯 **Alternative: Use Default Values**

If you want to test without setting up Firestore config, the app will use default values. Just make sure to:

1. **Get OpenRouter API key**
2. **Update the default value** in `firestore_config_service.dart`:
```dart
'openrouter_api_key': 'sk-or-v1-your-real-api-key-here',
```

This way your AI will work even without Firestore setup! 🚀
