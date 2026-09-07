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

// Some published plugins (e.g. on_audio_query_android) predate AGP's namespace
// requirement and only declare a manifest `package` attribute. Backfill the
// namespace from that attribute so the build doesn't fail on plugins we can't
// edit in place (pub cache is shared/reset independent of this project).
subprojects {
    plugins.withId("com.android.library") {
        val androidExtension = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (androidExtension != null) {
            if (androidExtension.namespace == null) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val packageName = groovy.xml.XmlParser().parse(manifestFile).attribute("package") as String?
                    if (packageName != null) {
                        androidExtension.namespace = packageName
                    }
                }
            }
            // Legacy plugins that never declare compileOptions fall back to
            // AGP's own default (currently Java 11), which then clashes with
            // the JVM 17 target we pin for Kotlin below. Setting it here
            // explicitly is authoritative unless the plugin sets it itself.
            androidExtension.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            androidExtension.compileOptions.targetCompatibility = JavaVersion.VERSION_17

            // on_audio_query_android pins compileSdk 33 itself, too low for
            // the AndroidX artifacts it depends on (they require 34+).
            // Ordinary `afterEvaluate` is "too late to set compileSdk" once
            // AGP has locked a module's own explicit value, so this uses the
            // variant API's finalizeDsl — the supported hook for exactly this
            // kind of cross-plugin DSL override, timed just before AGP locks
            // the value for good.
            extensions.findByType(com.android.build.api.variant.LibraryAndroidComponentsExtension::class.java)
                ?.finalizeDsl { libraryExtension ->
                    if ((libraryExtension.compileSdk ?: 0) < 34) {
                        libraryExtension.compileSdk = 36
                    }
                }
        }
    }
}

// Legacy plugins (e.g. on_audio_query_android) don't declare a Java/Kotlin
// target of their own, and the defaults picked up from the host JDK diverge
// between javac and kotlinc, which AGP now rejects. Pin both explicitly for
// every subproject so mismatched legacy plugins can't drift from the app.
subprojects {
    plugins.withId("org.jetbrains.kotlin.android") {
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
