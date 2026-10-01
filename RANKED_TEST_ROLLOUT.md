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
