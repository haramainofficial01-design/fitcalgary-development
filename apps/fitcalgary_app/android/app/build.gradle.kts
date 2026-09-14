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
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val appLinkHost = providers.gradleProperty("FITCALGARY_APP_LINK_HOST")
    .orElse("fitcalgary.invalid")
    .get()
val invalidReleaseHost = appLinkHost.isBlank() ||
    appLinkHost.contains("localhost", ignoreCase = true) ||
    appLinkHost.endsWith(".invalid", ignoreCase = true) ||
    appLinkHost.contains("://") ||
    appLinkHost.contains('/')

if (releaseRequested && !hasReleaseSigning) {
    throw GradleException(
        "FitCalgary release signing is missing. Supply the dedicated Play upload " +
            "keystore through FITCALGARY_RELEASE_KEYSTORE, " +
            "FITCALGARY_RELEASE_STORE_PASSWORD, FITCALGARY_RELEASE_KEY_ALIAS, " +
            "and FITCALGARY_RELEASE_KEY_PASSWORD. Debug signing is never used " +
            "for Release builds."
    )
}
if (releaseRequested && invalidReleaseHost) {
    throw GradleException(
        "FITCALGARY_APP_LINK_HOST must be an explicit production domain for " +
            "Release builds; localhost, URL schemes, paths, and .invalid are rejected."
    )
}

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
        manifestPlaceholders["appLinkHost"] = appLinkHost
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
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
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
