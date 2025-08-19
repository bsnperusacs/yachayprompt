// lib/pages/plantillas_por_categoria_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlantillasPorCategoriaPage extends StatelessWidget {
  final String categoriaId;

  const PlantillasPorCategoriaPage({super.key, required this.categoriaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plantillas: ${categoriaId.toUpperCase()}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('plantillas')
            .doc(categoriaId)
            .collection('plantillas')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay plantillas en esta categoría.'));
          }

          final plantillas = snapshot.data!.docs;

          return ListView.builder(
            itemCount: plantillas.length,
            itemBuilder: (context, index) {
              final doc = plantillas[index];
              final data = doc.data() as Map<String, dynamic>;
              final titulo = data['titulo'] ?? 'Sin título';
              final contenido = data['contenido'] ?? 'Sin contenido';

              return Card(
                color: Colors.teal.shade50,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(contenido, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // ✅ CAMBIO AQUÍ: Incluir el 'id' del documento en el mapa que se devuelve
                            final Map<String, dynamic> dataConId = {
                              'id': doc.id, // ¡Aquí añadimos el ID!
                              ...data,     // Y aquí incluimos todos los demás datos que ya tenías
                            };
                            Navigator.pop(context, dataConId); // Ahora enviamos el mapa con el ID
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Usar esta plantilla'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
