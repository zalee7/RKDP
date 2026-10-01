# Friend And Party Rewards

Updated October 1, 2026. Deployed and enabled for approved accounts on
`puzzlepartytest` ONLY. Production `rkpz-90484` and the normal client's wallet
rollout switch remain unchanged/disabled.

Installation follow-up, October 1: with explicit approval, installed the signed
`PP Social Test` build on the user's iPhone 16 Pro Max named `26`, replacing the
purchase-test app without uninstalling its data first. Signature verification
passed and the built configuration identifies `puzzlepartytest`. Installation
succeeded after one connection retry. Automatic launch was denied because the
phone was locked; signed-in gameplay/UI verification remains pending. The
no-install statements below describe the earlier deployment pass.

## Test Deployment

- All ten `socialGame_*` endpoints are ACTIVE in `us-central1`, Node.js 24,
  zero minimum instances, one maximum instance each and 30-second timeout.
  `SOCIAL_MAX_INSTANCES=1` is test configuration; the default remains five.
- The three Apple purchase endpoints were not redeployed: their deployment
  hashes and one-instance limits are unchanged.
- The existing Standard `(default)` database remains in `nam5`. Loaded 128
  canonical puzzles: eight modes, four difficulties, four seeds each. No
  `testEvidence` field was uploaded. Existing canonical IDs cannot silently
  change during repeat preparation.
- `economyPrivate/control.socialRewardsEnabled` is true, with an explicit
  `socialTestUIDs` allowlist checked for both callers and invited players.
  Other reward gates were not enabled. Existing purchase gates are preserved.
- Prepared the existing purchase-test account without resetting its wallet:
  3,500 coins and All Modes access preserved. Disposable live-check accounts
  are separate from that account and are removed after verification.
- Deployed `Tests/social-test.firestore.rules` through
  `firebase.social-test.json`, NOT the broad legacy application rules. All
  client writes remain denied; own profiles/wallets are get-only; social reads
  require allowlisting and membership. `socialTestProfiles` provides sanitized
  display-only profiles with no email address. Friendships are operator-prepared
  in this harness, rather than enabling the legacy client friendship writer.
- `PP_SOCIAL_SANDBOX` opens the existing Friends/Party gameplay screens with a
  clear test label and Sign Out. It excludes unrelated app tabs, account signup,
  search/add-friend, purchase recovery, legacy login reward reconciliation and
  push registration. It never falls back to production configuration or creates
  a fake local wallet after a read failure. Existing invited friends and Join Code
  use the normal game UI. Push delivery is not enabled/tested in this harness.
- `bash scripts/build-social-test.sh device` builds a signed phone app at
  `/private/tmp/RKDPSocialTest/Build/Products/Debug-iphoneos/RKDP.app`.
  The simulator variant is also built. Same bundle ID as the purchase test:
  coordinate before installing because it replaces that installed app.
- Verified matches now instantiate the legacy RTDB connection lazily, avoiding
  startup dependency on a database this test project does not have.

### Next Manual Check

Install the signed social build with approval, prepare a second human test
account/friendship, and run Play Now, Play Later, classic party and playlist on
phone/simulator. Check touch/typing locks, readiness, submitted restoration and
timer presentation. Neither a successful build nor callable tests substitute
for this signed-in two-client UI check.

## What This Pass Does

- Server-owned creation, participants, readiness, puzzle selection, start clocks,
  result verification, finish windows and final scores for Play Now, Play Later,
  classic parties and three-round party playlists.
- A genuine accepted final attempt uses the shared wallet ledger for daily play.
  It grants the existing +25 bonus at most once per UTC day across modes, and
  counts that game once. There are no new friend/party win coins or rank rewards.
- Duplicate callbacks, concurrent rooms and retries do not repeat credit.
  Refund debt is handled by the same ledger as other wallet income.
- Starting/leaving, fabricated public results, automatic timeouts, and empty
  timed games do not grant daily credit. A verified played loss can count.
- The first successful solve starts one 180-second party catch-up window.
  Anagrams and Word Hunt retain their normal timer, without that extra window.
- Parties award 10/7/5/3/1 round points, with shared competition placements for
  ties. Final standings use cumulative score, round wins, then latest placement.
  Synthetic timeouts/abandonments rank below actual submissions; two missing
  results tie. The Swift party comparator matches this distinction.
- Play Now race modes still finish on the first successful solver. Other friend
  games use the existing match tie-break order. Play Later waits for both.
- Pending final evidence persists locally and keeps the board locked while
  retrying. Party submissions carry the captured round index, so a delayed
  response cannot submit into a later round. Server-accepted results restore the
  submitted lock after reconnecting.

## Authority And Storage

`functions/social-lifecycle.js` is reached through authenticated, non-anonymous
`socialGame_create/join/accept/decline/ready/start/advance/forfeit/submit/tick`.
Callers never supply an authoritative score, duration, seed, winner or coin amount.

