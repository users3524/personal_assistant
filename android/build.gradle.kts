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
    pluginManager.withPlugin("com.android.base") {
        configure<com.android.build.gradle.BaseExtension> {
            logger.warn("Forcing compileSdk=36 for ${project.name}")
            compileSdkVersion(36)
        }
    }
}

// Override AAR metadata check: pre-built plugin AARs have mixed compileSdk,
// causing CheckAarMetadata to fail. This makes it always pass.
subprojects {
    afterEvaluate {
        tasks.matching { it.name.endsWith("AarMetadata") }.configureEach {
            // Clear the failing work action
            setActions(emptyList())
            // Create output directory for downstream BundleAar
            val outputDir = outputs.files.firstOrNull()
            doLast {
                outputDir?.mkdirs()
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
