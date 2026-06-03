# ── MediaPipe (pulled in by ultralytics_yolo) ─────────────────────────────────
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
-dontwarn com.google.mediapipe.framework.GraphProfiler
-dontwarn com.google.mediapipe.framework.Graph

# Keep all MediaPipe classes that are actually used at runtime
-keep class com.google.mediapipe.** { *; }

# ── SnakeYAML / java.beans (not present on Android, safe to ignore) ───────────
-dontwarn java.beans.**
-dontwarn org.yaml.snakeyaml.**

# ── TFLite / TensorFlow Lite ──────────────────────────────────────────────────
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.**

# ── Ultralytics YOLO plugin ───────────────────────────────────────────────────
-keep class com.ultralytics.** { *; }
-dontwarn com.ultralytics.**

# ── Flutter standard rules ────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
