# Game-Specific Achievements - Proposed V1

Status: planning only. No rewards, payouts, or gameplay rules have been implemented by this document.

Economy dependency: `ECONOMY_REVIEW.md` reviews the reward, purchase, and shop loop. Ranked wagers have now been replaced by uncapped human match rewards (20-75 per win, 5 per completed loss, 10 per draw), with no coin entry requirement. Keep the proposed 1,450-coin lifetime achievement budget, but fix wallet/purchase authority and remaining reward loopholes before implementing new achievement grants.

## September 29: Claimable Achievement Area (Next Pass)

User direction: give achievements their own area with a visible notification when a reward is ready, then let the player open it and press Claim, similar to the achievement reward experience in Clash of Clans. This is planned, not implemented in the solo reward pass.

- Profile > Achievements is the proposed home. Show In Progress, Ready to Claim, and Claimed states, with an unread/claimable count on its entry point. No push-notification campaign is implied.
- Qualifying gameplay creates a server-owned unlock, not an immediate achievement coin payout. Claim settles that unlock once, with a durable receipt that survives retry, logout, reinstall, and multiple devices.
- Ordinary puzzle rewards and the daily play bonus remain automatic; do not force a claim action after every game.
- Wearable badges remain a separate prestige collection. A feat can link to a badge where appropriate, but the exact relationship and navigation are still a design decision, not approved implementation scope.
- Post-game feedback should say a reward is ready and link to Achievements. Claiming a reward must never be confused with equipping a badge.
- No repeatable achievement coins, no automatic coin grant for upgrading a badge tier, and no change to the proposed 1,450 lifetime budget without another economy review.

See `SOLO_REWARDS_ROLLOUT.md` for the incomplete shared-wallet prerequisite. The new solo reward foundation is disabled and has not been deployed.

## Direction

Use coin achievements for approachable milestones and memorable moments. Use wearable badges for repeated, recognizable accomplishments. Existing ranked, friend, Underdog, solo mastery, and streak badges stay intact; these additions should not create another badge for every normal action.

- Coin achievements pay once per account, not once per mode context, difficulty, day, or reinstall.
- Badge families have four tiers: 3 / 10 / 25 / 100 qualifying distinct puzzles or completed rounds. The emblem upgrades automatically using the existing tier system.
- Badge tiers do not pay coins. A run may separately earn its once-only coin achievement and a badge tier.
- First-guess Word Guess is a fun lucky moment, not proof of skill. Give it a coin achievement, not a repeating prestige badge.
- No new speed achievements for V1. Board/deal variation, accessibility, and pause behavior need review before time thresholds are fair.

## Hint Policy

User requirement: hints are limited to selected games and must never be available in online or head-to-head modes.

- Proposed V1 allowlist: normal solo Sudoku and Anagrams only, matching the games with existing hint controls. No hints added to the other six games.
- Disable hints in ranked, casual matchmaking, friend Play Now/Play Later, and all classic/playlist parties. Also disable them in Daily challenges because players share puzzles and standings; keep this restriction for tournaments if re-enabled.
- Enforce eligibility both in the visible controls and the hint action itself. Use explicit gameplay context, not a missing session ID as a proxy for solo: Daily and party callers also reuse solo game views.
- A hinted normal-solo run may earn the basic +25 first-completion achievement. The +50/+100 performance achievements and new Game Feats badges require an unassisted attempt, stated in their requirements. Hint use must persist across resume/restart paths.
- Sudoku notes, Minesweeper flags, letter shuffling, and Solitaire Auto-to-foundation remain normal controls. Lava Rescue's category/starter letter are shared puzzle rules, not optional hints. Do not remove these while enforcing the hint policy.
- Audit existing routes first. This document does not claim that every current online hint path is already blocked.

## Proposed Coin Achievements

Each game gets three achievements worth 25, 50, and 100 coins. Requirements are lifetime unless explicitly described as one round. Different qualifying achievements can unlock together, but each achievement pays only once. All +50/+100 performance feats require no hints; the +25 first milestones may be earned with permitted solo hints.

