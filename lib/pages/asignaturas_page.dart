import 'package:flutter/material.dart';
import 'package:yachay_prompts/models/prompt_model.dart';
import 'package:yachay_prompts/pages/prompt_list_page.dart';

class AsignaturasPage extends StatefulWidget {
  // CAMBIO CLAVE: Ahora es un StatefulWidget
  final String nivelEducativo;
  final Map<String, List<PromptGenerado>> asignaturasMap;

  const AsignaturasPage({
    super.key,
    required this.nivelEducativo,
    required this.asignaturasMap,
  });

  @override
  State<AsignaturasPage> createState() => _AsignaturasPageState();
}

class _AsignaturasPageState extends State<AsignaturasPage> {
  // Clase State asociada
  @override
  Widget build(BuildContext context) {
    // Acceder a las propiedades a través de 'widget.'
    final asignaturas = widget.asignaturasMap.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nivelEducativo),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: asignaturas.length,
        itemBuilder: (context, index) {
          final asignatura = asignaturas[index];
          final promptsList = widget.asignaturasMap[asignatura]!;
          final totalPromptsInAsignatura = promptsList.length;

          return Card(
            elevation: 2.0,
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
            child: ListTile(
              leading: const Icon(Icons.folder_copy_outlined,
                  color: Colors.blueGrey, size: 40),
              title: Text(asignatura,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text('$totalPromptsInAsignatura prompts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                // La función es async para usar await
                final selectedPrompt = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PromptListPage(
                      pageTitle: asignatura,
                      prompts: promptsList,
                    ),
                  ),
                );
                // Ahora podemos usar 'mounted' de forma segura porque estamos en un StatefulWidget
                if (!mounted) {
                  return; // Si el widget ya no está en el árbol, salimos.
                }
                // Si la página siguiente devuelve un prompt, lo pasamos a la anterior
                if (selectedPrompt != null &&
                    selectedPrompt is PromptGenerado) {
                  // ignore: use_build_context_synchronously
                  Navigator.pop(context, selectedPrompt);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
