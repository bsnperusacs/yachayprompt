// lib/models/template_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PlantillaPrompt {
  final String id;
  final String tituloPlantilla;
  final String? descripcionPlantilla;
  final String textoPlantillaBase;
  final String idiomaPlantilla;
  final String? idNivelSugerido;
  final String? idAsignaturaSugerida;
  final List<String>? tags;
  final String? idAutorPlantilla;
  final String? categoria; // NUEVO

  PlantillaPrompt({
    required this.id,
    required this.tituloPlantilla,
    this.descripcionPlantilla,
    required this.textoPlantillaBase,
    required this.idiomaPlantilla,
    this.idNivelSugerido,
    this.idAsignaturaSugerida,
    this.tags,
    this.idAutorPlantilla,
    this.categoria, // NUEVO
    });

  factory PlantillaPrompt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PlantillaPrompt(
      id: doc.id,
      tituloPlantilla: data['tituloPlantilla']
          as String, // Asegúrate que 'tituloPlantilla' siempre exista en Firestore
      descripcionPlantilla: data['descripcionPlantilla'] as String?,
      textoPlantillaBase: data['textoPlantillaBase']
          as String, // Asegúrate que 'textoPlantillaBase' siempre exista
      idiomaPlantilla: data['idiomaPlantilla']
          as String, // Asegúrate que 'idiomaPlantilla' siempre exista
      idNivelSugerido: data['idNivelSugerido'] as String?,
      idAsignaturaSugerida: data['idAsignaturaSugerida'] as String?,
      tags: (data['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      idAutorPlantilla: data['idAutorPlantilla'] as String?,
      categoria: data['categoria'] as String?, // ← NUEVO
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tituloPlantilla': tituloPlantilla,
      'descripcionPlantilla': descripcionPlantilla,
      'textoPlantillaBase': textoPlantillaBase,
      'idiomaPlantilla': idiomaPlantilla,
      'idNivelSugerido': idNivelSugerido,
      'idAsignaturaSugerida': idAsignaturaSugerida,
      'tags': tags,
      'idAutorPlantilla': idAutorPlantilla,
      'categoria': categoria, // ← NUEVO
    };
  }
}
