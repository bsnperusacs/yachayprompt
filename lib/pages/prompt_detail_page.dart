import 'package:flutter/material.dart';
import 'package:yachay_prompts/models/prompt_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yachay_prompts/services/pdf_export_service.dart';
import 'package:flutter/services.dart'; // Para Clipboard

class PromptDetailPage extends StatelessWidget {
  final PromptGenerado prompt;

  const PromptDetailPage({super.key, required this.prompt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(prompt.tituloPersonalizado ?? 'Detalle del Prompt'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt.tituloPersonalizado != null &&
                prompt.tituloPersonalizado!.isNotEmpty)
              Text(
                prompt.tituloPersonalizado!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            const SizedBox(height: 16),
            _buildDetailRow(context, 'Nivel Educativo:', prompt.nivelEducativo),
            _buildDetailRow(context, 'Asignatura:', prompt.asignatura),
            _buildDetailRow(context, 'Idioma:', prompt.idiomaPrompt),
            if (prompt.varianteQuechua != null &&
                prompt.varianteQuechua!.isNotEmpty)
              _buildDetailRow(
                  context, 'Variante Quechua:', prompt.varianteQuechua!),
            const SizedBox(height: 16),
            Text(
              'Objetivo/Contenido:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                prompt.objetivoContenido,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Prompt Generado:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                // Permite seleccionar y copiar texto
                prompt.textoPromptFinal,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  context: context,
                  icon: Icons.copy,
                  label: 'Copiar',
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: prompt.textoPromptFinal));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('¡Prompt copiado al portapapeles!')),
                    );
                  },
                ),
                _buildActionButton(
                  context: context,
                  icon: Icons.share,
                  label: 'Compartir',
                  onPressed: () {
                    // ignore: deprecated_member_use
                    Share.share(prompt.textoPromptFinal);
                  },
                ),
                _buildActionButton(
                  context: context,
                  icon: Icons.download,
                  label: 'Descargar PDF',
                  onPressed: () {
                    PdfExportService.descargarPdf(
                      context: context,
                      promptText: prompt.textoPromptFinal,
                      titulo: prompt.tituloPersonalizado ?? 'Prompt Generado',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.center,
              child: FilledButton.icon(
                onPressed: () {
                  // La forma correcta de "usar" un prompt y volver a la pantalla principal
                  // es hacer un pop de todas las rutas hasta la primera,
                  // Y la primera ruta (generalmente tu HomePage o donde generas prompts)
                  // debe manejar el resultado de Navigator.push.

                  // Primero, asegúrate de que solo la ruta principal permanezca en el stack
                  // Luego, haz pop para pasar el prompt a la pantalla que la llamó originalmente.
                  //Navigator.of(context).popUntil((route) => route.isFirst); --> ESTO AHCIA LA PANTALLA NEGRA
                  // Ahora, desde la ruta raíz, haz pop para pasar el resultado.
                  // Esto asume que la ruta raíz fue abierta con Navigator.push y está esperando un resultado.
                  // Esto puede requerir un ajuste en cómo llamas a tu HistoryPromptsPage.
                  // La solución más sencilla es que HistoryPromptsPage sea llamada con `await Navigator.push`
                  // y que ella sea la que decida qué hacer con el prompt si se recibe.

                  // Para que funcione el "Usar este Prompt" y te lleve a la pantalla principal
                  // y puedas pasar el prompt, necesitamos que la llamada original a
                  // HistoryPromptsPage (ej. desde tu HomePage) espere un resultado.

                  // Opción 1 (la más común y recomendada):
                  // Popea directamente la página de detalle y pasa el prompt.
                  // Las páginas intermedias (PromptListPage, AsignaturasPage)
                  // deben "re-popear" este resultado hasta que llegue a la pantalla principal.
                  Navigator.pop(context,
                      prompt); // Pasa el prompt de vuelta a la página anterior

                  // Si la página anterior (PromptListPage) también hace un pop con el prompt,
                  // eventualmente llegará a la HomePage.

                  // Ejemplo de cómo tu HomePage podría llamar a HistoryPromptsPage:
                  // _handlePromptSelection() async {
                  //   final selectedPrompt = await Navigator.push(
                  //     context,
                  //     MaterialPageRoute(builder: (context) => const HistoryPromptsPage()),
                  //   );
                  //   if (selectedPrompt != null && selectedPrompt is PromptGenerado) {
                  //     // Aquí puedes usar selectedPrompt.textoPromptFinal
                  //     // para rellenar un TextField en tu HomePage.
                  //     print("Prompt seleccionado para usar: ${selectedPrompt.textoPromptFinal}");
                  //     // miControladorDeTexto.text = selectedPrompt.textoPromptFinal;
                  //   }
                  // }
                },
                icon: const Icon(Icons.content_paste_go_outlined),
                label: const Text('Usar este Prompt'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Creado el: ${prompt.fechaCreacion.toLocal().toString().split(' ')[0]}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            Text(
              'Última Modificación: ${prompt.fechaModificacion.toLocal().toString().split(' ')[0]}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon,
              size: 30, color: Theme.of(context).colorScheme.secondary),
          onPressed: onPressed,
          tooltip: label,
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
