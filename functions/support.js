// functions/support.js
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

/**
 * Forzar creación de un nuevo grupo aunque el anterior no cumpla la regla de min_miembros_para_nuevo_grupo.
 * data: { adminUid }
 */
exports.autorizarNuevoGrupo = onCall(async (request) => {
  const { adminUid } = request.data || {};
  if (!adminUid) throw new HttpsError("invalid-argument", "Falta adminUid");

  // Aquí podrías validar que el que llama es un "superadmin"
  // Ejemplo: verificar en custom claims o un flag en users

  await db.collection("users").doc(adminUid).update({
    overrideNuevoGrupo: true,
  });

  return { success: true };
});

/**
 * Forzar un grupo a estado activo (ej. soporte corrige un pago mal registrado).
 * data: { groupId }
 */
exports.forzarGrupoActivo = onCall(async (request) => {
  const { groupId } = request.data || {};
  if (!groupId) throw new HttpsError("invalid-argument", "Falta groupId");

  const ref = db.collection("grupos").doc(groupId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Grupo no existe");

  await ref.update({
    status: "active",
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});
