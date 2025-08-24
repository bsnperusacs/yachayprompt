// Archivo: functions/paquetes.js

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const mercadopago = require("mercadopago");

const db = admin.firestore();

// Configuración de Mercado Pago (asegúrate de que el token esté en Config Vars)
mercadopago.configurations.setAccessToken(process.env.MP_ACCESS_TOKEN);

exports.procesarPagoPaquete = onCall(async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Debes estar autenticado.");
  }

  const { paqueteId, descripcion, precio } = request.data;
  if (!paqueteId || !descripcion || !precio) {
    throw new HttpsError("invalid-argument", "Faltan datos del paquete.");
  }

  // 🔹 Validar que el usuario tenga un plan activo
  const userRef = db.collection("users").doc(userId);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new HttpsError("not-found", "Usuario no encontrado.");
  }

  const userData = userDoc.data();
  const ahora = admin.firestore.Timestamp.now();

  if (
    userData.estadoSuscripcion !== "activo" ||
    !userData.fechaFinSuscripcion ||
    userData.fechaFinSuscripcion.toDate() < ahora.toDate()
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Debes tener un plan activo para poder comprar un paquete."
    );
  }

  // 🔹 Crear preferencia de pago en Mercado Pago
  const preference = {
    items: [
      {
        id: paqueteId,
        title: descripcion,
        quantity: 1,
        currency_id: "PEN",
        unit_price: precio,
      },
    ],
    metadata: {
      userId,
      tipo: "paquete",
      paqueteId,
    },
  };

  try {
    const response = await mercadopago.preferences.create(preference);
    return { init_point: response.body.init_point };
  } catch (error) {
    console.error("Error creando preferencia de MP:", error);
    throw new HttpsError("internal", "Error procesando el pago.");
  }
});
