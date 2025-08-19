const { onCall, onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();

const auth = require("./auth");
const consultas = require("./consultas");
const getPlanesGrupales = require("./getPlanesGrupales");
const creargrupos = require("./creargrupos");
const paquetes = require("./paquetes");
const planesIndividuales = require("./planes_individuales");
const webhook = require("./webhook");

// ⬇️ NUEVO: demo de pago único S/ 1.99
const demoPago = require("./demo_pago");

module.exports = {
  // 🔐 Funciones de autenticación
  ...auth,

  // 🧾 Consultas RUC/DNI
  ...consultas,

  // 📦 Paquetes individuales
  procesarPagoPaquete: paquetes.procesarPagoPaquete,

  // 🎯 Planes individuales
  procesarPagoIndividual: planesIndividuales.procesarPagoIndividual,

  // 👥 Planes grupales
  crearGrupoConPago: creargrupos.crearGrupoConPago,
  ...getPlanesGrupales,

  // 📡 Webhook de Mercado Pago
  ...webhook,

  // 💳 Demo pago único (S/ 1.99)
  demoPago: demoPago.demoPago,
};
