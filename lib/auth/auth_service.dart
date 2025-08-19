import 'package:firebase_auth/firebase_auth.dart';
import 'package:yachay_prompts/models/user_model.dart';
import 'package:yachay_prompts/auth/firestore_user_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // <-- ¡Importado nuevo!

/// Servicio para centralizar la lógica de autenticación con Firebase Auth
/// y guardar datos del usuario en Firestore.
/// Usa el patrón Singleton para asegurar una única instancia.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreUserService _firestoreUserService = FirestoreUserService();

  static final AuthService _instance = AuthService._internal();

  final BehaviorSubject<UserApp?> _userAppSubject = BehaviorSubject<UserApp?>();

  // >>> INICIO DE CAMBIO SUGERIDO (renombrar userStream a user) <<<
  Stream<UserApp?> get user => _userAppSubject.stream; // Renombrado de userStream
  // >>> FIN DE CAMBIO SUGERIDO <<<

  factory AuthService() {
    return _instance;
  }

  AuthService._internal() {
    if (kDebugMode) {
      print("AuthService: Constructor _internal iniciado. Escuchando authStateChanges.");
    }
    _auth.authStateChanges().listen((user) async {
      if (kDebugMode) {
        print("AuthService: authStateChanges detectó usuario: ${user?.uid}");
      }
      if (user != null) {
        await _loadAndEmitUserApp(user.uid);
      } else {
        _userAppSubject.add(null);
        if (kDebugMode) {
          print("AuthService: No hay usuario autenticado. Emitiendo null.");
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print("AuthService: Error en authStateChanges listener: $error");
      }
      _userAppSubject.addError(error);
    });
  }

  // >>> INICIO DE CAMBIO SUGERIDO (añadir getter currentUserApp) <<<
  // Getter para obtener la instancia actual de UserApp de forma síncrona
  UserApp? get currentUserApp => _userAppSubject.value; 
  // >>> FIN DE CAMBIO SUGERIDO <<<

  // >>> INICIO: NUEVO MÉTODO PARA INICIALIZAR APP CHECK <<<
  Future<void> initializeFirebaseAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
      );
      if (kDebugMode) {
        print("AuthService: App Check activado correctamente.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("AuthService: Error al activar App Check: $e");
      }
      // Considera si quieres lanzar una excepción o simplemente registrar el error
      // La app seguirá funcionando, pero sin la protección de App Check.
    }
  }
  // >>> FIN: NUEVO MÉTODO PARA INICIALIZAR APP CHECK <<<

  Future<void> _loadAndEmitUserApp(String uid) async {
    if (kDebugMode) {
      print("AuthService: Intentando cargar UserApp para UID: $uid");
    }
    try {
      final userApp = await _firestoreUserService.getUserFromFirestore(uid);
      _userAppSubject.add(userApp);
      if (kDebugMode) {
        print("AuthService: UserApp cargado y emitido: ${userApp?.email}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("AuthService: Error al cargar y emitir UserApp desde Firestore: $e");
      }
      _userAppSubject.addError(e);
    }
  }

  Future<void> reloadUserFromFirestore() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _loadAndEmitUserApp(user.uid);
    } else {
      _userAppSubject.add(null);
    }
  }

  Future<UserCredential> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        await _loadAndEmitUserApp(userCredential.user!.uid);
      }
      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<UserCredential> registerWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    String role = 'docente',
  }) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        final newUser = UserApp(
          uid: userCredential.user!.uid,
          name: name,
          email: email,
          role: role,
          preferredColor: '#FF673AB7', // Color morado por defecto al registrar
          // Los campos del plan y créditos son asignados en register_page.dart al hacer el .set() inicial
          // en Firestore, no aquí en la creación del UserApp modelo para saveUserToFirestore.
          // Aquí solo se inicializan los campos básicos que Auth necesita.
          // Si saveUserToFirestore() solo guarda estos pocos campos,
          // entonces register_page.dart debería hacer el update con los campos del plan.
          // Si saveUserToFirestore() ya usa toFirestore() del modelo,
          // entonces user_model.dart debe tener todos los campos (plan, creditos, etc)
          // y serán guardados por register_page.dart en su .set(newUser.toFirestore()).
        );
        // Si saveUserToFirestore solo guarda los campos básicos (uid, name, email, role, color)
        // entonces la asignación de plan y créditos se hace en register_page.dart
        // directamente en el .set() inicial.
        await _firestoreUserService.saveUserToFirestore(newUser);
        
        // Después de que register_page.dart guarde el documento completo,
        // _loadAndEmitUserApp cargará el UserApp con plan y créditos.
        await _loadAndEmitUserApp(userCredential.user!.uid); 
      }
      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _userAppSubject.add(null);
  }

  Future<void> resetPassword({required String email}) async {
    return await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await user.sendEmailVerification();
    } else {
      throw Exception('No hay usuario logeado para enviar verificación.');
    }
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  void dispose() {
    _userAppSubject.close();
  }
}