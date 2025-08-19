// Archivo: lib/pages/planes_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Asegúrate de importar tus modelos
import '../models/plan_model.dart';
import '../models/paquete_model.dart';

class PlanesPage extends StatefulWidget {
  const PlanesPage({super.key});

  @override
  State<PlanesPage> createState() => _PlanesPageState();
}

class _PlanesPageState extends State<PlanesPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Plan> _planesIndividuales = [];
  List<Paquete> _paquetes = [];

  @override
  void initState() {
    super.initState();
    _fetchPlanesAndPaquetes();
  }

  // --- Función para obtener los planes y paquetes desde Firestore ---
  Future<void> _fetchPlanesAndPaquetes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final configDoc = await FirebaseFirestore.instance.collection('config').doc('precios_planes').get();

      if (!configDoc.exists) {
        throw Exception('Configuración de precios_planes no encontrada en Firestore.');
      }

      final data = configDoc.data();
      if (data == null) {
        throw Exception('Datos de configuración de precios_planes son nulos.');
      }

      // ===========================
      // Procesar planes individuales
      // ===========================
      final Map<String, dynamic>? planesIndividualesData =
          data['planes_individuales'] as Map<String, dynamic>?;

      _planesIndividuales = [];

      if (planesIndividualesData != null) {
        _planesIndividuales = planesIndividualesData.entries
            .where((entry) => entry.value is Map<String, dynamic>)
            .map((entry) =>
                Plan.fromFirestoreMap(entry.key, entry.value as Map<String, dynamic>))
            .toList(); // 👈 sin filtro, cargamos todos
      }

      // Fallback demo-pago: si no está en Firestore, lo añadimos desde la lista local
      if (!_planesIndividuales.any((p) => p.id == 'demo-pago') &&
          (Plan.planesDisponibles != null)) {
        final localDemo =
            Plan.planesDisponibles!.where((p) => p.id == 'demo-pago');
        _planesIndividuales.addAll(localDemo);
      }

      // --- Ordenar planes: demo primero, luego basico, luego creativo, luego el resto ---
      _planesIndividuales.sort((a, b) {
        const orden = ['demo-pago', 'basico', 'creativo'];
        final indexA = orden.indexOf(a.id);
        final indexB = orden.indexOf(b.id);

        if (indexA == -1 && indexB == -1) {
          return a.nombre.compareTo(b.nombre); // los demás, alfabético
        } else if (indexA == -1) {
          return 1;
        } else if (indexB == -1) {
          return -1;
        } else {
          return indexA.compareTo(indexB);
        }
      });

      // ===========================
      // Procesar paquetes
      // ===========================
      final Map<String, dynamic>? paquetesPromptsData =
          data['paquetes_prompts'] as Map<String, dynamic>?;

      if (paquetesPromptsData != null) {
        _paquetes = paquetesPromptsData.entries
            .where((entry) => entry.value is Map<String, dynamic>)
            .map((entry) {
              try {
                return Paquete.fromFirestoreMap(
                    entry.key, entry.value as Map<String, dynamic>);
              } catch (e) {
                return null;
              }
            })
            .where((paquete) => paquete != null)
            .cast<Paquete>()
            .toList();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar los planes: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Pago planes individuales ---
  Future<void> _iniciarPagoPlanIndividual(Plan plan) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para comprar un plan.')),
      );
      return;
    }

    try {
      final functions = FirebaseFunctions.instance;
      final String fnName =
          (plan.id == 'demo-pago') ? 'demoPago' : 'procesarPagoIndividual';
      final HttpsCallable callable = functions.httpsCallable(fnName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preparando pago para ${plan.nombre}...')),
      );

      final Map<String, dynamic> payload =
          (plan.id == 'demo-pago') ? {} : {'planId': plan.id};

      final HttpsCallableResult result = await callable.call(payload);
      if (!mounted) return;

      final String? checkoutUrl = result.data['checkoutUrl'];

      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          if (!mounted) return;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir la página de pago.')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: La URL de pago no fue generada.')),
        );
      }
    } catch (e) {
      String message = 'Error al iniciar el pago. Inténtalo de nuevo.';
      if (e is FirebaseFunctionsException) message = e.message ?? message;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // --- Pago paquetes ---
  Future<void> _iniciarPagoPaquete(Paquete paquete) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para comprar un paquete.')),
      );
      return;
    }

    try {
      final functions = FirebaseFunctions.instance;
      final HttpsCallable callable =
          functions.httpsCallable('procesarPagoPaquete');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preparando pago para ${paquete.nombre}...')),
      );

      final HttpsCallableResult result =
          await callable.call({'paqueteId': paquete.id});
      if (!mounted) return;

      final String? checkoutUrl = result.data['checkoutUrl'];

      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          if (!mounted) return;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No se pudo abrir la página de pago. Inténtalo de nuevo.')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: La URL de pago no fue generada.')),
        );
      }
    } catch (e) {
      String message = 'Error al iniciar el pago del paquete. Inténtalo de nuevo.';
      if (e is FirebaseFunctionsException) message = e.message ?? message;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuestros Planes y Paquetes'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.blueGrey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _fetchPlanesAndPaquetes,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Planes Individuales',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 16),
                          ..._planesIndividuales.map(
                            (plan) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: PlanCard(
                                plan: plan,
                                onPressed: () => _iniciarPagoPlanIndividual(plan),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paquetes de Prompts',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 16),
                          ..._paquetes.map(
                            (paquete) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: PaqueteCard(
                                paquete: paquete,
                                onPressed: () => _iniciarPagoPaquete(paquete),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// --- Widget para mostrar una tarjeta de Plan ---
class PlanCard extends StatelessWidget {
  final Plan plan;
  final VoidCallback onPressed;

  const PlanCard({
    super.key,
    required this.plan,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 0.0),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.nombre,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              plan.descripcion,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 15),
            Text(
              plan.precioDisplay,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text('Prompts: ${plan.promptsTotal}',
                style: TextStyle(color: Colors.grey[700])),
            if (plan.imagenesMax > 0)
              Text('Imágenes: ${plan.imagenesMax}',
                  style: TextStyle(color: Colors.grey[700])),
            Text('Duración: ${plan.duracionDias} días',
                style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 15),
            if (plan.caracteristicas.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Características:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade700)),
                  const SizedBox(height: 4),
                  ...plan.caracteristicas.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 18, color: Colors.blue.shade400),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(c,
                                  style: TextStyle(color: Colors.grey[800]))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  'Comprar Plan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Widget para mostrar una tarjeta de Paquete ---
class PaqueteCard extends StatelessWidget {
  final Paquete paquete;
  final VoidCallback onPressed;

  const PaqueteCard({
    super.key,
    required this.paquete,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 0.0),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paquete.nombre,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              paquete.descripcion,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 15),
            Text(
              'S/. ${paquete.precio.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text('Añade: ${paquete.cantidadPrompts} Prompts',
                style: TextStyle(color: Colors.grey[700])),
            Text(
                'Tipo: ${paquete.tipoPrompt == 'texto_imagen' ? 'Texto e Imagen' : 'Texto'}',
                style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  'Comprar Paquete',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
