plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.music_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.music_player"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // NOTE: youtubedl-android ships a ~30 MB Python runtime and FFmpeg
        // build per ABI, so the ABI list dominates APK size. abiFilters is
        // deliberately not set here: the Flutter Gradle plugin assigns it
        // from --target-platform and anything added here only unions with
        // that, and --target-platform in turn only covers Flutter's own
        // engine — the AAR's x86_64 payload rides along regardless. Splitting
        // is what actually drops it, and is how release builds should be made:
        //   flutter build apk --split-per-abi
    }

    packaging {
        jniLibs {
            // The Python/FFmpeg binaries are unzipped out of the APK on
            // first launch, which only works with legacy packaging.
            useLegacyPackaging = true
            // The Python/FFmpeg payloads are zip archives named .so so
            // that they get packaged at all. They aren't ELF objects, so
            // the NDK strip step errors out on them unless excluded.
            keepDebugSymbols += listOf(
                "**/libpython.zip.so",
                "**/libffmpeg.zip.so",
                "**/libaria2c.zip.so",
            )
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
    // Embeds a Python 3 runtime plus yt-dlp, and runs them on-device.
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    // Needed to extract/transcode the audio stream into a tagged MP3.
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.17.2")
}
