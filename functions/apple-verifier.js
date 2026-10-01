/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {readFileSync} = require("node:fs");
const {join} = require("node:path");
const {SignedDataVerifier, AppStoreServerAPIClient} = require("@apple/app-store-server-library");
const {check} = require("./wallet-ledger");

function createAppleVerifier({environment, appAppleId, keyID, issuerID, signingKey}) {
  check(["Production", "Sandbox"].includes(environment) && keyID && issuerID && signingKey, "Apple configuration required");
  check(environment !== "Production" || (Number.isSafeInteger(appAppleId) && appAppleId > 0), "Apple app ID required");
  const bundleID = "com.rkdp.app";
  const verifier = new SignedDataVerifier([readFileSync(join(__dirname, "apple-root-g3.pem"))], true, environment, bundleID, appAppleId);
  const client = new AppStoreServerAPIClient(signingKey, keyID, issuerID, bundleID, environment);
  return {
    notification: (payload) => verifier.verifyAndDecodeNotification(payload),
    currentTransaction: async (signed) => {
      const original = await verifier.verifyAndDecodeTransaction(signed);
      const response = await client.getTransactionInfo(original.transactionId);
      check(response.signedTransactionInfo, "Apple transaction unavailable");
      const current = await verifier.verifyAndDecodeTransaction(response.signedTransactionInfo);
      check(current.transactionId === original.transactionId && current.productId === original.productId &&
        current.originalTransactionId === original.originalTransactionId && current.signedDate >= original.signedDate,
      "Apple transaction state is stale or inconsistent");
      return current;
    },
  };
}
module.exports = {createAppleVerifier};
