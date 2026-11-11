import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyFile = rootProject.file("key.properties")
val releaseKeys = Properties().apply {
    if (releaseKeyFile.isFile) releaseKeyFile.inputStream().use { load(it) }
}
val readerPreview = providers.gradleProperty("wenkuReaderPreview").orNull == "true"
val forkDistribution = providers.gradleProperty("wenkuForkDistribution").orNull == "true"
val unsignedRelease = providers.gradleProperty("wenkuUnsignedRelease").orNull == "true"

android {
    namespace = "org.mewx.wenku8_flutter"
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

    defaultConfig {
        // Public source previews must not replace an installed distribution.
        applicationId = if (forkDistribution) "io.github.lingszb.wenku8.localreader"
            else "org.mewx.wenku8_flutter.source_preview"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["wenkuAppLabel"] = if (forkDistribution)
            "轻小说文库 · 本地阅读" else "轻小说文库 · 源码预览"
        // AGP otherwise builds upstream desktop utilities too, including the
        // DRM tool whose encryption code is intentionally disabled in this app.
        externalNativeBuild.cmake.targets.addAll(listOf("mobi", "wenku_mobi"))
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    if (releaseKeyFile.isFile) {
        signingConfigs.create("distribution") {
            keyAlias = releaseKeys.getProperty("keyAlias")
            keyPassword = releaseKeys.getProperty("keyPassword")
            storeFile = rootProject.file(requireNotNull(releaseKeys.getProperty("storeFile")))
            storePassword = releaseKeys.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            proguardFile(file("document-import.pro"))
            if (readerPreview) {
                applicationIdSuffix = ".reader_preview"
            }
            // Local previews remain install-compatible. Public distributions
            // use an owner's untracked key.properties, never an embedded key.
            signingConfig = if (unsignedRelease) null else signingConfigs.getByName(
                if (releaseKeyFile.isFile && !readerPreview) "distribution" else "debug"
            )
        }
    }

    // Match native document import libraries to the selected Flutter targets.
    val targets = project.findProperty("target-platform")?.toString()
    if (targets != null && project.findProperty("split-per-abi")?.toString()?.toBoolean() != true) {
        val targetAbis = targets.split(",").map { platform ->
            when (platform) {
                "android-arm" -> "armeabi-v7a"
                "android-arm64" -> "arm64-v8a"
                "android-x64" -> "x86_64"
                else -> error("Unsupported Flutter target platform: $platform")
            }
        }
        // Native dependencies and CMake also use defaultConfig. Filtering only
        // build types leaves unused ARM libraries inside x86_64 profile APKs.
        defaultConfig.ndk.abiFilters.clear()
        defaultConfig.ndk.abiFilters.addAll(targetAbis)
        buildTypes.configureEach {
            ndk.abiFilters.clear()
            ndk.abiFilters.addAll(targetAbis)
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.github.albfernandez:juniversalchardet:2.0.4")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")
    // Keep the media host classes available to the app's shared-engine wiring.
    implementation("androidx.media:media:1.7.0")
}
