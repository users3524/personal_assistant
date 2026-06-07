allprojects {
    repositories {
        google()
        maven { setUrl("https://maven.aliyun.com/repository/public") }
        maven { setUrl("https://maven.aliyun.com/repository/google") }
        mavenCentral()
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
    afterEvaluate {
        val androidExt = project.extensions.findByName("android") ?: return@afterEvaluate
        if (androidExt is com.android.build.gradle.BaseExtension) {
            try {
                val currentSdk = androidExt.compileSdkVersion?.toString()?.toIntOrNull() ?: 0
                if (currentSdk in 1..35) {
                    logger.warn("Overriding compileSdk for ${project.name} from $currentSdk to 36")
                    androidExt.setCompileSdkVersion(36)
                }
            } catch (e: Exception) {
                logger.warn("Could not override compileSdk for ${project.name}: ${e.message}")
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
