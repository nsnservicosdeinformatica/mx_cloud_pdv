# ProGuard rules gerais para o projeto
# Regras específicas por flavor são aplicadas via applicationVariants

# Mantém classes do Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Mantém classes nativas
-keepclasseswithmembers class * {
    native <methods>;
}

# Mantém classes anotadas com @Keep
-keep @androidx.annotation.Keep class *
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# CRÍTICO: Preserva MainActivity e métodos de ciclo de vida
-keep class com.example.mx_cloud_pdv.MainActivity {
    <init>(...);
    void onCreate(android.os.Bundle);
    void onStart();
    void onResume();
    void onPause();
    void onStop();
    void onDestroy();
    *;
}

# Preserva FlutterActivity completamente
-keep class io.flutter.embedding.android.FlutterActivity {
    <init>(...);
    void onCreate(android.os.Bundle);
    void onStart();
    void onResume();
    void onPause();
    void onStop();
    void onDestroy();
    *;
}

# Preserva métodos de ciclo de vida de qualquer Activity
-keepclassmembers class * extends android.app.Activity {
    public void onCreate(android.os.Bundle);
    public void onStart();
    public void onResume();
    public void onPause();
    public void onStop();
    public void onDestroy();
}

# Regras específicas para flavor mobile (aplicadas via build.gradle.kts)
# As classes do SDK Stone serão ignoradas no flavor mobile

