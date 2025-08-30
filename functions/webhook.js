// Archivo: functions/webhook.js
// Webhook de Mercado Pago – activa planes individuales, paquetes y plan grupal

const functions = require("firebase-functions/v2");
const { HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");
const mercadopago = require("mercadopago");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const MP_ACCESS_TOKEN = defineSecret("MP_ACCESS_TOKEN");

exports.webhookMercadoPago = functions.https.onRequest({ secrets: [MP_ACCESS_TOKEN] }, async (req, res) => {
  functions.logger.info("webhookMercadoPago: Solicitud recibida.", { body: req.body, query: req.query });

  mercadopago.configure({ access_token: MP_ACCESS_TOKEN.value() });

  const { topic, id } = req.query;
  if (!topic || !id) return res.status(400).send("Bad Request: Missing topic or ID.");

  try {
    if (topic !== "payment") return res.status(200).send("OK - Topic ignored");

    const paymentInfo = await mercadopago.payment.findById(id);
    if (!paymentInfo || !paymentInfo.body) return res.status(400).send("Bad Request: Could not retrieve payment info.");

    const status = paymentInfo.body.status; // approved | pending | rejected | cancelled
    const metadata = paymentInfo.body.metadata || {};
    const externalRef = paymentInfo.body.external_reference || "";

    functions.logger.info(`MP webhook: ${id} status=${status} tipo=${metadata.tipo}`);

    // ---------------- PLAN GRUPAL ----------------
    if (metadata.tipo === "plan_grupal") {
      const [adminUid, groupId] = externalRef.split("_");
      if (!adminUid || !groupId) return res.status(400).send("Bad Request: invalid external_reference");

      const groupRef = db.collection("grupos").doc(groupId);
      const groupSnap = await groupRef.get();
      if (!groupSnap.exists) throw new HttpsError("not-found", "Grupo no encontrado.");
      const g = groupSnap.data();

      if (status === "approved") {
        // Leer duración desde config según plan del grupo
        const preciosDoc = await db.collection("config").doc("precios_planes").get();
        const cfg = preciosDoc.data() || {};
        const planKey = (g.plan === "docente") ? "espacial_grupal_texto" : "espacial_grupal_texto_imagen";
        const duracionDias = (cfg.planes_grupales?.[planKey]?.duracion_dias) || 30;

        const now = admin.firestore.Timestamp.now();
        const expires = admin.firestore.Timestamp.fromDate(new Date(now.toDate().getTime() + duracionDias * 24 * 60 * 60 * 1000));

        // 1) Actualizar doc del grupo
        await groupRef.update({
          status: "active",
          paidAt: now,
          expiresAt: expires,
          metodoPago: paymentInfo.body.payment_method_id || null,
          montoPagado: paymentInfo.body.transaction_amount || null,
        });

        // 2) Registrar en subcolección pagos
        await groupRef.collection("pagos").add({
          amountPaid: paymentInfo.body.transaction_amount || 0,
          membersPaidFor: g.memberCount || 0,
          method: paymentInfo.body.payment_method_id || "",
          paidAt: now,
          status: "success",
          paymentId: paymentInfo.body.id,
        });

        // 3) Pasar miembros a active
        const miembrosSnap = await groupRef.collection("miembros").get();
        const batch = db.batch();
        miembrosSnap.forEach((d) => batch.update(d.ref, { status: "active" }));
        await batch.commit();

        // 4) Historial
        await groupRef.collection("historial").add({
          tipo: "grupo_pagado",
          fecha: now,
          uid: adminUid,
        });

        return res.status(200).send("OK");
      }

      // Estados no aprobados
      await groupRef.collection("pagos").add({
        amountPaid: paymentInfo.body.transaction_amount || 0,
        membersPaidFor: g.memberCount || 0,
        method: paymentInfo.body.payment_method_id || "",
        paidAt: admin.firestore.Timestamp.now(),
        status: status === "pending" ? "pending" : "failed",
        paymentId: paymentInfo.body.id,
      });

      return res.status(200).send("OK");
    }

    // ---------------- PLAN INDIVIDUAL ----------------
    if (metadata.tipo === "plan_individual") {
      const userId = metadata.userId;
      const planId = metadata.planId;
      const duracionDias = metadata.duracionDias;
      if (!userId || !planId || !duracionDias) return res.status(400).send("Bad Request: missing metadata");

      const userRef = db.collection("users").doc(userId);

      if (status === "approved") {
        const now = admin.firestore.Timestamp.now();
        const venc = admin.firestore.Timestamp.fromDate(new Date(now.toDate().getTime() + duracionDias * 24 * 60 * 60 * 1000));

        await userRef.update({
          planContratado: planId,
          fechaInicioSuscripcion: now,
          fechaFinSuscripcion: venc,
          estadoSuscripcion: "activo",
        });
      }
      return res.status(200).send("OK");
    }

    // ---------------- PAQUETE (recarga) ----------------
    if (metadata.tipo === "paquete") {
      const userId = metadata.userId;
      const cantidadPrompts = Number(metadata.cantidadPrompts || 0);
      const tipoPrompt = metadata.tipoPrompt || "texto";

      if (status === "approved" && userId && cantidadPrompts > 0) {
        const userRef = db.collection("users").doc(userId);
        await db.runTransaction(async (tx) => {
          const u = await tx.get(userRef);
          const data = u.data() || {};
          const promptsActuales = Number(data.saldoPromptsComprados || 0) + cantidadPrompts;
          const update = { saldoPromptsComprados: promptsActuales };
          if (tipoPrompt === "texto_imagen") {
            update.imagenesRestantes = Number(data.imagenesRestantes || 0) + cantidadPrompts;
          }
          tx.update(userRef, update);
        });
      }
      return res.status(200).send("OK");
    }

    // Tipos no manejados
    return res.status(200).send("OK");
  } catch (err) {
    functions.logger.error("webhookMercadoPago error:", err);
    return res.status(500).send("Internal Server Error");
  }
});
