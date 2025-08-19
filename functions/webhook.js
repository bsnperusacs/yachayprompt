// Archivo: webhook.js

const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");

// --- IMPORTACIÓN CORRECTA DE MERCADO PAGO ---
const mercadopago = require("mercadopago"); 

// Define el secreto para el Access Token de Mercado Pago
const MP_ACCESS_TOKEN = defineSecret("MP_ACCESS_TOKEN");

// Define la base de datos de Firestore
const db = admin.firestore();

// --- CONFIGURACIÓN DE MERCADO PAGO AL INICIO DE LA FUNCIÓN (CORREGIDA) ---
// La configuración se hará dentro del handler o en cada función que lo use para asegurar el acceso al valor del secreto.


exports.webhookMercadoPago = functions.https.onRequest({ secrets: [MP_ACCESS_TOKEN] }, async (req, res) => {
  functions.logger.info("webhookMercadoPago: Solicitud recibida.", { body: req.body, query: req.query });

  // Configurar accessToken dentro del handler para que funcione con defineSecret.value()
  // Esta es la forma que MercadoPago requiere para sus versiones más compatibles.
  mercadopago.configure({
    access_token: MP_ACCESS_TOKEN.value(),
  });

  const { topic, id } = req.query; 

  if (!topic || !id) {
    functions.logger.warn("webhookMercadoPago: Parámetros 'topic' o 'id' faltantes en la query.");
    return res.status(400).send('Bad Request: Missing topic or ID.');
  }

  try {
    // --- USAR mercadopago.payment.findById (CORREGIDO) ---
    let paymentInfo;
    if (topic === 'payment') {
      paymentInfo = await mercadopago.payment.findById(id); // Usa la función directamente de mercadopago
    } else {
      functions.logger.info(`webhookMercadoPago: Ignorando topic: ${topic}`);
      return res.status(200).send('OK - Topic ignored'); 
    }

    if (!paymentInfo || !paymentInfo.body) {
      functions.logger.error(`webhookMercadoPago: No se pudieron obtener detalles del pago para ID: ${id}`);
      return res.status(400).send('Bad Request: Could not retrieve payment info.');
    }

    const paymentStatus = paymentInfo.body.status;
    const externalReference = paymentInfo.body.external_reference; 
    const paymentMetadata = paymentInfo.body.metadata; // Metadatos que enviamos al crear la preferencia

    if (!externalReference || !paymentMetadata || !paymentMetadata.tipo) {
      functions.logger.error("webhookMercadoPago: external_reference o metadata.tipo inválidos.", { externalReference, paymentMetadata });
      return res.status(400).send('Bad Request: Invalid external_reference or metadata.');
    }

    functions.logger.info(`webhookMercadoPago: Pago ${id} con estado: ${paymentStatus}. Ref externa: ${externalReference}. Tipo: ${paymentMetadata.tipo}`);

    // Extraer userId y entidadId según el tipo de pago de los metadatos
    let userId;
    let entidadId; // entidadId puede ser grupoId, planId, paqueteId

    if (paymentMetadata.tipo === "plan_grupal") {
      [userId, entidadId] = externalReference.split('_'); // representanteUid_grupoIdTemporal
    } else { // Para 'plan_individual' y 'paquete'
      userId = paymentMetadata.userId;
      entidadId = paymentMetadata.planId || paymentMetadata.paqueteId;
    }

    if (!userId || !entidadId) {
      functions.logger.error("webhookMercadoPago: No se pudo extraer userId o entidadId de externalReference/metadata.", { externalReference, paymentMetadata });
      return res.status(400).send('Bad Request: Could not parse userId or entityId.');
    }

    const userRef = db.collection('users').doc(userId);

    // Ejecutar transacción para asegurar la atomicidad de las actualizaciones
    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        functions.logger.error(`webhookMercadoPago: Usuario ${userId} no encontrado.`);
        throw new HttpsError('not-found', 'Usuario no encontrado para actualizar.');
      }
      const userData = userDoc.data();

      // --- Lógica para PAGOS GRUPALES (metadata.tipo === "plan_grupal") ---
      if (paymentMetadata.tipo === "plan_grupal") {
        const grupoRef = db.collection('grupos').doc(entidadId); // entidadId es el grupoIdTemporal
        const grupoDoc = await transaction.get(grupoRef);
        if (!grupoDoc.exists) {
          functions.logger.error(`webhookMercadoPago: Grupo temporal ${entidadId} no encontrado.`);
          throw new HttpsError('not-found', 'Grupo temporal no encontrado.');
        }
        const grupoData = grupoDoc.data();

        if (grupoData.estadoGrupo === 'pendiente_pago' && paymentStatus === 'approved') {
          const fechaExpiracion = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)); // 30 días

          transaction.update(grupoRef, {
            estadoGrupo: 'activo',
            fechaActivacion: admin.firestore.FieldValue.serverTimestamp(),
            fechaVencimiento: fechaExpiracion,
            idPago: paymentInfo.body.id,
            montoPagado: paymentInfo.body.transaction_amount,
            metodoPago: paymentInfo.body.payment_method_id,
            pagoRealizado: true,
          });

          // Actualizar contadores del representante
          const cantidadGruposCreadosActual = (userData.cantidadGruposCreados || 0) + 1;
          const totalSlotsCompradosEnTodosMisGruposActual = (userData.totalSlotsCompradosEnTodosMisGrupos || 0) + grupoData.slotsComprados;

          transaction.update(userRef, {
            cantidadGruposCreados: cantidadGruposCreadosActual,
            totalSlotsCompradosEnTodosMisGrupos: totalSlotsCompradosEnTodosMisGruposActual,
            gruposRepresentados: admin.firestore.FieldValue.arrayUnion(entidadId), // Añade el ID del grupo
          });
          functions.logger.info(`webhookMercadoPago: Grupo ${entidadId} activado y representante ${userId} actualizado. Tipo: ${paymentMetadata.tipo}`);

        } else if (paymentStatus === 'rejected' || paymentStatus === 'cancelled') {
          transaction.update(grupoRef, {
            estadoGrupo: 'pago_fallido',
            pagoRealizado: false,
            preferenceId: id,
          });
          functions.logger.warn(`webhookMercadoPago: Pago ${id} rechazado para grupo ${entidadId}. Grupo marcado como fallido.`);
        } else if (paymentStatus === 'pending') {
          transaction.update(grupoRef, {
            estadoGrupo: 'pago_pendiente',
            pagoRealizado: false,
            preferenceId: id,
          });
          functions.logger.info(`webhookMercadoPago: Pago ${id} en estado ${paymentStatus} para grupo ${entidadId}. Grupo marcado como pendiente.`);
        }
      }

      // --- Lógica para PAGOS INDIVIDUALES (metadata.tipo === "plan_individual") ---
      else if (paymentMetadata.tipo === "plan_individual") {
        const planId = paymentMetadata.planId;
        const duracionDias = paymentMetadata.duracionDias; 
        
        if (paymentStatus === 'approved') {
            const now = admin.firestore.Timestamp.now();
            const vencimiento = admin.firestore.Timestamp.fromDate(
              new Date(now.toDate().getTime() + duracionDias * 24 * 60 * 60 * 1000)
            );

            if (userData.grupoIdPendiente && userData.planGrupalTipoPendiente && userData.fechaFinPlanIndividualActual) {
                functions.logger.info(`Usuario ${userId} con plan grupal pendiente cancelado por compra individual de ${planId}.`);
            }

            transaction.update(userRef, {
                planContratado: planId,
                fechaInicioSuscripcion: now,
                fechaFinSuscripcion: vencimiento,
                estadoSuscripcion: 'activo',
                grupoIdPendiente: admin.firestore.FieldValue.delete(),
                planGrupalTipoPendiente: admin.firestore.FieldValue.delete(),
                fechaFinPlanIndividualActual: admin.firestore.FieldValue.delete(),
            });
            functions.logger.info(`webhookMercadoPago: Plan individual ${planId} activado para usuario ${userId}.`);

        } else if (paymentStatus === 'rejected' || paymentStatus === 'cancelled') {
            functions.logger.warn(`webhookMercadoPago: Pago individual ${id} rechazado para usuario ${userId}. Plan: ${planId}`);
        } else if (paymentStatus === 'pending') {
            functions.logger.info(`webhookMercadoPago: Pago individual ${id} en estado ${paymentStatus} para usuario ${userId}. Plan: ${planId}`);
        }
      }

      // --- Lógica para PAGOS DE PAQUETES (metadata.tipo === "paquete") ---
      else if (paymentMetadata.tipo === "paquete") {
        const cantidadPrompts = paymentMetadata.cantidadPrompts;
        const paqueteId = paymentMetadata.paqueteId;

        if (paymentStatus === 'approved') {
            const promptsActuales = (userData.saldoPromptsComprados || 0);
            const nuevosPrompts = promptsActuales + cantidadPrompts;

            transaction.update(userRef, {
                saldoPromptsComprados: nuevosPrompts,
            });
            functions.logger.info(`webhookMercadoPago: Usuario ${userId} recargó ${cantidadPrompts} prompts. Nuevo saldo: ${nuevosPrompts}. Paquete: ${paqueteId}`);

        } else if (paymentStatus === 'rejected' || paymentStatus === 'cancelled') {
            functions.logger.warn(`webhookMercadoPago: Pago de paquete ${id} rechazado para usuario ${userId}. Paquete: ${paqueteId}`);
        } else if (paymentStatus === 'pending') {
            functions.logger.info(`webhookMercadoPago: Pago de paquete ${id} en estado ${paymentStatus} para usuario ${userId}. Paquete: ${paqueteId}`);
        }
      } else {
          functions.logger.warn(`webhookMercadoPago: Tipo de pago '${paymentMetadata.tipo}' no reconocido. No se realizó acción.`);
          return res.status(200).send('OK - Tipo de pago no reconocido');
      }
    });

    return res.status(200).send('OK'); // SIEMPRE responder 200 a Mercado Pago para evitar reintentos

  } catch (error) {
    functions.logger.error('webhookMercadoPago: Error en el webhook principal. Esto podría ser un problema de código o de red.', error);
    if (error instanceof HttpsError) {
        functions.logger.error(`Webhook HttpsError: ${error.code} - ${error.message}`);
    } else if (error.response) { // Errores de la API de Mercado Pago
        functions.logger.error(`Webhook MP API Error: ${error.response.status} - ${JSON.stringify(error.response.data)}`);
    }
    return res.status(500).send('Internal Server Error');
  }
});