# Firebase Setup Commands

## 🚀 **Quick Setup Commands**

### **1. Install Firebase CLI (if not installed)**
```bash
npm install -g firebase-tools
```

### **2. Login to Firebase**
```bash
firebase login
```

### **3. Initialize Firebase in your project**
```bash
cd calorie
firebase init
```

**Select these services:**
- ✅ Firestore
- ✅ Storage  
- ✅ Remote Config
- ✅ Hosting (optional)

### **4. Deploy Firestore Rules**
```bash
firebase deploy --only firestore:rules
```

### **5. Deploy Storage Rules**
```bash
firebase deploy --only storage
```

### **6. Deploy Remote Config**
```bash
firebase deploy --only remoteconfig
```

---

## 🔧 **Manual Setup Steps (You Need to Do)**

### **Step 1: Firebase Console Setup**
1. Go to: https://console.firebase.google.com/
2. Select project: `calorie-vita`
3. Enable these services:
   - Authentication → Sign-in method → Enable Email/Password
   - Authentication → Sign-in method → Enable Google Sign-In
   - Firestore Database → Create database
   - Storage → Get started
   - Remote Config → Get started
   - Analytics → Get started
   - Crashlytics → Get started

### **Step 2: Get OpenRouter API Key**
1. Go to: https://openrouter.ai/
2. Sign up/Login
3. Go to: https://openrouter.ai/keys
4. Create new API key
5. Copy the key (starts with `sk-or-v1-`)

### **Step 3: Set Up Remote Config Parameters**
In Firebase Console → Remote Config, add these parameters:

```
openrouter_api_key = sk-or-v1-your-actual-key-here
openrouter_base_url = https://openrouter.ai/api/v1/chat/completions
chat_model = openai/gpt-3.5-turbo
vision_model = google/gemini-pro-1.5-exp
backup_vision_model = google/gemini-pro-1.5
max_tokens = 100
chat_max_tokens = 100
analytics_max_tokens = 120
vision_max_tokens = 300
temperature = 0.7
vision_temperature = 0.1
app_name = Calorie Vita
app_url = https://calorievita.com
max_requests_per_minute = 60
request_timeout_seconds = 30
enable_chat = true
enable_analytics = true
enable_recommendations = true
enable_image_analysis = true
enable_debug_logs = false
enable_api_response_logging = false
```

### **Step 4: Publish Remote Config**
After adding all parameters, click "Publish changes"

---

## 🧪 **Test Commands**

### **Test Firebase Connection**
```bash
flutter run
# Look for: "Firebase initialized successfully"
```

### **Test AI Features**
1. Open app → AI Trainer screen
2. Send a test message
3. Check logs for success/error

### **Test Food Recognition**
1. Open app → Camera screen
2. Take photo of food
3. Check if AI analyzes it

---

## 🚨 **Troubleshooting Commands**

### **Check Firebase Status**
```bash
firebase projects:list
firebase use calorie-vita
firebase projects:list
```

### **Check Remote Config**
```bash
firebase remoteconfig:get
```

### **View Logs**
```bash
firebase functions:log
```

---

## 📋 **Complete Setup Checklist**

- [ ] Firebase CLI installed
- [ ] Logged into Firebase
- [ ] Firebase project initialized
- [ ] Authentication enabled (Email/Password + Google)
- [ ] Firestore database created
- [ ] Storage enabled
- [ ] Remote Config enabled
- [ ] Analytics enabled
- [ ] Crashlytics enabled
- [ ] OpenRouter API key obtained
- [ ] Remote Config parameters added
- [ ] Remote Config published
- [ ] Firestore rules deployed
- [ ] Storage rules deployed
- [ ] App tested with AI features
- [ ] Food recognition tested
- [ ] User authentication tested

---

## 🆘 **If You Get Stuck**

### **Common Issues:**

1. **"Firebase not initialized"**
   - Check internet connection
   - Verify project ID: `calorie-vita`
   - Make sure Firebase services are enabled

2. **"AI request failed"**
   - Check OpenRouter API key
   - Verify API key has credits
   - Check Remote Config is published

3. **"Authentication failed"**
   - Enable Email/Password in Firebase Console
   - Enable Google Sign-In if using it
   - Check Firestore rules

4. **"Remote Config not loading"**
   - Check if Remote Config is enabled
   - Verify all parameters are published
   - Check internet connection

### **Need Help?**
- Check Firebase Console for error messages
- Look at app logs for specific errors
- Verify all services are enabled
- Make sure API keys are valid

---

## 🎯 **Priority Order**

1. **FIRST**: Enable Firebase services in Console
2. **SECOND**: Get OpenRouter API key
3. **THIRD**: Set up Remote Config parameters
4. **FOURTH**: Deploy rules
5. **FIFTH**: Test everything

Your AI will work once you complete these steps! 🚀