Private records (all denied to clients):

- `economyPrivate/socialRooms/records/{id}`: room and pinned puzzle fingerprints.
- `economyPrivate/socialRequests/users/{uid}/requests/{requestID}`: creation retry identity.
- `economyPrivate/socialAccounts/players/{uid}`: short room-creation cooldown.
- `economyPrivate/socialCatalog/modes/{mode}_{difficulty}`: private puzzle IDs.
- `economyPrivate/matchPuzzles/records/{puzzleID}`: canonical `match-v1` puzzles.

Read-only public projections reuse existing listeners/notification triggers:

- `sessions/sv1_*` and `exhibitionInvites/sv1_*` for friends.
- `partyRooms/S1*` for parties, using a server-generated 12-character code.
- `coinWallets/{uid}/receipts/social_{roomID}_{roundIndex}` for accepted played rounds.

The reserved document-ID prefixes, not client-supplied flags, block all client
create/update/delete operations. Session reads require participation or ownership
of the winning result; invite reads require sender/recipient; party reads require
membership. Join-by-code goes through the callable before reading the room.
Existing session queries use playerIDs, and badge reconciliation queries winnerID.
Invite queries constrain fromID/toID. See `Tests/SocialRewardsRulesAudit.json`.

Active result projections omit guesses, words and board-state summaries. The
caller can recover their own complete result through the callable; completed
rounds expose breakdowns to participants. Puzzle seeds/payloads are still sent
to gameplay clients. This does NOT hide deterministic answers from a modified
client or prove a human played without a solver.

## Rollout Procedure

1. Keep production untouched. Use the existing `puzzlepartytest` Standard
   `(default)` database in `nam5`. Do not create another paid project.
2. Export and review a private catalog using
   `bash scripts/export-solo-reward-catalog.sh 4 --social`.
   This exports all eight modes at four difficulties; it uploads nothing.
   Each catalog document has `{version: 1, puzzleIDs: [...]}` and points at the
   matching canonical records. Do not upload `--test-proofs` fields. Four seeds
   are a development sample, not a release-sized pool.
3. Deploy the reviewed lifecycle functions and compiled rules to TEST only.
   Reusing the projection collections preserves existing invite push triggers;
   a selective functions deployment must include those triggers if testing push.
4. Provision reviewed migrated test wallets, and use the social gameplay test
   build pointed at that project. The installed purchase-only build is unchanged
   until a separately coordinated installation.
5. Enable `walletMigrationReady` and `socialRewardsEnabled` in the private test
   control document only after deployment/catalog preparation. For this restricted
   harness, also approve the exact test UIDs. The normal client wallet rollout
   switch remains false. The operator helper preserves existing balances and
   purchases, and only merges social control fields.
6. Test Play Now, Play Later, classic party and playlist flows on two devices:
   ready/start, all eight finals, daily bonus overlap with solo/dailies, failure
   and restart recovery, late submissions, timer expiry, ties and leaving lobbies.
   Check receipt amounts and revisions, not just the displayed coin balance.

## Remaining Limitations

- This is not a production deployment or a production anti-cheat guarantee. Public
  legacy sessions are never upgraded into trusted proof. Migrated clients refuse
  legacy invitation acceptance/party joining rather than falling back to payouts.
- There is no server-owned friend rematch handshake yet. Verified friend matches
  suppress the old rematch button; sending a fresh invitation creates a new match.
- Expiry is evaluated on authenticated actions/heartbeats, not by a scheduler.
  No-change heartbeats do not rewrite rooms. Offline rooms need a later action
  to materialize their terminal projection; add cleanup/monitoring before launch.
- Normal game deadlines have a 20-second transport grace. Catch-up deadlines
  are strict. Very late/offline submissions can become unpaid timeouts. Reopening
  does not reset the server clock, although full board/timer resume is not provided.
- Real-time proof checking, App Check, stronger rate limits, abuse monitoring,
  new-account wallet bootstrap, server badge/achievement progress, account-deletion
  cleanup and legacy rules hardening remain separate launch work.
- The normal app's legacy friendship and party-invite graph remains client-writable;
  the restricted test rules do not permit those client writes. An actual
  authenticated recipient must accept a friend game, or a player must join a party,
  before participating. This pass does not certify the legacy social graph.
- Emulator authorization tests and signed-in two-device acceptance have not run.
  The transaction double serializes requests; it is not a real Firestore conflict
  or load test. No phone installation was performed.

## Verification

### October 1 Test Rollout

- 53 live checks passed against the deployed Firebase callables and actual
  Firestore rules, using three disposable Auth accounts. These cover unsigned
  and unapproved requests, own/other/unsigned account reads, direct wallet/profile
  writes, private catalog/control/receipt reads, participant queries, fabricated
  results, Play Now/Play Later, repeated submissions, host authority, three-round
  scoring, old-round replay, and a real 180-second catch-up timeout. No clock,
  deadline or result was manually changed to make the timeout pass.
