import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yachay_prompts/auth/auth_service.dart';
import 'package:yachay_prompts/models/prompt_model.dart';
import 'package:yachay_prompts/services/pdf_export_service.dart';
import 'package:yachay_prompts/pages/prompt_detail_page.dart'; // Importa la página de detalle

class PromptListPage extends StatefulWidget {
  final String pageTitle;
  final List<PromptGenerado> prompts;

  const PromptListPage({
    super.key,
    required this.pageTitle,
    required this.prompts,
  });

  @override
  State<PromptListPage> createState() => _PromptListPageState();
}

class _PromptListPageState extends State<PromptListPage> {
  late List<PromptGenerado> _promptsList;

  @override
  void initState() {
    super.initState();
    _promptsList = List.from(widget.prompts);
  }

  Future<void> _eliminarPrompt(String promptId, int index) async {
    final user = AuthService().currentUser;
    if (user == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content:
            const Text('¿Estás seguro de que deseas eliminar este prompt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('prompts')
          .doc(promptId)
          .delete();

      setState(() {
        _promptsList.removeAt(index);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Prompt eliminado.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _verDetallesPrompt(PromptGenerado prompt) async {
    // <-- CAMBIO AQUÍ: await para esperar resultado
    final selectedPrompt = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromptDetailPage(prompt: prompt),
      ),
    );
    // Si recibimos un prompt de la página de detalles, lo devolvemos a la página anterior
    if (selectedPrompt != null && selectedPrompt is PromptGenerado) {
      if (!mounted) return;
      Navigator.pop(context, selectedPrompt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _promptsList.isEmpty
          ? const Center(
              child: Text('No hay prompts en esta carpeta.',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _promptsList.length,
              itemBuilder: (context, index) {
                final prompt = _promptsList[index];

                return Card(
                  elevation: 3.0,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (prompt.tituloPersonalizado != null &&
                            prompt.tituloPersonalizado!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              prompt.tituloPersonalizado!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                        Text(
                          prompt.objetivoContenido,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye_outlined),
                              tooltip: 'Ver Detalles',
                              onPressed: () => _verDetallesPrompt(prompt),
                            ),
                            // El botón "Usar este Prompt" aquí no es el principal para "usar"
                            // Ya que la acción principal es desde la página de detalles.
                            // Puedes decidir eliminarlo o mantenerlo para otros flujos.
                            // Si lo mantienes, su acción es simplemente regresar un prompt a la página anterior.
                            IconButton(
                              icon: const Icon(Icons.content_paste_go_outlined),
                              tooltip: 'Usar este Prompt (desde lista)',
                              onPressed: () {
                                Navigator.pop(context,
                                    prompt); // Pasa el prompt de vuelta a la página anterior (AsignaturasPage)
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.share_outlined),
                              tooltip: 'Compartir',
                              onPressed: () =>
                                  // ignore: deprecated_member_use
                                  Share.share(prompt.textoPromptFinal),
                            ),
                            IconButton(
                              icon: const Icon(Icons.download_outlined),
                              tooltip: 'Descargar PDF',
                              onPressed: () => PdfExportService.descargarPdf(
                                  context: context,
                                  promptText: prompt.textoPromptFinal,
                                  titulo: prompt.tituloPersonalizado ??
                                      'Prompt Generado'),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error),
                              tooltip: 'Eliminar',
                              onPressed: () =>
                                  _eliminarPrompt(prompt.id, index),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
