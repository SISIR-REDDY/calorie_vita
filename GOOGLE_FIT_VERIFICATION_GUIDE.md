# 🔐 Google Fit Verification Guide - Step by Step

## 🎯 Goal: Verify Your App for Google Fit Data Access

Your app uses these **sensitive scopes** (Google Fit):
- `https://www.googleapis.com/auth/fitness.activity.read`
- `https://www.googleapis.com/auth/fitness.body.read`
- `https://www.googleapis.com/auth/fitness.nutrition.read`
- `https://www.googleapis.com/auth/fitness.sleep.read`

**These require OAuth verification before production use.**

---

## 📋 Step-by-Step Verification Process

### **Step 1: Complete OAuth Consent Screen**

1. **Go to Google Cloud Console:**
   - Open: https://console.cloud.google.com/
   - Select project: **calorie-vita**

2. **Navigate to OAuth Consent Screen:**
   - Click **"APIs & Services"** (left sidebar)
   - Click **"OAuth consent screen"**

3. **Complete All Required Fields:**

   **App Information:**
   - ✅ **App name:** `Calorie Vita`
   - ✅ **User support email:** Your email address
   - ✅ **App logo:** Upload your app icon (512x512 PNG)
   - ✅ **Application home page:**
     ```
     https://sisir-reddy.github.io/calorie_vita_pages/
     ```
   - ✅ **Application privacy policy link:**
     ```
     https://sisir-reddy.github.io/calorie_vita_pages/privacy-policy.html
     ```
   - ✅ **Application Terms of Service link:**
     ```
     https://sisir-reddy.github.io/calorie_vita_pages/terms-of-service.html
     ```
   - ✅ **Authorized domains:** (Optional - can skip if GitHub Pages doesn't work)
     - Try: `sisir-reddy.github.io` (without https://)
     - If it doesn't work, you can skip this for now

   **Developer contact information:**
   - ✅ **Developer contact email:** Your email address

4. **Click "Save and Continue"**

---

### **Step 2: Add Scopes**

1. **In OAuth consent screen**, click **"Scopes"** tab (or "Add or Remove Scopes")

2. **Verify these scopes are added:**
   - ✅ `email`
   - ✅ `profile`
   - ✅ `openid`
   - ✅ `https://www.googleapis.com/auth/fitness.activity.read`
   - ✅ `https://www.googleapis.com/auth/fitness.body.read`
   - ✅ `https://www.googleapis.com/auth/fitness.nutrition.read`
   - ✅ `https://www.googleapis.com/auth/fitness.sleep.read`

3. **If scopes are missing:**
   - Click **"Add Scopes"**
   - Search for "Google Fit API"
   - Select the scopes you need
   - Click **"Add to Table"**

4. **Click "Save and Continue"**

---

### **Step 3: Add Test Users (For Development)**

**While waiting for verification, add test users:**

1. **In OAuth consent screen**, scroll to **"Test users"** section
2. Click **"+ ADD USERS"**
3. Add email addresses of test users (up to 100)
4. Click **"ADD"**

**Test users can sign in without the warning!**

---

### **Step 4: Submit for Verification**

1. **In OAuth consent screen**, click **"PUBLISH APP"** button (top right)

2. **Choose Publishing Status:**
   - **Testing:** Keep in testing mode (only test users can sign in)
   - **Production:** Submit for production (all users can sign in after verification)

3. **If submitting for Production:**
   - Click **"PUBLISH APP"**
   - You'll see a message: "Your app is now published"
   - For sensitive scopes, Google will review your app

4. **Verification Process:**
   - Google will review your app
   - Review time: **1-7 days**
   - You'll receive email updates

---

### **Step 5: Complete Verification Form (If Required)**

**Google may ask for additional information:**

1. **App Purpose:**
   - Explain why you need Google Fit data
   - Example: "Calorie Vita uses Google Fit data to sync activity, steps, and calories burned to provide comprehensive health tracking and personalized nutrition recommendations."

2. **Data Usage:**
   - Explain how you use the data
   - Example: "We use Google Fit data to calculate total calories burned, track daily activity, and provide accurate calorie balance calculations for our users."

3. **Security Measures:**
   - Explain your data security practices
   - Example: "All data is encrypted in transit and at rest using Firebase. We follow industry-standard security practices and comply with GDPR/CCPA regulations."

4. **Video Demonstration (Optional but Recommended):**
   - Record a short video showing how your app uses Google Fit
   - Upload to YouTube (unlisted)
   - Share the link in the verification form

---

## 📝 Required Information Checklist

### **Before Submitting:**

- [ ] App name: **Calorie Vita**
- [ ] User support email: Your email
- [ ] App logo uploaded (512x512 PNG)
- [ ] Home page URL: `https://sisir-reddy.github.io/calorie_vita_pages/`
- [ ] Privacy policy URL: `https://sisir-reddy.github.io/calorie_vita_pages/privacy-policy.html`
- [ ] Terms of service URL: `https://sisir-reddy.github.io/calorie_vita_pages/terms-of-service.html`
- [ ] Developer contact email: Your email
- [ ] All Google Fit scopes added
- [ ] Test users added (for development)

---

## 🎯 Your Google Fit Scopes

**These are the scopes your app uses:**

```dart
[
  'email',
  'profile',
  'openid',
  'https://www.googleapis.com/auth/fitness.activity.read',
  'https://www.googleapis.com/auth/fitness.body.read',
  'https://www.googleapis.com/auth/fitness.nutrition.read',
  'https://www.googleapis.com/auth/fitness.sleep.read'
]
```

**Make sure all of these are added in OAuth consent screen!**

---

## ⏱️ Timeline

1. **Complete OAuth consent screen:** 10-15 minutes
2. **Submit for verification:** 5 minutes
3. **Google review:** 1-7 days
4. **After approval:** No more warnings for users!

---

## ✅ After Verification

**Once approved:**
- ✅ All users can sign in without warning
- ✅ Google Fit data access works for all users
- ✅ App appears verified in Google's system
- ✅ No more "Google hasn't verified this app" message

---

## 🔗 Important Links

- **Google Cloud Console:** https://console.cloud.google.com/
- **OAuth Consent Screen:** https://console.cloud.google.com/apis/credentials/consent
- **Your Project:** calorie-vita (Project ID: 868343457049)
- **Your GitHub Pages:**
  - Home: https://sisir-reddy.github.io/calorie_vita_pages/
  - Privacy: https://sisir-reddy.github.io/calorie_vita_pages/privacy-policy.html
  - Terms: https://sisir-reddy.github.io/calorie_vita_pages/terms-of-service.html

---

## ❓ Common Issues

### **Issue: "App is in testing mode"**
- **Solution:** Add test users to test your app while waiting for verification

### **Issue: "Sensitive scopes require verification"**
- **Solution:** Submit for verification (this guide)

### **Issue: "Verification rejected"**
- **Solution:** Review Google's feedback, update your app/policies, and resubmit

### **Issue: "Authorized domains error"**
- **Solution:** You can skip authorized domains if GitHub Pages doesn't work. Your branding URLs are more important.

---

## 🚀 Quick Start

1. **Go to:** https://console.cloud.google.com/apis/credentials/consent
2. **Complete all required fields** (use your GitHub Pages URLs)
3. **Add all Google Fit scopes**
4. **Click "PUBLISH APP"**
5. **Wait for Google's review** (1-7 days)

---

## 📧 What to Expect

**After submitting:**
- You'll receive email confirmation
- Google will review your app
- You may receive questions or requests for clarification
- Once approved, you'll receive an approval email

**During review:**
- You can still use test users
- Your app works for test users
- Production users will see warning until approved

---

## ✅ Final Checklist

- [ ] OAuth consent screen completed
- [ ] All required URLs added (GitHub Pages)
- [ ] All Google Fit scopes added
- [ ] Test users added (for development)
- [ ] App published (Testing or Production)
- [ ] Verification submitted
- [ ] Waiting for Google's review

---

**Good luck with your verification! 🚀**

