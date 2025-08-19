// Archivo: lib/services/grupo_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yachay_prompts/models/grupo_model.dart';
import 'package:yachay_prompts/models/plan_model.dart';
import 'package:yachay_prompts/models/user_model.dart';

class GrupoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Método para obtener todos los planes grupales
  Future<List<Plan>> getPlanesGrupales() async {
    try {
      final querySnapshot = await _firestore
          .collection('config')
          .doc('planes')
          .collection('planes')
          .where('tipo', isEqualTo: 'grupal')
          .get();
      return querySnapshot.docs.map((doc) => Plan.fromFirestoreMap(doc.id, doc.data())).toList();
    } catch (e) {
      throw Exception('Error al obtener los planes grupales: $e');
    }
  }

  // Escucha un grupo en tiempo real por su ID
  Stream<Grupo?> getGrupo(String grupoId) {
    return _firestore.collection('grupos').doc(grupoId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return Grupo.fromFirestore(snapshot);
    });
  }

  // Crea un nuevo grupo (apertura de vacantes)
  Future<Grupo?> createGroup({
    required String nombreGrupo,
    required Plan planRepresentante,
    required UserApp representante,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('crearGrupo');
      final result = await callable.call(<String, dynamic>{
        'nombreGrupo': nombreGrupo,
        'planRepresentante': {
          'id': planRepresentante.id,
          // Usamos el precioNumerico de tu modelo
          'precioNumerico': planRepresentante.precioNumerico,
        },
        'representanteUid': representante.uid,
        'representanteNombre': "${representante.name} ${representante.paternalLastName}",
      });
      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final doc = await _firestore.collection('grupos').doc(data['grupoId']).get();
        return Grupo.fromFirestore(doc);
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error en la llamada a la función de la nube: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  // Unirse a un grupo existente
  Future<void> unirseAGrupo({
    required String codigoInvitacion,
    required UserApp miembro,
    required Plan planSeleccionado,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('unirseAGrupo');
      await callable.call(<String, dynamic>{
        'codigoInvitacion': codigoInvitacion,
        'miembroUid': miembro.uid,
        'miembroNombre': "${miembro.name} ${miembro.paternalLastName}",
        'planSeleccionado': {
          'id': planSeleccionado.id,
          // Usamos el precioNumerico de tu modelo
          'precioNumerico': planSeleccionado.precioNumerico,
        },
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error en la llamada a la función de la nube: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  // Crea la preferencia de pago grupal
  Future<Map<String, dynamic>> crearPagoGrupal({
    required String grupoId,
    required String representanteUid,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('crearPagoGrupal');
      final result = await callable.call(<String, dynamic>{
        'grupoId': grupoId,
        'representanteUid': representanteUid,
      });
      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return data;
      }
      throw Exception('Error en la función de pago');
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error en la llamada a la función de la nube: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }
}