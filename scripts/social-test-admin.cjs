"use strict";
// Operator-only test preparation and live verification. Never targets production
// and never prints passwords, OAuth tokens, signed receipts or puzzle answers.
const assert = require("node:assert/strict");
const {randomBytes, randomUUID} = require("node:crypto");
const {readFileSync} = require("node:fs");
const {execFileSync} = require("node:child_process");
const path = require("node:path");
const {createRequire} = require("node:module");
const root = path.resolve(__dirname, "..");
const lib = process.env.FIREBASE_TOOLS_LIB;
assert.ok(lib, "Set FIREBASE_TOOLS_LIB");
const {Command} = require(path.join(lib, "command"));
const {requireAuth} = require(path.join(lib, "requireAuth"));
const {getAccessToken} = require(path.join(lib, "apiv2"));
const fr = createRequire(path.join(root, "functions/package.json"));
const {initializeApp} = fr("firebase-admin/app");
const {getAuth} = fr("firebase-admin/auth");
const {Firestore, FieldValue} = fr("@google-cloud/firestore");
const {OAuth2Client} = createRequire(fr.resolve("google-gax"))("google-auth-library");
const project = "puzzlepartytest";
const [mode, argument, uid] = process.argv.slice(2);
assert.ok(["inspect", "prepare", "verify", "partner", "audit", "ranked-audit", "ranked-prepare", "ranked-v2-catalog", "ranked-v2-activate", "ranked-verify", "ranked-v2-verify", "ranked-unlock-simulator", "ranked-access-audit"].includes(mode), "Unknown admin mode");
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
new Command("social-test-admin").before(requireAuth).action(async () => {
  const app = initializeApp({projectId: project, credential: {getAccessToken: async () => ({
    access_token: await getAccessToken(), expires_in: 300,
  })}});
  const googleAuth = new OAuth2Client();
  googleAuth.refreshHandler = async () => ({access_token: await getAccessToken(), expiry_date: Date.now() + 3600000});
  const db = new Firestore({projectId: project, authClient: googleAuth});
  const auth = getAuth(app);
  try {
    if (mode === "ranked-audit") {
      const matches = await db.collection("economyPrivate/liveMatches/records").limit(200).get();
      for (const doc of matches.docs) {
        const m = doc.data();
        const verified = (await db.doc(`economyPrivate/verifiedMatches/records/${doc.id}`).get()).data();
        const players = [];
        for (const p of m.players.filter((p) => !p.isBot)) {
          const receipt = (await db.doc(`coinWallets/${p.userID}/receipts/match_${doc.id}`).get()).data();
          const progress = m.playerProgress?.[p.userID];
          players.push({name: p.username, result: m.playerResults[p.userID]?.status,
            completed: m.playerResults[p.userID]?.completed, forfeited: m.forfeitedIDs.includes(p.userID),
            progress: progress ? {status: progress.status, completed: progress.completed,
              score: progress.score, progress: progress.progress} : null,
            receipt: receipt ? {coins: receipt.matchReward, daily: receipt.dailyCoins,
              rankDelta: receipt.rankDelta, outcome: receipt.outcome, reason: receipt.reason,
              balance: receipt.balance} : null});
        }
        console.log(JSON.stringify({id: doc.id, mode: m.mode, kind: m.matchKind, status: m.status,
          created: new Date(m.createdAtMs).toISOString(), settled: !!verified?.settledAtMs, players}));
      }
      console.log(JSON.stringify({count: matches.size, truncated: matches.size === 200}));
    }
    else if (mode === "ranked-verify") await require("./ranked-test-checks.cjs")({db, auth, root, argument});
    else if (mode === "ranked-v2-verify") await require("./ranked-test-checks.cjs")({db, auth, root, argument, advanced: true});
    else if (mode === "ranked-prepare") await prepareRanked(db);
    else if (mode === "ranked-v2-catalog") await prepareRankedV2Catalog(db);
    else if (mode === "ranked-v2-activate") await activateRankedV2(db);
    else if (mode === "ranked-unlock-simulator") await unlockSimulatorRanked(db);
    else if (mode === "ranked-access-audit") await auditSimulatorRankedAccess(db);
    else if (mode === "audit") await audit(db);
    else if (mode === "partner") await provisionPartner(db, auth);
    else if (mode === "prepare") await prepare(db, auth);
    else if (mode === "verify") await verify(db, auth);
    else {
      const flags = (await db.doc("economyPrivate/control").get()).data();
      const catalog = await db.collection("economyPrivate/socialCatalog/modes").get();
      console.log(JSON.stringify({project, walletReady: flags?.walletMigrationReady,
        socialEnabled: flags?.socialRewardsEnabled, approvedAccounts: flags?.socialTestUIDs?.length ?? 0,
        catalogGroups: catalog.size, puzzles: catalog.docs.reduce((n, d) => n + d.data().puzzleIDs.length, 0)}));
    }
  } finally { await db.terminate(); }
}).runner()({project, nonInteractive: true}).catch((e) => {
  console.error(JSON.stringify({code: e.code || e.name,
    detail: e instanceof assert.AssertionError ? e.message.slice(0, 500) :
      typeof e.details === "string" ? e.details.slice(0, 500) : "Operation failed; no credentials logged"}));
  process.exitCode = 1;
});

