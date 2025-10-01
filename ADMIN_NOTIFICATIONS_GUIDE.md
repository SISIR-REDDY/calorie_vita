# 📢 Admin Notifications Guide

## Overview
Your app is configured to receive push notifications via Firebase Cloud Messaging (FCM). As an admin, you can send notifications to all users or specific users.

---

## 🔧 How to Send Notifications

### Method 1: Firebase Console (Easiest)
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Engage → Messaging**
4. Click **"New campaign" → "Notifications"**
5. Fill in:
   - **Title**: Your notification title
   - **Text**: Your notification message
   - **Image** (optional): Add image URL
6. Click **"Next"**
7. Choose target:
   - **All users**: Select your app
   - **Specific users**: Use user segments or topics
8. Click **"Review"** → **"Publish"**

### Method 2: Using Your Notification Service (Programmatic)

Your app has a `PushNotificationService` with two methods:

#### Send to ALL Users:
```dart
final pushService = PushNotificationService();

await pushService.sendNotificationToAllUsers(
  title: 'New Feature Available!',
  body: 'Check out our latest calorie tracking features!',
  data: {
    'type': 'announcement',
    'action': 'open_screen',
    'screen': 'home'
  },
  imageUrl: 'https://your-image-url.com/image.png', // Optional
);
```

#### Send to Specific User:
```dart
await pushService.sendNotificationToUser(
  userId: 'user_firebase_uid_here',
  title: 'Personal Message',
  body: 'You have achieved your weekly goal!',
  data: {
    'type': 'personal',
    'userId': 'user_firebase_uid_here'
  },
);
```

### Method 3: Server-Side (Recommended for Production)

Create a Cloud Function or backend API:

```javascript
// Example Cloud Function (Node.js)
const admin = require('firebase-admin');

exports.sendNotificationToAll = functions.https.onCall(async (data, context) => {
  // Check if user is admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }

  const message = {
    notification: {
      title: data.title,
      body: data.body,
    },
    topic: 'all_users' // All users subscribe to this topic
  };

  try {
    const response = await admin.messaging().send(message);
    return { success: true, messageId: response };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

## 📋 Required Setup

### 1. Firebase Cloud Messaging
- ✅ Already configured in your app
- ✅ `google-services.json` added
- ✅ FCM dependencies added
- ✅ Notification permissions implemented

### 2. User Topics (Recommended)
Subscribe all users to a topic for broadcast:

```dart
// In your app initialization or user login
await FirebaseMessaging.instance.subscribeToTopic('all_users');

// For specific groups
await FirebaseMessaging.instance.subscribeToTopic('premium_users');
await FirebaseMessaging.instance.subscribeToTopic('free_users');
```

### 3. Get User FCM Token
To send to specific users, you need their FCM token:

```dart
// Your app already does this in PushNotificationService
String? token = await FirebaseMessaging.instance.getToken();
// Store this token in Firestore under user document
```

---

## 🎯 Notification Types

### 1. Broadcast Announcements
**Use Case:** App updates, new features, system maintenance
```json
{
  "title": "🎉 New Feature Available!",
  "body": "AI nutrition analysis is now even smarter!",
  "data": {
    "type": "announcement",
    "version": "1.0.1"
  }
}
```

### 2. Personalized Messages
**Use Case:** Goal achievements, reminders, personal tips
```json
{
  "title": "🔥 Great Job!",
  "body": "You've maintained your streak for 7 days!",
  "data": {
    "type": "achievement",
    "userId": "user123",
    "streakDays": "7"
  }
}
```

### 3. Action Notifications
**Use Case:** Deep linking to specific screens
```json
{
  "title": "⚡ Quick Action",
  "body": "Log your breakfast now!",
  "data": {
    "type": "action",
    "action": "open_camera",
    "timestamp": "1234567890"
  }
}
```

---

## 🔐 Security Best Practices

### For Production:
1. **Remove Admin UI from App**
   - ✅ Already removed from Settings
   - Keep admin functions server-side only

2. **Use Server-Side Sending**
   - Implement Cloud Functions
   - Add admin authentication
   - Validate user permissions

3. **Rate Limiting**
   - Limit notifications per user
   - Prevent spam
   - Track notification history

4. **User Preferences**
   - Allow users to opt-out
   - Respect notification preferences
   - Implement Do Not Disturb hours

---

## 📊 Monitoring & Analytics

### Track Notification Performance:
1. **Firebase Console → Analytics**
   - Open rates
   - Click-through rates
   - Conversion tracking

2. **Custom Events**
```dart
// Log when notification is opened
await FirebaseAnalytics.instance.logEvent(
  name: 'notification_opened',
  parameters: {
    'notification_type': 'announcement',
    'notification_id': 'notif_123'
  },
);
```

---

## 🛠️ Testing

### Test Notifications:
1. **Use Firebase Console** → Send test message
2. **Use FCM API** with your device token
3. **Verify in app** notification handling works

### Get Your Device Token:
Your app logs it on initialization. Check logs for:
```
FCM Token: <your-device-token-here>
```

---

## 📝 Notification Service Functions

Your `PushNotificationService` includes:

### ✅ Available Functions:
- `initialize()` - Sets up FCM
- `requestPermission()` - Asks user for notification permission
- `getToken()` - Gets device FCM token
- `sendNotificationToAllUsers()` - Broadcast to all
- `sendNotificationToUser()` - Send to specific user
- `subscribeToTopic()` - Subscribe user to topic
- `unsubscribeFromTopic()` - Unsubscribe from topic

### 📍 Location:
- Service: `lib/services/push_notification_service.dart`
- Screen (removed): `lib/screens/admin_notification_screen.dart` (can delete)

---

## 🚀 Quick Start Commands

### Using Firebase Console:
```
1. Login: https://console.firebase.google.com
2. Select: calorie-vita project
3. Click: Engage → Messaging → New campaign
4. Send: Fill form and publish
```

### Using FCM REST API:
```bash
curl -X POST https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "topic": "all_users",
      "notification": {
        "title": "Hello!",
        "body": "This is a test notification"
      }
    }
  }'
```

---

## ✅ Summary

**Current Status:**
- ✅ FCM fully configured in app
- ✅ Notification permissions implemented
- ✅ Service methods ready for all users & specific users
- ✅ Admin UI removed from settings (security)
- ✅ Ready for Firebase Console usage

**Next Steps for Production:**
1. Use Firebase Console for manual notifications
2. Implement Cloud Functions for automated/server-side notifications
3. Add user topic subscriptions for targeted messaging
4. Set up analytics to track notification performance

---

**Need Help?**
- Firebase Docs: https://firebase.google.com/docs/cloud-messaging
- FCM API: https://firebase.google.com/docs/cloud-messaging/send-message
- Your notification service: `lib/services/push_notification_service.dart`

