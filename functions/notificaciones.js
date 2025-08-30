// functions/notificaciones.js
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

/**
 * Envía una notificación push a un usuario específico
 * data: { uid, titulo, cuerpo }
 */
exports.enviarNotificacion = onCall(async (request) => {
  const { uid, titulo, cuerpo } = request.data || {};
  if (!uid || !titulo || !cuerpo) {
    throw new HttpsError("invalid-argument", "Faltan uid, titulo o cuerpo");
  }

  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) throw new HttpsError("not-found", "Usuario no encontrado");

  const { fcmToken } = userDoc.data() || {};
  if (!fcmToken) throw new HttpsError("failed-precondition", "El usuario no tiene token registrado");

  const message = {
    token: fcmToken,
    notification: { title: titulo, body: cuerpo },
  };

  try {
    await admin.messaging().send(message);
    return { success: true };
  } catch (error) {
    console.error("Error enviando notificación:", error);
    throw new HttpsError("internal", "No se pudo enviar la notificación");
  }
});