function publicProfile(user) {
  return {id: user.id, username: user.username, email: "", createdAt: user.createdAt,
    coins: 0, ranks: {}, cosmetics: {equippedAvatarHead: user.cosmetics?.equippedAvatarHead || "avatar_head_none",
      equippedAvatarFace: user.cosmetics?.equippedAvatarFace || "avatar_face_smile",
      equippedAvatarOutfit: user.cosmetics?.equippedAvatarOutfit || "avatar_outfit_basic",
      equippedAvatarAura: user.cosmetics?.equippedAvatarAura || "avatar_aura_none"}};
}
async function activateRankedV2(db) {
  const {presets, onlineDifficulty} = require("../functions/match-reward-policy");
  await db.runTransaction(async (tx) => {
    const ref = db.doc("economyPrivate/control");
    const flags = (await tx.get(ref)).data();
    assert.ok(flags?.purchaseSandbox && flags.walletMigrationReady && flags.matchLifecycleEnabled && flags.matchRewardsEnabled);
    assert.deepEqual([...flags.matchTestUIDs].sort(), ["8nd9VCHUvWfAdOwOwZtnpuaiJc43", "social-simulator-partner-v1"].sort());
    for (const uid of flags.matchTestUIDs) {
      const account = (await tx.get(db.doc(`economyPrivate/matchAccounts/players/${uid}`))).data();
      if (account?.sessionID) {
        const match = (await tx.get(db.doc(`economyPrivate/liveMatches/records/${account.sessionID}`))).data();
        assert.ok(!["waiting", "inProgress"].includes(match?.status), "Finish the current test match before switching rules");
      } else {
        assert.ok(!account || account.cancelled || account.expiresAtMs <= Date.now(), "Cancel the current search before switching rules");
      }
    }
    for (const game of Object.keys(presets)) for (const points of [0, 3600]) {
      const key = `${game}_${onlineDifficulty(game, "ranked", points)}`;
      const catalog = (await tx.get(db.doc(`economyPrivate/matchCatalog/modes/${key}`))).data();
      assert.ok(catalog?.version === 1 && catalog.puzzleIDs?.length > 0, "Missing v2 catalog");
    }
    tx.update(ref, {onlineRulesVersion: 2});
  });
  console.log(JSON.stringify({project, onlineRulesVersion: 2, accountDataChanged: false}));
}

async function unlockSimulatorRanked(db) {
  const userID = "social-simulator-partner-v1";
  await db.runTransaction(async (tx) => {
    const control = (await tx.get(db.doc("economyPrivate/control"))).data();
    assert.ok(control?.purchaseSandbox && control?.matchTestUIDs?.includes(userID));
    const ref = db.doc(`coinWallets/${userID}`);
    const wallet = (await tx.get(ref)).data();
    const userRef = db.doc(`users/${userID}`);
    const user = (await tx.get(userRef)).data();
    assert.ok(wallet?.purchaseSandbox && wallet.version === 1 && wallet.matchEconomyVersion === 1);
    assert.ok(user?.socialSimulatorPartner === true);
    tx.update(ref, {rankedAccess: {...wallet.rankedAccess, allModesUnlocked: true}, testRankedAccessGrantedAtMs: Date.now()});
    tx.update(userRef, {rankedAccess: {...user.rankedAccess, allModesUnlocked: true}, testRankedAccessGrantedAtMs: Date.now()});
  });
  console.log(JSON.stringify({project, account: "simulator", allModesUnlocked: true, productionChanged: false}));
}

async function auditSimulatorRankedAccess(db) {
  const userID = "social-simulator-partner-v1";
  const [wallet, user] = await Promise.all([
    db.doc(`coinWallets/${userID}`).get(),
    db.doc(`users/${userID}`).get(),
  ]);
  console.log(JSON.stringify({project, account: "simulator",
    walletAllModes: wallet.data()?.rankedAccess?.allModesUnlocked === true,
    profileAllModes: user.data()?.rankedAccess?.allModesUnlocked === true}));
}

async function prepareRankedV2Catalog(db) {
  const {presets, onlineDifficulty} = require("../functions/match-reward-policy");
  const flags = (await db.doc("economyPrivate/control").get()).data();
  assert.ok(flags?.purchaseSandbox && flags.walletMigrationReady);
  const manifests = new Map();
  for (const game of Object.keys(presets)) {
    for (const points of [0, 3600]) {
      const difficulty = onlineDifficulty(game, "ranked", points);
      const key = `${game}_${difficulty}`;
      const catalog = (await db.doc(`economyPrivate/socialCatalog/modes/${key}`).get()).data();
      assert.equal(catalog?.version, 1); assert.ok(catalog.puzzleIDs.length > 0);
      for (const id of catalog.puzzleIDs) {
        const puzzle = (await db.doc(`economyPrivate/matchPuzzles/records/${id}`).get()).data();
        assert.equal(puzzle?.mode, game); assert.equal(puzzle?.difficulty, difficulty);
        assert.equal(puzzle?.protocolVersion, "match-v1"); assert.ok(!puzzle.testEvidence);
      }
      manifests.set(key, catalog);
    }
  }
  const batch = db.batch();
  for (const [key, catalog] of manifests) batch.set(db.doc(`economyPrivate/matchCatalog/modes/${key}`), catalog);
  await batch.commit();
  // Activation is separate: finish old searches and install both clients first.
  console.log(JSON.stringify({project, preparedV2Catalogs: manifests.size, activated: false}));
}

