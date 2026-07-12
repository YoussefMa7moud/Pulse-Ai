buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
    }
}

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
    // Fix for older plugins missing namespace (like isar_flutter_libs) and lStar errors
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                // Force compileSdkVersion to 36 to fix androidx.health.connect requirement
                try {
                    androidExt.javaClass.getMethod("compileSdkVersion", Int::class.java).invoke(androidExt, 36)
                } catch (e: Exception) {
                    try {
                        androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.java).invoke(androidExt, 36)
                    } catch (e2: Exception) {}
                }

                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val packageName = Regex("package=\"([^\"]*)\"").find(manifestFile.readText())?.groupValues?.get(1)
                    if (packageName != null) {
                        try {
                            val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                            val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                            if (getNamespace.invoke(androidExt) == null) {
                                setNamespace.invoke(androidExt, packageName)
                            }
                        } catch (e: Exception) {}
                    }
                }
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
