buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.3.15") // ⬅️ Firebase plugin
    }
}

plugins {
    // niks hier van google-services
}

// 🔧 NDK-versie instellen die door app module gebruikt wordt:
ext.set("android.ndkVersion", "27.0.12077973")

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Activeer plugin na evaluatie
apply(plugin = "com.google.gms.google-services")
