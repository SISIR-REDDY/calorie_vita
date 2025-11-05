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

# Keep all app classes (safe - prevents any functionality breakage)
# Keeping all services, models, widgets, screens, and config classes

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

# Remove unused classes from dependencies (safe - only suppresses warnings)
-dontwarn org.apache.**
-dontwarn javax.annotation.**
-dontwarn javax.inject.**

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

# Aggressive optimization for size reduction
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 7
-allowaccessmodification
-dontpreverify

# Remove line numbers to save space
-dontwarn **
-ignorewarnings

# ProGuard output files (for debugging if needed)
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

# Keep all models and services from your app (safe - prevents breaking functionality)
-keep class com.sisirlabs.calorievita.models.** { *; }
-keep class com.sisirlabs.calorievita.services.** { *; }
-keep class com.sisirlabs.calorievita.widgets.** { *; }
-keep class com.sisirlabs.calorievita.screens.** { *; }
-keep class com.sisirlabs.calorievita.config.** { *; }

# Remove unused resources more aggressively
-keepclassmembers class **.R$* {
    public static <fields>;
}
