# Ranked / Casual Test Build

## Scope

Prepared October 1, 2026. Build-only pass requested by the user. Do not install
on a phone or simulator until the user returns and explicitly authorizes it.
Production flags, rules, data and functions remain unchanged.

The test build uses `PP_SOCIAL_SANDBOX` plus `PP_RANKED_SANDBOX`, inherits the
existing fail-closed `puzzlepartytest` bootstrap and server-wallet requirement,
and cannot compile for Release or without social sandbox isolation.

The root screen exposes Ranked / Casual and all eight game modes at their fixed
online presets. It reuses `MatchmakingView` and `MultiplayerViewModel`, not a
simulated matchmaking UI. Friends and parties remain accessible. Account refresh
and match dismissal reload the server-backed profile.

## Build Without Installing

- `bash scripts/build-ranked-test.sh device`
- `bash scripts/build-ranked-test.sh simulator`
- Output root: `/private/tmp/RKDPRankedTest/Build/Products/`
- No install, launch, or device-management commands are included in the script.
- Display name: `PP Ranked Test`; bundle remains `com.rkdp.app`.

## Required Before Live Ranked Testing

The previously deployed social test backend alone is not sufficient. Before
asking the user to queue, prepare and verify these test-only dependencies:

1. Deploy official match callables and settlement support to `puzzlepartytest`.
2. Prepare preset `matchCatalog` manifests using reviewed canonical puzzles.
3. Prepare `matchEconomyVersion` and authoritative rank maps for the two approved
   wallets without resetting balances, purchase entitlements or daily history.
4. Add participant-only reads for `serverMatches` to the isolated test rules;
   keep client writes and private economy records denied. Test authorization.
5. Enable only the required test-project match lifecycle / reward controls.
6. Verify live queue, ready, submission and settlement before device acceptance.

## Device Acceptance

Start both accounts in the same ranked mode within 15 seconds to exercise human
pairing rather than Bronze bot fallback. Verify shared puzzles, fixed settings,
entry consumption at start, winner/loser rank and coins, repeat result opening,
disconnect/forfeit, and server expiry. Then test casual and cross-mode daily
bonus behavior. Tier-specific fixtures must be operator-controlled and test-only.

## Checks

- Match lifecycle and match reward suites: 84 tests passed in this pass.
- Development-signed iPhone build and signed simulator build both passed.
- Both built apps' embedded Firebase project is `puzzlepartytest`; code signature
  verification passed for both. Neither app was installed or launched.
- Normal and ranked-test Swift parse, generated plist lint, build-script syntax,
  and `git diff --check` passed.
- No live ranked test is claimed by these local tests or the build itself.

## Test Deployment And Installation (October 1 Follow-Up)

- User returned with phone unlocked and authorized continuing installation.
- Deployed six `officialMatch_*` callables and `settleWalletMatch` to
  `puzzlepartytest` only. The asynchronous settlement trigger is NOT deployed;
  finish calls and explicit result-screen settlement retries handle this harness.
- Enabled match lifecycle/rewards with `matchTestUIDs` restricted to the two test
  accounts. Prepared eight preset catalogs from existing reviewed social puzzles.
  Added match rank/counter fields without changing balances or purchases.
- Added participant-only `serverMatches` reads to test rules; all client writes
  remain denied. These are restricted prototype harness rules, not full-app
  production rules or a comprehensive security certification.
- 28 live checks passed using disposable accounts: ranked/casual pairing, Expert
  Color Link, readiness, invalid proof rejection, verified finish, Bronze 20/5 and
  casual 15/5 payouts, daily bonus once, repeat settlement/submission idempotence,
  participant reads, outsider/anonymous denial, update/delete denial, and private
  match/opponent-wallet denial. Fixtures were removed; real test wallets were not
  used by the live checks. Each fixture match used a verified winning proof, not
  UI gameplay. Other modes and real two-device gameplay remain user acceptance.
- 85 local match tests passed, including the optional ranked test allowlist.
- Installed the previously verified builds without uninstalling on iPhone `26`
  and isolated simulator `277B32A1-8B43-4564-BE9E-213FD61320A5`.
- Production remained untouched. Test partner has one free ranked entry per mode
  per UTC day; do not silently grant All Modes or overwrite purchased access.

## Online Rules V2: Prepared Locally, Not Activated

- Sudoku cells now have full-cell button targets; tapping the selected cell no
  longer deselects it. Online hints are hidden. Device feel still needs acceptance.
- New ranked matches use Easy Sudoku/Minesweeper and Hard Color Link below
  Platinum, then Medium Sudoku/Minesweeper and Expert Color Link from 3600 points.
  Word Guess uses one word, 6 guesses below Platinum and 5 above. Fewer guesses
  wins, then elapsed time; both misses draw. Casual always uses the lower preset.
- Other modes retain their current presets. Friend/party Word Guess is unchanged.
- Rules are stored per match. Missing version means the old rules; v2 searches
  use separate queue buckets. Existing matches retain their format and timeout.
- Sudoku result snapshots accept old and new separators. Minesweeper snapshots
  are reconstructed from verified evidence and exposed only with final results.
- Reward receipts now include before/after rank points. The UI also supports old
  receipts using the starting match rank. Forfeit coin eligibility is unchanged.
- Local verification: 193 backend checks passed, including generated puzzle
  fixtures; signed device and simulator builds succeeded. No installation or
  deployment was performed in this pass. Physical tap feel/layout not yet checked.

