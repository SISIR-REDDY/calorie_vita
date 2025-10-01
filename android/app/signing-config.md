# 🔐 Production Signing Configuration

## Required for Play Store Launch

### 1. Generate Production Keystore
```bash
# Run this command in the android/app/ directory
keytool -genkey -v -keystore calorie-vita-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias calorie-vita

# You'll be prompted for:
# - Keystore password
# - Key password
# - Your name and organization details
```

### 2. Update build.gradle.kts
Replace the debug signing configuration with:

```kotlin
android {
    signingConfigs {
        create("release") {
            keyAlias = "calorie-vita"
            keyPassword = "your_key_password"
            storeFile = file("calorie-vita-key.jks")
            storePassword = "your_keystore_password"
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // ... other release config
        }
    }
}
```

### 3. Security Notes
- **Never commit keystore files to version control**
- **Store passwords securely**
- **Keep backup of keystore file**
- **Use different keystores for different environments**

### 4. Environment Variables (Recommended)
Store sensitive data in environment variables:

```bash
# Create android/key.properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=calorie-vita
storeFile=calorie-vita-key.jks
```

Then update build.gradle.kts to use these variables for better security.
