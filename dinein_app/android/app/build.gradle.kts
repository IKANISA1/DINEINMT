import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val appId = "com.dineinmalta.app"

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

fun releaseSigningValue(propertyKey: String, envKey: String): String? =
    (keystoreProperties.getProperty(propertyKey) ?: System.getenv(envKey))
        ?.takeIf { it.isNotBlank() }

val releaseStoreFile =
    releaseSigningValue("storeFile", "ANDROID_KEYSTORE_FILE")
val releaseStorePassword =
    releaseSigningValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias =
    releaseSigningValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword =
    releaseSigningValue("keyPassword", "ANDROID_KEY_PASSWORD")
val hasReleaseSigning =
    listOf(
        releaseStoreFile,
        releaseStorePassword,
        releaseKeyAlias,
        releaseKeyPassword,
    ).all { !it.isNullOrBlank() }

android {
    namespace = appId
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = rootProject.file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    defaultConfig {
        applicationId = appId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "country"

    productFlavors {
        create("mt") {
            dimension = "country"
            applicationId = "com.dineinmalta.app"
            resValue("string", "app_name", "Dinein MT")
            manifestPlaceholders["appLinkHost"] = "dineinmalta.com"
        }
        create("rw") {
            dimension = "country"
            applicationId = "com.dineinrw.app"
            resValue("string", "app_name", "Dinein RW")
            manifestPlaceholders["appLinkHost"] = "dineinrw.ikanisa.com"
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Fail explicitly — never ship a debug-signed release.
                throw GradleException(
                    "Release signing config is missing. " +
                    "Set up key.properties or the ANDROID_KEYSTORE_* env vars."
                )
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    lint {
        // Local/CI release packaging already has separate analyze/test gates.
        // Skipping automatic release lint keeps bundle generation deterministic
        // for store-upload artifacts while still allowing explicit lint runs.
        checkReleaseBuilds = false
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
