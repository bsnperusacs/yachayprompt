// Archivo: getPlanesGrupales.js (CORREGIDO)

const { onCall } = require("firebase-functions/v2/https");
const { getFirestore } = require("firebase-admin/firestore");

const getPlanesGrupales = onCall(async (request) => {
  try {
    const db = getFirestore();
    
    // --- CAMBIO AQUÍ: LEER EL DOCUMENTO CORRECTO ---
    const preciosDoc = await db.collection("config").doc("precios_planes").get();

    if (!preciosDoc.exists) {
        return { success: false, message: "El documento de precios no existe." };
    }

    const planesGrupales = preciosDoc.data().planes_grupales || {};

    const planes = Object.keys(planesGrupales).map((key) => ({
      id: key, // La clave del mapa es el ID del plan
      ...planesGrupales[key],
    }));

    return { success: true, planes };
  } catch (error) {
    console.error("Error al obtener planes grupales:", error);
    return { success: false, message: "Error al obtener planes grupales." };
  }
});

module.exports = { getPlanesGrupales };