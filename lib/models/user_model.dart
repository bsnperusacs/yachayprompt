// Archivo: lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Función de utilidad para convertir HEX a Color
Color colorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF$hexColor"; // Añadir FF para opacidad si no está
  }
  return Color(int.parse(hexColor, radix: 16));
}

// Función de utilidad para convertir Color a HEX
String colorToHex(Color color) {
  // Asegurarse de que incluye el canal alfa (FF)
  // CORRECCIÓN: Usar color.value.toRadixString(16)
return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';}

class UserApp {
  final String uid;
  final String name;
  final String email;
  final String role; // 'docente' o 'admin'
  final String? preferredColor; // Declaración única de preferredColor
  final String? profilePictureUrl;
  final String? planContratado; // ID del plan actual del usuario (ej. 'demo', 'basico', 'creativo', 'espacial_grupal_texto')
  final int? diasRestantes;
  final int? promptsContratados; // Prompts del plan contratado (total mensual)
  final int? promptsRestantes; // Prompts que le quedan al usuario del plan mensual
  final int? promptsPaqueteDocenteRestantes;
  final int? promptsPaqueteCreativoRestantes;
  final int? imagenesRestantes;
  final int? anosDeServicio;
  final String? especialidadPrincipal;
  final String? especialidadSecundaria;
  final List<String>? otrasEspecialidades;
  final String? numeroCelular;
  final String? ciudadResidencia;
  final String? nacionalidad;
  final String? cargo;
  final String? dni;
  final String? paternalLastName;
  final String? maternalLastName;
  final String? documentType;
  final String? fullAddress;
  final String? department;
  final String? province;
  final bool isActive;
  // --- NUEVOS CAMPOS PARA GRUPOS Y DESCUENTOS ---
  final String? idGrupoActivo; // ID del grupo al que el usuario pertenece actualmente
  final String? rolEnGrupo; // 'representante', 'miembro' (para el grupo activo)

  // Campos específicos para el REPRESENTANTE de grupo
  final List<String>? gruposRepresentados; // Lista de IDs de grupos que este usuario representa
  final int cantidadGruposCreados; // Contador de grupos que este usuario ha creado (para descuento)
  final int totalSlotsCompradosEnTodosMisGrupos; // Suma de slots de todos sus grupos creados (para descuento)

  // Campos específicos para MIEMBROS con plan grupal pendiente de activar
  final String? grupoIdPendiente; // ID del grupo si hay una afiliación pendiente
  final String? planGrupalTipoPendiente; // Tipo de plan grupal pendiente ('espacial_grupal_texto', 'espacial_grupal_texto_imagen')
  final DateTime? fechaFinPlanIndividualActual; // Fecha de fin del plan individual si está activo y en espera de grupal

  UserApp({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.preferredColor,
    this.profilePictureUrl,
    this.planContratado,
    this.diasRestantes,
    this.promptsContratados,
    this.promptsRestantes,
    this.promptsPaqueteDocenteRestantes,
    this.promptsPaqueteCreativoRestantes,
    this.imagenesRestantes,
    this.anosDeServicio,
    this.especialidadPrincipal,
    this.especialidadSecundaria,
    this.otrasEspecialidades,
    this.numeroCelular,
    this.ciudadResidencia,
    this.nacionalidad,
    this.cargo,
    this.dni,
    this.paternalLastName,
    this.maternalLastName,
    this.documentType,
    this.fullAddress,
    this.department,
    this.province,
    this.isActive = true,
    // --- NUEVOS CAMPOS EN EL CONSTRUCTOR ---
    this.idGrupoActivo,
    this.rolEnGrupo,
    this.gruposRepresentados,
    this.cantidadGruposCreados = 0,
    this.totalSlotsCompradosEnTodosMisGrupos = 0,
    this.grupoIdPendiente,
    this.planGrupalTipoPendiente,
    this.fechaFinPlanIndividualActual,
  });

  factory UserApp.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      if (kDebugMode) {
        print("UserApp.fromFirestore: Document data is null for uid: ${doc.id}");
      }
      return UserApp(
        uid: doc.id,
        name: 'Usuario Desconocido',
        email: 'desconocido@example.com',
        role: 'guest',
      );
    }

    return UserApp(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'docente',
      preferredColor: data['preferredColor'] as String?,
      profilePictureUrl: data['profilePictureUrl'] as String?,
      planContratado: data['planContratado'] as String?,
      diasRestantes: (data['diasRestantes'] as num?)?.toInt(),
      promptsContratados: (data['promptsContratados'] as num?)?.toInt(),
      promptsRestantes: (data['promptsRestantes'] as num?)?.toInt(),
      promptsPaqueteDocenteRestantes: (data['promptsPaqueteDocenteRestantes'] as num?)?.toInt(),
      promptsPaqueteCreativoRestantes: (data['promptsPaqueteCreativoRestantes'] as num?)?.toInt(),
      imagenesRestantes: (data['imagenesRestantes'] as num?)?.toInt(),
      anosDeServicio: (data['anosDeServicio'] as num?)?.toInt(),
      especialidadPrincipal: data['especialidadPrincipal'] as String?,
      especialidadSecundaria: data['especialidadSecundaria'] as String?,
      otrasEspecialidades: (data['otrasEspecialidades'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      numeroCelular: data['numeroCelular'] as String?,
      ciudadResidencia: data['ciudadResidencia'] as String?,
      nacionalidad: data['nacionalidad'] as String?,
      cargo: data['cargo'] as String?,
      dni: data['dni'] as String?,
      paternalLastName: data['paternalLastName'] as String?,
      maternalLastName: data['maternalLastName'] as String?,
      documentType: data['documentType'] as String?,
      fullAddress: data['fullAddress'] as String?,
      department: data['department'] as String?,
      province: data['province'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      // --- LECTURA DE NUEVOS CAMPOS DESDE FIRESTORE ---
      idGrupoActivo: data['idGrupoActivo'] as String?,
      rolEnGrupo: data['rolEnGrupo'] as String?,
      gruposRepresentados: (data['gruposRepresentados'] as List<dynamic>?)?.cast<String>(),
      cantidadGruposCreados: (data['cantidadGruposCreados'] as num?)?.toInt() ?? 0,
      totalSlotsCompradosEnTodosMisGrupos: (data['totalSlotsCompradosEnTodosMisGrupos'] as num?)?.toInt() ?? 0,
      grupoIdPendiente: data['grupoIdPendiente'] as String?,
      planGrupalTipoPendiente: data['planGrupalTipoPendiente'] as String?,
      fechaFinPlanIndividualActual: (data['fechaFinPlanIndividualActual'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'preferredColor': preferredColor,
      'profilePictureUrl': profilePictureUrl,
      'planContratado': planContratado,
      'diasRestantes': diasRestantes,
      'promptsContratados': promptsContratados,
      'promptsRestantes': promptsRestantes,
      'promptsPaqueteDocenteRestantes': promptsPaqueteDocenteRestantes,
      'promptsPaqueteCreativoRestantes': promptsPaqueteCreativoRestantes,
      'imagenesRestantes': imagenesRestantes,
      'anosDeServicio': anosDeServicio,
      'especialidadPrincipal': especialidadPrincipal,
      'especialidadSecundaria': especialidadSecundaria,
      'otrasEspecialidades': otrasEspecialidades,
      'numeroCelular': numeroCelular,
      'ciudadResidencia': ciudadResidencia,
      'nacionalidad': nacionalidad,
      'cargo': cargo,
      'dni': dni,
      'paternalLastName': paternalLastName,
      'maternalLastName': maternalLastName,
      'documentType': documentType,
      'fullAddress': fullAddress,
      'department': department,
      'province': province,
      'isActive': isActive,
      // --- ESCRITURA DE NUEVOS CAMPOS A FIRESTORE ---
      'idGrupoActivo': idGrupoActivo,
      'rolEnGrupo': rolEnGrupo,
      'gruposRepresentados': gruposRepresentados,
      'cantidadGruposCreados': cantidadGruposCreados,
      'totalSlotsCompradosEnTodosMisGrupos': totalSlotsCompradosEnTodosMisGrupos,
      'grupoIdPendiente': grupoIdPendiente,
      'planGrupalTipoPendiente': planGrupalTipoPendiente,
      'fechaFinPlanIndividualActual': fechaFinPlanIndividualActual != null ? Timestamp.fromDate(fechaFinPlanIndividualActual!) : null,
    };
  }

  UserApp copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    String? preferredColor,
    String? profilePictureUrl,
    String? planContratado,
    int? diasRestantes,
    int? promptsContratados,
    int? promptsRestantes,
    int? promptsPaqueteDocenteRestantes,
    int? promptsPaqueteCreativoRestantes,
    int? imagenesRestantes,
    int? anosDeServicio,
    String? especialidadPrincipal,
    String? especialidadSecundaria,
    List<String>? otrasEspecialidades,
    String? numeroCelular,
    String? ciudadResidencia,
    String? nacionalidad,
    String? cargo,
    String? dni,
    String? paternalLastName,
    String? maternalLastName,
    String? documentType,
    String? fullAddress,
    String? department,
    String? province,
    bool? isActive,
    // --- NUEVOS CAMPOS EN copyWith ---
    String? idGrupoActivo,
    String? rolEnGrupo,
    List<String>? gruposRepresentados,
    int? cantidadGruposCreados,
    int? totalSlotsCompradosEnTodosMisGrupos,
    String? grupoIdPendiente,
    String? planGrupalTipoPendiente,
    DateTime? fechaFinPlanIndividualActual,
  }) {
    return UserApp(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      preferredColor: preferredColor ?? this.preferredColor,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      planContratado: planContratado ?? this.planContratado,
      diasRestantes: diasRestantes ?? this.diasRestantes,
      promptsContratados: promptsContratados ?? this.promptsContratados,
      promptsRestantes: promptsRestantes ?? this.promptsRestantes,
      promptsPaqueteDocenteRestantes: promptsPaqueteDocenteRestantes ?? this.promptsPaqueteDocenteRestantes,
      promptsPaqueteCreativoRestantes: promptsPaqueteCreativoRestantes ?? this.promptsPaqueteCreativoRestantes,
      imagenesRestantes: imagenesRestantes ?? this.imagenesRestantes,
      anosDeServicio: anosDeServicio ?? this.anosDeServicio,
      especialidadPrincipal: especialidadPrincipal ?? this.especialidadPrincipal,
      especialidadSecundaria: especialidadSecundaria ?? this.especialidadSecundaria,
      otrasEspecialidades: otrasEspecialidades ?? this.otrasEspecialidades,
      numeroCelular: numeroCelular ?? this.numeroCelular,
      ciudadResidencia: ciudadResidencia ?? this.ciudadResidencia,
      nacionalidad: nacionalidad ?? this.nacionalidad,
      cargo: cargo ?? this.cargo,
      dni: dni ?? this.dni,
      paternalLastName: paternalLastName ?? this.paternalLastName,
      maternalLastName: maternalLastName ?? this.maternalLastName,
      documentType: documentType ?? this.documentType,
      fullAddress: fullAddress ?? this.fullAddress,
      department: department ?? this.department,
      province: province ?? this.province,
      isActive: isActive ?? this.isActive,
      // --- COPIA DE NUEVOS CAMPOS ---
      idGrupoActivo: idGrupoActivo ?? this.idGrupoActivo,
      rolEnGrupo: rolEnGrupo ?? this.rolEnGrupo,
      gruposRepresentados: gruposRepresentados ?? this.gruposRepresentados,
      cantidadGruposCreados: cantidadGruposCreados ?? this.cantidadGruposCreados,
      totalSlotsCompradosEnTodosMisGrupos: totalSlotsCompradosEnTodosMisGrupos ?? this.totalSlotsCompradosEnTodosMisGrupos,
      grupoIdPendiente: grupoIdPendiente ?? this.grupoIdPendiente,
      planGrupalTipoPendiente: planGrupalTipoPendiente ?? this.planGrupalTipoPendiente,
      fechaFinPlanIndividualActual: fechaFinPlanIndividualActual ?? this.fechaFinPlanIndividualActual,
    );
  }
}