| Game | First milestone: +25 | Signature feat: +50 | Advanced feat: +100 |
| --- | --- | --- | --- |
| Color Link | Complete a board with every cell filled | Complete an Expert board | Complete 3 distinct Expert boards |
| Solitaire | Clear all 52 cards to foundations | Clear a Draw 3 deal | Clear Draw 3 with the one-redeal ruleset |
| Sudoku | Complete a puzzle | Complete Medium or higher without hints | Complete Hard or Expert without hints or conflicts |
| Minesweeper | Reveal every safe cell without hitting a mine | Clear a Medium or higher board | Clear a Hard or Expert board |
| Word Guess | Solve a word | Second Sight: solve a word on exactly guess 2 | Solve 10 distinct words within 3 guesses each |
| Lava Rescue | Rescue a word | Rescue a 6+ letter word with zero wrong letters | Rescue a 7+ letter word with zero wrong letters |
| Word Hunt | Find 5 distinct valid words in one completed round | Find a word of at least 6 letters in a completed round | Find 15 distinct words on a 4x4 board in one completed round |
| Anagrams | Find 5 distinct valid words in one completed round | Find a word of at least 6 letters in a completed round | Find 10 distinct words from a 7+ letter rack in one completed round |

Additional Word Guess achievement: Lucky First, +50 coins once for an exact first-guess solve. It does not also satisfy the exactly-second-guess achievement.

Budget: 24 base achievements x their 25/50/100 distribution = 1,400 coins, plus Lucky First = 1,450 total lifetime coins. No repeating achievement faucet or ad multiplier. Daily claims, daily play bonuses, ads, wagers, and existing match rewards remain unchanged.

The 10/15-word round targets are proposed, not proven balanced. Validate them against generated puzzles, available-word counts, and natural play before shipping. Test that qualifying rack/grid sizes can actually offer the required words; do not ship inaccessible targets or promise every random puzzle can satisfy every feat.

## Proposed Wearable Badge Families

Each family advances at 3 / 10 / 25 / 100 distinct qualifying puzzles or rounds, not consecutive wins. Count only the player's own unassisted performance; winning the multiplayer match is not required.

| Badge | One qualifying performance |
| --- | --- |
| Circuit Breaker | Complete an Expert Color Link board |
| Foundation Ace | Clear a Draw 3 Solitaire deal, with any supported redeal limit |
| Clear Mind | Complete Medium-or-higher Sudoku with no hints and no conflicts |
| Safe Hands | Clear Medium-or-higher Minesweeper without hitting a mine |
| Word Sense | Solve a Word Guess word within 3 guesses |
| Cool Head | Rescue a 6+ letter Lava Rescue word with zero wrong letters |
| Trailblazer | Find 15 distinct words in a completed 4x4 Word Hunt round |
| Wordsmith | Find 10 distinct words in a completed Anagrams round with a 7+ letter rack |

These differ from current badges: Specialists prove ranked wins, solo Mastery proves all four solo difficulties, and the new families prove repeated individual performance. Profile should group badges into Competitive, Game Feats, and Milestones so the expanded collection stays understandable.

## Eligibility And Fairness

- Eligible contexts: solo, Daily, ranked, casual, Play Now, Play Later, and classic/playlist parties. A game's required settings still apply. Fixed online presets are never changed to help earn an achievement.
- Finalized submitted results only. Starting, previewing, backing out, forfeiting, debug fixtures, and fabricated win-by-forfeit results cannot award anything.
- Word Guess/Lava Rescue may contain several words per match. Count each qualifying word separately only after the player's complete turn is submitted; exclude partial words. A finalized loss can still contain a legitimately solved qualifying word.
- Timed word games must reach their normal round end. Duplicate words never increase achievement progress.
- Multiplayer badge credit must not depend on an opponent finishing or winning, except for existing competitive badges whose requirements explicitly say so.
- Use a stable server-issued attempt identity for settlement, plus a private canonical puzzle fingerprint for repeat protection. Reopening, reconnecting, replaying a Daily, or playing the same puzzle through another route must not increase progress twice.
- For word-solve feats, fingerprint the target plus relevant rules privately, so repeating a known word cannot farm tiers. Do not expose raw answers or reusable answer hashes in public achievement data.
- A retry of an already seen puzzle is not a new qualifying first attempt. Mark participation when real gameplay begins; never grant credit simply for this start record. Account for restart/resume without creating fresh first attempts.
- Shuffle, notes, flags, and Solitaire's existing Auto-to-foundation control remain allowed. Optional hints follow the explicit solo-only allowlist above; they exclude performance feats and Game Feats badge progress, not the basic first milestone.
- Old first-completion achievements can be credited only from trustworthy, context-sufficient saved evidence. Do not infer no-hint, no-conflict, unique-puzzle counts, or first-attempt history from a personal-best number. Missing evidence means progress begins with new eligible attempts.

