# ─── Flutter ────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Firebase Crashlytics ───────────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# ─── Google Play Services / Firebase Core ───────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ─── Supabase / OkHttp / Retrofit (used by plugins) ────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# ─── Flutter Secure Storage ─────────────────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ─── Keep Android WiFi / Network classes used via method channels ───────────
-keep class android.net.wifi.** { *; }
-keep class android.net.** { *; }

# ─── General R8 safety ──────────────────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod
