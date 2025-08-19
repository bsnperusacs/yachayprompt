// Archivo: planes_individuales.js

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { MercadoPagoConfig, Preference } = require("mercadopago"); // CORRECCIÓN: Nueva importación
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin"); // Necesario para Firestore

// Asegúrate de que Firebase Admin SDK se inicialice una sola vez.
if (admin.apps.length === 0) {
    admin.initializeApp();
}

// Define la base de datos de Firestore
const db = admin.firestore();

// Define el secreto para el Access Token de Mercado Pago
const MP_ACCESS_TOKEN = defineSecret("MP_ACCESS_TOKEN");
// Define el secreto para el Webhook URL de Mercado Pago
const MP_WEBHOOK_URL_SECRET = defineSecret("MP_WEBHOOK_URL");

exports.procesarPagoIndividual = onCall({ secrets: [MP_ACCESS_TOKEN, MP_WEBHOOK_URL_SECRET] }, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Solo usuarios autenticados pueden procesar pagos individuales.');
    }
    const userId = request.auth.uid;

    const { planId } = request.data;

    // 1. Validar datos de entrada
    if (!planId) {
        throw new HttpsError('invalid-argument', 'Falta el ID del plan para procesar el pago individual.');
    }

    try {
        // 2. Obtener Precios y Descuentos desde Firestore
        const preciosDoc = await db.collection('config').doc('precios_planes').get();
        if (!preciosDoc.exists) {
            throw new HttpsError('internal', 'Configuración de precios no encontrada en Firestore.');
        }
        const preciosConfig = preciosDoc.data();

        const planesIndividualesConfig = preciosConfig.planes_individuales;
        const descuentosRepresentanteConfig = preciosConfig.descuentos_representante;

        const planDetalles = planesIndividualesConfig[planId];

        if (!planDetalles) {
            throw new HttpsError('invalid-argument', `Plan individual con ID '${planId}' no encontrado en la configuración.`);
        }

        const nombrePlan = planDetalles.nombre;
        const precioBase = planDetalles.precio_regular;
        const duracionDias = planDetalles.duracion_dias;

        // 3. Obtener datos del usuario
        const userDocRef = db.collection('users').doc(userId);
        const userDoc = await userDocRef.get();

        if (!userDoc.exists) {
            throw new HttpsError('not-found', 'No se encontró el perfil del usuario.');
        }
        const userData = userDoc.data();
        const cantidadGruposCreados = userData.cantidadGruposCreados || 0;
        const totalSlotsCompradosEnTodosMisGrupos = userData.totalSlotsCompradosEnTodosMisGrupos || 0;

        // 4. Calcular el precio final
        let precioFinalPago = precioBase;
        let descuentoAplicado = false;

        if (cantidadGruposCreados >= descuentosRepresentanteConfig.nivel_2.min_grupos &&
            totalSlotsCompradosEnTodosMisGrupos >= descuentosRepresentanteConfig.nivel_2.min_total_slots) {
            precioFinalPago = descuentosRepresentanteConfig.nivel_2.precio;
            descuentoAplicado = true;
        } else if (cantidadGruposCreados >= descuentosRepresentanteConfig.nivel_1.min_grupos &&
            totalSlotsCompradosEnTodosMisGrupos >= descuentosRepresentanteConfig.nivel_1.min_total_slots) {
            precioFinalPago = descuentosRepresentanteConfig.nivel_1.precio;
            descuentoAplicado = true;
        }

        // 5. Crear una preferencia de pago en Mercado Pago
        const MERCADOPAGO_ACCESS_TOKEN = MP_ACCESS_TOKEN.value();
        const MERCADOPAGO_WEBHOOK_URL = MP_WEBHOOK_URL_SECRET.value();

        if (!MERCADOPAGO_ACCESS_TOKEN) {
            throw new HttpsError('internal', 'Access Token de Mercado Pago no configurado. Contactar soporte.');
        }
        if (!MERCADOPAGO_WEBHOOK_URL) {
            throw new HttpsError('internal', 'URL de webhook de Mercado Pago no configurada. Contactar soporte.');
        }

        // CORRECCIÓN CLAVE: Inicializar el cliente del SDK moderno
        const client = new MercadoPagoConfig({
            accessToken: MERCADOPAGO_ACCESS_TOKEN
        });
        const preference = new Preference(client);

        const result = await preference.create({
            body: { // El 'body' sí es necesario al crear la preferencia con el nuevo SDK
                items: [
                    {
                        title: nombrePlan,
                        quantity: 1,
                        unit_price: parseFloat(precioFinalPago.toFixed(2)),
                        currency_id: "PEN"
                    },
                ],
                metadata: {
                    tipo: "plan_individual",
                    userId: userId,
                    planId: planId,
                    nombrePlan: nombrePlan,
                    precioPagado: parseFloat(precioFinalPago.toFixed(2)),
                    duracionDias: duracionDias,
                    descuentoAplicado: descuentoAplicado,
                },
                back_urls: {
                    success: `https://www.google.com`, // Usando URLs genéricas por ahora
                    failure: `https://www.google.com`,
                    pending: `https://www.google.com`,
                },
                notification_url: MERCADOPAGO_WEBHOOK_URL,
                auto_return: "approved",
                binary_mode: true,
            }
        });

        // Se retorna la URL de pago para que la app de Flutter la abra
        return {
            success: true,
            preferenceId: result.id, // CORRECCIÓN: El nuevo SDK devuelve 'id' directamente
            checkoutUrl: result.init_point, // CORRECCIÓN: El nuevo SDK devuelve 'init_point' directamente
            precioMostrado: precioFinalPago,
            descuentoAplicado: descuentoAplicado,
        };

    } catch (error) {
        // Loguear el error completo para debug
        console.error("Error al procesar el pago en Cloud Function:", error);
        // Lanzar un error más específico para que el cliente lo maneje
        throw new HttpsError('internal', 'Hubo un error al crear la preferencia de pago. Por favor, inténtalo de nuevo más tarde.', error.message);
    }
});
