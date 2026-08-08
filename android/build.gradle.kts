allprojects {
    repositories {
        google()
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
    project.evaluationDependsOn(":app")
}

// Silence Java compile warnings that originate inside third-party plugin
// sources (e.g. cloud_firestore's [unchecked] cast, firebase_auth's
// [deprecation] updateEmail/fetchSignInMethodsForEmail). These live in the
// read-only pub-cache and can't be fixed here; suppressing keeps the build
// output clean. Does not affect errors.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.isDeprecation = false
        options.compilerArgs.addAll(listOf("-Xlint:none", "-nowarn"))
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
