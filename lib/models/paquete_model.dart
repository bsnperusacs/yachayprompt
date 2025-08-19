// Archivo: lib/models/paquete_model.dart

class Paquete {
  final String id; // ID único del paquete (ej. 'recarga_texto_25', 'recarga_imagen_10')
  final String nombre; // Nombre legible (ej. "Paquete de 25 Prompts", "Paquete de 10 Imágenes")
  final String descripcion; // Descripción del paquete
  final double precio; // Precio del paquete
  final int cantidadPrompts; // Cantidad de prompts que añade este paquete
  final String tipoPrompt; // "texto" o "texto_imagen" (indica si son prompts de texto o de imagen)

  const Paquete({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.cantidadPrompts,
    required this.tipoPrompt,
  });

  // Factory constructor para crear un objeto Paquete desde un Map de Firestore
  factory Paquete.fromFirestoreMap(String id, Map<String, dynamic> data) {
    return Paquete(
      id: id,
      nombre: data['nombre'] as String,
      descripcion: data['descripcion'] as String? ?? '',
      precio: (data['precio'] as num? ?? 0.0).toDouble(), // Asegura que sea double
      cantidadPrompts: (data['cantidad_prompts'] as num? ?? 0).toInt(),
      tipoPrompt: data['tipo_prompt'] as String? ?? 'texto', // Por defecto a 'texto' si no está definido
    );
  }

  // Método para convertir a Map (si fuera necesario enviarlo a Firestore, por ejemplo, en un admin)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'cantidad_prompts': cantidadPrompts,
      'tipo_prompt': tipoPrompt,
    };
  }
}