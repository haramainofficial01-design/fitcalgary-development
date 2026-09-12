plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystore = System.getenv("FITCALGARY_RELEASE_KEYSTORE")
val releaseStorePassword = System.getenv("FITCALGARY_RELEASE_STORE_PASSWORD")
val releaseKeyAlias = System.getenv("FITCALGARY_RELEASE_KEY_ALIAS")
val releaseKeyPassword = System.getenv("FITCALGARY_RELEASE_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseKeystore,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "ca.fitcalgary.index"
    // flutter_secure_storage 11 uses Android 17 APIs and requires API 37 at compile time.
    // targetSdk remains managed by Flutter so runtime opt-ins stay deliberate.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ca.fitcalgary.index"
        manifestPlaceholders["appLinkHost"] = providers.gradleProperty("FITCALGARY_APP_LINK_HOST").orElse("fitcalgary.invalid").get()
        manifestPlaceholders["appAuthRedirectScheme"] = "ca.fitcalgary.index"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseKeystore!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Local release artifacts remain debug-signed until production
            // keystore variables are supplied by the release environment.
            signingConfig = signingConfigs.getByName(if (hasReleaseSigning) "release" else "debug")
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
