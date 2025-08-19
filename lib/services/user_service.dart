// Archivo: lib/services/user_service.dart
import 'package:yachay_prompts/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserApp> getRepresentante() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      throw Exception('Datos de usuario no encontrados');
    }
    return UserApp.fromFirestore(doc);
  }
}