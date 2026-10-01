# Cosmetics Release Plan

## Direction

Keep the squared puzzle character, flat head, bottom notch, thin outline, and small feet. Polish a smaller launch selection before expanding it. Most body skins remain aesthetic purchases. Earned rewards primarily communicate accomplishments through titles, badges, frames, and a few distinctive accessories. Simple rank-color bodies are the exception.

## 1. Visual Foundation - First Pass Implemented

- Five material skins: Frost, Lava, Obsidian, Prism, Starlight. Each has a clear static identity and one controlled motion idea.
- Larger shape-drawn Smile, Wink, Laugh, and Determined expressions; larger Shades; consistent drawn smiles and properly clipped Rainbow Eyes.
- Full-color shop previews even when purchase is disabled. Remove the moving white card overlay.
- Ten launch bodies including Custom Solid; nine launch expressions including Smile. Keep the existing eleven launch paid heads and eight launch paid auras for now.
- Hidden items stay in the catalog and remain equipable by their owners. Debug checklist includes the full catalog.
- Verified the actual renderer in a separate offline simulator preview at 56 and 140 points, including animation and static fallback. Signed-in Shop/Profile checks were completed during Step 2; user aesthetic approval remains separate.

## 2. Visual Review - Implementation And Device Check Complete

- Reviewed all eleven launch hats at Home, Shop, and Profile sizes. Refined Wizard Hat, Flame Crown, Lightning Hair, Party Hat, Top Hat, and Visor for containment and face clearance.
- Reworked and reviewed Storm Cloud and Cosmic Aura alone and with large hats. Aura art now remains visible above the badge and behind the character.
- Reworked Teal, Candy, Royal Blue, and Royal Velvet as distinct animated materials. Kept all four in the launch selection.
- Used the actual app renderer for comparisons. Rechecked Home, daily Shop cards, visible body checklist cards, Profile, and owned customization on the final installed renderer build after sign-in. No purchases or equipped-item changes were made. The full hat/body/aura review used the isolated renderer preview, not this account's limited owned collection.
- Completed a physical iPhone 16 Pro Max rendering check: sampled CPU work fell from about 15% of one core with nine visible animated avatars to below 0.4% offscreen. Thermal state stayed Nominal during the short run.
- Added geometry-based viewport tracking for iOS 17. Physical testing used iOS 26.6; long-session battery testing and older-device coverage remain release validation tasks.

See `COSMETIC_VISUAL_REVIEW.md` for the changes, measurement method, and remaining validation limits.

## 3. Earned Status Cosmetics - First Set Implemented September 26

The first set uses existing saved progress, not new grind counters. This replaces the earlier speculative 50-solve/100-win thresholds for this initial release pass.

| Reward | Count | Requirement |
| --- | --- | --- |
| Mode Master titles | 8 | Complete all four solo difficulties in that mode |
| First Finish badge | 1 | Complete any solo difficulty |
| All-Rounder badge | 1 | Complete a solo difficulty in every mode |
| Seven-Day Spark badge | 1 | Longest daily play streak reaches seven days |
| Mode Mastery badges | 8 | Complete all four solo difficulties in the matching mode; independent of equipped title |
| Steady Flame / Unbroken badges | 2 | Longest daily play streak reaches 14 / 30 days |
| Ranked Contender / Century Winner badges | 2 | 25 / 100 recorded ranked wins across modes, including rewarded training-bot wins |
| Puzzle Polymath badge | 1 | Complete all 32 solo difficulties |
| Silver through Master Crest frames | 5 | Reach that tier's point threshold in any ranked mode |

September 27 badge expansion: 13 additional badges, for 16 wearable badges and 29 earned rewards total. Existing IDs and single-badge equip behavior remain unchanged. Mastery badges use shields, ranked milestones use hexagons/trophies, and streak badges use colored circular flames; larger emblems show milestone numbers. These use existing saved records, not new backend counters or invented historical results.

Expansion verification: all 16 badge emblems reviewed offline at 48 and 24 points; 320-point collection requirements/filter and equipping Ranked Contender checked with local sample data. Full Debug build, normal/DEBUG parse, 256 reward checks, and whitespace checks passed. Main installed app and live account were not modified.

### Competitive Badge Expansion - September 27

Added 16 more badges with no additional solo requirements. At this point the catalog contained 32 wearable badges (18 competitive) and 45 earned rewards total; the tiered-family pass below supersedes those display counts.

