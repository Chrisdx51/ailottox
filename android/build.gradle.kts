// -----------------------------------------------------
// ⭐ PROJECT-LEVEL build.gradle.kts (Firebase Ready)
// -----------------------------------------------------

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // ⭐ Required for Firebase (Google Services Plugin)
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ⭐ Correct build directory relocation (KTS uses .set)
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

// ⭐ Required clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
