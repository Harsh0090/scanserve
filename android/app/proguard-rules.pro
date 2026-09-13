# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Dio / OkHttp
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Socket.io client (uses reflection heavily)
-keep class io.socket.** { *; }
-keep class com.github.nkzawa.** { *; }
-dontwarn io.socket.**

# Cookie Jar / Dio Cookie Manager
-keep class com.lyokone.** { *; }
-dontwarn javax.annotation.**

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# General: keep all model/data classes (prevents JSON serialization issues)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Prevent R8 from stripping Dart-generated classes
-keep class com.example.frontend.** { *; }

# Google Play Core (Flutter deferred components - not needed for standard APK builds)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# GSON rules for flutter_local_notifications
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Plugin-specific rules for flutter_local_notifications
-keep class com.dexterous.** { *; }

