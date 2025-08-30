// Archivo: functions/creargrupos.js
// Cloud Functions v2 – Flujo de grupos (crear, unirse, cerrar, pagar)

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { MercadoPagoConfig, Preference } = require("mercadopago");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const MP_ACCESS_TOKEN = defineSecret("MP_ACCESS_TOKEN");
const MP_WEBHOOK_URL = defineSecret("MP_WEBHOOK_URL");

// Mapeo entre tu campo `plan` del grupo y las claves de `planes_grupales` en config
const PLAN_KEYS = {
  docente: "espacial_grupal_texto",
  creativo: "espacial_grupal_texto_imagen",
};

// -------------------- Utils --------------------

async function generarCodigoInvitacionUnico(len = 6, maxTry = 20) {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  for (let t = 0; t < maxTry; t++) {
    let code = "";
    for (let i = 0; i < len; i++) code += chars[Math.floor(Math.random() * chars.length)];
    const snap = await db.collection("grupos").where("inviteCode", "==", code).limit(1).get();
    if (snap.empty) return code;
  }
  throw new HttpsError("internal", "No se pudo generar un código único. Intenta otra vez.");
}

async function leerConfigPrecios() {
  const doc = await db.collection("config").doc("precios_planes").get();
  if (!doc.exists) throw new HttpsError("internal", "Falta config/precios_planes.");
  const data = doc.data();
  const reglas = data.reglas || { min_miembros_por_grupo: 5, max_miembros_por_grupo: 12 };
  return {
    reglas,
    planesGrupales: data.planes_grupales || {},
    planesIndividuales: data.planes_individuales || {},
  };
}

function deepLinkFromCode(code) {
  return `yachayprompt://join?code=${code}`;
}

// Precio por slot según si ya llegó al mínimo (precio grupal) o no (precio individual equivalente)
function resolverPrecioSlot(cfg, plan, aplicaGrupal) {
  const grupalKey = PLAN_KEYS[plan];
  if (!grupalKey) throw new HttpsError("invalid-argument", `Plan no soportado: ${plan}`);
  if (aplicaGrupal) {
    const planGrupal = cfg.planesGrupales[grupalKey];
    if (!planGrupal) throw new HttpsError("internal", `No existe plan grupal ${grupalKey} en config.`);
    return Number(planGrupal.precio_por_slot);
  }
  // equivalente individual
  const indKey = plan === "docente" ? "basico" : "creativo";
  const planInd = cfg.planesIndividuales[indKey];
  if (!planInd) throw new HttpsError("internal", `No existe plan individual ${indKey} en config.`);
  return Number(planInd.precio_regular);
}

// -------------------- 1) Crear grupo --------------------

exports.crearGrupo = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Inicia sesión.");

  const { plan, nombreGrupo } = request.data || {};
  if (!plan || !PLAN_KEYS[plan]) {
    throw new HttpsError("invalid-argument", "plan debe ser 'docente' o 'creativo'.");
  }

  const code = await generarCodigoInvitacionUnico();
  const docRef = db.collection("grupos").doc();

  await docRef.set({
    adminUid: uid,
    plan,                                 // "docente" | "creativo"
    status: "open",                        // open | closed | active
    inviteCode: code,
    deepLink: deepLinkFromCode(code),
    memberCount: 0,
    createdAt: FieldValue.serverTimestamp(),
    nombreGrupo: nombreGrupo || null,
  });

  return { success: true, groupId: docRef.id, inviteCode: code, deepLink: deepLinkFromCode(code) };
});

// -------------------- 2) Unirse a grupo (por código) --------------------

exports.unirseAGrupo = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Inicia sesión.");

  const { inviteCode, planType, displayName, email } = request.data || {};
  if (!inviteCode || !planType) {
    throw new HttpsError("invalid-argument", "Faltan inviteCode o planType.");
  }
  if (!["docente", "creativo"].includes(planType)) {
    throw new HttpsError("invalid-argument", "planType inválido.");
  }

  const q = await db.collection("grupos").where("inviteCode", "==", inviteCode).limit(1).get();
  if (q.empty) throw new HttpsError("not-found", "Código inválido.");

  const groupRef = q.docs[0].ref;

  await db.runTransaction(async (tx) => {
    const gSnap = await tx.get(groupRef);
    if (!gSnap.exists) throw new HttpsError("not-found", "Grupo no existe.");
    const g = gSnap.data();

    if (g.status !== "open") {
      throw new HttpsError("failed-precondition", "El grupo no acepta nuevos miembros.");
    }

    const cfg = await leerConfigPrecios();
    const max = cfg.reglas.max_miembros_por_grupo || 12;
    const min = cfg.reglas.min_miembros_por_grupo || 5;

    // Límite superior
    if ((g.memberCount || 0) >= max) {
      throw new HttpsError("failed-precondition", "El grupo alcanzó el máximo de miembros.");
    }

    // Evitar duplicado
    const miembroRef = groupRef.collection("miembros").doc(uid);
    const miembroSnap = await tx.get(miembroRef);
    if (miembroSnap.exists) return; // ya estaba

    // Crear miembro
    tx.set(miembroRef, {
      uid,
      displayName: displayName || null,
      email: email || null,
      planType,                 // "docente" | "creativo" por miembro
      status: "pending",        // pasa a active cuando se paga el grupo
      joinedAt: FieldValue.serverTimestamp(),
    });

    // Actualizar contador
    tx.update(groupRef, { memberCount: FieldValue.increment(1) });

    // Si llegó al mínimo y quieres forzar cierre automático, podrías:
    // if ((g.memberCount || 0) + 1 >= min) tx.update(groupRef, { status: "closed", closedAt: FieldValue.serverTimestamp() });
  });

  return { success: true };
});

