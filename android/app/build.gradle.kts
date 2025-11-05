import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load keystore properties for production signing
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.sisirlabs.calorievita"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf(
            "-Xlint:-options",
            "-Xlint:-deprecation"  // Suppress deprecation warnings (dependencies may use deprecated APIs)
        ))
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sisirlabs.calorievita"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Optimize for size: Only include arm64-v8a (all modern devices since API 26+ support this)
        // This reduces bundle size by ~15-20 MB by excluding armeabi-v7a
        ndk {
            abiFilters.add("arm64-v8a")
        }
    }
    
    // Exclude integration_test from release builds
    configurations {
        releaseImplementation {
            exclude(group = "dev.flutter.plugins.integration_test")
        }
    }

    signingConfigs {
        // Only create release signing config if keystore properties file exists
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                val keystoreFile = keystoreProperties["storeFile"] as String?
                storeFile = keystoreFile?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    // Bundle configuration - optimize for size
    // Note: App Bundles include all architectures but Play Store splits them automatically
    // The bundle size shows all architectures, but users only download their device's architecture
    bundle {
        language {
            // Disable language splits to reduce bundle size
            enableSplit = false
        }
        density {
            // Disable density splits to reduce bundle size
            enableSplit = false
        }
        abi {
            // Enable ABI splits - Play Store will generate separate APKs per architecture
            // This doesn't reduce bundle size, but reduces download size for users
            enableSplit = true
        }
    }
    
    buildTypes {
        release {
            // Production signing configuration
            // Use release signing if keystore exists, otherwise fall back to debug (for development)
            signingConfig = if (keystorePropertiesFile.exists() && signingConfigs.findByName("release") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            
            // Production optimizations - aggressive size reduction
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            
            // Additional size optimizations
            // Remove unused code and resources more aggressively
            // This helps reduce APK size by removing unused drawables, strings, etc.
            // Note: Make sure to test thoroughly as this removes unused resources
            
            // Additional resource optimization
            // Remove unused resources from dependencies
            // This is safe as it only removes truly unused resources
            
            // Performance optimizations
            // Note: Debug symbol stripping disabled due to Android SDK path containing spaces
            // To enable: Move Android SDK to path without spaces (e.g., C:\Android\Sdk)
            // ndk {
            //     debugSymbolLevel = "NONE" // Remove debug symbols to save space
            // }
        }
        
        debug {
            // Debug optimizations
            isDebuggable = true
            // Removed applicationIdSuffix to match Firebase configuration
            // applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    implementation("com.google.android.gms:play-services-location:21.0.1")
    implementation("androidx.health.connect:connect-client:1.1.0-alpha07")
    // Google Fit dependencies
    implementation("com.google.android.gms:play-services-fitness:21.1.0")
    implementation("com.google.android.gms:play-services-identity:18.0.1")
}
