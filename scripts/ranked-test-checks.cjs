"use strict";
const assert = require("node:assert/strict");
const {randomUUID, randomBytes} = require("node:crypto");
const {readFileSync} = require("node:fs");
const {execFileSync} = require("node:child_process");
module.exports = async ({db, auth, root, argument}) => {
  const config = JSON.parse(execFileSync("plutil", ["-convert", "json", "-o", "-",
    `${root}/.firebase/puzzlepartytest/GoogleService-Info.plist`], {encoding: "utf8"}));
  assert.equal(config.PROJECT_ID, "puzzlepartytest");
  const proofs = new Map(JSON.parse(readFileSync(argument, "utf8")).map((p) => [p.id, p.testEvidence]));
  const users = []; const rooms = []; let checks = 0;
  const pass = () => checks++;
  const call = async (name, user, data, reject = false) => {
    const res = await fetch(`https://us-central1-puzzlepartytest.cloudfunctions.net/${name}`, {
      method: "POST", headers: {"Content-Type": "application/json", ...(user ? {Authorization: `Bearer ${user.token}`} : {})},
      body: JSON.stringify({data}), signal: AbortSignal.timeout(65000)});
    const value = await res.json();
    if (reject) { assert.ok(value.error); pass(); return; }
    assert.ok(res.ok && !value.error, `${name}: ${value.error?.message || res.status}`);
    return value.result ?? value.data;
  };
  const probe = async (path, user, status, method = "GET", body) => {
    const res = await fetch(`https://firestore.googleapis.com/v1/projects/puzzlepartytest/databases/(default)/documents/${path}`, {
      method, headers: {"Content-Type": "application/json", ...(user ? {Authorization: `Bearer ${user.token}`} : {})},
      ...(body ? {body: JSON.stringify(body)} : {}), signal: AbortSignal.timeout(30000)});
    assert.equal(res.status, status, `Rules ${method} ${path}`); pass();
  };
  const control = db.doc("economyPrivate/control");
  try {
    for (let i = 0; i < 3; i++) {
      const password = randomBytes(32).toString("base64url");
      const user = await auth.createUser({email: `ranked-${randomUUID()}@example.invalid`, password});
      users.push(user);
      const res = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${config.API_KEY}`, {
        method: "POST", headers: {"Content-Type": "application/json"},
        body: JSON.stringify({email: user.email, password, returnSecureToken: true})});
      const login = await res.json(); assert.ok(login.idToken); user.token = login.idToken;
      await db.doc(`users/${user.uid}`).create({id: user.uid, username: "Ranked Fixture", coins: 500, ranks: {}, cosmetics: {}, testFixture: true});
      await db.doc(`coinWallets/${user.uid}`).create({version: 1, balance: 500, revision: 0,
        migratedAtMs: Date.now(), matchEconomyVersion: 1, matchRanks: {}, rankedAccess: {},
        casualRewards: {dayKey: "", count: 0}, rewardedBotWins: {dayKey: "", count: 0}});
    }
    const [a, b, outsider] = users;
    await db.runTransaction(async (tx) => {
      const f = (await tx.get(control)).data();
      tx.update(control, {matchTestUIDs: [...f.matchTestUIDs, a.uid, b.uid], socialTestUIDs: [...f.socialTestUIDs, a.uid, b.uid]});
    });
    await call("officialMatch_queue", null, {}, true);
    await call("officialMatch_queue", outsider, {requestID: randomUUID(), mode: "colorLink", matchKind: "ranked"}, true);
    for (const matchKind of ["ranked", "casual"]) {
      await call("officialMatch_queue", a, {requestID: randomUUID(), mode: "colorLink", matchKind});
      const reply = await call("officialMatch_queue", b, {requestID: randomUUID(), mode: "colorLink", matchKind});
      const id = reply.sessionID; assert.ok(id); rooms.push(id); pass();
      await probe(`serverMatches/${id}`, a, 200);
      await probe(`serverMatches/${id}`, outsider, 403);
      await probe(`serverMatches/${id}`, null, 403);
      await probe(`serverMatches/${id}`, a, 403, "PATCH", {fields: {status: {stringValue: "finished"}}});
      await probe(`serverMatches/${id}`, a, 403, "DELETE");
      await probe(`economyPrivate/liveMatches/records/${id}`, a, 403);
      await probe(`coinWallets/${b.uid}`, a, 403);
      await call("officialMatch_ready", a, {sessionID: id});
      await call("officialMatch_ready", b, {sessionID: id});
      const live = (await db.doc(`economyPrivate/liveMatches/records/${id}`).get()).data();
      assert.equal(live.status, "inProgress"); assert.equal(live.difficulty, "expert"); pass();
      await call("officialMatch_submit", a, {sessionID: id, evidence: {completed: true}}, true);
      const evidence = proofs.get(live.puzzleID); assert.ok(evidence);
      await call("officialMatch_submit", a, {sessionID: id, evidence});
      const wa = (await db.doc(`coinWallets/${a.uid}`).get()).data();
      const wb = (await db.doc(`coinWallets/${b.uid}`).get()).data();
      const ra = (await db.doc(`coinWallets/${a.uid}/receipts/match_${id}`).get()).data();
      const rb = (await db.doc(`coinWallets/${b.uid}/receipts/match_${id}`).get()).data();
      assert.equal(ra.matchReward, matchKind === "ranked" ? 20 : 15);
      assert.equal(rb.matchReward, 5); assert.equal(ra.dailyCoins, matchKind === "ranked" ? 25 : 0); pass();
      await call("settleWalletMatch", a, {sessionID: id});
      await call("officialMatch_submit", a, {sessionID: id, evidence});
      assert.deepEqual((await db.doc(`coinWallets/${a.uid}`).get()).data(), wa);
      assert.deepEqual((await db.doc(`coinWallets/${b.uid}`).get()).data(), wb); pass();
      assert.equal((await db.doc(`serverMatches/${id}`).get()).data().status, "finished"); pass();
    }
    console.log(JSON.stringify({project: "puzzlepartytest", rankedAndCasualLiveChecks: checks, passed: true}));
  } finally {
    const ids = users.map((u) => u.uid);
    await db.runTransaction(async (tx) => {
      const f = (await tx.get(control)).data();
      tx.update(control, {matchTestUIDs: f.matchTestUIDs.filter((id) => !ids.includes(id)), socialTestUIDs: f.socialTestUIDs.filter((id) => !ids.includes(id))});
    });
    for (const id of rooms) for (const p of [`serverMatches/${id}`, `economyPrivate/liveMatches/records/${id}`, `economyPrivate/verifiedMatches/records/${id}`]) await db.doc(p).delete();
    for (const user of users) {
      await db.recursiveDelete(db.doc(`coinWallets/${user.uid}`));
      await db.doc(`users/${user.uid}`).delete();
      await db.doc(`economyPrivate/matchAccounts/players/${user.uid}`).delete();
      await auth.deleteUser(user.uid);
    }
    console.log("Disposable ranked fixtures removed; phone and simulator accounts were not used.");
  }
};
