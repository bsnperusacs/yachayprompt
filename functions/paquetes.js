// Archivo: paquetes.js

const { onCall, HttpsError } = require("firebase-functions/v2/https");
// --- CAMBIO CLAVE: Importación del SDK moderno ---
const { MercadoPagoConfig, Preference } = require("mercadopago");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

const db = admin.firestore();

// Define los secretos
const MP_ACCESS_TOKEN = defineSecret("MP_ACCESS_TOKEN");
const MP_WEBHOOK_URL_SECRET = defineSecret("MP_WEBHOOK_URL");

exports.procesarPagoPaquete = onCall({ secrets: [MP_ACCESS_TOKEN, MP_WEBHOOK_URL_SECRET] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Solo usuarios autenticados pueden procesar pagos de paquetes.');
  }

  const userId = request.auth.uid;
  const { paqueteId } = request.data;

  if (!paqueteId) {
    throw new HttpsError('invalid-argument', 'Falta el ID del paquete para procesar el pago.');
  }

  // Obtener configuración de precios
  const preciosDoc = await db.collection('config').doc('precios_planes').get();
  if (!preciosDoc.exists) {
    throw new HttpsError('internal', 'Configuración de precios no encontrada en Firestore.');
  }

  const paquetesPromptsConfig = preciosDoc.data().paquetes_prompts;
  const paqueteDetalles = paquetesPromptsConfig[paqueteId];

  if (!paqueteDetalles) {
    throw new HttpsError('invalid-argument', `Paquete de prompts con ID '${paqueteId}' no encontrado.`);
  }

  const nombrePaquete = paqueteDetalles.nombre;
  const precioPaquete = paqueteDetalles.precio;
  const cantidadPromptsPaquete = paqueteDetalles.cantidad_prompts;

  // --- CAMBIO CLAVE: Inicialización del cliente con el SDK moderno ---
  const MERCADOPAGO_ACCESS_TOKEN = MP_ACCESS_TOKEN.value();
  const MERCADOPAGO_WEBHOOK_URL = MP_WEBHOOK_URL_SECRET.value();

  if (!MERCADOPAGO_WEBHOOK_URL) {
    throw new HttpsError('internal', 'URL de webhook no configurada.');
  }

  const client = new MercadoPagoConfig({ accessToken: MERCADOPAGO_ACCESS_TOKEN });
  const preference = new Preference(client);

  // --- CAMBIO CLAVE: Creación de la preferencia usando el objeto 'body' ---
  const result = await preference.create({
    body: {
      items: [
        {
          title: nombrePaquete,
          quantity: 1,
          unit_price: parseFloat(precioPaquete.toFixed(2)),
          currency_id: "PEN"
        },
      ],
      metadata: {
        tipo: "paquete",
        userId,
        paqueteId,
        cantidadPrompts: cantidadPromptsPaquete,
        precioPagado: parseFloat(precioPaquete.toFixed(2)),
      },
      back_urls: {
        success: "https://yachayprompts.page.link/exito",
        failure: "https://yachayprompts.page.link/fallo",
        pending: "https://yachayprompts.page.link/pendiente",
      },
      notification_url: MERCADOPAGO_WEBHOOK_URL,
      auto_return: "approved",
      binary_mode: true,
    },
  });

  return {
    success: true,
    preferenceId: result.id, // El nuevo SDK devuelve 'id'
    checkoutUrl: result.init_point, // El nuevo SDK devuelve 'init_point'
    precioMostrado: parseFloat(precioPaquete.toFixed(2)),
  };
});