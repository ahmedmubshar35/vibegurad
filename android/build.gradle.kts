allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // Force dependency resolution to fix OkHttp/OkIO conflicts
    configurations.all {
        resolutionStrategy {
            force("com.squareup.okhttp3:okhttp:4.12.0")
            force("com.squareup.okio:okio:3.6.0")
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