| New badges | Requirement |
| --- | --- |
| First Victory / On the Rise | 1 / 10 recorded ranked wins |
| Arena Veteran / Arena Elite / Thousand Victories | 250 / 500 / 1,000 recorded ranked wins |
| Eight game-specific Specialist badges | 25 recorded ranked wins in the matching game |
| Triple Threat / Versatile Rival / Complete Competitor | At least 10 recorded ranked wins in each of 3 / 5 / 8 different games |

- Existing Ranked Contender (25) and Century Winner (100) remain unchanged; milestone ordering is ascending.
- Specialists use game-colored seals; versatility uses diamond emblems; higher win milestones use distinct symbols/colors. Large emblems display the target number; small worn emblems retain the symbol.
- Existing ranked win totals backfill eligibility. These totals include rewarded training-bot wins, disclosed in requirements. No new match tracking, economy changes, account schema changes, or paid unlocks.
- Party victories, consecutive competitive wins, and comeback achievements remain deferred until reliable result tracking exists. Friendly Fire and Underdog now use saved session evidence as described below, not aggregate counters.
- Reward checks now cover 386 assertions, including exact thresholds, mode isolation, cross-game breadth, historical credit, permanent unlocks, and saved selections. This expansion does not replace the pending account-backed and two-client checks below.

### Tiered Families, Friendly Fire, And Underdog - September 27

The current collection shows 24 distinct badges and 37 rewards across badges, titles, and frames. Internal tier IDs are not displayed as separate collection items. One-off solo feats and existing frames remain separate.

| Family | Tier requirements |
| --- | --- |
| Ranked Victor | 1 / 10 / 25 / 100 / 250 / 500 / 1,000 recorded ranked wins |
| Each game's Specialist | 3 / 10 / 25 / 100 recorded ranked wins in that game |
| Versatile Rival | 10 recorded wins each in 3 / 5 / 8 different ranked games |
| Daily Flame | 7 / 14 / 30-day longest play streak |
| Friendly Fire | 1 / 5 / 25 / 100 normally resolved human Play Now or Play Later wins |
| Underdog | 1 / 5 / 25 / 100 normally resolved human ranked wins over a player at least one division higher at match start |

- Collection and trophy shelf show only the highest earned tier per family, or the first locked tier. Collection entries expose next-tier progress and an expandable All Tiers list. Equipped badges automatically resolve to the highest earned tier. Tier numbers appear in compact worn emblems as well as larger previews.
- All old reward IDs remain recognized. Previously unlocked tiers and equipped selections survive, including historical unlocks whose underlying counters are unavailable. The old 25-win Specialist ID remains Tier 3. No coins or match rules changed.
- New optional showcase fields: `friendlyWins`, `underdogWins`, `creditedWinSessionIDs`. Defaults preserve old documents. Counters cap at the highest implemented target (100 each), with at most 200 credited session IDs. Duplicate callbacks and transaction retries cannot award a win twice.
- New counters require a saved finished two-human-player session, the recorded winner, and agreement with the existing match resolver. Forfeit/abandon markers are excluded. Underdog uses captured points/divisions, not live opponent profiles or higher points within the same division. Missing or inconsistent historical rank snapshots do not count.
- Ranked settlement and friend result handling credit qualifying wins. Login/refresh can recover verified saved wins, including Play Later results resolved while absent, by querying sessions won by the user and re-reading candidate sessions plus the latest user in small transactions. This historical lookup reads winning-session history until both new families are maxed; monitor its cost for large accounts before release. No historical counters are invented.
- Database metadata confirmed existing `rkpz-90484/(default)` STANDARD edition. No rule changes, deployments, live account edits, or new collections. Saved-result validation is still client code: server-authoritative reward grants and rules hardening remain required before treating badges as tamper-resistant.
- Verification: 605 earned/tier/result-credit assertions, 38 match-resolution checks, 225 solo-presentation checks, normal/DEBUG Swift parse, full Debug simulator build, and whitespace checks passed. The isolated production-view preview verified the 320-point collection, tier disclosure, next-tier progress, Friendly Fire and Underdog requirements, and local equip behavior. Main installed app untouched; live transaction and two-device validation remain pending.

### Next Discussion: Achievement Rewards Versus Badge Prestige

