// Archivo: functions/webhook.js

const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");

// --- IMPORTACIÓN DE MERCADO PAGO ---
const mercadopago = require("mercadopago"); 

// Define el secreto para el Access Token de Mercado Pago
const MP_ACCESS_TOKEN = defineSecret("MP_ACCESS_TOKEN");

// Define la base de datos de Firestore
const db = admin.firestore();

exports.webhookMercadoPago = functions.https.onRequest({ secrets: [MP_ACCESS_TOKEN] }, async (req, res) => {
  functions.logger.info("webhookMercadoPago: Solicitud recibida.", { body: req.body, query: req.query });

  // Configurar accessToken dentro del handler usando defineSecret
  mercadopago.configure({
    access_token: MP_ACCESS_TOKEN.value(),
  });

  const { topic, id } = req.query; 

  if (!topic || !id) {
    functions.logger.warn("webhookMercadoPago: Parámetros 'topic' o 'id' faltantes en la query.");
    return res.status(400).send('Bad Request: Missing topic or ID.');
  }

  try {
    let paymentInfo;
    if (topic === 'payment') {
      paymentInfo = await mercadopago.payment.findById(id);
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
    const paymentMetadata = paymentInfo.body.metadata;

    if (!externalReference || !paymentMetadata || !paymentMetadata.tipo) {
      functions.logger.error("webhookMercadoPago: external_reference o metadata.tipo inválidos.", { externalReference, paymentMetadata });
      return res.status(400).send('Bad Request: Invalid external_reference or metadata.');
    }

    functions.logger.info(`webhookMercadoPago: Pago ${id} con estado: ${paymentStatus}. Ref externa: ${externalReference}. Tipo: ${paymentMetadata.tipo}`);

    let userId;
    let entidadId; 

    if (paymentMetadata.tipo === "plan_grupal") {
      [userId, entidadId] = externalReference.split('_');
    } else { 
      userId = paymentMetadata.userId;
      entidadId = paymentMetadata.planId || paymentMetadata.paqueteId;
    }

    if (!userId || !entidadId) {
      functions.logger.error("webhookMercadoPago: No se pudo extraer userId o entidadId de externalReference/metadata.", { externalReference, paymentMetadata });
      return res.status(400).send('Bad Request: Could not parse userId or entityId.');
    }

    const userRef = db.collection('users').doc(userId);

    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        functions.logger.error(`webhookMercadoPago: Usuario ${userId} no encontrado.`);
        throw new HttpsError('not-found', 'Usuario no encontrado para actualizar.');
      }
      const userData = userDoc.data();

      // --- PAGOS GRUPALES ---
      if (paymentMetadata.tipo === "plan_grupal") {
        const grupoRef = db.collection('grupos').doc(entidadId);
        const grupoDoc = await transaction.get(grupoRef);
        if (!grupoDoc.exists) {
          functions.logger.error(`webhookMercadoPago: Grupo temporal ${entidadId} no encontrado.`);
          throw new HttpsError('not-found', 'Grupo temporal no encontrado.');
        }
        const grupoData = grupoDoc.data();

        if (grupoData.estadoGrupo === 'pendiente_pago' && paymentStatus === 'approved') {
          const fechaExpiracion = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000));

          transaction.update(grupoRef, {
            estadoGrupo: 'activo',
            fechaActivacion: admin.firestore.FieldValue.serverTimestamp(),
            fechaVencimiento: fechaExpiracion,
            idPago: paymentInfo.body.id,
            montoPagado: paymentInfo.body.transaction_amount,
            metodoPago: paymentInfo.body.payment_method_id,
            pagoRealizado: true,
          });

          const cantidadGruposCreadosActual = (userData.cantidadGruposCreados || 0) + 1;
          const totalSlotsCompradosEnTodosMisGruposActual = (userData.totalSlotsCompradosEnTodosMisGrupos || 0) + grupoData.slotsComprados;

          transaction.update(userRef, {
            cantidadGruposCreados: cantidadGruposCreadosActual,
            totalSlotsCompradosEnTodosMisGrupos: totalSlotsCompradosEnTodosMisGruposActual,
            gruposRepresentados: admin.firestore.FieldValue.arrayUnion(entidadId),
          });
          functions.logger.info(`webhookMercadoPago: Grupo ${entidadId} activado y representante ${userId} actualizado.`);

        } else if (paymentStatus === 'rejected' || paymentStatus === 'cancelled') {
          transaction.update(grupoRef, {
            estadoGrupo: 'pago_fallido',
            pagoRealizado: false,
            preferenceId: id,
          });
        } else if (paymentStatus === 'pending') {
          transaction.update(grupoRef, {
            estadoGrupo: 'pago_pendiente',
            pagoRealizado: false,
            preferenceId: id,
          });
        }
      }

      // --- PAGOS INDIVIDUALES ---
      else if (paymentMetadata.tipo === "plan_individual") {
        const planId = paymentMetadata.planId;
        const duracionDias = paymentMetadata.duracionDias; 
        
        if (paymentStatus === 'approved') {
          // 🚫 Bloquear demo-pago si ya lo tuvo
          if (planId === "demo-pago" && userData.historialPlanes?.includes("demo-pago")) {
            functions.logger.warn(`Usuario ${userId} ya usó demo-pago, no se acredita de nuevo.`);
            return;
          }

          const now = admin.firestore.Timestamp.now();
          const vencimiento = admin.firestore.Timestamp.fromDate(
            new Date(now.toDate().getTime() + duracionDias * 24 * 60 * 60 * 1000)
          );

          transaction.update(userRef, {
            planContratado: planId,
            fechaInicioSuscripcion: now,
            fechaFinSuscripcion: vencimiento,
            estadoSuscripcion: 'activo',
            historialPlanes: admin.firestore.FieldValue.arrayUnion(planId),
            grupoIdPendiente: admin.firestore.FieldValue.delete(),
            planGrupalTipoPendiente: admin.firestore.FieldValue.delete(),
            fechaFinPlanIndividualActual: admin.firestore.FieldValue.delete(),
          });
          functions.logger.info(`webhookMercadoPago: Plan individual ${planId} activado para usuario ${userId}.`);
        }
      }

      // --- PAGOS DE PAQUETES ---
      else if (paymentMetadata.tipo === "paquete") {
        const cantidadPrompts = paymentMetadata.cantidadPrompts;
        const paqueteId = paymentMetadata.paqueteId;
        const tipoPrompt = paymentMetadata.tipoPrompt || "texto";

        if (paymentStatus === 'approved') {
          const promptsActuales = (userData.saldoPromptsComprados || 0);
          const nuevosPrompts = promptsActuales + cantidadPrompts;

          let updateData = {
            saldoPromptsComprados: nuevosPrompts,
          };

          // 🔹 Si el paquete es texto_imagen también sumar imágenes
          if (tipoPrompt === "texto_imagen") {
            const imagenesActuales = (userData.imagenesRestantes || 0);
            updateData.imagenesRestantes = imagenesActuales + cantidadPrompts;
          }

          transaction.update(userRef, updateData);
          functions.logger.info(`webhookMercadoPago: Usuario ${userId} recargó ${cantidadPrompts} prompts${tipoPrompt === "texto_imagen" ? " y el mismo número de imágenes" : ""}. Paquete: ${paqueteId}`);
        }
      }
    });

    return res.status(200).send('OK');
  } catch (error) {
    functions.logger.error('webhookMercadoPago: Error en el webhook principal.', error);
    return res.status(500).send('Internal Server Error');
  }
});