Next operator steps, in order (test project only):
1. With user approval, install both prepared ranked-test builds. Do not uninstall
   or reset either account. Finish/cancel outstanding searches on the old builds.
2. Deploy updated `officialMatch_*` and `settleWalletMatch` implementations to
   `puzzlepartytest`. Keep the existing tester allowlist and production untouched.
3. Run `scripts/social-test-admin.cjs ranked-v2-catalog` with the existing CLI
   library configuration. This validates and stages catalog manifests only; it
   does not activate v2, alter balances, ranks, purchases, or existing catalogs.
4. After the above checks, set `economyPrivate/control.onlineRulesVersion` to 2
   in the test project. Without that flag, deployed code continues creating v1.
5. Check fresh base/Platinum matches, Word Guess solve/miss/tie cases, Sudoku taps,
   final board previews, and forfeit rank display. Audit saved receipts afterward.
   Old matches cannot gain board snapshots that were never recorded.

## V2 Installed And Activated (October 1 Follow-Up)

- User authorized installation on both devices. Installed the prepared builds
  in place on iPhone `26` and test simulator
  `277B32A1-8B43-4564-BE9E-213FD61320A5`; no uninstall or account reset.
- Simulator launched successfully. Phone installation succeeded, but remote
  launch was denied because the phone was locked; user was asked to open it.
- Test bootstrap explicitly uses `PPTestFirebase` in the generated Info.plist,
  not the bundled production GoogleService-Info.plist, and fails closed if the
  runtime project is not `puzzlepartytest`.
- Updated only the six `officialMatch_*` functions and `settleWalletMatch` in
  `puzzlepartytest`. No production deployment or rules changes.
- Staged 12 v2 catalog manifests. Guarded activation verified the two-account
  allowlist, no active match/search, and catalog presence before setting
  `onlineRulesVersion: 2`. Balances, ranks and entitlements were not changed.
- 28 live ranked/casual smoke checks passed with disposable accounts, now using
  Hard Color Link and asserting rules version 2. Authorization, final settlement,
  payouts, daily bonus and replay/idempotence checks passed. Fixtures removed.
- Awaiting user gameplay acceptance: Sudoku tap feel, board previews, BO1 Word
  Guess and forfeit rank display. Platinum boundary and reconnect acceptance
  remain next; the prior local fixture tests do not replace those live checks.

## Live Platinum And Reconnect Checks

### Subsequent Word Hunt Preset Change

- Word Hunt now uses Medium (5x5, 75 seconds) for new ranked/casual matches at
  every rank. Solitaire remains Easy; other agreed presets remain unchanged.
- Word Hunt matches use rules version 3 and separate queue buckets. Existing
  version 1/2 Easy matches remain valid, including settlement after deployment.
- Medium catalog staged in the test project; local verification passed all 194
  checks, including backward-compatible Easy forfeit settlement. Swift parse and
  lint passed. Installed clients receive the difficulty from the server; no
  reinstall is needed for current test gameplay. Client preset source is updated
  for the next build. Solo/friend/party choices are unchanged.
- Deployment of the six official match callables and settlement completed in
  `puzzlepartytest`; production and device installations were not changed.

### Word Guess Race And Sudoku Result Clarity

- A verified first solve now immediately ends a v2 Word Guess match. The other
  player receives the final status `Opponent solved first`, cannot continue
  entering guesses, receives the normal ranked loss, and receives no coin reward
  without a completed result. The winner's verified solve remains the only
  eligible daily-play completion.
- Word Guess rank remains division-adjusted, with a small server-verified winner
  bonus: 1 / 2 / 3 guesses adds +6 / +4 / +2 Rank Points respectively, and a
  solve under 30 seconds adds +1. The combined performance bonus never exceeds
  +6 and never increases the opponent's loss.
- Sudoku results now persist a separate givens mask. The updated breakdown grid
  renders given numbers, player-entered numbers, and remaining blanks distinctly.
  The Sudoku card omits generic stats so the board is the focus.
- 194 local backend tests, Swift parse, `git diff --check`, and development-signed
  simulator/device test builds passed. The server update was deployed only to
  `puzzlepartytest`; no production deployment occurred.
- A live disposable-account verification was intentionally blocked because a real
  tester occupied the same rank bracket. Fixtures were removed without touching
  real data. Run it later between device tests, or after assigning fixture ranks
  that cannot pair with active testers.

### Earlier Boundary And Reconnect Run

- Ran `ranked-v2-verify` while the user continued device testing. Used disposable
  accounts only, at 3599 and 3600 authoritative rank points. A guard rejected the
  run if real testers occupied either fixture bracket, avoiding accidental pairing.
- All 36 checks passed across eight fixture matches: Easy/Medium Sudoku and
  Minesweeper, Hard/Expert Color Link, and Medium/Hard single-word Word Guess.
- Renewed authentication and requeued each active fixture with a new request ID:
  the same match was returned and repeated readiness preserved its start time.
- Verified forfeit loss/win rank deltas and receipt start/end points, zero coin
  reward for either unfinished player, and repeated settlement idempotence.
- Word Guess confirmed one-round metadata, hidden opponent results until finish,
  accepted single-round proof and no additional payout on retry.
- Removed fixture accounts and matches. Real device accounts, ranks, coins and
  entitlements were untouched. No app installation, deployment or rules change.
- Scope: these are live API reconnect tests, not a physical network drop, SwiftUI
  state restoration, or full app termination/relaunch acceptance test.
