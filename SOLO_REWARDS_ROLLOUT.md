# Solo Rewards: Implementation And Rollout

Updated September 30, 2026.

## Status

PARTIAL IMPLEMENTATION. Local foundation is implemented and tested; deployment and shared-wallet migration are not complete. This is not a production anti-cheat system yet.

Latest follow-up: verified Daily Challenges now have server-issued attempts,
proof-derived results, shared +25 daily credit, once-per-day +50 all-eight bonus,
retry/discard recovery and migrated-wallet guards on dormant tournament writers.
This slice is **local only**, with no deployment or activation. Friend/party
trusted issuance and daily-play settlement are now implemented locally as well,
including private puzzles, participant clocks, retry receipts and playlist rounds.
See `DAILY_CHALLENGE_ROLLOUT.md` and `SOCIAL_REWARDS_ROLLOUT.md`. Neither gameplay
slice is deployed or accepted in a two-device test yet.
Apple purchase sandbox progress is tracked in `APPLE_PURCHASE_ROLLOUT.md`; its
newer live test results supersede the historical "not tested" notes below.

`SoloRewardClient.rolloutEnabled` is false. The server also requires BOTH `economyPrivate/control.soloRewardsEnabled` and `walletMigrationReady`, plus an Admin-provisioned `coinWallets/{uid}` with version 1. No production flags, wallet documents, catalog entries, balances, functions, or rules were changed by this pass. Do not create migrated wallets or enable these switches until the checklist below is complete.

## Shared Wallet Migration: First Working Slice

The follow-up implementation now connects solo payouts, the +50 shop daily claim, and direct cosmetic purchases to `functions/wallet-ledger.js`. One transaction updates the authoritative balance, user-facing balance mirror, ordered revision, and immutable receipt. Repeat requests return their receipt instead of minting coins or charging again. Cosmetic equipping validates ownership and slot without accepting inventory changes from the client.

- `wallet-shop.js` owns daily reset time, cosmetic prices, daily rotation eligibility, and purchase debits. Its rotation was checked against the actual Swift catalog. Stale displayed prices and off-rotation items are rejected; existing owners are not charged again.
- `wallet-migration.js` is an **Admin-only library, not a callable endpoint**. It requires an operator-reviewed snapshot approval at `economyPrivate/migrations/users/{uid}`, with `version: 1`, `approved: true`, `approvedBy`, and the exact `expectedHash` from `snapshotHash(user)`. It aborts if the source economy changes after review. Approval means the operator has accepted the legacy data; the hash alone is not proof that old coins were legitimately earned.
- Migration preserves balance, inventory, previous daily claim/play days, existing user reward markers, and a private source snapshot. It creates a migration receipt and a stable account token for future server-verified purchase binding. Repeating migration cannot reset the balance or grant starting coins again.
- The private catalog belongs at `economyPrivate/cosmeticCatalog`. `bash scripts/export-wallet-catalog.sh` exports the app's exact prices, defaults, slots and visibility; it does not upload anything. Exported `testDay`/`testRotation` fields are local comparison metadata, not authority for server rotation.
- The client routes migrated daily claims, cosmetic purchases and equipment saves through callables. Direct balance/whole-user writes and unmigrated generic wallet mutations are refused for migrated accounts. `FirestoreService.serverWalletRolloutEnabled` remains **false**. Backend shop operations additionally require `walletOperationsEnabled` and `walletMigrationReady`; migration requires `migrationsEnabled` and `walletMigrationReady`. No flags or approvals were created in production.
- StoreKit finishes coin and ranked purchases only after their grants succeed. Migrated purchases now have a locally implemented Apple signature/API verification route, global account binding and refund reconciliation. It remains unconfigured/undeployed; legacy local tokens are not a cross-device authority. See `APPLE_PURCHASE_ROLLOUT.md` for configuration, historical-purchase limitations and required live sandbox tests.
- Prototype rules now also protect migrated cosmetics and the migration marker. A Firebase CLI rules **dry run compiled successfully** without deployment. Broader legacy rule weaknesses and emulator/authorization tests remain open.