- Live finals exercised Word Guess, Lava Rescue and Color Link. All eight modes
  have local verifier coverage; seven modes x four difficulties x four seeds
  also passed real Swift-generated proof compatibility. Solitaire has its
  separate known-deck legal winning replay, not a live solved-game check here.
- All 24 social tests passed with the generated catalog, no skips. Additional
  purchase/wallet/match/daily regression run: 70 passed, one fixture-dependent
  skip (Apple product export not supplied in that invocation).
- Development-signed device build, ad-hoc-signed simulator build, normal
  signing-disabled simulator build, normal/social Swift parse, plist lint,
  backend lint and `git diff --check` passed.
- Live fixtures cleaned up successfully. Final original-account inspection:
  wallet/profile both 3,500 coins, revision 4, All Modes still unlocked, original
  three coin receipts and one ranked receipt unchanged.
- No app was installed, no signed-in two-client UI check was performed, and no
  production project was written. Test rules are a restricted prototype; the
  full app's production rules still need independent hardening and validation.
- Operator scripts: `scripts/social-test-admin.cjs prepare <catalog> <UID>`,
  `inspect`, and `verify <local-proof-catalog>`. They reuse the operator CLI
  session in memory, hardcode `puzzlepartytest`, and do not print credentials.
  Never use `firebase login:list --json` for diagnostics: that CLI output includes
  credentials. A diagnostic exposure occurred in this pass; with the operator's
  approval, Firebase CLI logout successfully revoked the session after live
  verification and cleanup. Future deployment/admin commands require Google
  reauthentication. App sign-ins and deployed services are unaffected.

### Original Local Implementation

- `scripts/check-social-lifecycle.sh`: real Swift catalog compatibility for all
  four difficulties in seven modes; separate legal winning Solitaire replay.
- All 23 social tests passed with that generated catalog. The combined Node suite
  passed 179 tests with two fixture-dependent skips; the social fixture check was
  then run separately. All 38 existing Swift match-resolution checks passed.
- Social tests cover all eight game types, duplicate/cross-room credit, forged
  results, membership/host authority, lost-response retries, Play Later clocks,
  expiry, finish-window timing, playlist scoring and stale round submissions.
- Full signing-disabled simulator build, DEBUG Swift parse, backend lint and
  diff checks passed. Repeat them before rollout if code or catalogs change.
- The original prototype rules only compiled in a TEST dry run. The separate
  restricted harness rules have now compiled and deployed to TEST, as above.

I've set up prototype Security Rules to keep the data in Firestore safe. They are
designed to be secure for server-owned social results and wallet receipts by
denying client writes and restricting participant reads. However, you should
review and verify them before broadly sharing your app. If you'd like, I can help
you harden these rules.
# Manual Test Server Audit (2026-10-01)

Read-only audit of `puzzlepartytest`; no production or remote data changes.

- Eight stored social rooms inspected. Play Now Anagram finished with both results;
  the completed public results match the private authoritative results.
- Single-round Color Link party finished with a 180-second catch-up window and
  a server timeout for the other player. Scores: 10 / 7.
- Three-round Color Link / Anagram / Minesweeper party finished. Round points
  accumulated correctly to 30 / 21; all public round results match private results.
- Play Later Word Hunt has one saved result, but the invitation was declined and
  the session is abandoned. This confirms the user's decline-after-submission test.
  Its public result is intentionally sanitized because the round is not finished.
- Follow-up Play Later Color Link match `sv1_e0ef50b3-3636-4912-8421-610e3dfe2814`
  finished with both players accepted and both results saved (phone 4 seconds,
  simulator 12 seconds). Phone correctly won; invite is completed, and public
  results match authoritative results. Each account has exactly one receipt for
  this round, both +0 because the daily bonus was already claimed. Wallet chains
  still reconcile at revisions 11 and 3. Both-players-finish test is now verified.
- Wallet receipt chains reconcile from bootstrap through current revision for
  both accounts. Phone balance: 3,525; simulator partner: 525. User-facing coin
  fields match. Each received one +25 social daily bonus, with no duplicate daily
  credits in the observed records. Zero-word / timeout partner attempts did not
  produce social reward receipts.
- Cloud Functions / Cloud Run error-level logs since 2026-10-01 00:00 UTC returned
  no entries at audit time. This does not prove the absence of handled rejections.
- Three unused old party lobbies remain stored as lobby. Expiration is checked
  on access; automatic stale-room cleanup remains a follow-up.
- This read-only audit does not itself exercise replay requests, UI board locks,
  or every game mode. Prior automated checks and user observations are separate
  evidence; this audit verifies the persisted outcomes of the tested scenarios.
- Deferred UI request: replace the playlist AirPlay leaderboard presentation
  with a proper round-by-round results breakdown.
