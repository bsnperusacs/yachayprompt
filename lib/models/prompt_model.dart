import 'package:cloud_firestore/cloud_firestore.dart';

class PromptGenerado {
  final String id;
  final String userId;
  final String nivelEducativo;
  final String asignatura;
  final String objetivoContenido;
  final String idiomaPrompt;
  final String? varianteQuechua;
  final String textoPromptFinal;
  final String? tituloPersonalizado;
  final DateTime fechaCreacion;
  final DateTime fechaModificacion;
  final String? idPlantillaOrigen;
  final Map<String, dynamic>? parametrosIaUsados;
  final String? respuestaIaRecibida;
  final bool favorito;
  final List<String>? tagsPersonales;
  final String? carpetaOrganizacion;

  PromptGenerado({
    this.id = '',
    required this.userId,
    required this.nivelEducativo,
    required this.asignatura,
    required this.objetivoContenido,
    required this.idiomaPrompt,
    this.varianteQuechua,
    required this.textoPromptFinal,
    this.tituloPersonalizado,
    required this.fechaCreacion,
    required this.fechaModificacion,
    this.idPlantillaOrigen,
    this.parametrosIaUsados,
    this.respuestaIaRecibida,
    this.favorito = false,
    this.tagsPersonales,
    this.carpetaOrganizacion,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'nivelEducativo': nivelEducativo,
      'asignatura': asignatura,
      'objetivoContenido': objetivoContenido,
      'idiomaPrompt': idiomaPrompt,
      'varianteQuechua': varianteQuechua,
      'textoPromptFinal': textoPromptFinal,
      'tituloPersonalizado': tituloPersonalizado,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaModificacion': Timestamp.fromDate(fechaModificacion),
      'idPlantillaOrigen': idPlantillaOrigen,
      'parametrosIaUsados': parametrosIaUsados,
      'respuestaIaRecibida': respuestaIaRecibida,
      'favorito': favorito,
      'tagsPersonales': tagsPersonales,
      'carpetaOrganizacion': carpetaOrganizacion,
    };
  }

  factory PromptGenerado.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PromptGenerado(
      id: doc.id,
      userId: data['userId'] ?? '',
      nivelEducativo: data['nivelEducativo'] ?? 'N/A',
      asignatura: data['asignatura'] ?? 'N/A',
      objetivoContenido: data['objetivoContenido'] ?? '',
      idiomaPrompt: data['idiomaPrompt'] ?? '',
      varianteQuechua: data['varianteQuechua'],
      textoPromptFinal: data['textoPromptFinal'] ?? '',
      tituloPersonalizado: data['tituloPersonalizado'],
      fechaCreacion:
          (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaModificacion:
          (data['fechaModificacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      idPlantillaOrigen: data['idPlantillaOrigen'],
      parametrosIaUsados: data['parametrosIaUsados'],
      respuestaIaRecibida: data['respuestaIaRecibida'],
      favorito: data['favorito'] ?? false,
      tagsPersonales: data['tagsPersonales'] != null
          ? List<String>.from(data['tagsPersonales'])
          : null,
      carpetaOrganizacion: data['carpetaOrganizacion'],
    );
  }
}