## What The Current Build Already Has

- Completion, difficulty, elapsed time, and several performance values are already available in game/result code.
- Word Guess includes solo guesses and per-word online solved/guess summaries. Lava Rescue tracks wrong letters; per-word normalization is still needed for multi-word turns.
- Word Hunt and Anagrams expose word counts and longest-word length; board/rack settings must accompany them for consistent eligibility.
- Solitaire has draw rules, moves, foundation progress, and redeals used. There is no need to invent an undo-based achievement or alter Auto behavior.
- Sudoku tracks hints and conflicts locally, but its online result summary does not currently save them. Solo display strings are not a reliable achievement data contract.
- Color Link and Minesweeper can report successful completion. Do not infer clean path drawing, flag accuracy, or guess-free play from that fact.
- The existing tiered badge UI and permanent unlock model can be reused. Reliable first-attempt evidence, cross-context puzzle identity, and authoritative coin grants are new work, not already guaranteed by the current build.

## Implementation Order

1. Finalize names, thresholds, the 1,450-coin budget, and what should be a badge versus a coin-only achievement. Playtest timed-word targets before committing them.
2. Enforce and test the solo-only hint allowlist across every game route. Then normalize typed achievement evidence across all eight games and all result routes, including settings, completion, assistance, attempt identity, and per-word metrics. Do not parse UI labels or expose puzzle answers.
3. Add deterministic achievement evaluation and tests without coin payouts first. Cover unique-puzzle rules, partial turns, resets, repeated submissions, and legacy missing fields.
4. Add authoritative, idempotent settlement for coin grants and permanent badge progress. Clients display outcomes; they must not be able to write their own coin achievement completion. Audit the associated access rules before release.
5. Add Profile > Achievements with game filters, progress, Ready to Claim/Claimed states, exact requirements, and a notification count for claimable rewards. Keep wearable rewards separate; finalize the linking design before implementation.
6. Add compact post-game feedback: achievement name and reward ready to claim, plus Wear Badge when a badge unlocks. Consolidate multiple unlocks into one results section, not stacked blocking popups. Never move an active board.
7. Verify all eight modes across representative contexts, then review coin totals and completion rates. Roll out only validated families; defer unsupported ones rather than silently weakening their requirements.

## Verification And Release Gates

- Below/exactly/above every threshold, including first versus second guesses and at-least-size rules.
- No payout or tier progress for unfinished/partial/debug/forfeit outcomes or repeated puzzle evidence.
- Multiple achievements in one result settle once; retries, app restart, sign-out/in, and two devices cannot double-pay.
- Same personal performance counts consistently across solo, Daily, multiplayer, and party result paths when settings qualify.
- Hint and conflict counters persist across allowed resume paths and cannot reset into a clean achievement.
- Hints are absent and their actions rejected in every online, friend, party, Daily, and tournament route; only allowlisted normal-solo games can invoke them.
- Coin receipts match the economy budget; badge upgrades never pay repeat coins or modify wagers/rank.
- Legacy data remains readable and existing equipped badges remain intact; no invented historical feats.
- Natural playthroughs and small-screen/accessibility checks, not only fixture tests.
- Rule/backend tests reject caller-supplied unlocks or coin amounts. Full build and Swift checks remain required, but are not a substitute for reward security testing.

## Deferred

Speed records, no-flag Minesweeper, perfect Color Link path runs, Solitaire move-efficiency records, comeback feats, and additional lucky-moment badges. These need better evidence or balancing and should not inflate the initial collection.
