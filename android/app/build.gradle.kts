import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing config from android/key.properties (if present)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.perfusioncalc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (it uses java.time APIs
        // that need desugaring on older Android API levels).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.perfusioncalc"
        // flutter_local_notifications v21 raised its floor to Android 7.0
        // (API 24). Flutter's own default currently sits at 24 as well, but
        // it is a moving target - taking the maximum keeps the build correct
        // if Flutter ever lowers it, and follows Flutter upwards if it rises.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Ohne key.properties fiel der Release-Build bisher still auf den
            // Debug-Key zurueck. Ein debug-signiertes APK unter dem Release-
            // Namen sieht echt aus, laesst sich sideloaden und ist nie wieder
            // durch ein korrekt signiertes Update ersetzbar. release.yml setzt
            // deshalb PERFUSIONCALC_REQUIRE_RELEASE_SIGNING=true; dann bricht
            // der Build ab statt zu degradieren. Lokale Builds ohne die
            // Variable verhalten sich unveraendert.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                if (System.getenv("PERFUSIONCALC_REQUIRE_RELEASE_SIGNING") == "true") {
                    throw GradleException(
                        "Release signing required but android/key.properties is missing. " +
                        "Refusing to fall back to the debug key."
                    )
                }
                signingConfigs.getByName("debug")
            }
            // R8 strips the generic signatures that Gson's TypeToken needs,
            // which made every SCHEDULED notification crash the app with
            // "Missing type parameter" the moment it fired. proguard-rules.pro
            // keeps those signatures and the plugin's model classes.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Needed for flutter_local_notifications' java.time usage on older APIs.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
