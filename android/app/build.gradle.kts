import java.io.FileInputStream // Importación necesaria para leer el archivo key.properties
import java.util.Properties // Importación necesaria para manejar las propiedades del keystore

plugins {
    id("com.android.application")
    id("kotlin-android")
    // El plugin de Flutter Gradle debe aplicarse después de los plugins de Android y Kotlin Gradle.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bsn.yachayprompt" // Tu namespace único
    compileSdk = 35 // Compila con la API de Android 35 (la más alta requerida por tus plugins)
    ndkVersion = "29.0.13113456" // Versión del NDK de Android

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17 // Compatibilidad con Java 17 para el código fuente
        targetCompatibility = JavaVersion.VERSION_17 // Compatibilidad con Java 17 para el código compilado
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString() // Objetivo JVM para Kotlin, compatible con Java 17
    }

    // --- Configuración de Firmas (Signing Configurations) ---
    // Este bloque define cómo se firmarán tus APKs/AABs.
    signingConfigs {
        // Configuración para el modo DEBUG (usada por `flutter run`)
        // Flutter y Android Studio ya tienen claves de depuración por defecto.
        // No necesitas añadir nada aquí a menos que quieras personalizar las claves de depuración.
        getByName("debug") {
            // Puedes añadir propiedades específicas si las necesitas, pero normalmente no es necesario.
        }

        // Configuración para la firma de LANZAMIENTO (release) para Google Play.
        // ESTO ES LO QUE NECESITAS PARA TU AAB.
        create("release") {
            // Carga las propiedades de tu archivo 'key.properties' de forma segura.
            // Este archivo DEBE estar en la carpeta 'android/' (C:\ProyctosFlutter\Yachay Prompt\yachay_prompts\android\key.properties)
            // ¡IMPORTANTE: NO subas 'key.properties' a tu repositorio de código (Git)!
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            } else {
                // Mensaje de advertencia si el archivo 'key.properties' no se encuentra.
                // Esto es CRÍTICO para las compilaciones de release.
                println("⚠️ ADVERTENCIA: key.properties no encontrado en la carpeta 'android/'. La compilación de lanzamiento FALLARÁ sin una configuración de firma adecuada.")
            }
        }
    }
    // --- Fin de Configuración de Firmas ---

    defaultConfig {
        // ID de la aplicación, debe ser único para Google Play.
        applicationId = "com.bsn.yachayprompt"
        // Versión mínima de SDK de Android que soporta tu aplicación (API 23 para Firebase)
        minSdk = 23
        // Versión de SDK de Android a la que está dirigida tu aplicación (viene de Flutter)
        targetSdk = flutter.targetSdkVersion
        // Código de versión de la aplicación (para actualizaciones)
        versionCode = flutter.versionCode
        // Nombre de la versión de la aplicación (para mostrar al usuario)
        versionName = flutter.versionName
    }

    buildTypes {
        // --- Configuración para compilaciones de LANZAMIENTO (RELEASE) ---
        release {
            // Asigna la configuración de firma 'release' que definimos arriba.
            // ESTA ES LA QUE SE USA PARA GENERAR TU AAB PARA GOOGLE PLAY.
            signingConfig = signingConfigs.getByName("release")
            // Opcional: Estas líneas reducen el tamaño del AAB/APK final.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }

        // --- Configuración para compilaciones de DEPURACIÓN (DEBUG) ---
        debug {
            // Asigna la configuración de firma 'debug' por defecto.
            // ESTA ES LA QUE SE USA CUANDO EJECUTAS `flutter run`.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.." // Ruta al directorio raíz de tu proyecto Flutter
}

// ESTE ES EL BLOQUE DE DEPENDENCIAS. ES CRUCIAL PARA INCLUIR LIBRERÍAS EXTERNAS.
dependencies {
    // Dependencias por defecto de Kotlin (asegúrate de tener esta o una versión similar)
    implementation(platform("org.jetbrains.kotlin:kotlin-bom:1.8.0"))

    // Si estás usando Jetpack Compose, mantén esta línea. Si no, puedes comentarla.
    // implementation(platform("androidx.compose:compose-bom:2023.08.00"))

    // AÑADE ESTA LÍNEA ESPECÍFICAMENTE para Material Design 3.
    // Esta librería proporciona el tema Theme.Material3.DayNight.NoActionBar.
    // Usa la versión más reciente y estable. 1.12.0 es una buena opción.
    implementation("com.google.android.material:material:1.12.0")

    // Asegúrate de que tus dependencias de Firebase también estén aquí.
    // Si las tenías en otro lugar, muévelas a este bloque 'dependencies'.
    // Ejemplos de dependencias comunes de Firebase:
    // implementation("com.google.firebase:firebase-auth-ktx")
    // implementation("com.google.firebase:firebase-firestore-ktx")
    // implementation("com.google.firebase:firebase-storage-ktx")
    // ... y cualquier otra dependencia que necesiten tus plugins de Flutter
}