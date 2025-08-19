// backend_creargrupos_opt.js
// Firebase Functions (v2) - Backend optimizado para creación y manejo de grupos
// Recomendaciones: desplegar en un proyecto Firebase con Firestore y definir secretos
// MP_ACCESS_TOKEN y MP_WEBHOOK_URL con `firebase functions:secrets:manager`.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { MercadoPagoConfig, Preference } = require('mercadopago');

// Inicializar admin si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// Secrets (defínelos con `firebase functions:secrets:manager:set ...`)
const MP_ACCESS_TOKEN = defineSecret('MP_ACCESS_TOKEN');
const MP_WEBHOOK_URL = defineSecret('MP_WEBHOOK_URL');

// Constantes
const INVITATION_CODE_LENGTH = 6;
const INVITATION_MAX_ATTEMPTS = 20;
const MIN_MIEMBROS = 5;
const MAX_MIEMBROS = 12;

// --- Util: generar código único de invitación ---
async function generarCodigoInvitacionUnico() {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const charactersLength = characters.length;
  for (let attempt = 0; attempt < INVITATION_MAX_ATTEMPTS; attempt++) {
    let code = '';
    for (let i = 0; i < INVITATION_CODE_LENGTH; i++) {
      code += characters.charAt(Math.floor(Math.random() * charactersLength));
    }
    const snapshot = await db.collection('grupos').where('codigoInvitacion', '==', code).limit(1).get();
    if (snapshot.empty) return code;
  }
  throw new HttpsError('internal', 'No se pudo generar un código de invitación único. Inténtalo de nuevo.');
}

// --- Util: leer configuración de planes desde Firestore (config/planes) ---
async function obtenerPlanesConfig() {
  const doc = await db.collection('config').doc('planes').get();
  if (!doc.exists) {
    throw new HttpsError('not-found', 'No se encontró la configuración de planes en config/planes.');
  }
  const data = doc.data();
  // Esperamos que data.planes sea un array con objects { id, precioIndividual, precioGrupal, nombre }
  const planes = data.planes || [];
  return planes;
}

// --- Util: recalcula precios y estado de un grupo - retorna { nuevosMiembros, nuevoEstado, total } ---
async function recalcularGrupoYPrecios(grupoSnapshot) {
  const planesConfig = await obtenerPlanesConfig();
  const grupo = grupoSnapshot.data();
  const miembros = grupo.miembros || [];

  // Determinar si aplica precio grupal
  const aplicarPrecioGrupal = miembros.length >= MIN_MIEMBROS;

  const nuevosMiembros = miembros.map(miembro => {
    const plan = planesConfig.find(p => p.id === miembro.planId);
    if (!plan) return miembro; // si no se encuentra plan, devolvemos tal cual (pero idealmente no debería pasar)

    const precio = aplicarPrecioGrupal ? parseFloat(plan.precioGrupal) : parseFloat(plan.precioIndividual);
    return { ...miembro, precioPlan: precio };
  });

  const nuevoEstado = grupo.estado === 'pagado' ? 'pagado' : (aplicarPrecioGrupal ? 'listo_pago' : 'apertura');
  const total = nuevosMiembros.reduce((s, m) => s + (parseFloat(m.precioPlan) || 0), 0);

  return { nuevosMiembros, nuevoEstado, total };
}

