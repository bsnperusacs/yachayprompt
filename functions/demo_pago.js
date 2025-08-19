// Archivo: functions/demo_pago.js
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const mercadopago = require("mercadopago");

const MP_ACCESS_TOKEN = defineSecret("MP_ACCESS_TOKEN");

const demoPago = onCall({ secrets: [MP_ACCESS_TOKEN] }, async (request) => {
  const ctx = request.auth;
  if (!ctx || !ctx.uid) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");

  const planId = "demo-pago";           // ← ID fijo del plan demo de pago
  const nombrePlan = "Demo (pago único)";
  const precio = 1.99;                  // ← S/ 1.99
  const duracionDias = 7;

  mercadopago.configure({ access_token: MP_ACCESS_TOKEN.value() });

  const preference = {
    items: [
      { id: planId, title: `YachayPrompt - ${nombrePlan}`, quantity: 1, currency_id: "PEN", unit_price: precio },
    ],
    auto_return: "approved",
    back_urls: {
      success: "https://tudominio.com/checkout/success",
      failure: "https://tudominio.com/checkout/failure",
      pending: "https://tudominio.com/checkout/pending",
    },
    // USA LA MISMA URL QUE YA USAS PARA TUS OTROS PAGOS (tu webhook actual)
    notification_url: "https://us-central1-yachay-prompts.cloudfunctions.net/webhookMercadoPago",
    metadata: { tipo: "plan_individual", userId: ctx.uid, planId, duracionDias },
  };

  const res = await mercadopago.preferences.create(preference);
  return { checkoutUrl: res.body.init_point };
});

module.exports = { demoPago };
