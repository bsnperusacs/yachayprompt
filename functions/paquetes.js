// Archivo: functions/paquetes.js
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const mercadopago = require("mercadopago");
const { defineSecret } = require("firebase-functions/params");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const MP_ACCESS_TOKEN = defineSecret("MP_ACCESS_TOKEN");
const MP_WEBHOOK_URL = defineSecret("MP_WEBHOOK_URL");

exports.procesarPagoPaquete = onCall({ secrets: [MP_ACCESS_TOKEN, MP_WEBHOOK_URL] }, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError("unauthenticated", "Debes estar autenticado.");

  const { paqueteId, descripcion, precio, cantidadPrompts, tipoPrompt } = request.data || {};
  if (!paqueteId || !descripcion || !precio || !cantidadPrompts) {
    throw new HttpsError("invalid-argument", "Faltan datos del paquete.");
  }

  // Validar plan activo
  const userRef = db.collection("users").doc(userId);
  const userDoc = await userRef.get();
  if (!userDoc.exists) throw new HttpsError("not-found", "Usuario no encontrado.");

  const ahora = admin.firestore.Timestamp.now();
  const u = userDoc.data() || {};
  if (u.estadoSuscripcion !== "activo" || !u.fechaFinSuscripcion || u.fechaFinSuscripcion.toDate() < ahora.toDate()) {
    throw new HttpsError("failed-precondition", "Debes tener un plan activo para poder comprar un paquete.");
  }

  mercadopago.configure({ access_token: MP_ACCESS_TOKEN.value() });

  const preference = {
    items: [{ id: paqueteId, title: descripcion, quantity: 1, currency_id: "PEN", unit_price: Number(precio) }],
    metadata: {
      tipo: "paquete",
      userId,
      paqueteId,
      cantidadPrompts: Number(cantidadPrompts),
      tipoPrompt: tipoPrompt || "texto",
    },
    notification_url: MP_WEBHOOK_URL.value(),
    auto_return: "approved",
  };

  try {
    const response = await mercadopago.preferences.create(preference);
    return { init_point: response.body.init_point };
  } catch (error) {
    console.error("Error creando preferencia de MP:", error);
    throw new HttpsError("internal", "Error procesando el pago.");
  }
});
