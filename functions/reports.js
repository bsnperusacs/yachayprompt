// functions/reports.js
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

/**
 * Reporte general de grupos: totales, activos, pendientes.
 */
exports.reporteGrupos = onCall(async () => {
  const snap = await db.collection("grupos").get();
  let total = 0, abiertos = 0, cerrados = 0, activos = 0;

  snap.forEach((doc) => {
    total++;
    const { status } = doc.data();
    if (status === "open") abiertos++;
    if (status === "closed") cerrados++;
    if (status === "active") activos++;
  });

  return { total, abiertos, cerrados, activos };
});

/**
 * Reporte de usuarios totales y con plan activo.
 */
exports.reporteUsuarios = onCall(async () => {
  const snap = await db.collection("users").get();
  let total = 0, activos = 0;

  snap.forEach((doc) => {
    total++;
    const { estadoSuscripcion } = doc.data();
    if (estadoSuscripcion === "activo") activos++;
  });

  return { total, activos };
});