Still not live: deployment/acceptance of the new online match lifecycle and Apple purchase verification/refunds, friend/party daily play, Daily challenge rewards, historical purchase/entitlement backfill, earned reward authority, new-account bootstrap and the coordinated production rollout. Ranked/casual/bot settlement is connected locally to the official lifecycle. Hidden packs/tournaments must remain disabled. This is not an instruction to activate the feature flags.

Follow-up checks passed: **13 shared-wallet tests, all 80 solo reward tests, full signing-disabled simulator build, Swift parse, backend lint and diff checks**. Transaction concurrency checks still use a serialized in-memory double, not a running Firestore emulator. No actual StoreKit sandbox purchase or signed-in UI flow was performed.

## Ranked And Casual Settlement Slice

`functions/match-rewards.js` now settles both human wallets in one transaction. `match-reward-policy.js` resolves all eight games with the existing tie-break order, starting-rank win ladder (20/30/40/50/60/75), losses 5, draws 10, and no wager debit. Casual remains 15/5 up to 90/day. Quitters and synthetic forfeit winners receive no coins; a genuinely completed winner retains the normal reward. Bot wins remain limited to three rewarded wins/day across modes; no bot loss/draw coin reward is added. Counters use server UTC settlement day.

- Stable `match_{sessionID}` receipts prevent repeat payouts and rank changes. Either human participant can retry; both are settled atomically. A receipt remains readable through the callable after payout gates are paused. Calls cannot supply a winner, amount, starting rank or bot flag.
- Verified participation grants the shared +25 daily play bonus and increments games played once, inside the same transaction. Simply appearing in a lobby is not participation. Solo/shop/match transactions share the same authoritative balance and revision. The app no longer separately requests a daily bonus on partial Word Guess/Lava rounds.
- Migration now carries reviewed competitive rank fields, casual caps and bot caps into the server wallet (`matchEconomyVersion: 1`). Competitive updates preserve newer solo difficulty records. No already-provisioned wallet is silently upgraded; an explicit reviewed upgrade would be needed for any older test wallets.
- The migrated app paths call `settleWalletMatch`, refresh the user, and display committed receipt values. They never fall back to legacy payouts after server failure. Failed verification remains retryable. All client/backend rollout gates remain off/not provisioned.
- `settleVerifiedWalletMatch` is an automatic creation trigger on the **private** verified-record path, not public `sessions`. It settles both participants even if one is offline. While paused, new events are skipped; recovery must replay pending records through the idempotent settlement operation after unpausing.

### Official Match Lifecycle: Implemented Locally, Not Deployed

**There is deliberately no writer that copies current public session results into verified records.** `functions/match-lifecycle.js` instead owns a separate authenticated queue, readiness, server start clock, submissions, forfeits and expiry. `match-evidence.js` derives final results for all eight games from the canonical puzzle and submitted evidence. Current public sessions/RTDB results and client bot/rank snapshots remain untrusted and cannot mint verified matches.

- `officialMatch_queue/cancel/ready/submit/forfeit/tick` require non-anonymous authentication. All lifecycle actions except cancellation require `walletMigrationReady`, `matchLifecycleEnabled` and `matchRewardsEnabled`. These flags remain absent/off. Queueing requires a migrated version-1 competitive wallet.
- The official queue buckets by mode, ranked/casual and ranked tier, with fixed standard presets. Private per-account state prevents pairing the same account into multiple matches. Search requests renew a 20-second lease; a cancellation tombstone prevents a late callback recreating that request. Waiting rooms expire after two minutes. Bronze bot fallback is server-generated after 15 seconds and restricted by the private daily bot-win counter.
- Ranked entry is consumed atomically only once, when all humans are ready. Approved migration snapshots include ranked access; Apple entitlement writers now exist locally, while ad tickets still need trusted writers. Public user-ranked-access edits do not authorize official entry.
- Private state lives in `economyPrivate/liveMatches/records/{id}`, `economyPrivate/matchAccounts/players/{uid}`, and `economyPrivate/matchQueues/buckets/{key}`. Participant-only `serverMatches/{v1_id}` is a client-read-only projection. It withholds opponent result summaries until the match ends. Authenticated reconnect replies return only the caller's own accepted result.
- Client finals include boards, paths, legal Solitaire moves, Minesweeper revealed cells, Word Guess round guesses, Lava round letter histories, or found words. The server determines score, finality and receipt-based elapsed time. Timed games allow a 20-second delivery grace; their deadline does not reset on reconnect. Word Guess has no gameplay timer but abandoned sessions expire after 24 hours. A legitimate late/offline submission can miss that deadline; verify the UX in two-device testing.
- Missing-result expiry runs when a client reconnects or sends a heartbeat; this is not a scheduled cleanup worker. Both missing results abandon without coins. One missing result is handled as a forfeit. Add operational cleanup/monitoring before launch.
- The client stores pending final evidence for retry, restores submitted-board locking on reconnect, and checks official finished sessions during account refresh for missed payouts. A submitted final cannot be replaced or undone by forfeiting. Same-opponent official rematch consent is not implemented yet; its button is hidden for official sessions and Play Again starts another search. Legacy rematches are unchanged.

#### Canonical Online Catalog

`bash scripts/export-solo-reward-catalog.sh 4 --online` exports actual standard-preset app puzzles as `match-v1` records; it does not upload them. Store each record at `economyPrivate/matchPuzzles/records/{id}` and a version-1 `puzzleIDs` list at `economyPrivate/matchCatalog/modes/{mode}` using an authorized Admin operation after review. Word Guess/Lava include their three-round canonical data and the exact existing online payload. Publish a release-sized immutable catalog, not these four-seed samples. The match binds a canonical hash to its selected record, rejecting changes during play. `--test-proofs` output must remain local.

This verifies valid game evidence, not human play. Board-set evidence is not a full action history for every game. The app's existing online payload may expose answers to a modified client; collusion, repeat catalog puzzles and automated solvers remain risks. Server authority removes caller-selected outcomes/coin amounts, but does not make farming impossible.

The source is `economyPrivate/verifiedMatches/records/{sessionID}`, already denied to clients by the private-collection rules. Only a trusted match lifecycle may create it after verifying:

1. Server-issued session identity, participants, authenticated readiness, standard preset, canonical puzzle and server start/finish clocks. Both human accounts must be migrated before the match starts.
2. Server-snapshotted starting ranks from wallet state, ranked entry entitlement, and server-generated bot identity/result (not client `isBot` or a copied public session).
3. Authenticated per-player attempts/proofs, finality, participation, forfeit ownership and timeout rules. Multiplayer Word Guess/Lava now have dedicated round adapters; the solo validator alone is not a substitute.
4. One immutable verified result record for the issued match, with anti-replay binding to that issued match. Never accept user-created session IDs as authority for producing more verified games.

Record schema: `version: 1`, `verifierVersion: "match-v1"`, `sessionID`, `status: "finished"`, `matchKind` (ranked/casual), `mode`, `difficulty`, `startedAtMs`, `finishedAtMs`, two `players` with `userID/isBot/rankPoints`, `playerResults` in the app result shape, `playedUserIDs` (humans with verified actual play), and `forfeitedIDs` (zero or one participant). Results are recomputed, not taken from a caller's `winnerID`. The payout transaction adds `settledAtMs` and `resolvedWinnerID`. The schema validator is **not** a gameplay/anti-cheat verifier. Synthetic test fixtures must never be uploaded to production.

Competitive badge reconciliation, earned-title authority, public leaderboard write restrictions, official rematch consent, production catalog operations, and old-client rollout behavior still need completion before activation. This slice does not claim to close collusion, solver abuse, legacy forged balances, or all reward loopholes.

## Implemented Locally

- Approved 32 game/difficulty reward values in `SoloCoinRewards` and `functions/solo-reward-policy.js`.
- Authenticated, non-anonymous callable endpoints for status, beginning, completing, and abandoning a solo attempt.
- Admin-only canonical puzzle catalog. The caller supplies neither the puzzle nor the reward amount. Public attempt responses include only identifiers, game/difficulty, seed, reward, and expiry; no solution/word list is returned.
- One active attempt per account across devices. Reopening on another device resumes the same seed and server clock. Explicit discard can close an old-device attempt even if its local request ID was lost.
- Puzzle identity reserved at issuance, including abandoned attempts. Repackaging a known word/board/deal at another difficulty cannot award the same identity again. Minesweeper identity includes seed and board parameters because placement depends on first tap.
- Completion validators for Sudoku constraints/givens, Color Link paths, Minesweeper placement/safe cells, Solitaire legal move replay, Word Guess guesses, Lava letter history, and timed word-game valid words/server duration.
- Atomic server wallet update, mirrored user balance, once-daily +25, final receipt, and attempt status. Duplicate callbacks/retries return the original receipt. Kill switches are reread inside the settlement transaction; existing receipts remain recoverable after payouts are paused.
- Client completion evidence, persisted pending claims, retry/discard controls, and reward receipt summary. Replay waits for settlement or explicit discard. No local base coin increment.
- Difficulty reward labels and post-game Puzzle +X / Daily bonus +Y only when rollout is enabled.
- Server-owned collection rules and conditional protection for migrated users. Legacy accounts deliberately remain unchanged until migration.

## Remaining Release Blockers

1. **Shared wallet authority:** finish migrating the remaining live coin writers before creating any `coinWallets` documents. The ledger, daily claim, direct cosmetic purchase and equip paths now exist; whole-user saves and other legacy writers must not bypass them. Trusted gameplay/achievement eligibility still needs server ownership, not just the balance field.
2. **Trusted online acceptance:** issuance, proof-derived results and private settlement are connected locally. Privately provision/review the canonical catalog, test real two-device queues/reconnects/clock behavior, finish rematch consent and operational expiry, then deploy as part of the coordinated rollout. Current client-authored sessions are deliberately rejected as evidence.
3. **Purchase acceptance:** configure and sandbox-test the implemented Apple verifier, global transaction binding, refunds/reversals, and cross-device recovery. Add notification failure monitoring/history reconciliation and reviewed historical purchase migration. Legacy grants remain for non-migrated accounts. See `APPLE_PURCHASE_ROLLOUT.md`; no real Apple delivery/refund has been tested yet.
4. **Other rewards/spending:** deploy and accept the locally implemented friend/party and Daily Challenge slices in test; implement trusted ad rewards before enabling ads. Shop claim/direct cosmetics and ranked/casual/bot settlement already use the ledger locally; trusted gameplay producers remain undeployed. Keep dormant tournament and pack paths disabled or port them before restoring them.
5. **Migration/backfill:** preserve trusted balances, already-paid daily bonus day, streak history, applied result IDs, verified purchases, and ownership without resetting money or replaying grants. Existing client-authored balances cannot simply be declared verified. Plan mixed-version behavior and account deletion before provisioning wallets.
6. **Catalog operations:** validate, privately upload and replenish a sufficiently large immutable catalog. `scripts/export-solo-reward-catalog.sh` uses actual app generators but only exports JSON; it does not upload anything. Default four seeds per game/difficulty is a development sample, not a release catalog. The server scans up to 24 candidates and fails closed when no fresh puzzle is found. Add a clear unrewarded-play path and replenishment monitoring before launch so catalog exhaustion does not block solo play.
7. **Abuse controls:** add App Check enforcement/client tokens, per-account request limits, start/abandon limits, anomaly monitoring, and solver-abuse review. A valid board proof cannot prove a human played it; a timed server window also includes idle time. No claim of "impossible to farm" is justified.
8. **Rules/emulator testing:** rules compilation passed a Firebase CLI dry run. Still exercise rules in a Firestore emulator, including owner/non-owner/unauthenticated reads and writes, protected-map deletion, and batched writes. The current machine has no Java runtime; these emulator tests have not run. See `Tests/FirestoreEconomyAudit.json` for legacy critical findings. Rules are still prototype/beta rules, not production-ready.
9. **Integrated acceptance:** real signed-in flow, offline/restart recovery, two-device Firestore transaction contention, all eight natural game finishes, cross-mode daily bonus, exact receipt display, and shop/ranked/purchase regressions. Do not use isolated transaction-double tests as proof of deployed Firestore behavior.

## Wallet Writer Inventory

| Current path | Migration required |
| --- | --- |
| `FirestoreService.createUser` / `updateUser` | Server-controlled initial balance; whitelist ordinary profile fields; never overwrite wallet/caps/ownership from a stale user snapshot |
| `AuthViewModel.recordSoloResult` | Gated new path saves statistics only; legacy path still grants daily bonus and saves the user |
| `FirestoreService.recordDailyPlay` | Shared server day and receipt, across friend/party and other submitted results |
| `RankingService.applyFinishedSession` | Official lifecycle, verifier and settlement connected locally; catalog/deployment/acceptance pending |
| `FirestoreService.applyFinishedCasualSession` | Official lifecycle, verifier and cap/receipt connected locally; catalog/deployment/acceptance pending |
| `FirestoreService.claimDailyCoins` / rewarded coin method | Daily claim ported; ad callback verification and shared ad caps still needed |
| `FirestoreService.applyCoinPackPurchase` / StoreKit service | Verified server grant/binding/refunds implemented locally; configuration, historical reconciliation and sandbox acceptance pending |
| `FirestoreService.purchaseCosmetic` / hidden pack method | Direct purchase/equip ported; keep packs disabled |
| `DailyChallengeService` / `TournamentService` | Server-validated entries and idempotent bonuses; tournaments remain hidden |

## Verification

- Apple purchase follow-up: **26 purchase tests** including production Swift catalog parity, plus **194 existing wallet/solo/match tests**, passed. Full signing-disabled simulator build, Swift parse, lint and diff checks passed. The Apple positive API boundary was mocked; actual credentials, sandbox delivery/refunds and cross-device acceptance remain outstanding. No rules change, deployment or new simulator installation in this pass. See `APPLE_PURCHASE_ROLLOUT.md` for setup and dependency-security blockers.
- Official lifecycle follow-up: **29 lifecycle tests**, including two real generated puzzles per mode, passed. Tests cover authenticated pairing/readiness, entry consumption, cancellation races, canonical puzzle binding, evidence-derived results, private reconnect replies, bot limits, expiry and payout integration. **72 match-wallet tests**, **13 wallet/shop tests**, **80 solo tests** and **195 ranked coin checks** also passed. Full signing-disabled simulator build, backend lint, Swift parse, rules-compilation dry run and diff checks passed. No functions/rules/catalog deployment, wallet migration, simulator install, signed-in two-device test or emulator authorization test was performed.
- Match-wallet follow-up: **72 match-wallet tests**, including a contract comparison against **448 production Swift cases**, passed. The **13 wallet/shop tests**, **80 solo reward tests** and **195 ranked coin checks** also passed. Final signing-disabled simulator build, targeted Swift parse, backend lint and `git diff --check` passed. No deployment, emulator authorization test, signed-in two-device match or new simulator installation was performed. Rules were unchanged in this follow-up; the earlier compilation dry run is not a new authorization test.
- `bash scripts/check-solo-rewards.sh`: 80 passing tests, including 64 app-generator compatibility cases (two seeds for each game/difficulty). Includes legal Solitaire replay fixture, invalid/partial proofs, failed attempts, concurrency ordering, retries, abandoned identities, expiry, kill switches, daily bonus limit and day rollover.
- Existing regressions: 195 ranked reward checks, 158 board-game flow checks, and 66 Word Guess/Lava flow checks passed. Swift parse, backend lint, and `git diff --check` passed. Simulator-target Xcode build with signing disabled passed; no install or signed-in simulator flow was performed.
- The transaction double serializes operations and enforces reads before writes. It does not simulate network failures, optimistic retry conflicts, security rules, or production load.
- Catalog proof export (`--test-proofs`) is for local tests only. Never expose it to clients or use its proof fields as caller-trusted data.
- Xcode simulator build, targeted Swift parsing, lint, and existing gameplay/ranked regression checks are required before merging. Test results are reported in the task response; rerun after any migration changes.

## Future Achievements

`GAME_ACHIEVEMENTS_PLAN.md` now records the requested claimable achievement area. Unlock eligibility, claim receipts, and wearable badge progression should remain separate concepts. Ordinary puzzle payouts stay automatic. No achievement notification, badge linkage, or claim UI is implemented here.
