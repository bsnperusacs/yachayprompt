// Archivo: lib/auth/verify_email_view.dart

import 'dart:async'; // Para el Timer
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yachay_prompts/auth/auth_service.dart'; // Tu AuthService
import 'package:yachay_prompts/auth/login_page.dart'; // Para navegar de vuelta al login
import 'package:yachay_prompts/home/home_page.dart';

class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key});

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  // StreamSubscription para escuchar cambios en el usuario (si el email se verifica)
  late final StreamSubscription<User?> _userSubscription;
  bool _isSendingVerification = false;
  Timer? _timer; // Para el temporizador de reenvío

  @override
  void initState() {
    super.initState();
    // Inmediatamente al cargar la página, enviar email de verificación
    _sendEmailVerification();

    // Escuchar cambios en el estado de autenticación (especialmente si el emailVerified cambia)
    _userSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && user.emailVerified) {
        // Si el email ya está verificado, navegar a la Home Screen
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (Route<dynamic> route) =>
                false, // Elimina todas las rutas anteriores
          );
        }
      }
    });

    // Configurar un temporizador para chequear el estado de verificación cada pocos segundos
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final user = AuthService().currentUser; // Obtener el usuario actual
      if (user != null) {
        await user.reload(); // Recargar el estado del usuario desde Firebase
        if (user.emailVerified) {
          timer.cancel(); // Detener el temporizador
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false,
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _userSubscription.cancel(); // Cancelar la suscripción al stream
    _timer?.cancel(); // Cancelar el temporizador
    super.dispose();
  }

  // Función para enviar el correo de verificación
  Future<void> _sendEmailVerification() async {
    if (mounted) {
      setState(() {
        _isSendingVerification = true;
      });
    }
    try {
      await AuthService().sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email de verificación enviado. Revisa tu bandeja de entrada.',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar email: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ocurrió un error inesperado al enviar email: ${e.toString()}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingVerification = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu correo electrónico')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Hemos enviado un enlace de verificación a tu correo electrónico. Por favor, revísalo para verificar tu cuenta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSendingVerification ? null : _sendEmailVerification,
              child:
                  _isSendingVerification
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Text('Reenviar email de verificación'),
            ),
            TextButton(
              onPressed: () async {
                await AuthService().signOut(); // Cierra sesión
                if (mounted) {
                  // Navega a la página de login y elimina todas las rutas anteriores
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
              child: const Text('Volver a Iniciar Sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
