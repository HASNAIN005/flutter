plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.id_scanner"
    compileSdk = 35 // Updated compileSdkVersion
    ndkVersion = "27.0.12077973" // Updated ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.id_scanner"
        minSdk = 23 // Updated minSdkVersion
        targetSdk = 35 // Updated targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = "your-key-alias"
            keyPassword = "123456"
            storeFile = file("release-key.jks")
            storePassword = "123456"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.12.0"))
    implementation("com.google.firebase:firebase-analytics")

    // Exclude unused ML Kit language models
    implementation("com.google.mlkit:text-recognition:16.0.0") {
        exclude(group = "com.google.mlkit", module = "text-recognition-chinese")
        exclude(group = "com.google.mlkit", module = "text-recognition-japanese")
        exclude(group = "com.google.mlkit", module = "text-recognition-korean")
        exclude(group = "com.google.mlkit", module = "text-recognition-devanagari")
    }
}