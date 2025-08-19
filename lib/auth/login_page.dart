// Archivo: lib/auth/login_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Necesario para FirebaseAuthException

// Importa las otras pantallas de autenticación que pueden ser navegadas desde aquí
// Asegúrate de que estos archivos existan en la misma carpeta lib/auth/
import 'package:yachay_prompts/auth/register_page.dart'; // Importación absoluta
import 'package:yachay_prompts/auth/forgot_password_screen.dart'; // Importación absoluta

// *** IMPORTA TU CLASE AuthService (ahora con ruta absoluta) ***
import 'package:yachay_prompts/auth/auth_service.dart';
// ***************************************************************

/// Pantalla de inicio de sesión para el aplicativo YachayPrompts.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controladores para los campos de texto de email y contraseña
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState(); // Llama primero al método initState de la clase padre
    // Inicializa los controladores cuando el widget se crea
    _email = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    // Desecha los controladores cuando el widget se destruye para liberar recursos
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Sesión en YachayPrompts'),
      ), // Título de la app bar
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // WIDGET PARA MOSTRAR TU LOGO DE YACHAYPROMPTS
              // Asegúrate de que el archivo de tu logo esté en la carpeta assets/images/
              // y que hayas declarado esa carpeta en pubspec.yaml.
              // CAMBIA 'assets/images/logo_yachayprompts.png' por la ruta real de tu logo.
              // Si no tienes un logo, puedes poner un Icon o Text('Logo Aquí') temporalmente.
              Image.asset(
                'assets/images/yachay_logo.png', // <-- ¡CAMBIA ESTA RUTA A TU LOGO REAL DE YACHAYPROMPTS!
                height: 300,
                width: 270,
              ),

              const SizedBox(height: 40),

              // Campo de texto para el Correo Electrónico
              TextField(
                controller: _email,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  hintText: 'Ingresa tu Email aquí',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 15.0,
                    horizontal: 10.0,
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              // Campo de texto para la Contraseña
              TextField(
                controller: _password,
                enableSuggestions: false,
                autocorrect: false,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  hintText: 'Ingresa tu Contraseña aquí',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 15.0,
                    horizontal: 10.0,
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              // Botón principal de Login
              ElevatedButton(
                onPressed: () async {
                  final email = _email.text.trim();
                  final password = _password.text;

                  // Validación simple de campos vacíos
                  if (email.isEmpty || password.isEmpty) {
                    if (!mounted) {
                      return;
                    }
                    await showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Campos Vacíos'),
                            content: const Text(
                              'Por favor, ingresa tu email y contraseña.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                    );
                    return;
                  }

                  try {
                    await AuthService().loginWithEmailAndPassword(
                      email: email,
                      password: password,
                    );
                    // Si el login es exitoso, StreamBuilder en main.dart manejará la navegación.
                  } on FirebaseAuthException catch (e) {
                    String message;
                    String title;
                    List<Widget> actions = [];

                    // Manejo de Errores de Credenciales Genéricos
                    if (e.code == 'user-not-found' ||
                        e.code == 'wrong-password' ||
                        e.code == 'invalid-credential') {
                      title = 'Error de Acceso';
                      message =
                          'Correo o contraseña incorrectos. Por favor, verifica tus credenciales.'; // Mensaje más genérico y amigable
                      actions = [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ];
                    }
                    // Manejo de error de formato de email inválido
                    else if (e.code == 'invalid-email') {
                      title = 'Email Inválido';
                      message =
                          'El formato del correo electrónico ingresado es incorrecto.';
                      actions = [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ];
                    }
                    // Manejo de otros errores de Firebase Auth no específicos
                    else {
                      title = 'Error de Login';
                      message =
                          'Ocurrió un error de autenticación: ${e.message ?? 'Error desconocido'} (Código: ${e.code})';
                      actions = [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ];
                    }

                    if (!mounted) {
                      return;
                    }
                    await showDialog(
                      // ignore: use_build_context_synchronously
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text(title),
                            content: Text(message),
                            actions: actions,
                          ),
                    );
                  } catch (e) {
                    // Manejo de otros errores inesperados
                    if (!mounted) {
                      return;
                    }
                    await showDialog(
                      // ignore: use_build_context_synchronously
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Error Inesperado'),
                            content: Text(
                              'Ocurrió un error inesperado: ${e.toString()}',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Iniciar Sesión'),
              ),
              const SizedBox(height: 10.0),
              // Botón para ir a la pantalla de Registro
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RegisterPage(),
                    ),
                  );
                },
                child: const Text('¿No registrado? Regístrate aquí'),
              ),
              // Botón para ir a la pantalla de Recuperar Contraseña
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
