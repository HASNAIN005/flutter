# Keep all classes from Google Play Core
-keep class com.google.android.play.core.** { *; }

# Keep all classes from Google ML Kit
-keep class com.google.mlkit.** { *; }

# Keep Flutter-related classes
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Firebase dependencies
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Prevent stripping of annotations
-keepattributes *Annotation*

# General rule to avoid issues with Kotlin metadata
-keepattributes KotlinMetadata

# Keep models and builders for ML Kit text recognition languages
-keep class com.google.mlkit.vision.text.** { *; }

# Keep Play Core tasks
-keep class com.google.android.play.core.tasks.** { *; }