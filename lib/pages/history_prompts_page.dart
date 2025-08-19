import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yachay_prompts/auth/auth_service.dart';
import 'package:yachay_prompts/models/prompt_model.dart';
import 'package:yachay_prompts/pages/asignaturas_page.dart';

class HistoryPromptsPage extends StatefulWidget {
  const HistoryPromptsPage({super.key});

  @override
  State<HistoryPromptsPage> createState() => _HistoryPromptsPageState();
}

class _HistoryPromptsPageState extends State<HistoryPromptsPage> {
  late Future<Map<String, Map<String, List<PromptGenerado>>>>
      _futureGroupedPrompts;

  @override
  void initState() {
    super.initState();
    _futureGroupedPrompts = _fetchAndGroupPrompts();
  }

  Future<void> _refreshPrompts() async {
    setState(() {
      _futureGroupedPrompts = _fetchAndGroupPrompts();
    });
  }

  Future<Map<String, Map<String, List<PromptGenerado>>>>
      _fetchAndGroupPrompts() async {
    final user = AuthService().currentUser;
    if (user == null) return {};

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('prompts')
        .orderBy('fechaCreacion', descending: true)
        .get();

    final prompts =
        snapshot.docs.map((doc) => PromptGenerado.fromFirestore(doc)).toList();
    var groupedMap = <String, Map<String, List<PromptGenerado>>>{};

    for (var prompt in prompts) {
      if (prompt.nivelEducativo.isEmpty || prompt.asignatura.isEmpty) continue;
      groupedMap.putIfAbsent(prompt.nivelEducativo, () => {});
      groupedMap[prompt.nivelEducativo]!
          .putIfAbsent(prompt.asignatura, () => []);
      groupedMap[prompt.nivelEducativo]![prompt.asignatura]!.add(prompt);
    }

    return groupedMap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial por Carpetas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPrompts,
        child: FutureBuilder<Map<String, Map<String, List<PromptGenerado>>>>(
          future: _futureGroupedPrompts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                  child:
                      Text('Error al cargar el historial: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_off_outlined,
                        size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Tu historial está vacío',
                        style: TextStyle(fontSize: 18, color: Colors.grey)),
                    Text('Los prompts que guardes aparecerán aquí.',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              );
            }

            final groupedPrompts = snapshot.data!;
            final niveles = groupedPrompts.keys.toList();

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: niveles.length,
              itemBuilder: (context, index) {
                final nivel = niveles[index];
                final asignaturasMap = groupedPrompts[nivel]!;
                final totalPromptsInNivel = asignaturasMap.values
                    .fold<int>(0, (prev, list) => prev + list.length);

                return Card(
                  elevation: 2.0,
                  margin: const EdgeInsets.symmetric(
                      vertical: 6.0, horizontal: 8.0),
                  child: ListTile(
                    leading: const Icon(Icons.folder_special_outlined,
                        color: Colors.amber, size: 40),
                    title: Text(nivel,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text('$totalPromptsInNivel prompts'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      // <-- CAMBIO AQUÍ: await para esperar resultado
                      final selectedPrompt = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AsignaturasPage(
                            nivelEducativo: nivel,
                            asignaturasMap: asignaturasMap,
                          ),
                        ),
                      );
                      // Si recibimos un prompt, lo devolvemos a la página anterior
                      if (selectedPrompt != null &&
                          selectedPrompt is PromptGenerado) {
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        Navigator.pop(context, selectedPrompt);
                      } else {
                        // Si no se seleccionó un prompt (ej. se volvió sin seleccionar),
                        // entonces refrescamos la lista por si se eliminó algo.
                        _refreshPrompts();
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
