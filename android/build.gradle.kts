allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some plugins ship with a low compileSdk; bump so AAPT sees newer android: attrs (e.g. lStar).
subprojects {
    afterEvaluate {
        val ext = extensions.findByName("android") ?: return@afterEvaluate
        val sdk = 35
        for (method in listOf("setCompileSdkVersion", "setCompileSdk")) {
            try {
                ext.javaClass.getMethod(method, Integer.TYPE).invoke(ext, sdk)
                break
            } catch (_: ReflectiveOperationException) {
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
