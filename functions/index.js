// functions/index.js
const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp();

const auth = require("./auth");
const consultas = require("./consultas");
const getPlanesGrupales = require("./getPlanesGrupales");
const grupos = require("./creargrupos");
const paquetes = require("./paquetes");
const planesIndividuales = require("./planes_individuales");
const webhook = require("./webhook");
const demoPago = require("./demo_pago");
const notificaciones = require("./notificaciones");
const support = require("./support");
const reports = require("./reports");

module.exports = {
  // 🔐 Auth
  ...auth,

  // 📄 Consultas externas
  ...consultas,

  // 📦 Paquetes
  procesarPagoPaquete: paquetes.procesarPagoPaquete,

  // 👤 Planes individuales
  procesarPagoIndividual: planesIndividuales.procesarPagoIndividual,

  // 👥 Grupos
  crearGrupo: grupos.crearGrupo,
  unirseAGrupo: grupos.unirseAGrupo,
  cerrarGrupo: grupos.cerrarGrupo,
  crearPagoGrupal: grupos.crearPagoGrupal,

  // 📡 Webhook MercadoPago
  ...webhook,

  // 💳 Demo de pago
  demoPago: demoPago.demoPago,

  // 🔔 Notificaciones push
  ...notificaciones,

  // 🛠️ Funciones de soporte
  ...support,

  // 📊 Reportes
  ...reports,
};