Proposed launch catalog, economy budget, evidence requirements, and implementation order: see `GAME_ACHIEVEMENTS_PLAN.md`. This is a plan, not implemented reward behavior.

User requested game-specific feats next, including first- and second-guess Word Guess solves. Discuss the balance before adding payouts or more badges:

- Coin achievements: approachable one-time accomplishments with modest payouts, not repeatable coin farming.
- Wearable badges: memorable feats or demonstrated consistency; avoid a badge for every ordinary action.
- Some standout achievements may grant both, with coin rewards paid once and tiered badges carrying the lasting recognition.
- First-guess Word Guess is substantially luck-driven; distinguish that fun surprise from repeated low-guess solves before naming it a skill reward.
- Define eligibility across solo/online/daily/friend modes, assistance, repeated seeds, abandoned attempts, and historical evidence before implementation.
- Agree on a small launch set across all eight games and a total achievable coin budget. No achievement coin rewards were added in this pass.

- Profile > Earned Collection has Titles, Badges, and Frames, explicit requirements, progress, an unlocked filter, equip/remove actions, and a live identity preview. Customize Profile also links there.
- Profile and friend profile display the equipped frame/title/badge plus a tappable trophy shelf. Tapping a reward explains its requirement.
- Live pre-match screens show both players' identities and their current rank/W/L for the selected game. Existing automatic countdown, friend Ready, abort rules, bot labels, and puzzle privacy are unchanged. Async friend matches retain their existing direct-to-turn flow.
- One title slot is shared with existing shop titles; equipping either replaces the other. Badge and frame each have one independent slot. Earned rewards never enter the purchasable catalog or packs. Paid bodies remain unchanged.
- Optional `users/{uid}.earnedShowcase` stores permanent unlocked IDs and equipped badge/frame IDs. Titles reuse `cosmetics.equippedTitle`. Old documents default to an empty showcase; eligible existing completions, current rank points, and longest streak backfill on account load/equip.
- Solo completion, daily-play recording, and ranked settlement reconcile unlocks. Ranked settlement reconciles before and after a rank change, preserving frames through later demotion. Unknown historical peak ranks cannot be reconstructed for an old account that already dropped before this update.
- Equip saves run a Firestore transaction against the latest user document, reject unknown/locked/wrong-slot IDs, and update only showcase fields or the title field. No coin, inventory, rank-score, or match-rule changes.
- This is saved-record eligibility, NOT server-verified achievement proof. Current rules allow users to write their own progression. Authoritative reward grants and anti-cheat/rule hardening remain a separate pre-release requirement. No rules/functions were deployed in this pass.
- Full model coverage: `bash scripts/check-earned-showcase.sh` (605 assertions after the tiered-family pass). Covers thresholds, tier migration/upgrades, cross-mode wins, all 32 difficulties, session evidence, duplicate credit, and equipped-title independence. Solo presentation (225) and tie resolution (38) checks also passed again.
- Full Debug simulator build, regular/DEBUG Swift parse, and `git diff --check` passed. The main installed app was left untouched; visual review used a separate offline preview.
- Offline production-view preview checked 320-point collection layout, title/badge/frame equip and removal, unlocked filter, locked progress, trophy shelf requirements, and two-player identity layout. These checks use local sample accounts, not real Firebase writes or a live two-client match.

Next: account-backed equip/reload and two-client pre-match validation; then concise post-game unlock feedback, additional distinctive reward art, and server-authoritative grants. Perfect-solve accessories, distinct-seed milestones, and basic rank bodies are not included yet.

## 4. Follow-On Product Work

- Inspect the current Party flow before changing it: one Create Party entry, optional playlist, clear post-round standings, no separate Stage creation requirement.
- Verify Daily remains the main repeatable challenge destination and tournament entry points remain hidden where intended.
- Measure device heat and battery usage with representative scrolling and gameplay. Prioritize observed animation/listener work instead of guessing from the simulator.

## Completion Criteria

- Recognizable cosmetics at 56, 92, and 140 point avatar sizes.
- Stable outline, readable face, no artwork moving off-center.
- Motion visibly supports the material and freezes cleanly with accessibility/power settings.
- No ownership loss when a cosmetic is removed from the launch shop.
- Earned status must reflect play, not purchases. V1 uses saved-record eligibility; authoritative verification remains required for a tamper-resistant release.
