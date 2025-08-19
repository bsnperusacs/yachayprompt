// lib/models/language_data.dart

// Asegúrate de que esta importación esté

class Language {
  final String
      id; // El ID del documento en Firestore (ej. "quechua", "espanol")
  final String name; // El nombre legible del idioma (ej. "Quechua", "Español")

  Language({required this.id, required this.name});

  // Constructor para crear un objeto Language desde un DocumentSnapshot de Firestore
  factory Language.fromFirestore(Map<String, dynamic> data, String docId) {
    return Language(
      id: docId,
      name: data['name'] as String,
    );
  }

  // Método para convertir un objeto Language a un Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
    };
  }
}
