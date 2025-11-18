import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")   // ⭐ Firebase plugin
}

android {
    namespace = "com.ck.ai_lotto_generator.ai_lotto_generator"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11

        // ⭐ REQUIRED for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.ck.ai_lotto_generator.ai_lotto_generator"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ⭐ RELEASE SIGNING — LOAD key.properties
    signingConfigs {
        create("release") {
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("key.properties")

            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))

                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            // ⭐ FIX BUILD ERROR — DISABLE SHRINKING
            isMinifyEnabled = false
            isShrinkResources = false

            // ⭐ USE RELEASE SIGNING (IMPORTANT)
            signingConfig = signingConfigs.getByName("release")
        }

        getByName("debug") {
            // debug stays unsigned
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ⭐ Needed for notifications, scheduling, background services, etc.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
