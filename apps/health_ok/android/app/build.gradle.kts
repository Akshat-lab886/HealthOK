plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.healthok.health_ok"
    compileSdk = flutter.compileSdkVersion
    // Flutter's Gradle plugin pins an ndkVersion; instead of letting AGP
    // auto-install into the read-only system SDK, we vendor the exact NDK
    // (r28c = 28.2.13676358) inside the workspace and point ndkPath at it.
    ndkPath = "/Users/akshatpratap/HealthOK/.tooling/android-ndk-r28c"

    signingConfigs {
        getByName("debug") {
            // macOS JVM ignores $HOME for user.home, so AGP cannot create the
            // default ~/.android/debug.keystore under the sandbox. Use a
            // workspace-local debug keystore instead (generated via keytool).
            storeFile = file("/Users/akshatpratap/HealthOK/.tooling/android-debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.healthok.health_ok"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
