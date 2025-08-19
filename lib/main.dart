// Archivo: lib/main.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'package:yachay_prompts/services/local_database_service.dart';
import 'package:yachay_prompts/auth/login_page.dart';
import 'package:yachay_prompts/auth/verify_email_view.dart';
import 'package:yachay_prompts/home/home_page.dart';
import 'package:yachay_prompts/auth/auth_service.dart';
import 'package:yachay_prompts/models/user_model.dart';
import 'package:yachay_prompts/services/plan_service.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (kDebugMode) {
      print("Error inicializando Firebase: ${e.message}");
    }
  } catch (e) {
    if (kDebugMode) {
      print(
        "Ocurrió un error inesperado durante la inicialización de Firebase: $e",
      );
    }
  }

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );

  await PlanService().loadAvailablePlans();

  try {
    await LocalDatabaseService().database;
    if (kDebugMode) {
      print("SQLite Database initialized.");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error inicializando SQLite Database: $e");
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  ThemeData _buildThemeData(UserApp? userApp) {
    Color currentSeedColor = const Color(0xFF673AB7); // Tu morado por defecto

    if (userApp != null && userApp.preferredColor != null) {
      try {
        currentSeedColor = _colorFromHex(userApp.preferredColor!);
      } catch (e) {
        if (kDebugMode) {
          print('Error al parsear color preferido del usuario: ${userApp.preferredColor} - $e');
        }
      }
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: currentSeedColor,
        brightness: Brightness.light,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: currentSeedColor,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: currentSeedColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          elevation: 4,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: currentSeedColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          elevation: 4,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: currentSeedColor,
          side: BorderSide(color: currentSeedColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      // ¡CORREGIDO! De CardThemeData a CardTheme
      cardTheme: CardThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        surfaceTintColor: Colors.white,
        color: Colors.white,
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: currentSeedColor, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600),
        hintStyle: TextStyle(color: Colors.grey.shade400),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),

      dividerTheme: DividerThemeData(
        space: 32,
        thickness: 1,
        color: Colors.grey.shade300,
        indent: 16,
        endIndent: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserApp?>(
      stream: AuthService().user,
      builder: (context, snapshot) {
        final UserApp? currentUserApp = snapshot.data;
        final ThemeData lightTheme = _buildThemeData(currentUserApp);
        final ThemeData darkTheme = _buildThemeData(currentUserApp).copyWith(brightness: Brightness.dark);

        final Key appKey = ValueKey(currentUserApp?.preferredColor ?? 'default');

        Widget homeScreenWidget;
        if (snapshot.connectionState == ConnectionState.waiting) {
          homeScreenWidget = const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) { // ¡AÑADIDO! Manejo de errores para la carga inicial
          if (kDebugMode) { // Solo imprime en modo debug
            print("MyApp StreamBuilder Error: ${snapshot.error}");
          }
          homeScreenWidget = Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar el usuario: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      AuthService().reloadUserFromFirestore(); // Intentar recargar
                    },
                    child: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      AuthService().signOut(); // Ir a la pantalla de login
                    },
                    child: const Text('Ir a la pantalla de inicio de sesión'),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasData) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            if (user.emailVerified) {
              homeScreenWidget = const HomeScreen();
            } else {
              homeScreenWidget = const VerifyEmailView();
            }
          } else {
            homeScreenWidget = const LoginPage();
          }
        } else {
          homeScreenWidget = const LoginPage();
        }

        return MaterialApp(
          key: appKey,
          title: 'YachayPrompts',
          debugShowCheckedModeBanner: false,

          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.system,

          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'ES'),
            Locale('en', 'US'),
          ],
          locale: const Locale('es', 'ES'),

          home: homeScreenWidget,
        );
      },
    );
  }
}