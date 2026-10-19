plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 올리기용 서명(업로드 키). 값은 저장소에 두지 않고 환경 변수(GitHub Actions 비밀값)로만 받는다.
// 없으면 디버그 키로 서명한다(시험 설치용, 플레이 스토어에는 못 올림).
val uploadKeystore = System.getenv("ALKKAGI_KEYSTORE_PATH")
val hasUploadKey = !uploadKeystore.isNullOrBlank() && file(uploadKeystore).exists()

android {
    namespace = "TTong.alkkagi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "TTong.alkkagi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(uploadKeystore!!)
                storePassword = System.getenv("ALKKAGI_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ALKKAGI_KEY_ALIAS")
                keyPassword = System.getenv("ALKKAGI_KEY_PASSWORD")
            }
        }
    }

    // 두 가지 판(2026-10-11 형 요청 「자동 업데이트」):
    //  - sideload: 휴대폰 시험판. 켤 때 새 판을 받아 스스로 업데이트한다(인터넷·설치 권한).
    //  - play: 플레이 스토어 판. 스토어가 업데이트하므로 업데이트 기능·인터넷 권한이 없다.
    // 시험판(sideload)은 앱 ID `TTong.alkkagi` 그대로 — 깔린 시험판 위로 업데이트된다.
    // 플레이 판은 `ttong.alkkagi`: 2026-10-19 플레이 콘솔이 대문자로 시작하는 패키지 이름을 받지 않아
    // (「소문자로 시작해야 합니다」) 소문자로 만들었다. 두 판은 폰에 따로 깔린다. 코틀린 namespace 는 그대로.
    flavorDimensions += "channel"
    productFlavors {
        create("sideload") { dimension = "channel" }
        create("play") {
            dimension = "channel"
            applicationId = "ttong.alkkagi"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")
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
