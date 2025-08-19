// Archivo: lib/models/plan_model.dart

class Plan {
  final String id; // ID único del plan (ej. 'demo', 'basico', 'creativo', 'espacial_grupal_texto')
  final String nombre; // Nombre legible (ej. "Versión de Prueba", "Plan Docente")
  final String descripcion; // Descripción corta
  final double precioNumerico; // Precio numérico real para cálculos (ej. 24.90, 0.0)
  final int promptsTotal; // Cantidad máxima de prompts que incluye el plan (por miembro)
  final int imagenesMax; // Cantidad máxima de imágenes (por miembro, se consume de promptsTotal)
  final List<String> caracteristicas; // Lista de beneficios del plan
  final bool esDePrueba; // True si es el plan de prueba
  final int duracionDias; // Duración del plan en días (ej. 30 para 1 mes)
  final String? tipoPrompt; // "texto" o "texto_imagen" para paquetes o tipos de planes

  static List<Plan>? planesDisponibles;

  const Plan({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precioNumerico,
    required this.promptsTotal,
    required this.imagenesMax,
    required this.caracteristicas,
    this.esDePrueba = false,
    required this.duracionDias,
    this.tipoPrompt,
  });

  // --- PROPIEDAD GETTER para precioDisplay ---
  String get precioDisplay {
    if (precioNumerico <= 0) {
      return 'Gratis'; // Solo gratis si realmente el precio es 0
    }
    return 'S/. ${precioNumerico.toStringAsFixed(2)}'; // Ej: "S/. 1.99"
  }

  // --- Factory constructor para crear un objeto Plan desde un Map de Firestore ---
  factory Plan.fromFirestoreMap(String id, Map<String, dynamic> data) {
    final double parsedPrecioNumerico = (data['precio_regular'] as num? ?? 0.0).toDouble();

    return Plan(
      id: id,
      nombre: data['nombre'] as String,
      descripcion: data['descripcion'] as String? ?? '',
      precioNumerico: parsedPrecioNumerico,
      promptsTotal: (data['prompts_total'] as num? ?? data['cantidad_prompts'] as num? ?? 0).toInt(),
      imagenesMax: (data['imagenes_max'] as num? ?? 0).toInt(),
      caracteristicas: (data['caracteristicas'] is List)
          ? (data['caracteristicas'] as List<dynamic>).map((e) => e.toString()).toList()
          : [],
      esDePrueba: data['esDePrueba'] as bool? ?? false,
      duracionDias: (data['duracion_dias'] as num? ?? 0).toInt(),
      tipoPrompt: data['tipo_prompt'] as String?,
    );
  }

  // Método para convertir a Map para Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'precio_regular': precioNumerico,
      'prompts_total': promptsTotal,
      'imagenes_max': imagenesMax,
      'caracteristicas': caracteristicas,
      'esDePrueba': esDePrueba,
      'duracion_dias': duracionDias,
      'tipo_prompt': tipoPrompt,
    };
  }
}
