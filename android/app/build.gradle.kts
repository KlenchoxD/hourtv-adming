import java.util.Properties

plugins {
    id("com.android.application")
    id("com.chaquo.python")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release propia. La keystore y sus contraseñas viven en
// android/key.properties (ya ignorado por git) para no publicar la llave.
// Si el archivo no existe todavia, el build sigue funcionando con la llave de
// debug pero AVISA: un APK firmado con debug no se puede instalar encima de
// uno firmado de release (INSTALL_FAILED_UPDATE_INCOMPATIBLE), asi que las
// actualizaciones desde GitHub solo son fiables con la keystore propia.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val configuredKeystore = (keystoreProperties["storeFile"] as String?)?.let {
    rootProject.file(it)
}
val hasReleaseKeystore = configuredKeystore?.isFile == true
if (!hasReleaseKeystore) {
    logger.warn(
        "HourTV: la keystore release configurada no existe -> se usara la " +
            "llave DEBUG compatible con las versiones publicadas actuales."
    )
}

android {
    namespace = "com.example.mi_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mi_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = configuredKeystore
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Rhino exposes optional JavaBeans converters that Android does
            // not provide. Suppress only those absent desktop-only classes
            // so R8 can finish the release build without weakening shrinking.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Host-specific direct-stream extraction. Kept behind HourTV's own bridge
    // so provider-library changes do not alter the native player contract.
    implementation("io.github.darkryh.moongetter:moongetter-core:2.0.0-alpha02")
    implementation("io.github.darkryh.moongetter:moongetter-server-bundle:2.0.0-alpha02")
    implementation("io.github.darkryh.moongetter:moongetter-client-ktor:2.0.0-alpha02")
    implementation("io.ktor:ktor-client-okhttp:3.2.1")
    implementation("androidx.webkit:webkit:1.15.0")
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("androidx.mediarouter:mediarouter:1.8.1")
    implementation("com.google.android.gms:play-services-cast-framework:21.5.0")
    // Publicidad: Unity LevelPlay (el SDK lo trae el plugin) + red Unity Ads.
    implementation("com.unity3d.ads-mediation:unityads-adapter:5.13.0")
    implementation("com.unity3d.ads:unity-ads:4.20.1")
    implementation("com.google.android.gms:play-services-appset:16.0.2")
    implementation("com.google.android.gms:play-services-ads-identifier:18.0.1")
    implementation("com.google.android.gms:play-services-basement:18.3.0")
}

flutter {
    source = "../.."
}

chaquopy {
    defaultConfig {
        version = "3.11"
        val configuredPython = providers.environmentVariable("HOURTV_BUILD_PYTHON").orNull
        if (configuredPython != null) {
            buildPython(configuredPython)
        } else if (System.getProperty("os.name").startsWith("Windows")) {
            buildPython("py", "-3.11")
        } else {
            buildPython("python3.11")
        }
        pip {
            install("yt-dlp==2026.8.19")
        }
    }
}
