// lib/pages/template_library_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yachay_prompts/pages/plantillas_por_categoria_page.dart';
// flutter/foundation.dart no es necesario si no usas kDebugMode

// Importación para la carga de plantillas (si aún la necesitas en el botón de la nube)
// import 'package:yachay_prompts/utils/firestore_uploader.dart'; 

/// Página principal que muestra las categorías de plantillas.
/// Las categorías ahora se leen desde un campo 'nombre' dentro de cada documento.
class TemplateLibraryPage extends StatelessWidget {
  const TemplateLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Los prints de depuración del usuario se han eliminado.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de Plantillas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          // Si aún necesitas el botón de la nube para subir, descomenta el siguiente bloque
          // y asegúrate de que la importación de 'firestore_uploader.dart' esté activa.
          /*
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Subir plantillas a Firestore',
            onPressed: () async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Confirmar Subida'),
                    content: const Text(
                        '¿Estás seguro de que quieres subir las plantillas? '
                        'Esto creará/actualizará la colección "plantillas" en Firestore. '
                        'Se recomienda borrar la colección existente si no quieres duplicados.'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancelar'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                      ),
                      FilledButton(
                        child: const Text('Subir Ahora'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true);
                        },
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                if (!context.mounted) return; 

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(width: 15),
                        Text('Subiendo plantillas...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    duration: Duration(days: 365),
                    backgroundColor: Colors.blueAccent,
                  ),
                );

                try {
                  await cargarPlantillasAFirestore();

                  if (!context.mounted) return; 
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ ¡Plantillas subidas exitosamente!', style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 5),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return; 
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error al subir plantillas: $e', style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 10),
                    ),
                  );
                }
              }
            },
          ),
          */
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('plantillas').snapshots(),
        builder: (context, snapshot) {
          // Los prints de depuración se han eliminado.

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar categorías: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No hay categorías disponibles.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  // Solo mostrar esta sugerencia si el botón de la nube NO está presente
                  // Si lo descomentas arriba, podrías quitar este texto
                  /*
                  const Text(
                    'Usa el botón de la nube ☁️ en la barra superior para subir las plantillas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  */
                ],
              ),
            );
          }

          final categorias = snapshot.data!.docs;
          // Los prints de depuración se han eliminado.

          return ListView.builder(
            itemCount: categorias.length,
            itemBuilder: (context, index) {
              final doc = categorias[index];
              final data = doc.data() as Map<String, dynamic>;

              final categoriaNombre = data['nombre'] ?? 'Categoría Desconocida';
              final categoriaId = doc.id;

              // Los prints de depuración se han eliminado.

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.folder, color: Colors.blue, size: 30),
                  title: Text(
                    categoriaNombre.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () async { // Asegúrate de que 'async' esté aquí
                    final Map<String, dynamic>? plantillaSeleccionadaData = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlantillasPorCategoriaPage(categoriaId: categoriaId),
                      ),
                    );

                    if (plantillaSeleccionadaData != null) {
                      if (!context.mounted) return;
                      Navigator.pop(context, plantillaSeleccionadaData); // Este pop regresa a HomeScreen
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}