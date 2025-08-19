// Archivo: lib/models/grupo_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa un miembro dentro de un grupo, como se guarda en Firestore.
class Miembro {
  final String uid;
  final String nombre;
  final String rol;
  final String planId;
  final double precioPlan;
  final DateTime fechaUnion;

  Miembro({
    required this.uid,
    required this.nombre,
    required this.rol,
    required this.planId,
    required this.precioPlan,
    required this.fechaUnion,
  });

  factory Miembro.fromMap(Map<String, dynamic> data) {
    return Miembro(
      uid: data['uid'] as String,
      nombre: data['nombre'] as String,
      rol: data['rol'] as String,
      planId: data['planId'] as String,
      // Manejar 'num' para asegurar el tipo 'double'
      precioPlan: (data['precioPlan'] as num).toDouble(),
      fechaUnion: (data['fechaUnion'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': nombre,
      'rol': rol,
      'planId': planId,
      'precioPlan': precioPlan,
      'fechaUnion': Timestamp.fromDate(fechaUnion),
    };
  }
}

/// Representa un grupo creado dentro del sistema.
class Grupo {
  final String grupoId;
  final String nombreGrupo;
  final String codigoInvitacion;
  final String estado;
  final String representanteUid;
  final List<Miembro> miembros;

  Grupo({
    required this.grupoId,
    required this.nombreGrupo,
    required this.codigoInvitacion,
    required this.estado,
    required this.representanteUid,
    required this.miembros,
  });

  factory Grupo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    var miembrosList = data['miembros'] as List<dynamic>;
    List<Miembro> miembros = miembrosList.map((m) => Miembro.fromMap(m)).toList();

    return Grupo(
      grupoId: doc.id,
      nombreGrupo: data['nombreGrupo'] as String,
      codigoInvitacion: data['codigoInvitacion'] as String,
      estado: data['estado'] as String,
      representanteUid: data['representanteUid'] as String,
      miembros: miembros,
    );
  }
}