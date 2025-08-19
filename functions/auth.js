// ==========================
// auth.js
// ==========================

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");

exports.testAuthContext = onCall(async (request) => {
  logger.info("testAuthContext llamada.");
  if (request.auth) {
    return {
      status: "Autenticado",
      uid: request.auth.uid,
      email: request.auth.token.email || "Email no disponible",
      tokenClaims: request.auth.token,
    };
  } else {
    throw new HttpsError(
      "unauthenticated",
      "request.auth no fue recibido por la función testAuthContext."
    );
  }
});