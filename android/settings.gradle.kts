pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Automatically patch legacy 'proguard-android.txt' in cached plugins for AGP 9.0+ compatibility
try {
    val home = System.getProperty("user.home")
    val localAppData = System.getenv("LOCALAPPDATA") ?: "$home/AppData/Local"
    val pubCacheDirs = listOf(
        java.io.File(localAppData, "Pub/Cache/hosted/pub.dev"),
        java.io.File(home, ".pub-cache/hosted/pub.dev")
    )
    for (cacheDir in pubCacheDirs) {
        if (cacheDir.exists()) {
            cacheDir.listFiles()?.forEach { pluginDir ->
                val bg = java.io.File(pluginDir, "android/build.gradle")
                if (bg.exists()) {
                    val content = bg.readText()
                    if (content.contains("proguard-android.txt")) {
                        bg.writeText(content.replace("proguard-android.txt", "proguard-android-optimize.txt"))
                    }
                }
            }
        }
    }
} catch (_: Exception) {}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
