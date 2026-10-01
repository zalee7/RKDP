"use strict";
// Uses the operator's existing Firebase CLI login, in memory. No downloaded
// service-account key, password, ID token, or Apple key is written to disk.
const assert = require("node:assert/strict");
const {randomBytes} = require("node:crypto");
const {execFileSync} = require("node:child_process");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const lib = process.env.FIREBASE_TOOLS_LIB;
if (!lib) throw new Error("Set FIREBASE_TOOLS_LIB to the installed firebase-tools/lib directory");
const {Command} = require(path.join(lib, "command"));
const {requireAuth} = require(path.join(lib, "requireAuth"));
const {getAccessToken} = require(path.join(lib, "apiv2"));
const functionRequire = require("node:module").createRequire(path.join(root, "functions/package.json"));
const {initializeApp} = functionRequire("firebase-admin/app");
const {getAuth} = functionRequire("firebase-admin/auth");
const {Firestore} = functionRequire("@google-cloud/firestore");
// Match Firestore/gax's auth-library version (v9 uses plain header objects;
// the independently installed v10 uses Headers and is not interchangeable).
const gaxRequire = require("node:module").createRequire(functionRequire.resolve("google-gax"));
const {OAuth2Client} = gaxRequire("google-auth-library");
const {provisionPurchaseSandbox} = require(path.join(root, "functions/test-support/provision-purchase-sandbox"));
const project = "puzzlepartytest";
const [mode, uid] = process.argv.slice(2);
assert.ok(mode === "verify-rules" || (["provision", "inspect"].includes(mode) && uid),
    "Expected verify-rules, provision <UID>, or inspect <UID>");
if (uid) assert.match(uid, /^[A-Za-z0-9_-]{1,128}$/, "Invalid UID");

new Command("purchase-test-admin").before(requireAuth).action(async () => {
  const app = initializeApp({projectId: project, credential: {getAccessToken: async () => ({
    access_token: await getAccessToken(), expires_in: 300,
  })}});
  const googleAuth = new OAuth2Client();
  googleAuth.refreshHandler = async () => ({access_token: await getAccessToken(), expiry_date: Date.now() + 3600000});
  const auth = getAuth(app);
  const db = new Firestore({projectId: project, authClient: googleAuth});
  try {
    if (mode === "provision") {
      console.log(JSON.stringify(await provisionPurchaseSandbox({db, auth, uid})));
    } else if (mode === "inspect") {
      const wallet = (await db.doc(`coinWallets/${uid}`).get()).data();
      const user = (await db.doc(`users/${uid}`).get()).data();
      assert.ok(wallet?.purchaseSandbox && user?.purchaseSandbox, "Expected provisioned test account");
      const receipts = await db.collection(`coinWallets/${uid}/receipts`).limit(100).get();
      const purchases = receipts.docs.map((doc) => doc.data()).filter((r) =>
        r.kind === "applePurchase" || r.kind === "appleRefund");
      console.log(JSON.stringify({project, balance: wallet.balance, mirroredCoins: user.coins,
        balancesMatch: wallet.balance === user.coins, revision: wallet.revision,
        walletRankedAccess: wallet.rankedAccess, userRankedAccess: user.rankedAccess,
        receiptScanLimit: 100, receiptScanMayBeTruncated: receipts.size === 100,
        appleReceipts: purchases.map((r) => ({kind: r.kind, productID: r.productID,
          environment: r.environment, delta: r.delta, balanceBefore: r.balanceBefore,
          balance: r.balance, revoked: r.revoked}))}, null, 2));
    } else {
      await verifyRules(auth, db);
    }
  } finally { await db.terminate(); }
}).runner()({project, nonInteractive: true}).catch((e) => {
  // Deliberately avoid raw API errors, which may include credential-bearing requests.
  console.error(JSON.stringify({code: e.code || e.name,
    detail: typeof e.details === "string" ? e.details.slice(0, 600) : undefined}));
  process.exitCode = 1;
});

async function verifyRules(auth, db) {
  const config = JSON.parse(execFileSync("plutil", ["-convert", "json", "-o", "-",
    path.join(root, ".firebase/puzzlepartytest/GoogleService-Info.plist")], {encoding: "utf8"}));
  assert.equal(config.PROJECT_ID, project);
  // Recover only this script's disposable fixtures from an interrupted run.
  const existing = await auth.listUsers(1000);
  for (const user of existing.users.filter((u) => /^rules-[0-9a-f]{24}@example\.invalid$/.test(u.email || ""))) {
    await db.doc(`users/${user.uid}`).delete();
    await db.doc(`coinWallets/${user.uid}`).delete();
    await auth.deleteUser(user.uid);
  }
  const users = []; const docs = []; let passed = 0;
  try {
    for (let i = 0; i < 2; i++) {
      const password = randomBytes(24).toString("base64url");
      const user = await auth.createUser({email: `rules-${randomBytes(12).toString("hex")}@example.invalid`, password});
      users.push(user);
      const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${config.API_KEY}`, {
        method: "POST", headers: {"Content-Type": "application/json"},
        body: JSON.stringify({email: user.email, password, returnSecureToken: true}),
      });
      const login = await response.json(); assert.ok(login.idToken, "Fixture sign-in failed");
      user.testToken = login.idToken;
      for (const collection of ["users", "coinWallets"]) {
        const ref = db.doc(`${collection}/${user.uid}`); docs.push(ref);
        await ref.create({coins: 500, balance: 500, ruleTestFixture: true});
      }
    }
    async function probe(label, docPath, token, expected, method = "GET", body) {
      const response = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/${docPath}`, {
        method, headers: {"Content-Type": "application/json", ...(token ? {Authorization: `Bearer ${token}`} : {})},
        ...(body ? {body: JSON.stringify(body)} : {}),
      });
      assert.equal(response.status, expected, `${label}: HTTP ${response.status}`);
      passed++; console.log(`PASS: ${label}`);
    }
    const [a, b] = users;
    for (const collection of ["users", "coinWallets"]) {
      await probe(`own ${collection} get`, `${collection}/${a.uid}`, a.testToken, 200);
      await probe(`other ${collection} denied`, `${collection}/${a.uid}`, b.testToken, 403);
      await probe(`unsigned ${collection} denied`, `${collection}/${a.uid}`, null, 403);
      await probe(`${collection} list denied`, collection, a.testToken, 403);
      await probe(`${collection} delete denied`, `${collection}/${a.uid}`, a.testToken, 403, "DELETE");
      await probe(`${collection} balance/role edit denied`, `${collection}/${a.uid}`, a.testToken, 403, "PATCH",
          {fields: {balance: {integerValue: "999999"}, isAdmin: {booleanValue: true}}});
      await probe(`${collection} create denied`, `${collection}/${a.uid}_new`, a.testToken, 403, "PATCH",
          {fields: {balance: {integerValue: "-1"}}});
    }
    await probe("private control denied", "economyPrivate/control", a.testToken, 403);
    await probe("receipt read denied", `coinWallets/${a.uid}/receipts/test`, a.testToken, 403);
    await probe("receipt write denied", `coinWallets/${a.uid}/receipts/test`, a.testToken, 403, "PATCH", {fields: {}});
    console.log(`${passed} live test-project rule checks passed.`);
  } finally {
    for (const ref of docs) await ref.delete();
    for (const user of users) await auth.deleteUser(user.uid);
  }
}
