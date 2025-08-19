import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yachay_prompts/models/plan_model.dart'; // Asegúrate de que la ruta sea correcta

class PlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> loadAvailablePlans() async {
    List<Plan> loadedPlans = [];

    // 1. Añadir el plan 'demo' localmente. Este siempre estará disponible.
    //    ¡IMPORTANTE: Usa aquí los VALORES REALES de tu plan demo!
            loadedPlans.add(Plan(
          id: 'demo-pago',   // mejor renombrar para evitar confusión
          nombre: 'Demo (pago único)',
          descripcion: 'Acceso limitado para probar las funciones de la aplicación.',
          precioNumerico: 1.99,
          promptsTotal: 10,
          imagenesMax: 2,
          caracteristicas: ['10 prompts de texto', '2 creaciones de imágenes', 'Acceso básico'],
          esDePrueba: false,  // ← así ya no sale como Gratis
          duracionDias: 7,
          tipoPrompt: 'texto',
        ));


    // 2. Intentar cargar los planes de compra de Firestore.
    try {
      DocumentSnapshot preciosPlanesDoc = await _firestore.collection('config').doc('precios_planes').get();

      if (preciosPlanesDoc.exists && preciosPlanesDoc.data() != null) {
        Map<String, dynamic> data = preciosPlanesDoc.data() as Map<String, dynamic>;

        // --- FUNCIÓN AUXILIAR PARA PROCESAR MAPAS DE PLANES ---
        // 'plansMapData' será el mapa (ej. data['paquetes_prompts'])
        void processFirestorePlanMap(Map<String, dynamic>? plansMapData) {
          if (plansMapData != null) {
            // Itera sobre las entradas del mapa (clave = id del plan, valor = datos del plan)
            plansMapData.forEach((planId, planDetails) {
              if (planDetails is Map<String, dynamic>) {
                // Solo añadir si no es el plan 'demo' (que ya lo añadimos localmente)
                if (planId != 'demo') {
                  loadedPlans.add(Plan.fromFirestoreMap(planId, planDetails));
                }
              }
            });
          }
        }

        // --- LLAMA A LA FUNCIÓN PARA CADA SECCIÓN DE PLANES EN TU DOCUMENTO ---
        // Asegúrate de que los nombres de los campos sean EXACTOS
        processFirestorePlanMap(data['paquetes_prompts'] as Map<String, dynamic>?);
        processFirestorePlanMap(data['planes_grupales'] as Map<String, dynamic>?);
        processFirestorePlanMap(data['planes_individuales'] as Map<String, dynamic>?);
       // processFirestorePlanMap(data['precios_planes'] as Map<String, dynamic>?); // Si este campo también contiene planes (como "nivel_1", "nivel_2")

        // Aquí podrías agregar lógica para 'descuentos_representante' si también contiene planes
        // o si es solo información de descuentos y no planes en sí.
        // Si 'descuentos_representante' contiene mapas anidados de planes, tendríamos que ajustarlo.
        // Por ahora, asumimos que son solo 'paquetes_prompts', 'planes_grupales', 'planes_individuales', 'precios_planes'


      } else {
      }

    } catch (e) {
      // No necesitamos hacer nada aquí porque 'loadedPlans' ya contiene el plan demo.
    }

    // 3. Asignar la lista final (demo + comprados) a la variable estática.
    Plan.planesDisponibles = loadedPlans;
  }
}