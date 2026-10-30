import java.util.Properties

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// AdMob app IDs, matching the ad units in lib/app/services/ad_service.dart:
// release builds use the real app, everything else Google's test app so our
// own taps never count. -PadmobAppId=... still overrides both.
val admobOverride = (project.findProperty("admobAppId") as String?)?.trim().orEmpty()
val admobReleaseAppId = admobOverride.ifEmpty { "ca-app-pub-9008446165886687~3364916890" }
val admobTestAppId = admobOverride.ifEmpty { "ca-app-pub-3940256099942544~3347511713" }

android {
    namespace = "com.sfdevelopers.stiksy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.sfdevelopers.stiksy"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobTestAppId
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            manifestPlaceholders["admobAppId"] = admobReleaseAppId
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // R8 (the ProGuard successor): shrink, obfuscate and drop unused resources.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
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
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Google Play in-app review, called from MainActivity. A Flutter plugin
    // for this would bring its own Kotlin Gradle plugin, which breaks this
    // project's built-in Kotlin build.
    implementation("com.google.android.play:review:2.0.2")
}
