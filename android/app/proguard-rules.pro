# ProGuard rules for Calorie Vita production build - Optimized for size

# Keep Flutter framework (minimal)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Firebase classes (minimal)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep only essential AI service classes
-keep class com.sisirlabs.calorievita.services.AIService { *; }
-keep class com.sisirlabs.calorievita.services.LoggerService { *; }
-keep class com.sisirlabs.calorievita.services.AuthService { *; }
-keep class com.sisirlabs.calorievita.config.ProductionConfig { *; }

# Keep essential model classes only
-keep class com.sisirlabs.calorievita.models.FoodEntry { *; }
-keep class com.sisirlabs.calorievita.models.UserPreferences { *; }

# Keep serialization (minimal)
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enums (minimal)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Remove unused HTTP classes
-dontwarn okhttp3.**
-dontwarn retrofit2.**
-dontwarn com.bumptech.glide.**

# Aggressive logging removal
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Remove debug prints
-assumenosideeffects class kotlin.io.PrintStream {
    public void print(...);
    public void println(...);
}

# Aggressive optimization for size
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 7
-allowaccessmodification
-dontpreverify

# Remove line numbers to save space
-dontwarn **
-ignorewarnings

# Aggressive shrinking for maximum size reduction
-optimizationpasses 7
-allowaccessmodification
-dontpreverify
-verbose
-dump class_files.txt
-printseeds seeds.txt
-printusage unused.txt
-printmapping mapping.txt

# Remove unused resources
-keep class **.R
-keep class **.R$* {
    <fields>;
}

# Keep only essential classes
-keep public class com.sisirlabs.calorievita.MainActivity { *; }
-keep public class com.sisirlabs.calorievita.MainApplication { *; }