// --- Función: Crear grupo (apertura de vacantes) ---
exports.crearGrupoCloudFunction = onCall(
  { secrets: [MP_ACCESS_TOKEN, MP_WEBHOOK_URL] },
  async (request) => {
    const { nombreGrupo, planRepresentanteId, representanteUid, representanteNombre } = request.data;

    if (!nombreGrupo || !planRepresentanteId || !representanteUid || !representanteNombre) {
      throw new HttpsError('invalid-argument', 'Faltan parámetros requeridos.');
    }

    try {
      // Obtener precios seguros desde config
      const planesConfig = await obtenerPlanesConfig();
      const planRepresentante = planesConfig.find(p => p.id === planRepresentanteId);
      if (!planRepresentante) {
        throw new HttpsError('not-found', 'El plan seleccionado para el representante no existe en configuración.');
      }

      const codigoInvitacion = await generarCodigoInvitacionUnico();

      const nuevoGrupoRef = db.collection('grupos').doc();

      const miembroRepresentante = {
        uid: representanteUid,
        nombre: representanteNombre,
        rol: 'representante',
        planId: planRepresentanteId,
        precioPlan: parseFloat(planRepresentante.precioIndividual), // inicia con precio individual
        fechaUnion: FieldValue.serverTimestamp(),
      };

      const grupoObj = {
        nombreGrupo: nombreGrupo,
        codigoInvitacion: codigoInvitacion,
        estado: 'apertura',
        representanteUid: representanteUid,
        miembros: [miembroRepresentante],
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      await nuevoGrupoRef.set(grupoObj);

      return {
        success: true,
        grupoId: nuevoGrupoRef.id,
        codigoInvitacion: codigoInvitacion,
      };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error('Error al crear grupo:', e);
      throw new HttpsError('internal', 'Error interno al crear el grupo.');
    }
  }
);

// --- Función: Unirse a grupo con manejo transaction para concurrencia ---
exports.unirseAGrupoCloudFunction = onCall(
  { secrets: [] },
  async (request) => {
    const { codigoInvitacion, miembroUid, miembroNombre, planSeleccionadoId } = request.data;

    if (!codigoInvitacion || !miembroUid || !miembroNombre || !planSeleccionadoId) {
      throw new HttpsError('invalid-argument', 'Faltan parámetros requeridos.');
    }

    try {
      const grupoQuery = await db.collection('grupos').where('codigoInvitacion', '==', codigoInvitacion).limit(1).get();
      if (grupoQuery.empty) throw new HttpsError('not-found', 'El código de invitación no es válido.');

      const grupoRef = grupoQuery.docs[0].ref;

      // Usar transaction para evitar condiciones de carrera
      await db.runTransaction(async (tx) => {
        const snapshot = await tx.get(grupoRef);
        if (!snapshot.exists) throw new HttpsError('not-found', 'Grupo no existe.');

        const grupo = snapshot.data();

        if (grupo.estado === 'pagado') {
          throw new HttpsError('failed-precondition', 'El grupo ya fue pagado y no acepta nuevos miembros.');
        }

        const miembros = grupo.miembros || [];

        // Verificar si ya es miembro
        if (miembros.some(m => m.uid === miembroUid)) {
          // No lanzamos error, devolvemos resultado: ya es miembro
          return;
        }

        // Validar limite maximo
        if (miembros.length >= MAX_MIEMBROS) {
          throw new HttpsError('failed-precondition', 'El grupo ha alcanzado el número máximo de miembros.');
        }

        // Verificar que el plan existe en la config
        const planesConfig = await obtenerPlanesConfig();
        const planSeleccionado = planesConfig.find(p => p.id === planSeleccionadoId);
        if (!planSeleccionado) throw new HttpsError('not-found', 'El plan seleccionado no existe.');

        // Construir el nuevo miembro con precio individual por defecto
        const nuevoMiembro = {
          uid: miembroUid,
          nombre: miembroNombre,
          rol: 'miembro',
          planId: planSeleccionadoId,
          precioPlan: parseFloat(planSeleccionado.precioIndividual),
          fechaUnion: FieldValue.serverTimestamp(),
        };

        const nuevosMiembrosArray = [...miembros, nuevoMiembro];

        // Recalcular precios y estado
        const aplicarPrecioGrupal = nuevosMiembrosArray.length >= MIN_MIEMBROS;

        const miembrosActualizados = nuevosMiembrosArray.map(m => {
          const cfg = planesConfig.find(p => p.id === m.planId);
          if (!cfg) return m; // si no existe config del plan, lo dejamos
          const precio = aplicarPrecioGrupal ? parseFloat(cfg.precioGrupal) : parseFloat(cfg.precioIndividual);
          return { ...m, precioPlan: precio };
        });

        const nuevoEstado = aplicarPrecioGrupal ? 'listo_pago' : 'apertura';

        tx.update(grupoRef, {
          miembros: miembrosActualizados,
          estado: nuevoEstado,
          updatedAt: FieldValue.serverTimestamp(),
        });

        return;
      });

      return { success: true };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error('Error al unirse al grupo:', e);
      throw new HttpsError('internal', 'Error interno al unirse al grupo.');
    }
  }
);

// --- Función: Crear preferencia de pago grupal (solo representante) ---
exports.crearPagoGrupal = onCall(
  { secrets: [MP_ACCESS_TOKEN, MP_WEBHOOK_URL] },
  async (request) => {
    const { grupoId, representanteUid } = request.data;

    if (!grupoId || !representanteUid) {
      throw new HttpsError('invalid-argument', 'Faltan parámetros requeridos.');
    }

    try {
      const grupoRef = db.collection('grupos').doc(grupoId);
      const grupoSnap = await grupoRef.get();
      if (!grupoSnap.exists) throw new HttpsError('not-found', 'Grupo no encontrado.');

      const grupo = grupoSnap.data();

      if (grupo.representanteUid !== representanteUid) {
        throw new HttpsError('permission-denied', 'Solo el representante puede iniciar el pago.');
      }

      if ((grupo.miembros || []).length < MIN_MIEMBROS) {
        throw new HttpsError('failed-precondition', 'El grupo aún no cumple con el mínimo de miembros.');
      }

      if (grupo.estado === 'pagado') {
        throw new HttpsError('failed-precondition', 'El grupo ya fue pagado.');
      }

      // Recalcular precios finales y total (fuente de verdad: config)
      const planesConfig = await obtenerPlanesConfig();
      const recalculo = await recalcularGrupoYPrecios(grupoSnap);
      const total = parseFloat(recalculo.total.toFixed(2));

      // Crear preferencia Mercado Pago
      const client = new MercadoPagoConfig({ accessToken: MP_ACCESS_TOKEN.value() });
      const preference = new Preference(client);

      const items = [
        {
          id: grupoId,
          title: `Suscripción grupal (${grupo.nombreGrupo}) - ${ (grupo.miembros || []).length } miembros`,
          quantity: 1,
          unit_price: total,
          currency_id: 'PEN',
        },
      ];

      const result = await preference.create({
        body: {
          items,
          external_reference: `${representanteUid}_${grupoId}`,
          metadata: {
            tipo: 'plan_grupal',
            grupoId: grupoId,
            representanteUid: representanteUid,
            numMiembros: (grupo.miembros || []).length,
            precioTotal: total,
          },
          back_urls: {
            success: `https://yachayprompts.page.link/exito?grupoId=${grupoId}`,
            failure: `https://yachayprompts.page.link/fallo?grupoId=${grupoId}`,
            pending: `https://yachayprompts.page.link/pendiente?grupoId=${grupoId}`,
          },
          notification_url: MP_WEBHOOK_URL.value(),
          auto_return: 'approved',
          binary_mode: true,
        },
      });

      // Optionally: Guardar preferenciaId y total en el documento de grupo
      await grupoRef.update({
        preferenceId: result.id,
        totalAPagar: total,
        updatedAt: FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        preferenceId: result.id,
        checkoutUrl: result.init_point,
      };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error('Error al crear pago grupal:', e);
      throw new HttpsError('internal', 'Error interno al crear el pago.');
    }
  }
);

// --- Webhook / Notificación (ejemplo básico) ---
// Recomendación: crear una función HTTP separada para recibir notificaciones de MP y validar firmas.
// Cuando confirmes pago, actualiza grupo.estado = 'pagado' y registra pago en subcolección 'pagos'.

// --- Fin del archivo ---
