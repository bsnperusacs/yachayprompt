// ==========================
// consultas.js
// ==========================

const { defineSecret } = require("firebase-functions/params");
const { onCall: onCallV2, HttpsError: HttpsErrorV2 } = require("firebase-functions/v2/https");
const axios = require("axios");
const admin = require("firebase-admin");

const APIS_NET_PE_TOKEN_SECRET = defineSecret("APIS_NET_PE_TOKEN");
const APIS_NET_PE_TOKEN_VALUE = process.env.APIS_NET_PE_TOKEN;

exports.consultarRUC = onCallV2({ secrets: [APIS_NET_PE_TOKEN_SECRET] }, async (request) => {
  const numeroRUC = request.data.ruc;

  if (!numeroRUC || numeroRUC.length !== 11 || !/^[0-9]+$/.test(numeroRUC)) {
    throw new HttpsErrorV2("invalid-argument", "RUC inválido");
  }

  const cacheRef = admin.firestore().collection("cacheRUC").doc(numeroRUC);
  const doc = await cacheRef.get();

  if (doc.exists) return doc.data();

  const url = `https://api.apis.net.pe/v2/sunat/ruc/full?numero=${numeroRUC}&token=${APIS_NET_PE_TOKEN_VALUE}`;
  const res = await axios.get(url);

  await cacheRef.set({ ...res.data, fechaCacheado: admin.firestore.FieldValue.serverTimestamp() });

  return res.data;
});

exports.consultarDNI = onCallV2({ secrets: [APIS_NET_PE_TOKEN_SECRET] }, async (request) => {
  const numeroDNI = request.data.dni;

  if (!numeroDNI || numeroDNI.length !== 8 || !/^[0-9]+$/.test(numeroDNI)) {
    throw new HttpsErrorV2("invalid-argument", "DNI inválido");
  }

  const cacheRef = admin.firestore().collection("cacheDNI").doc(numeroDNI);
  const doc = await cacheRef.get();

  if (doc.exists) return doc.data();

  const url = `https://api.apis.net.pe/v2/reniec/dni?numero=${numeroDNI}&token=${APIS_NET_PE_TOKEN_VALUE}`;
  const res = await axios.get(url);

  const nombreCompleto = res.data.nombre || `${res.data.nombres} ${res.data.apellidoPaterno} ${res.data.apellidoMaterno}`.trim();
  await cacheRef.set({
    ...res.data,
    nombreCompletoCalculado: nombreCompleto,
    fechaCacheado: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    numeroDocumento: res.data.numeroDocumento || numeroDNI,
    nombres: res.data.nombres || '',
    apellidoPaterno: res.data.apellidoPaterno || '',
    apellidoMaterno: res.data.apellidoMaterno || '',
  };
});
