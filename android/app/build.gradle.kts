import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.time_gochi"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.time_gochi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "mode"
    productFlavors {
        create("prod") {
            dimension = "mode"
        }
        create("admin") {
            dimension = "mode"
            applicationIdSuffix = ".admin"
            versionNameSuffix = "-admin"
            resValue("string", "app_label", "타임고치 관리자")
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile")!!)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // key.properties 없으면 로컬 편의용 debug 서명. 배포 전 key.properties.example 참고.
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
            // R8 매핑(충돌 복원용): assembleRelease 후
            // build/app/outputs/mapping/release/mapping.txt
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Flutter CLI 산출 APK는 (Flutter 루트)/build/app/outputs/flutter-apk 에 둔다.
// :app 의 layout.buildDirectory( android/app/build ) 와 다르므로 루트 기준 경로로 복사한다.
val flutterApkOutDir = rootProject.projectDir.parentFile.resolve("build/app/outputs/flutter-apk")

// Flutter 기본 산출물은 app-release.apk 라서 이름이 안 바뀐 것처럼 보임.
// release 조립이 끝나면 프로젝트 build/ 에 고정 파일명으로 복사한다.
val exportTimeGochiApk =
    tasks.register<Copy>("exportTimeGochiApk") {
        group = "build"
        description =
            "assembleProdRelease 산출 APK를 (프로젝트 루트)/build/apk_named/time_gochi-release.apk 로 복사"
        from(flutterApkOutDir) {
            include("app-prod-release.apk")
            rename("app-prod-release.apk", "time_gochi-release.apk")
        }
        into(rootProject.projectDir.parentFile.resolve("build/apk_named"))
    }

val exportTimeGochiAdminApk =
    tasks.register<Copy>("exportTimeGochiAdminApk") {
        group = "build"
        description =
            "assembleAdminRelease 산출 APK를 (프로젝트 루트)/build/apk_named/time_gochi-admin-release.apk 로 복사"
        from(flutterApkOutDir) {
            include("app-admin-release.apk")
            rename("app-admin-release.apk", "time_gochi-admin-release.apk")
        }
        into(rootProject.projectDir.parentFile.resolve("build/apk_named"))
    }

afterEvaluate {
    tasks.matching { it.name == "assembleProdRelease" }.configureEach {
        finalizedBy(exportTimeGochiApk)
    }
    tasks.matching { it.name == "assembleAdminRelease" }.configureEach {
        finalizedBy(exportTimeGochiAdminApk)
    }
}
