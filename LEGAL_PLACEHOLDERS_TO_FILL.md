# 📝 Legal Document Placeholders - Action Required

## Overview
I've updated your Terms & Conditions and Privacy Policy screens with professional legal content. However, there are several placeholders that need to be filled with your actual company/business information.

---

## 🔴 CRITICAL - Must Fill Before Launch

### Terms & Conditions Screen

#### 1. **Jurisdiction Information** (Line 357)
**Location:** Section 12 - Governing Law and Dispute Resolution

Replace:
- `[YOUR_JURISDICTION]` with your actual jurisdiction
  - Example: "the State of California, United States"
  - Example: "India"
  - Example: "England and Wales"

#### 2. **Arbitration Body** (Line 370)
**Location:** Section 12 - Governing Law and Dispute Resolution

Replace:
- `[YOUR_ARBITRATION_BODY]` with your arbitration organization
  - Example: "American Arbitration Association (AAA)"
  - Example: "International Chamber of Commerce (ICC)"
  - Example: "Indian Council of Arbitration"
  - Or: Remove arbitration clause if not applicable

#### 3. **Arbitration Location** (Line 371)
**Location:** Section 12 - Governing Law and Dispute Resolution

Replace:
- `[YOUR_ARBITRATION_LOCATION]` with city/jurisdiction
  - Example: "San Francisco, California"
  - Example: "Mumbai, India"
  - Example: "London, England"

#### 4. **Court Jurisdiction** (Line 376)
**Location:** Section 12 - Governing Law and Dispute Resolution

Replace:
- `[YOUR_COURT_JURISDICTION]` with specific courts
  - Example: "courts located in San Francisco County, California"
  - Example: "courts of Mumbai, Maharashtra, India"
  - Example: "courts of England and Wales"

#### 5. **Contact Information** ✅ UPDATED
**Location:** Section 13 - Contact Information

**Status:** Already updated to `calorievita@gmail.com` - No action needed!

---

### Privacy Policy Screen

#### 1. **Payment Processor** (Line 162)
**Location:** Section 3 - Information Sharing and Disclosure

Replace or remove:
- `[YOUR_PAYMENT_PROCESSOR - if applicable]`
  - Example: "Stripe" (if you use Stripe)
  - Example: "Razorpay" (if you use Razorpay)
  - Or: Remove this line if you don't have payments yet

#### 2. **Contact Information** ✅ UPDATED
**Location:** Section 9 - Contact Information and Data Protection

**Status:** Already updated to `calorievita@gmail.com` - No action needed!

---

## 📋 Quick Checklist

Before publishing your app, ensure you've replaced ALL of the following:

### Terms & Conditions (4 placeholders):
- [ ] `[YOUR_JURISDICTION]`
- [ ] `[YOUR_ARBITRATION_BODY]` (or remove if not applicable)
- [ ] `[YOUR_ARBITRATION_LOCATION]` (or remove if not applicable)
- [ ] `[YOUR_COURT_JURISDICTION]`
- [x] ✅ Contact Information - Already updated to `calorievita@gmail.com`

### Privacy Policy (1 placeholder):
- [ ] `[YOUR_PAYMENT_PROCESSOR]` (or remove if not applicable)
- [x] ✅ Contact Information - Already updated to `calorievita@gmail.com`

---

## 🎯 Recommended Company Information Template

Here's a template to help you organize the information:

```
Company Legal Name: _______________________
Street Address: _______________________
City, State, Zip: _______________________
Country: _______________________
Support Phone: _______________________
Support Hours: _______________________

Legal Jurisdiction: _______________________
Court Jurisdiction: _______________________
Arbitration Body: _______________________ (or "N/A")
Arbitration Location: _______________________ (or "N/A")

Payment Processor: _______________________ (or "None yet")
EU Representative: _______________________ (or "N/A")
```

---

## ⚠️ Important Notes

1. **Legal Review Recommended**: While the content is professionally written, consider having a lawyer review these documents, especially for:
   - Jurisdiction-specific requirements
   - Industry regulations (health/wellness apps may have additional requirements)
   - International data transfer compliance (GDPR, CCPA)

2. **Email Addresses**: The following email addresses are referenced and should be set up:
   - `support@calorievita.com`
   - `legal@calorievita.com`
   - `privacy@calorievita.com`

3. **Arbitration Clause**: If you're a small business or startup, you may want to remove the arbitration clause entirely and just use regular court jurisdiction. Consult with a lawyer about this.

4. **EU Representative**: Only required if you:
   - Have users in the European Union
   - Are not established in the EU
   - Process significant amounts of EU user data

5. **Data Protection**: The privacy policy references GDPR, CCPA, and other regulations. Ensure you understand your obligations under these laws.

---

## 📞 Next Steps

1. **Fill in all placeholders** using your actual company information
2. **Set up email addresses** (support, legal, privacy)
3. **Optional: Get legal review** from a qualified attorney
4. **Test the screens** to ensure all text displays correctly
5. **Update annually** or when business practices change

---

## ✅ What's Already Done (No Action Needed)

- ✅ Professional legal language throughout
- ✅ Comprehensive health/medical disclaimers
- ✅ AI service provider correctly updated to OpenRouter
- ✅ Firebase and Google Cloud Platform references
- ✅ GDPR, CCPA compliance language
- ✅ Data security and protection details
- ✅ User rights and data portability
- ✅ Children's privacy (COPPA compliance)
- ✅ International data transfers
- ✅ All UI components unchanged

---

## 📧 Email Contact Feature

✅ **Contact email updated to:** `calorievita@gmail.com`

**What's working:**
- Email is updated in all legal documents (Terms & Conditions, Privacy Policy)
- Settings > Contact Us now shows clickable email
- Clicking the email automatically opens the user's mail app
- Pre-fills subject line with "Calorie Vita Support"
- Graceful error handling if mail app unavailable

**Files Updated:**
- `lib/screens/terms_conditions_screen.dart` - Email updated
- `lib/screens/privacy_policy_screen.dart` - Email updated  
- `lib/screens/settings_screen.dart` - Contact dialog with clickable email
- `pubspec.yaml` - Added url_launcher package

---

**Last Updated:** $(date)

