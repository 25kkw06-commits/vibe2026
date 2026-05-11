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

// Flutter 기본 산출물은 app-release.apk 라서 이름이 안 바뀐 것처럼 보임.
// release 조립이 끝나면 프로젝트 build/ 에 고정 파일명으로 복사한다.
val exportTimeGochiApk =
    tasks.register<Copy>("exportTimeGochiApk") {
        dependsOn("assembleRelease")
        group = "build"
        description =
            "assembleRelease 산출 APK를 (프로젝트 루트)/build/apk_named/time_gochi-release.apk 로 복사"
        from(layout.buildDirectory.dir("outputs/apk/release")) {
            include("*.apk")
            rename(".*\\.apk", "time_gochi-release.apk")
        }
        into(rootProject.projectDir.parentFile.resolve("build/apk_named"))
    }

afterEvaluate {
    tasks.named("assembleRelease").configure { finalizedBy(exportTimeGochiApk) }
}
