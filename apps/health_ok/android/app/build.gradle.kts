plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.healthok.health_ok"
    compileSdk = 36
    // Flutter's Gradle plugin pins an ndkVersion; instead of letting AGP
    // auto-install into the read-only system SDK, we vendor the exact NDK
    // (r28c = 28.2.13676358) inside the workspace and point ndkPath at it.
    ndkPath = "/Users/akshatpratap/HealthOK/.tooling/android-ndk-r28c"
    ndkVersion = "28.2.13676358"

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
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.healthok.health_ok"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            // Strip non-arm64 ABIs from plugins to reduce APK size
            excludes += setOf(
                "lib/armeabi-v7a/**",
                "lib/x86_64/**",
                "lib/x86/**",
            )
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
