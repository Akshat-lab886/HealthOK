# flutter_local_notifications
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class me.carda.** { *; }
-keepclassmembers class * extends com.dexterous.flutterlocalnotifications.models.* { *; }
-keep class io.flutter.plugins.** { *; }

# health plugin
-keep class dev.flutter.plugins.health.** { *; }

# llamadart / llama.cpp
-keep class com.ookiie.** { *; }
-keep class ggml.** { *; }

# Keep all Flutter plugin registrants
-keep class io.flutter.** { *; }
