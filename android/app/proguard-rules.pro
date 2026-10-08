# Flutter + plugin keep rules for R8 (release minify).

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# sqlite3 native binding
-keep class com.sqlite3.** { *; }

# local_auth / biometrics
-keep class androidx.biometric.** { *; }

# shared_preferences / secure_storage / share_plus (keep plugin registrant)
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

# Kotlin / metadata
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }
