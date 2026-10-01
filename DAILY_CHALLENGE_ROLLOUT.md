# Verified Daily Challenge Wallet Slice

Updated September 30, 2026. Implemented locally, not deployed or enabled.

## What Changed

- Authenticated `dailyChallenge_today/begin/complete/discard` callables.
- One pinned server schedule per UTC day, with all eight standard presets. It
  selects private `solo-v1` catalog puzzles and returns only public identifiers,
  mode/difficulty and seed. It does not return answers or accepted-word lists.
- One private attempt per account/challenge. Reopening retains the same puzzle
  and server start time. Completed or explicitly discarded attempts cannot restart.
- Completion validates actual game evidence, derives safe summary metrics, and
  commits the result, wallet receipt, balance mirror and daily progress atomically.
- No extra per-puzzle daily reward. Qualifying play shares the existing +25 daily
  bonus with solo and official matches. All eight submitted dailies grant +50 once.
  Valid terminal losses count; starting/quitting and empty timed rounds do not.
- A reviewed pre-migration all-dailies bonus marker suppresses another +50.
- Pending proof survives app restart. Retry uses the same receipt identity.
  Discard cannot reverse a payout that already committed. One failed old upload
  does not prevent other daily submissions or loading today's page.
- Result UI locks the board and distinguishes success from an upload failure.
- Dormant tournament coin debit/prize paths and legacy daily writes reject a
  migrated user snapshot inside their transactions as well as at entry.

## Data And Gates

Existing private rules cover:

- `economyPrivate/dailySchedules/days/{UTC-day}`: pinned challenge metadata and
  canonical puzzle hashes; never written by clients.
- `economyPrivate/dailyAccounts/users/{uid}/attempts/{challengeID}`: start clock,
  challenge binding, expiry, active/submitted/abandoned state.
- `economyPrivate/dailyAccounts/users/{uid}/days/{UTC-day}`: verified submitted
  modes and all-dailies bonus marker.

The new read-only projection is
`serverDailyChallenges/{UTC-day}/entries/{uid}_{challengeID}`. It contains public
username/avatar identifiers, mode, difficulty, completion, score/progress/time,
compact counts and submission timestamp. No guesses, letters, puzzle answers,
paths, email, evidence, payment information or private catalog data are included.
Signed-in users can compare entries; all client writes are denied. Legacy
`dailyChallenges` documents never authorize a verified payout.

Each payout uses `coinWallets/{uid}/receipts/dailyChallenge_{challengeID}`.
The private server switch `dailyChallengesEnabled` AND `walletMigrationReady`
must be true, with a provisioned version-1 wallet. Neither switch was changed.
The existing client `serverWalletRolloutEnabled` remains false. Do not enable it
or migrate production wallets based solely on these tests.

## Acceptance Still Needed

1. Provision and review a sufficiently large private solo catalog in the test
   project. Four-seed sample exports are not release content. Selection can reuse
   a catalog puzzle on another day; fresh-content scheduling/replenishment needs
   operational review before release.
2. Deploy the explicit daily functions and reviewed rules to the test project,
   not the production project. The purchase-only rules/config do not include
   full-app daily access. Use a separate approved full-app test build/account.
3. Exercise every natural finish/loss on-device, cross-device attempts, restart,
   network failure, discard versus payout, UTC midnight, and all-eight completion.
4. Submission is accepted until two hours after the challenge day's midnight.
   Streak credit uses submission day; the all-eight bonus belongs to challenge day.
   Server elapsed time includes network delay and time away from the game.
   Review that UX before release; it is not a client stopwatch authority.
5. Add Firestore emulator authorization/contention checks, App Check, rate limits,
   leaderboard pagination and monitored catalog operations before launch.

This validates puzzle evidence, not human play. Seeded client generators still
allow a modified client to derive answers. Automated solvers, collusion and
shared answers are not solved by an atomic wallet transaction.

## Friend And Party Follow-Up

Implemented locally in the subsequent social pass: private creation/start records
now bind participants, canonical puzzles, per-round clocks and final proof before
shared-wallet daily credit. Existing public legacy results are never copied into
trusted records. The new path remains disabled and undeployed pending test-project
catalog provisioning and two-device acceptance. See `SOCIAL_REWARDS_ROLLOUT.md`.

## Verification

- `bash scripts/check-daily-challenges.sh`: all daily tests passed with actual
  Swift-generated proof compatibility for seven modes; Solitaire is covered by
  a known legal winning replay. The transaction double checks read-before-write
  ordering and serializes calls; it is not a Firestore emulator.
- Signing-disabled simulator build, targeted Swift parse, backend lint and
  `git diff --check` passed during this pass.
- Rules dry-run compilation passed against `puzzlepartytest`, without deployment.
  Java is not installed, so emulator authorization tests have not run.
- No live wallet, flag, function, rule, catalog or installed phone app changed.
  See `Tests/DailyChallengeRulesAudit.json` for the scoped rules review.
