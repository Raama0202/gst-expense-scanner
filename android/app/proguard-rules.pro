# ML Kit / Document Scanner
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# Hive / Secure storage
-keepclassmembers class * extends com.google.crypto.tink.** { *; }

# Keep model fromJson factories used via reflection-free maps
-keepclassmembers class * {
  public <init>(...);
}