// -------------------- 3) Cerrar grupo (solo admin) --------------------

exports.cerrarGrupo = onCall(async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError("unauthenticated", "Inicia sesión.");

  const { groupId } = request.data || {};
  if (!groupId) throw new HttpsError("invalid-argument", "Falta groupId.");

  const groupRef = db.collection("grupos").doc(groupId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(groupRef);
    if (!snap.exists) throw new HttpsError("not-found", "Grupo no existe.");
    const g = snap.data();

    if (g.adminUid !== adminUid) throw new HttpsError("permission-denied", "No eres el representante.");
    if (g.status !== "open") throw new HttpsError("failed-precondition", "El grupo ya fue cerrado o pagado.");

    const cfg = await leerConfigPrecios();
    const min = cfg.reglas.min_miembros_por_grupo || 5;

    if ((g.memberCount || 0) < min) {
      throw new HttpsError("failed-precondition", `Para cerrar se requieren al menos ${min} miembros.`);
    }

    tx.update(groupRef, { status: "closed", closedAt: FieldValue.serverTimestamp() });
  });

  return { success: true };
});

// -------------------- 4) Crear preferencia de pago (solo admin, grupo cerrado) --------------------

exports.crearPagoGrupal = onCall({ secrets: [MP_ACCESS_TOKEN, MP_WEBHOOK_URL] }, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError("unauthenticated", "Inicia sesión.");

  const { groupId } = request.data || {};
  if (!groupId) throw new HttpsError("invalid-argument", "Falta groupId.");

  const groupRef = db.collection("grupos").doc(groupId);
  const snap = await groupRef.get();
  if (!snap.exists) throw new HttpsError("not-found", "Grupo no existe.");
  const g = snap.data();

  if (g.adminUid !== adminUid) throw new HttpsError("permission-denied", "No eres el representante.");
  if (g.status !== "closed") throw new HttpsError("failed-precondition", "Primero cierra el grupo.");

  const cfg = await leerConfigPrecios();
  const min = cfg.reglas.min_miembros_por_grupo || 5;
  const aplicaGrupal = (g.memberCount || 0) >= min;

  // Calcular el total: cada miembro puede tener planType distinto
  const miembrosSnap = await groupRef.collection("miembros").get();
  let total = 0;
  miembrosSnap.forEach((doc) => {
    const m = doc.data();
    const precio = resolverPrecioSlot(cfg, m.planType || g.plan, aplicaGrupal);
    total += Number(precio || 0);
  });
  total = Math.round(total * 100) / 100;

  const client = new MercadoPagoConfig({ accessToken: MP_ACCESS_TOKEN.value() });
  const preference = new Preference(client);

  const result = await preference.create({
    body: {
      items: [{
        id: groupId,
        title: `Suscripción grupal (${g.nombreGrupo || groupId}) - ${g.memberCount || 0} miembros`,
        quantity: 1,
        unit_price: total,
        currency_id: "PEN",
      }],
      external_reference: `${adminUid}_${groupId}`,
      metadata: { tipo: "plan_grupal", grupoId: groupId, representanteUid: adminUid, numMiembros: g.memberCount || 0, precioTotal: total },
      back_urls: {
        success: `https://yachayprompts.page.link/exito?grupoId=${groupId}`,
        failure: `https://yachayprompts.page.link/fallo?grupoId=${groupId}`,
        pending: `https://yachayprompts.page.link/pendiente?grupoId=${groupId}`,
      },
      notification_url: MP_WEBHOOK_URL.value(),
      auto_return: "approved",
      binary_mode: true,
    },
  });

  await groupRef.update({
    preferenceId: result.id,
    totalAPagar: total,
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { success: true, preferenceId: result.id, checkoutUrl: result.init_point };
});
