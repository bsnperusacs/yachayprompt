// lib/models/education_data.dart

class NivelEducativo {
  final String id;
  final String nombre;

  NivelEducativo({required this.id, required this.nombre});

  // Puedes añadir un factory constructor para crear desde JSON/Map si los cargas de Firestore
  factory NivelEducativo.fromJson(Map<String, dynamic> json) {
    return NivelEducativo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
    );
  }
}

class Asignatura {
  final String id;
  final String nombre;
  final String idNivel; // Para vincular a NivelEducativo

  Asignatura({required this.id, required this.nombre, required this.idNivel});

  // Puedes añadir un factory constructor para crear desde JSON/Map si los cargas de Firestore
  factory Asignatura.fromJson(Map<String, dynamic> json) {
    return Asignatura(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      idNivel: json['idNivel'] as String,
    );
  }
}