async function prepareRanked(db) {
  const {presets} = require("../functions/match-reward-policy");
  const approved = ["8nd9VCHUvWfAdOwOwZtnpuaiJc43", "social-simulator-partner-v1"];
  const manifests = [];
  for (const [game, difficulty] of Object.entries(presets)) {
    const catalog = (await db.doc(`economyPrivate/socialCatalog/modes/${game}_${difficulty}`).get()).data();
    assert.equal(catalog?.version, 1);
    assert.ok(catalog.puzzleIDs.length > 0);
    for (const id of catalog.puzzleIDs) {
      const p = (await db.doc(`economyPrivate/matchPuzzles/records/${id}`).get()).data();
      assert.equal(p?.mode, game); assert.equal(p?.difficulty, difficulty);
      assert.equal(p?.protocolVersion, "match-v1"); assert.ok(!p.testEvidence);
    }
    manifests.push([game, catalog]);
  }
  await db.runTransaction(async (tx) => {
    const control = db.doc("economyPrivate/control");
    const flags = (await tx.get(control)).data();
    assert.ok(flags?.purchaseSandbox && flags.walletMigrationReady);
    const wallets = [];
    for (const id of approved) {
      assert.ok(flags.socialTestUIDs.includes(id));
      const ref = db.doc(`coinWallets/${id}`);
      const w = (await tx.get(ref)).data();
      const u = (await tx.get(db.doc(`users/${id}`))).data();
      assert.ok(w?.purchaseSandbox && w.version === 1 && w.balance === u.coins);
      assert.ok(w.matchEconomyVersion === undefined || w.matchEconomyVersion === 1);
      const ranks = w.matchRanks ?? u.ranks ?? {};
      for (const r of Object.values(ranks)) {
        assert.ok([r.points, r.wins, r.losses].every((v) => Number.isSafeInteger(v) && v >= 0));
      }
      wallets.push({ref, w, ranks});
    }
    for (const {ref, w, ranks} of wallets) tx.update(ref, {matchEconomyVersion: 1, matchRanks: ranks,
      casualRewards: w.casualRewards ?? {dayKey: "", count: 0},
      rewardedBotWins: w.rewardedBotWins ?? {dayKey: "", count: 0}});
    for (const [game, catalog] of manifests) tx.set(db.doc(`economyPrivate/matchCatalog/modes/${game}`), catalog);
    tx.update(control, {matchTestUIDs: approved, matchLifecycleEnabled: true, matchRewardsEnabled: true});
  });
  console.log(JSON.stringify({project, rankedPrepared: true, approvedAccounts: approved.length, presetCatalogs: manifests.length}));
}
async function audit(db) {
  const flags = (await db.doc("economyPrivate/control").get()).data();
  const rooms = await db.collection("economyPrivate/socialRooms/records").limit(200).get();
  console.log(JSON.stringify({project, roomCount: rooms.size, truncated: rooms.size === 200}));
  for (const doc of rooms.docs) {
    const m = doc.data();
    const publicDoc = (await db.doc(`${m.kind === "party" ? "partyRooms" : "sessions"}/${doc.id}`).get()).data();
    console.log(JSON.stringify({room: doc.id, kind: m.kind, status: m.status,
      created: new Date(m.createdAtMs).toISOString(), projectionStatus: publicDoc?.status,
      scores: m.scores, winner: m.winnerID, inviteStatus: m.invite?.status,
      expires: new Date(m.expiresAtMs).toISOString(), acceptedCount: m.acceptedIDs?.length,
      rounds: m.rounds.map((r) => ({index: r.index,
        mode: r.mode, status: r.status, windowSeconds: r.deadlineMs ? (r.deadlineMs - r.windowStartedMs) / 1000 : null,
        scoreRows: r.scoreRows, results: Object.entries(r.results).map(([id, v]) => ({id,
          completed: v.completed, status: v.status, elapsed: v.elapsedSeconds,
          timeout: v.summary?.partyTimeout, abandoned: v.summary?.abandoned})),
        projectionMatches: JSON.stringify(publicDoc?.stageRounds?.[r.index]?.results ??
          (m.kind !== "party" ? publicDoc?.playerResults : Object.fromEntries((publicDoc?.players || []).filter((p) => p.result).map((p) => [p.userID, p.result])))) === JSON.stringify(r.results)}))}));
  }
  for (const id of flags.socialTestUIDs || []) {
    const w = (await db.doc(`coinWallets/${id}`).get()).data();
    const u = (await db.doc(`users/${id}`).get()).data();
    const receipts = await db.collection(`coinWallets/${id}/receipts`).limit(300).get();
    const ledger = receipts.docs.map((d) => d.data()).sort((a, b) => a.revision - b.revision);
    let balance = 0;
    for (const [index, receipt] of ledger.entries()) {
      assert.equal(receipt.revision, index, "Missing or duplicate wallet revision");
      assert.equal(receipt.balanceBefore, balance, "Wallet chain broken");
      balance += receipt.delta;
      assert.equal(receipt.balance, balance, "Receipt arithmetic differs");
    }
    assert.equal(balance, w.balance);
    assert.equal(u.coins, w.balance);
    const rewardedDays = ledger.filter((r) => r.kind === "socialPlay" && r.delta > 0)
        .map((r) => new Date(r.settledAtMs).toISOString().slice(0, 10));
    assert.equal(new Set(rewardedDays).size, rewardedDays.length, "Repeated daily social reward");
    console.log(JSON.stringify({account: id, ledgerVerified: true}));
    console.log(JSON.stringify({account: id, balance: w?.balance, displayedCoins: u?.coins,
      revision: w?.revision, receipts: receipts.docs.map((d) => {
        const r = d.data(); return {id: d.id, kind: r.kind, delta: r.delta, balanceBefore: r.balanceBefore,
          balance: r.balance, revision: r.revision, sessionID: r.sessionID, roundIndex: r.roundIndex,
          dailyCoins: r.dailyCoins, settledAtMs: r.settledAtMs};
      })}));
  }
  const response = await fetch("https://logging.googleapis.com/v2/entries:list", {
    method: "POST", headers: {Authorization: `Bearer ${await getAccessToken()}`, "Content-Type": "application/json"},
    body: JSON.stringify({resourceNames: [`projects/${project}`],
      filter: 'severity>=ERROR AND (resource.type="cloud_run_revision" OR resource.type="cloud_function") AND timestamp>="2026-10-01T00:00:00Z"',
      pageSize: 100, orderBy: "timestamp desc"})});
  const logs = await response.json();
  console.log(JSON.stringify({logStatus: response.status, moreLogs: !!logs.nextPageToken,
    errors: (logs.entries || []).map((e) => ({time: e.timestamp, service: e.resource?.labels?.service_name || e.resource?.labels?.function_name,
      httpStatus: e.httpRequest?.status, message: String(e.textPayload || e.jsonPayload?.message || "").slice(0, 350)}))}));
}
async function provisionPartner(db, auth) {
  assert.match(argument || "", /^[A-Za-z0-9_-]{1,128}$/);
  const hostRef = db.doc(`coinWallets/${argument}`);
  const hostBefore = (await hostRef.get()).data();
  const host = (await db.doc(`users/${argument}`).get()).data();
  const control = db.doc("economyPrivate/control");
  const flags = (await control.get()).data();
  assert.ok(hostBefore?.purchaseSandbox && flags?.socialTestUIDs?.includes(argument));
  const partnerID = "social-simulator-partner-v1";
  const email = "simulator-partner@example.invalid";
  const password = randomBytes(32).toString("base64url");
  let existing;
  try { existing = await auth.getUser(partnerID); }
  catch (error) { if (error.code !== "auth/user-not-found") throw error; }
  if (existing) {
    assert.equal(existing.email, email);
    assert.equal((await db.doc(`users/${partnerID}`).get()).data()?.socialSimulatorPartner, true);
    await auth.updateUser(partnerID, {password});
  } else await auth.createUser({uid: partnerID, email, password, displayName: "Test Partner"});
  await db.runTransaction(async (tx) => {
    const userRef = db.doc(`users/${partnerID}`);
    const walletRef = db.doc(`coinWallets/${partnerID}`);
    const [userDoc, walletDoc, controlDoc] = await Promise.all([tx.get(userRef), tx.get(walletRef), tx.get(control)]);
    assert.ok(controlDoc.data()?.socialRewardsEnabled);
    assert.equal(userDoc.exists, walletDoc.exists);
    const rankedAccess = {allModesUnlocked: false, unlockedModeIDs: []};
    const profile = userDoc.data() || {id: partnerID, username: "Test Partner", email,
      createdAt: new Date(), coins: 500, ranks: {}, cosmetics: {purchasedIDs: []},
      rankedAccess, serverWalletVersion: 1, purchaseSandbox: true, socialSimulatorPartner: true};
    if (!userDoc.exists) {
      tx.create(userRef, profile);
      tx.create(walletRef, {version: 1, balance: 500, revision: 0, migratedAtMs: Date.now(),
        appAccountToken: randomUUID(), purchaseRefundDebt: 0, rankedAccess, purchaseSandbox: true});
      tx.create(walletRef.collection("receipts").doc("sandbox_bootstrap"), {
        kind: "sandboxBootstrap", delta: 500, balanceBefore: 0, balance: 500, revision: 0, settledAtMs: Date.now()});
    }
    tx.set(db.doc(`socialTestProfiles/${partnerID}`), publicProfile(profile));
    const friendID = [argument, partnerID].sort().join("_");
    tx.set(db.doc(`friendships/${friendID}`), {id: friendID, userIDs: [argument, partnerID],
      usernames: {[argument]: host.username, [partnerID]: "Test Partner"}, createdAt: new Date()});
    tx.update(control, {socialTestUIDs: FieldValue.arrayUnion(partnerID)});
  });
  assert.deepEqual((await hostRef.get()).data(), hostBefore, "Host wallet must remain unchanged");
  // Transfer only to the local login UI, never to logs or command arguments.
  execFileSync("pbcopy", [], {input: password});
  console.log(JSON.stringify({project, email, partnerReady: true, hostWalletPreserved: true,
    passwordOnClipboard: true}));
}
async function prepare(db, auth) {
  assert.match(uid || "", /^[A-Za-z0-9_-]{1,128}$/);
  assert.equal((await auth.getUser(uid)).disabled, false);
  const user = (await db.doc(`users/${uid}`).get()).data();
  const wallet = (await db.doc(`coinWallets/${uid}`).get()).data();
  assert.ok(user?.purchaseSandbox && wallet?.purchaseSandbox && wallet.version === 1,
      "Only an already-provisioned purchase test account can be prepared");
  assert.equal(user.coins, wallet.balance);
  const puzzles = JSON.parse(readFileSync(argument, "utf8"));
  assert.equal(puzzles.length, 128, "Expected 4 seeds for all 8 modes / 4 difficulties");
  const groups = new Map();
  for (const p of puzzles) {
    assert.equal(p.protocolVersion, "match-v1");
    assert.ok(!Object.hasOwn(p, "testEvidence"), "Never upload test proofs");
    assert.match(p.id, /^match_v1_[A-Za-z]+_(easy|medium|hard|expert)_\d+$/);
    assert.equal(typeof p.puzzleData, "string");
    assert.ok(Buffer.byteLength(JSON.stringify(p)) < 750000, "Puzzle too large");
    const key = `${p.mode}_${p.difficulty}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(p.id);
  }
  assert.equal(groups.size, 32);
  // Never silently replace a canonical puzzle already pinned by a room.
  for (const p of puzzles) {
    const ref = db.doc(`economyPrivate/matchPuzzles/records/${p.id}`);
    const existing = (await ref.get()).data();
    if (existing) assert.deepEqual(existing, p, "Canonical catalog differs; use new puzzle IDs");
    else await ref.create(p);
  }
  const batch = db.batch();
  for (const [id, puzzleIDs] of groups) {
    assert.equal(puzzleIDs.length, 4);
    batch.set(db.doc(`economyPrivate/socialCatalog/modes/${id}`), {version: 1, puzzleIDs});
  }
  batch.set(db.doc(`socialTestProfiles/${uid}`), publicProfile(user));
  await batch.commit();
  await db.runTransaction(async (tx) => {
    const ref = db.doc("economyPrivate/control");
    const flags = (await tx.get(ref)).data();
    assert.ok(flags?.purchaseSandbox && flags.walletMigrationReady);
    tx.update(ref, {socialRewardsEnabled: true, socialTestUIDs: FieldValue.arrayUnion(uid)});
  });
  const after = (await db.doc(`coinWallets/${uid}`).get()).data();
  assert.deepEqual(after, wallet, "Preparation must not change the wallet");
  console.log(JSON.stringify({project, prepared: true, catalogGroups: groups.size, puzzles: puzzles.length,
    balancePreserved: wallet.balance, rankedAccessPreserved: wallet.rankedAccess?.allModesUnlocked === true}));
}

async function verify(db, auth) {
  const config = JSON.parse(execFileSync("plutil", ["-convert", "json", "-o", "-",
    path.join(root, ".firebase/puzzlepartytest/GoogleService-Info.plist")], {encoding: "utf8"}));
  assert.equal(config.PROJECT_ID, project);
  const puzzles = JSON.parse(readFileSync(argument, "utf8"));
  const proofByID = new Map(puzzles.map((p) => [p.id, p.testEvidence]));
  const users = []; const rooms = []; const requests = []; let passed = 0;
  const pass = (label) => { passed++; console.log(`PASS: ${label}`); };
  const control = db.doc("economyPrivate/control");
  const call = async (method, user, data = {}, rejection = false) => {
    const response = await fetch(`https://us-central1-${project}.cloudfunctions.net/socialGame_${method}`, {
      method: "POST", headers: {"Content-Type": "application/json", ...(user ? {Authorization: `Bearer ${user.token}`} : {})},
      body: JSON.stringify({data}), signal: AbortSignal.timeout(65000),
    });
    const value = await response.json().catch(() => ({}));
    if (rejection) { assert.ok(value.error, `Expected rejection: ${method}, HTTP ${response.status}`); return value.error; }
    assert.ok(response.ok && !value.error, `${method} failed: ${value.error?.message || response.status}`);
    return value.result ?? value.data;
  };
  const room = async (id) => (await db.doc(`economyPrivate/socialRooms/records/${id}`).get()).data();
  const wallet = async (u) => (await db.doc(`coinWallets/${u.uid}`).get()).data();
  async function probe(label, docPath, user, expected, method = "GET", body) {
    const response = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents${docPath.startsWith(":") ? "" : "/"}${docPath}`, {
      method, headers: {"Content-Type": "application/json", ...(user ? {Authorization: `Bearer ${user.token}`} : {})},
      ...(body ? {body: JSON.stringify(body)} : {}), signal: AbortSignal.timeout(30000),
    });
    assert.equal(response.status, expected, `${label}: HTTP ${response.status}`);
    pass(label);
    return response;
  }
  try {
    for (let i = 0; i < 3; i++) {
      const password = randomBytes(24).toString("base64url");
      const u = await auth.createUser({email: `social-${randomBytes(12).toString("hex")}@example.invalid`, password});
      users.push(u);
      const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${config.API_KEY}`, {
        method: "POST", headers: {"Content-Type": "application/json"},
        body: JSON.stringify({email: u.email, password, returnSecureToken: true}),
      });
      const login = await response.json(); assert.ok(login.idToken, "Fixture login failed"); u.token = login.idToken;
      const profile = {id: u.uid, username: `Social Tester ${i + 1}`, email: u.email,
        createdAt: new Date(), coins: 500, ranks: {}, cosmetics: {}, socialTestFixture: true};
      await db.doc(`users/${u.uid}`).create(profile);
      await db.doc(`coinWallets/${u.uid}`).create({version: 1, balance: 500, revision: 0, socialTestFixture: true});
      await db.doc(`socialTestProfiles/${u.uid}`).create(publicProfile(profile));
    }
    const [a, b, outsider] = users;
    await control.update({socialTestUIDs: FieldValue.arrayUnion(a.uid, b.uid)});
    await db.doc(`friendships/${[a.uid, b.uid].sort().join("_")}`).create({
      id: [a.uid, b.uid].sort().join("_"), userIDs: [a.uid, b.uid],
      usernames: {[a.uid]: "Social Tester 1", [b.uid]: "Social Tester 2"}, createdAt: new Date(),
    });
    await call("tick", null, {sessionID: "sv1_unknown"}, true); pass("unsigned callable rejected");
    await call("create", outsider, {requestID: randomUUID(), kind: "party", rounds: [{mode: "wordle", difficulty: "easy"}]}, true);
    pass("unapproved test account rejected");
    for (const collection of ["users", "coinWallets"]) {
      await probe(`own ${collection}`, `${collection}/${a.uid}`, a, 200);
      await probe(`other ${collection} private`, `${collection}/${a.uid}`, b, 403);
      await probe(`unsigned ${collection} private`, `${collection}/${a.uid}`, null, 403);
      await probe(`${collection} listing denied`, collection, a, 403);
      await probe(`${collection} update denied`, `${collection}/${a.uid}`, a, 403, "PATCH", {fields: {coins: {integerValue: "999999"}}});
      await probe(`${collection} create denied`, `${collection}/${a.uid}_forged`, a, 403, "PATCH", {fields: {isAdmin: {booleanValue: true}}});
      await probe(`${collection} delete denied`, `${collection}/${a.uid}`, a, 403, "DELETE");
    }
    const publicResponse = await probe("display-only profile readable", `socialTestProfiles/${a.uid}`, b, 200);
    assert.equal((await publicResponse.json()).fields.email.stringValue, ""); pass("public profile contains no email");
    await probe("unapproved profile read denied", `socialTestProfiles/${a.uid}`, outsider, 403);
    await probe("private control denied", "economyPrivate/control", a, 403);
    await probe("private catalog denied", "economyPrivate/socialCatalog/modes/wordle_easy", a, 403);
    await probe("receipt read denied", `coinWallets/${a.uid}/receipts/test`, a, 403);
    async function create(kind, modes = ["wordle"]) {
      await sleep(3100);
      const requestID = randomUUID(); requests.push(requestID);
      const data = {requestID, kind, friendID: b.uid, rounds: modes.map((mode) => ({mode, difficulty: "easy"}))};
      const reply = await call("create", a, data); rooms.push(reply.sessionID);
      assert.deepEqual(await call("create", a, data), reply); pass(`${kind} create retry is idempotent`);
      return reply.sessionID;
    }
    const action = (method, id, user = a, extra = {}) => call(method, user, {sessionID: id, ...extra});
    async function start(id, kind) {
      await action(kind === "party" ? "join" : "accept", id, b);
      await action("ready", id); await action("ready", id, b);
      if (kind === "party") await action("start", id);
    }
    async function submit(id, user = a, index = 0) {
      const r = (await room(id)).rounds[index]; const evidence = proofByID.get(r.puzzleID);
      assert.ok(evidence, "Missing local proof fixture");
      return action("submit", id, user, {roundIndex: index, evidence});
    }
    for (const kind of ["exhibition", "asyncExhibition"]) {
      const id = await create(kind); await start(id, kind);
      await call("submit", a, {sessionID: id, roundIndex: 0, evidence: {completed: true, coins: 999999}}, true);
      pass(`${kind} fabricated result rejected`);
      await submit(id); await submit(id);
      assert.equal((await wallet(a)).balance, 525); pass(`${kind} daily reward once, retry no extra coins`);
      const pub = await probe(`${kind} participant read`, `sessions/${id}`, b, 200);
      assert.ok(!(await pub.text()).includes('"evidence"')); pass(`${kind} active projection omits evidence`);
      await probe(`${kind} outsider read denied`, `sessions/${id}`, outsider, 403);
      await probe(`${kind} forged result denied`, `sessions/${id}`, a, 403, "PATCH", {fields: {winnerID: {stringValue: a.uid}}});
      await submit(id, b); assert.equal((await room(id)).status, "finished"); pass(`${kind} finishes with both submissions`);
    }
    const playlist = await create("party", ["wordle", "hangman", "colorLink"]);
    await call("start", b, {sessionID: playlist}, true); pass("non-host start denied");
    await start(playlist, "party");
    for (let index = 0; index < 3; index++) {
      await submit(playlist, a, index); await submit(playlist, b, index);
      assert.equal((await room(playlist)).rounds[index].scoreRows.length, 2);
      if (index < 2) await action("advance", playlist, a, {roundIndex: index});
    }
    assert.equal((await room(playlist)).status, "finished");
    assert.equal((await wallet(a)).balance, 525); pass("three-round playlist scores and daily cap preserved");
    await submit(playlist, a, 0); assert.equal((await wallet(a)).balance, 525); pass("old-round replay cannot grant again");
    const timer = await create("party"); await start(timer, "party"); await submit(timer);
    const timedRound = (await room(timer)).rounds[0];
    assert.equal(timedRound.deadlineMs - timedRound.windowStartedMs, 180000); pass("first success starts exactly 180-second window");
    await action("tick", timer, b); assert.equal((await room(timer)).status, "inProgress"); pass("early tick cannot finish the party");
    await probe("party participant read", `partyRooms/${timer}`, a, 200);
    await probe("party outsider read denied", `partyRooms/${timer}`, outsider, 403);
    await probe("party rewrite denied", `partyRooms/${timer}`, a, 403, "PATCH", {fields: {status: {stringValue: "finished"}}});
    for (const [collection, field, op, value] of [
      ["friendships", "userIDs", "ARRAY_CONTAINS", a.uid],
      ["exhibitionInvites", "fromID", "EQUAL", a.uid],
      ["exhibitionInvites", "toID", "EQUAL", b.uid],
      ["sessions", "playerIDs", "ARRAY_CONTAINS", a.uid],
    ]) {
      await probe(`${collection} actual membership query`, ":runQuery", field === "toID" ? b : a, 200, "POST", {structuredQuery: {
        from: [{collectionId: collection}], where: {fieldFilter: {field: {fieldPath: field}, op, value: {stringValue: value}}},
      }});
    }
    console.log("Waiting for the real server deadline; no clock or result mutation.");
    await sleep(Math.max(0, timedRound.deadlineMs - Date.now() + 1200));
    await action("tick", timer, b); await action("tick", timer, a);
    const finished = await room(timer);
    assert.equal(finished.status, "finished");
    assert.equal(finished.rounds[0].results[b.uid].status, "Time expired");
    assert.equal((await wallet(b)).balance, 525); pass("real deadline finalizes once; timeout adds no coins");
    console.log(`${passed} live social/rule checks passed on ${project}.`);
  } finally {
    if (users.length) await control.update({socialTestUIDs: FieldValue.arrayRemove(...users.map((u) => u.uid))});
    for (const id of rooms) {
      for (const p of [`economyPrivate/socialRooms/records/${id}`, `sessions/${id}`, `partyRooms/${id}`, `exhibitionInvites/${id}`]) await db.doc(p).delete();
    }
    for (const u of users) {
      assert.match(u.email, /^social-[0-9a-f]{24}@example\.invalid$/);
      await db.recursiveDelete(db.doc(`coinWallets/${u.uid}`));
      await db.doc(`users/${u.uid}`).delete(); await db.doc(`socialTestProfiles/${u.uid}`).delete();
      await db.doc(`economyPrivate/socialAccounts/players/${u.uid}`).delete();
      for (const requestID of requests) await db.doc(`economyPrivate/socialRequests/users/${u.uid}/requests/${requestID}`).delete();
      await auth.deleteUser(u.uid);
    }
    if (users.length > 1) await db.doc(`friendships/${[users[0].uid, users[1].uid].sort().join("_")}`).delete();
  }
}
