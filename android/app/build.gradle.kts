plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

import java.util.Properties

android {
    namespace = "de.tsv.kassenapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Align with Flutter/AGP recommended Java 17
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Ensure Java 17 toolchain is used
    java {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(17))
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "de.tsv.kassenapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Signing configuration: read from key.properties if it exists
    signingConfigs {
        create("release") {
            val keystoreProps = Properties()
            val propsFile = file("key.properties")
            if (propsFile.exists()) {
                propsFile.inputStream().use { keystoreProps.load(it) }
                val storePath = keystoreProps.getProperty("storeFile")
                if (!storePath.isNullOrBlank()) {
                    storeFile = file(storePath)
                }
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Use real release keystore if key.properties exists, otherwise fall back to debug signing
            val propsFile = file("key.properties")
            signingConfig = if (propsFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            // Recommended for release sizes (can be tuned later)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
