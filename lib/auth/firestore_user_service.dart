// Archivo: lib/auth/firestore_user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yachay_prompts/models/user_model.dart';
import 'package:flutter/foundation.dart'; // Asegúrate que esta línea esté presente
class FirestoreUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final FirestoreUserService _instance =
      FirestoreUserService._internal();

  factory FirestoreUserService() {
    return _instance;
  }

  FirestoreUserService._internal();

  Future<void> saveUserToFirestore(UserApp user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(user.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserColor({
    required String uid,
    required String? newColorHex,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'preferredColor': newColorHex,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<UserApp?> getUserFromFirestore(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserApp.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('FirestoreUserService: Error al obtener usuario de Firestore: $e');
      }
      rethrow; // ¡CRUCIAL! Relanzar la excepción para que el AuthService la capture
    }
  }

  // ¡ELIMINADO! Si no se usa y updateUserColor hace lo mismo.
  // Future<void> updateUserPreferredColor({required String uid, String? newColorHex}) async {
  //   // Puedes eliminar este método si no lo utilizas en otras partes de tu código.
  //   // Si lo utilizas, deberías llamarlo o implementar la lógica aquí.
  // }
}