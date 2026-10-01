# Puzzle Party: Complete Sound Design Guide

Updated September 30, 2026. This is the master recording brief, event map and delivery guide. You design the sounds; Codex imports them, wires events, mixes and tests them afterward. It supersedes the shorter starter checklist where recommendations differ.

## Scope And Status

- Covers all eight current games, solo, Daily, ranked, casual, friends, party playlists, currency, purchases, cosmetics, badges and proposed achievements/XP.
- This pass is documentation only. Listed new sounds are NOT implemented audio hooks.
- Seven custom clips currently exist; several other events use Apple system sounds and many are silent.
- Rank points exist. No separate claimable XP/account-level system was found. XP recordings are future-ready, not a current feature.
- Claimable achievements are planned. Wearable badges/tier families and cosmetic equip flows exist. Unlocking, claiming and equipping are separate events.
- Some server rewards remain gated. This guide does not enable rewards or change payouts.
- Packs and tournaments remain hidden: no audio production for them this release.
- Coverage includes deliberate silence. Not every action needs a unique recording or a sound.

## Creative Direction

Premium playful puzzle arcade: tactile clicks, glassy pops, short rounded chimes, restrained sparkle, light card/paper textures. Complement the pink/teal/gold visual identity without becoming shrill or casino-like.

- Frequent actions: tiny, dry, quick and quiet; pleasant after 200 repetitions.
- Correct action: resolving/upward. Invalid action: soft damped bump, not a punishment alarm.
- Progress/rank: rising notes. Coins: rounded metallic clinks. Badges: medal/clasp identity. Equip: quick snap and soft shimmer.
- Greater value means richer detail, not much louder or longer.
- No spoken numbers/words; reuse across languages and changing amounts.
- Paid skins must not change competitive information or add distracting gameplay sound.

## Priorities

| Label | Meaning |
| --- | --- |
| Existing | Bundled clip and SoundManager entry exist; keep unless deliberately redesigning |
| P1 | Core design batch: gameplay, timers, results, rewards, equip and prestige |
| P2 | Optional detail; reuse a P1 sound or silence for initial release |
| Future | Corresponding feature is planned/disabled; do not prioritize now |

New WAV names below are delivery names, not existing asset identifiers. Reuse references request no additional recordings. Durations include the decay; they are creative targets, not format restrictions.

## Existing Audio Inventory

| Existing file | Current routing observed | Recommendation |
| --- | --- | --- |
| GameFound.mp3 | Online opponent found/pre-match screen | Keep; appropriate for live friend matching too |
| GridVictory.mp3 | Online victory | Keep; reuse for final solo/party wins where appropriate |
| GridLoss.mp3 | Online defeat | Keep; reuse for final unsuccessful solo results |
| Matchmaking.mp3 | Online search music loop | Keep; stop when search ends |
| InOnlineGame.mp3 | Quiet online gameplay loop | Keep; stop at submit/result/exit |
| OtherKeyboardPress.mp3 | Anagrams/Word Hunt/Lava input; Solitaire moves | Keep generic input; replace card use with CardPlace |
| WordleTileClick.mp3 | Word Guess input | Keep; legacy internal name is fine |

All seven were found under `RKDP/Resources/Assets.xcassets`. Inventoried, not auditioned for quality in this pass.

System placeholders to replace: five word-length sounds, invalid/repeated word sound, generic gameOver alert, repeated combo pings. Generic gameOver does not adequately distinguish solve, loss and time expiry. Most reward/equip events have no dedicated audio calls.

## Shared Gameplay And Result Recordings

| Filename | Priority | Seconds | Design / trigger |
| --- | --- | --- | --- |
| InvalidInput.wav | P1 | 0.10-0.25 | Soft blocked tap for visible invalid word/move/conflict |
| WordFound3.wav | P1 | 0.10-0.25 | Small positive pop for accepted 3-letter word |
| WordFound4.wav | P1 | 0.10-0.30 | Slightly brighter member of same family |
| WordFound5.wav | P1 | 0.15-0.35 | Fuller satisfying chime |
| WordFound6.wav | P1 | 0.20-0.40 | Stronger upward accent |
| WordFound7Plus.wav | P1 | 0.25-0.50 | Best short word flourish; covers all lengths 7+ |
| WordCombo.wav | P2 | 0.20-0.40 | Compact rising overlay for successive accepted words |
| WordAlreadyFound.wav | P2 | 0.10-0.25 | Gentle double muted tap; reuse InvalidInput initially |
| InputErase.wav | P2 | 0.06-0.15 | Soft reverse/tick for actual deletion, not empty backspace |
| ShuffleTiles.wav | P2 | 0.15-0.35 | Short tile rattle, one per shuffle |
| HintReveal.wav | P2 | 0.20-0.45 | Small glass/lightbulb accent after permitted hint appears |
| CountdownTick.wav | P1 | 0.08-0.18 | Dry pre-game countdown tick for each displayed step |
| RoundStart.wav | P1 | 0.25-0.50 | Brief upbeat launch when control becomes available |
| TimeRunningLow.wav | P1 | 0.30-0.60 | Two restrained ticks/pulse, once at 10 seconds remaining |
| FinalSecondsTick.wav | P2 | 0.05-0.12 | Optional quiet last-three-seconds tick; not needed initially |
| RoundTimeUp.wav | P1 | 0.40-0.80 | Neutral expiry cue, not inherently victory or defeat |
| PuzzleSolved.wav | P1 | 0.30-0.60 | Compact solved accent for intermediate puzzle in multi-puzzle turn |
| PuzzleFailed.wav | P2 | 0.25-0.50 | Gentle unresolved accent for intermediate failed puzzle |
| MatchDraw.wav | P1 | 0.40-0.80 | Balanced neutral ending for an actual tie |
| TurnSubmitted.wav | P1 | 0.20-0.45 | Crisp accepted-submission confirmation; waiting then silent |
| PersonalBest.wav | P1 | 0.50-0.90 | Bright flourish for a genuinely improved saved record |
| DifficultyUnlocked.wav | P2 | 0.50-0.90 | Rising latch/unlock; PersonalBest can cover initially |

WordFound3 through WordFound7Plus are ONE family with increasing pitch/harmonic detail, not harshness. These represent Anagrams/Word Hunt word length, NOT Word Guess guess count.

The old starter brief's `AchievementUnlock.wav` combined personal-best/difficulty feedback. Use `PersonalBest.wav` for that immediate purpose now; dedicated badge/achievement cues are specified below. No need to make a duplicate old-name file.

## Color Link

Current: no direct SoundManager calls in its view model; the outer online screen supplies match music/results.

| Event | Audio |
| --- | --- |
| Select valid colored endpoint | Existing input tap once, optional |
| Draw across cells / hold / backtrack | Silent by default, never per-frame ticks |
| Connect matching endpoints | ColorConnected on disconnected -> connected transition |
| Break/re-route a connected pair | ColorDisconnected optional; not repeatedly during drag |
| Clear path | InputErase optional, once for actual clear |
| Blocked/outside-board drag | Silent; normal finger correction isn't an error alarm |
| All pairs connected but unfilled cells remain | No victory; only connection feedback |
| Fully valid solved board | GridVictory for final solo result; PuzzleSolved if another puzzle follows |
| Online submission / external deadline | Shared submission and timer policy |

New files:
- **ColorConnected.wav (P1, 0.15-0.35 s):** satisfying magnetic/electrical snap with soft tonal finish.
- **ColorDisconnected.wav (P2, 0.08-0.20 s):** gentle unclick, not failure.

## Solitaire

Current: moves use OtherKeyboardPress; completion uses generic gameOver. Card-specific routing is new.

| Event | Audio |
| --- | --- |
| Initial visible deal | CardDeal optional, one sequence, not 52 separate sounds |
| Select or drag card | Silent or quiet input tap; no repeated dragging noise |
| Legal tableau/stack placement | CardPlace once per move, not per card |
| Draw 1 / Draw 3 | CardFlip once per draw action |
| Reveal face-down top card | CardFlip; coalesce with placement rather than stacking loudly |
| Recycle waste to stock | CardRedeal once |
| Send card to foundation | CardFoundation instead of ordinary CardPlace |
| Auto-to-foundation | Short rate-capped foundation sequence, never dozens of overlapping effects |
| Illegal move / no redeals left | InvalidInput once when rejected feedback appears |
| All foundations complete | GridVictory for final solo completion; online outcome follows match policy |
| Abandon / no-op tap | Silent, no fake win or reward |

New files:
- **CardPlace.wav (P1, 0.08-0.20 s):** soft card slap on felt, not keyboard click.
- **CardFlip.wav (P2, 0.08-0.18 s):** light paper flick.
- **CardFoundation.wav (P2, 0.12-0.30 s):** placement plus small upward accent.
- **CardRedeal.wav (P2, 0.20-0.45 s):** gathering/shuffle texture.
- **CardDeal.wav (P2, 0.40-0.80 s):** compact initial dealing texture, no music baked in.

No undo recording requested: an undo mechanic isn't established in the audited current flow.

## Sudoku

Current: no direct SoundManager calls in view model. Notes, erase, visible conflicts, hints and completion exist.

| Event | Audio |
| --- | --- |
| Select cell | Quiet existing tap optional; deselection may be silent |
| Enter/change digit | SudokuPlace once per actual change |
| Add/remove pencil note | SudokuNote or quieter generic tap |
| Toggle note mode | UISelect optional, not a correct-answer cue |
| Erase nonempty cell/notes | InputErase; empty erase silent |
| New visible duplicate/conflict | InvalidInput instead of ordinary placement |
| Nonconflicting digit | Placement only; NEVER reveal hidden solution correctness through sound |
| Permitted solo hint applied | HintReveal; no hint cues in competitive contexts |
| Row/box completion | Silent for launch; avoid repeated completion noise |
| Entire puzzle validated complete | GridVictory / shared online result policy |

New files:
- **SudokuPlace.wav (P2, 0.06-0.16 s):** precise soft ceramic/pencil tap; existing input covers launch.
- **SudokuNote.wav (P2, 0.04-0.12 s):** lighter pencil mark than full digit placement.

## Minesweeper

Current: no direct SoundManager calls in view model. Reveal, flood reveal, chord, flags, restart and terminal states exist.

| Event | Audio |
| --- | --- |
| Reveal safe cell | MineReveal |
| Flood opens many cells | MineCascade once, not per cell |
| Place/remove flag | FlagPlace / FlagRemove |
| Successful chord | One reveal/cascade cue based on visible opening |
| Tap/chord hits mine | MineHit once; avoid immediate overlap with full loss fanfare |
| No-op tap/long press | Silent |
| Flag on actual mine vs safe cell | IDENTICAL sound; no hidden correctness information |
| All safe cells revealed | GridVictory |
| Restart board | RoundStart after reset, not another mine/loss cue |

New files:
- **MineReveal.wav (P2, 0.06-0.16 s):** soft tile click; generic input sufficient initially.
- **MineCascade.wav (P2, 0.15-0.35 s):** short unfolding tile ripple.
- **FlagPlace.wav (P2, 0.08-0.20 s):** small cloth/stick click.
- **FlagRemove.wav (P2, 0.06-0.16 s):** lighter release click.
- **MineHit.wav (P1, 0.25-0.55 s):** rounded low impact, not startling explosion.

## Word Guess

Current: WordleTileClick handles keyboard actions; no dedicated custom reveal cue. Reveal animation must not inflate scoring time.

| Event | Audio |
| --- | --- |
| Accepted letter input | Existing WordleTileClick |
| Delete actual letter | Existing click / InputErase; empty delete silent |
| Short/non-dictionary rejection | InvalidInput once, only if action actually produces rejection feedback |
| Valid row begins reveal / tiles flip | GuessReveal synced to visible reveal; neutral family, not five loud effects |
| Gray/yellow/green results | No sound before visible result; one neutral flip family sufficient |
| Valid guess that doesn't solve | No invalid alarm: this is normal progress |
| Solved word | PuzzleSolved for intermediate puzzle; final result takes priority on last word |
| Guess limit reached | PuzzleFailed for intermediate puzzle; GridLoss for final solo failure |
| Next word in multi-word turn | Quiet RoundStart once |
| First/second-guess achievement | Future AchievementReady only after confirmed eligibility; not every solve |

New file:
- **GuessReveal.wav (P1, 0.07-0.16 s):** single soft tile flip/tick. Deliver ONE hit, not a baked five-tile sequence; code schedules it.

No time-running-low cue for an elapsed-time-only run. Actual external deadlines use shared timer policy.

## Lava Rescue

Current: input tap, some wrong letters use wordInvalid, terminal flow uses generic gameOver. Correct letters/lava need thematic routing.

| Event | Audio |
| --- | --- |
| Accepted letter selection | Existing input click, quieter than result accent |
| Correct letter revealed | LetterRescued once per guess, not per matching letter occurrence |
| Wrong letter raises lava | LavaRise instead of generic invalid alarm |
| Repeated letter | Silent or InvalidInput if explicitly rejected; no second lava cue |
| Lava crosses high-danger threshold | LavaDanger optional once per puzzle |
| Liquid animation / changing expression | Silent, no continuous bubbling loop |
| Word rescued | PuzzleSolved for intermediate puzzle; final solo win uses GridVictory |
| Lava reaches maximum | PuzzleFailed intermediate / GridLoss final solo loss |
| Actual timed turn expires | RoundTimeUp, no fake impact when timeout caused the finish |
| New word | Reset warning state; quiet RoundStart |

New files:
- **LavaRise.wav (P1, 0.15-0.40 s):** small rising bubble/sizzle, playful not gruesome.
- **LetterRescued.wav (P1, 0.10-0.25 s):** clear upward rescue pop.
- **LavaDanger.wav (P2, 0.30-0.55 s):** warm low pulse; skip if ending immediately or timer warning already plays.

## Word Hunt

Current: path taps, length-based system sounds, invalid/repeat system cue, generic timer-end sound.

| Event | Audio |
| --- | --- |
| Start path / enter new tile | Existing input tap with rate limiting; not repeatedly inside same tile |
| Diagonal movement | Same as horizontal/vertical, no special warning |
| Backtrack | InputErase optional, prevent jitter from alternating taps |
| Accepted new word | WordFound3/4/5/6/7Plus based on accepted length |
| Invalid / too short / already found | InvalidInput; optional WordAlreadyFound for duplicates |
| Cancel path without submission | Silent |
| Rapid consecutive accepted words | Optional WordCombo; reset at round start/end and account changes |
| Ten seconds remaining | TimeRunningLow once |
| Timer expires | RoundTimeUp; input and input audio stop immediately |
| Final score / saved best | Neutral timed ending; PersonalBest only if result qualifies |

No additional mode-specific recordings needed beyond the shared family.

## Anagrams

Current: pick/return/clear/shuffle taps; word-length, invalid/repeat and timer-end system sounds.

| Event | Audio |
| --- | --- |
| Pick/return tile | Existing input; optional InputErase on return |
| Clear assembled word | One InputErase, not one per tile |
| Shuffle rack | ShuffleTiles instead of ordinary tap |
| Accepted new word | WordFound3/4/5/6/7Plus |
| Too short / non-word / duplicate | InvalidInput; optional WordAlreadyFound |
| Permitted normal-solo hint | HintReveal once; no hint sound online, Daily, friend or party |
| Full-rack/longest word | Appropriate word-length cue; no additional jackpot required |
| Combo / low time / expiry | Shared WordCombo, TimeRunningLow, RoundTimeUp |
| Browse found/missed words after finish | Silent; viewing word does not grant score again |

No additional mode-specific recordings needed beyond the shared family.

## Contexts: Solo, Daily, Ranked, Casual, Friends, Parties

Keep puzzle-action feedback consistent everywhere. Context controls submission, timers and final outcomes.

| Context/event | Sound decision |
| --- | --- |
| Solo start/replay | RoundStart once when ready, not each view render |
| Solo solve / fail | GridVictory / GridLoss; don't use generic timer ending |
| Timed word-game finish | RoundTimeUp, whether or not record is beaten |
| Best-by-difficulty saved | PersonalBest once; old record browsing silent |
| Next difficulty unlocked | DifficultyUnlocked or PersonalBest; coalesce when both happen |
| Daily opened | RoundStart, no entry currency sound |
| Daily result accepted | TurnSubmitted if no overlapping final cue; reward only when granted |
| All Daily modes finished | DailySetComplete optional, then one coin receipt cue |
| Daily friends/global leaderboard updates | Silent |
| Ranked/casual searching | Existing Matchmaking loop only while search active/visible |
| Match found | GameFound once per session; stop search loop |
| Pre-match badge/avatar showcase | Silent; no cosmetic unlock sound for every opponent item |
| Pre-match countdown | CountdownTick per visible step; RoundStart when control enabled |
| Active online play | Existing quiet gameplay loop and mode SFX |
| Local final accepted | TurnSubmitted once; stop board audio/music; no assumed victory |
| Waiting on opponent | Silent, no repeated submit cue/heartbeat |
| Actual final win/loss/draw | GridVictory / GridLoss / MatchDraw once per match |
| Opponent forfeits | Confirmed outcome only; not personal puzzle completion/achievement |
| Local forfeit/canceled search | Silent or UIBack; no coin-loss cue for no-wager ranked |
| Disconnect/reconnect | ConnectionLost/Restored once per state transition in foreground |
| Friend invite sent / request accepted | SocialConfirm optional after action succeeds |
| Incoming friend invite | InviteReceived optional in lobby only, not over gameplay |
| Friend Play Now | Online start/submitted/final flow without rank progression cues |
| Friend Play Later | TurnSubmitted; waiting silent; newly shown final outcome may sound once |
| Party join/leave/ready | PartyReady/UISelect optional, rate-limited; not a chorus per snapshot |
| Party host starts round | Actual start/countdown UI cues; don't invent countdown for audio |
| First solve starts 180-second finish window | FinishWindowStarted once per round, not on reconnect |
| Local party submission | TurnSubmitted, then board locked and waiting silent |
| Catch-up reaches ten seconds | TimeRunningLow for unsubmitted active players only |
| Catch-up expires | RoundTimeUp for previously unsubmitted players; no second timeout for submitted players |
| Party round scoreboard | RoundScoreReveal optional once at first reveal |
| Host advances playlist | RoundStart after next round ready |
| Final champion/shared winner | PartyChampion or GridVictory; MatchDraw where result is a draw |
| Canceled/expired room | Neutral notice, no unearned victory or reward |

| New file | Priority | Seconds | Character |
| --- | --- | --- | --- |
| FinishWindowStarted.wav | P1 | 0.35-0.65 | Two-note clock/chime, distinct from victory |
| ConnectionLost.wav | P2 | 0.15-0.35 | Soft descending notification, not each retry |
| ConnectionRestored.wav | P2 | 0.15-0.35 | Resolved counterpart |
| SocialConfirm.wav | P2 | 0.15-0.30 | Friendly send/accept accent |
| InviteReceived.wav | P2 | 0.25-0.50 | Welcoming two notes, foreground only |
| PartyReady.wav | P2 | 0.10-0.25 | Compact checkmark click |
| RoundScoreReveal.wav | P2 | 0.25-0.50 | Neutral scoreboard arrival, not payout |
| PartyChampion.wav | P2 | 0.80-1.30 | Fuller final celebration |
| DailySetComplete.wav | P2 | 0.50-0.90 | Bright daily-set stamp, not each puzzle |

Custom push-notification audio is outside this brief. Hidden/background screens must not trigger foreground effects.

## Coin Amounts And Claims

Five coordinated sizes, not one recording per amount. These are proposed AUDIO bands, not new economy values.

| Filename | Priority | Actual credit | Seconds | Character |
| --- | --- | --- | --- | --- |
| CoinsTiny.wav | P1 | 1-19 | 0.15-0.30 | One/two soft clinks; small solo/casual/completed-loss/draw rewards |
| CoinsSmall.wav | P1 | 20-49 | 0.25-0.45 | Neat handful; daily play +25, lower-rank wins |
| CoinsMedium.wav | P1 | 50-99 | 0.35-0.60 | Fuller handful; daily +50, higher-rank wins, verified ad +75 when enabled |
| CoinsLarge.wav | P1 | 100-999 | 0.50-0.85 | Rich short cascade; larger bundled/achievement credit if implemented |
| CoinsJackpot.wav | P1 | 1,000+ | 0.70-1.10 | Polished coin shower for packs, not slot-machine audio |
| CoinCountTick.wav | P2 | Count-up display | 0.03-0.08 | Dry tick, rate-capped; NOT one tick per coin |
| CoinsSpend.wav | P2 | Cosmetic purchase | 0.15-0.35 | Short outgoing clink, not punishment |
| RewardAdjusted.wav | P2 | Refund/adjustment notice | 0.20-0.40 | Neutral bookkeeping accent |

- Use actual confirmed net credit, not total wallet balance or requested grant. Zero credit = no reward sound.
- Shared family covers daily claim, daily play, solo, ranked/casual, Daily completion, future achievement claims and verified ads.
- Source policy: solo 3-18; ranked wins 20/30/40/50/60/75, completed losses 5, draws 10. Rollout differs; do not infer grants from displayed rank.
- Packs of 1,000/3,300/6,000/13,500 can ALL reuse CoinsJackpot. No four extra recordings needed.
- Combine one presentation's confirmed grants: 7 base + 25 daily = one 32-coin cue. Keep visual breakdown; avoid simultaneous mini-rewards.
- Reopening or refreshing a settled receipt must not replay it. Background balance changes should not queue later celebrations.
- Refund-debt recovery may reduce net credit; choose band from remaining actual positive credit, explain adjustments visually.
- Count-up: starting limit roughly 8 ticks/second and 1 second total. Never 13,500 ticks.
- Apple's payment sheet owns its system audio. App celebration starts only after server delivery succeeds, not after pressing Buy.
- For cosmetic spending/unlock, choose one lead cue; don't stack spend, success, unlock and equip all at once.

## Rank Points And Future XP

Rank points are implemented; separate claimable XP and account levels are NOT established. Buying ranked access grants neither rank points nor XP.

| Filename | Priority | Seconds | Event |
| --- | --- | --- | --- |
| RankPointsGain.wav | P1 | 0.25-0.50 | Crisp upward accent after confirmed points gain |
| RankPointsLoss.wav | P2 | 0.20-0.40 | Gentle downward resolve; no coin-spending implication |
| DivisionUp.wav | P2 | 0.45-0.75 | Compact promotion within tier |
| RankTierUp.wav | P1 | 0.80-1.30 | Strong earned tier promotion; reuse across ranks |
| RankDown.wav | P2 | 0.30-0.60 | Neutral down-step, no humiliating sting |
| XPClaim.wav | Future | 0.25-0.55 | Warm energy absorption after successful future XP claim |
| XPCountTick.wav | Future | 0.04-0.10 | Soft pitched progress tick for controlled count-up |
| LevelUp.wav | Future | 0.70-1.20 | Warm expanding resolution if account levels are added |

Tier promotion supersedes division-up and normal point-gain audio. Multiple crossed tiers get one final cue. No ranked points sound in modes that do not change rank. XP initially needs one claim family, not a full set per amount. Do not prioritize future XP over existing gameplay.

## Cosmetic Equip, Badges, Achievements And Purchases

Categories: avatar head/face/body/aura, board themes, tile themes, Solitaire card themes, name titles. Earned wearable slots include badge/title/frame. Reuse sounds across items.

| Filename | Priority | Seconds | Event / direction |
| --- | --- | --- | --- |
| CosmeticEquip.wav | P1 | 0.15-0.35 | Light snap/shimmer after changed equipped item saves |
| CosmeticUnequip.wav | P2 | 0.10-0.25 | Soft unclasp on actual removal/reset |
| BadgeEquip.wav | P1 | 0.18-0.40 | Weightier medal clasp after badge equip saves |
| BadgeUnlock.wav | P1 | 0.55-0.95 | Earned prestige chime, not purchase feedback |
| BadgeTierUp.wav | P1 | 0.65-1.10 | Upgraded-medal flourish for existing badge family |
| CosmeticUnlock.wav | P2 | 0.35-0.65 | New ownership accent after confirmed direct purchase |
| AchievementReady.wav | Future | 0.30-0.55 | Claimable achievement becomes ready; no coins yet |
| AchievementClaim.wav | Future | 0.30-0.55 | Short seal/stamp accent after durable claim; coin family handles amount |
| PurchaseSuccess.wav | P2 | 0.40-0.70 | Delivered permanent ranked unlock, NOT rank promotion |
| RestoreComplete.wav | P2 | 0.20-0.40 | Quiet user-initiated restore confirmation |

- Preview/scroll: silent or UISelect on deliberate preview, never equip/unlock audio.
- Equip: after successful save only; already-equipped taps/no-op saves silent. Failed save = UIError once.
- All cosmetic categories share CosmeticEquip; earned title/frame also use it. Badge uses BadgeEquip.
- Custom color picker dragging stays silent. Optional one equip cue after saved color change.
- Badge unlock doesn't mean equipped and doesn't mean coins. Only actual independent currency grants get coin audio.
- Friendly Fire, Underdog, specialists, mastery and other families reuse BadgeUnlock/BadgeTierUp. No file per badge.
- First tier = unlock; advancing existing family = tier-up. Multiple tiers awarded together = one cue for final state.
- Entering Profile, inventory loads, viewing old badges: never replay unlocks.
- Direct purchase with auto-equip: choose CosmeticUnlock as lead; don't stack CosmeticEquip and CoinsSpend too.
- Achievement Ready, Claim, and Equip must remain distinguishable. Future claim-all combines credits, not one fanfare per item.
- Greater cosmetic rarity can add subtle variation to unlock, not require four equip recordings. Fast familiar interactions should remain fast.
- Canceled payment silent; pending payment neutral visual status; failed delivery UIError once; celebrate only after later delivery succeeds.
- Restore that adds nothing uses RestoreComplete or silent confirmation, not a new-unlock fanfare. No coin celebration on restore of existing rights.

## General UI

| Filename | Priority | Seconds | Use |
| --- | --- | --- | --- |
| UISelect.wav | P2 | 0.04-0.12 | Soft purposeful selection/toggle; generic tap can substitute |
| UIBack.wav | P2 | 0.06-0.15 | Optional dismiss/back click |
| UIError.wav | P1 | 0.15-0.35 | Gentle save/claim failure, insufficient coins, app error; not game loss |

Silent by default: tabs, scrolling, disabled controls, passive counters, loading, filters, notifications repeatedly refreshed. Muting immediately stops audio; haptics remain independently controlled. No chat sound package requested because chat is not established here.

## Music And Ambience

- Keep existing two music loops unless redesigning deliberately. Additional music isn't a required first delivery.
- Optional MenuLoop/SoloLoop: 30-60 seconds or longer, seamless, sparse and low-fatigue. No vocals/baked-in reward cues.
- No unique music per mode required. Cosmetic animations, storm/cosmic auras, liquid lava movement stay silent; no constant loops for them.
- Search music stops on cancel/match found; gameplay music stops on submit/result/exit.
- Suspend app audio on background/interruption; no warnings from inactive scenes or replay of missed warnings afterward.
- Respect Music/SFX separately, Silent Mode/session behavior and other audio. Essential information must also be visual; sound is never the only timer cue.

## Timing And Anti-Spam Integration Rules

1. Trigger from accepted actions/saved results, not animation frames/view appearance/repeated network snapshots.
2. Stop gameplay audio at submission, timeout or terminal state, including hardware keyboard routes.
3. TimeRunningLow crosses 10 seconds once per actual timed attempt. Ordinary elapsed clocks are silent. Persist per-attempt warning state through reconnect; no repeated warning on return.
4. Overlapping party and built-in timers use the effective nearest deadline and one warning. Submitted players do not hear personal timeout cues while waiting.
5. Choose one primary ending: win, loss or time up. Solving locally online isn't proof of match victory.
6. Final card/connection/letter accent may be skipped/shortened when the final flourish immediately follows.
7. Proposed result order: outcome, one prestige milestone, one confirmed coin credit. Cancel pending sequence on leave/background; do not force an audio queue.
8. For simultaneous milestones, choose one lead: rank tier > badge unlock/tier > personal best/difficulty. Still show all visually.
9. Debounce rapid input (starting target 60-80 ms between taps); large cascades and Auto-to-foundation aggregate events.
10. Reset/cancel combo callbacks on finish, user switch, mute or disappearance. Current delayed system-ping implementation needs replacement.
11. Deduplicate reward presentations by receipt/attempt identity; balance change alone isn't proof of a new reward.
12. Current cached one-shot player restarts same clip on reuse. Integration must choose limited pooling vs debounce; no unlimited long overlapping tails.
13. No hidden-answer leakage: Sudoku conflict vs correctness, Minesweeper flag correctness, unseen Word Guess reveal.
14. Test real phone speaker then headphones at moderate volume, with music and rapid actions together.

## Production Batches

1. **Core words/timers:** WordFound3/4/5/6/7Plus, InvalidInput, TimeRunningLow, RoundTimeUp, CountdownTick, RoundStart.
2. **Mode identity:** ColorConnected, CardPlace, MineHit, GuessReveal, LavaRise, LetterRescued, PuzzleSolved.
3. **Results/economy:** MatchDraw, TurnSubmitted, PersonalBest, FinishWindowStarted, five Coins amount cues, RankPointsGain, RankTierUp, UIError.
4. **Customization/prestige:** CosmeticEquip, BadgeEquip, BadgeUnlock, BadgeTierUp.
5. **P2 detail:** optional tables above; shared cues or silence can cover launch.
6. **Future:** XP/claimable achievements when scheduled. No packs/tournaments now.

Do not make every optional sound before trying the core family inside the app. Delivering 5-10 first helps establish the style and mix.

## Quality And Export Settings

Project recommendations, not App Store format requirements:

| Setting | Recommendation |
| --- | --- |
| Master format | Uncompressed WAV, PCM; not MP3 renamed to WAV |
| Sample rate | 48,000 Hz preferred; clean existing 44,100 Hz acceptable, no need to upsample |
| Bit depth | 24-bit preferred for masters; clean 16-bit WAV also accepted |
| Channels | Mono for short SFX; stereo for music/ambience or meaningful spatial design |
| Peaks | Aim at or below -3 dBFS sample peak; no clipping/aggressive brickwall limiting |
| Loudness | Match each family by ear; taps quieter than rewards. No strict LUFS target for tiny one-shots |
| Start | Trim unnecessary leading silence, ideally under about 5-10 ms for taps |
| End | Preserve intentional decay; tiny fades where needed to prevent clicks |
| Noise | No hiss, DC offset, exported metronome or accidental room noise |
| Reverb | Short on frequent cues; no several-second tails per keypress |
| Stereo | Check mono compatibility; important parts must not cancel |
| Loops | Exact seamless boundaries, no baked intro/outro fade; note intended loop region |
| Source project | Optional; flattened WAV required so no special DAW/plugins needed |

Don't normalize every file to maximum loudness. Larger reward = richer texture, not excessive volume. Codex will tune runtime volumes and can make compressed music copies while retaining lossless masters.

Export from your audio editor/DAW, not a screen recording/video. Converting a low-quality MP3 to WAV does not restore detail. Use your own recordings or samples licensed for game distribution.

## How To Upload Here

**Preferred: attach one ZIP per batch directly to this chat.** Alternatively, put a folder on this Mac (e.g. Downloads/PuzzlePartyAudio) and send the full folder path. You do not need to import anything into Xcode yourself.

```text
PuzzlePartyAudio_v01/
  01_Gameplay/
    WordFound3.wav
    WordFound4.wav
    InvalidInput.wav
  02_ModeSpecific/
    ColorConnected.wav
    CardPlace.wav
  03_Rewards/
    CoinsTiny.wav
    CoinsSmall.wav
    BadgeUnlock.wav
  04_UI/
    CosmeticEquip.wav
  05_Music/
  Future/
  Alternates/
  audio-manifest.csv
  notes.txt
```

- Exact filenames above, no spaces. Put version on batch folder; preserve event names.
- Alternates: e.g. `Alternates/CoinsSmall_alt02.wav`, with preferred take noted.
- One sound per file, not a long compilation. A montage can be an extra preview, not replacement assets.
- Small batches welcome. An MP3 listening preview is optional; WAV remains the master.
- Include brief licensing/source notes if sample packs were used; no passwords/keys.
- Notes can state desired playback timing, suggested volume, loop details or intentional silence.

Optional manifest (plain-text list is also fine):

```csv
filename,event,duration_seconds,sample_rate_hz,bit_depth,channels,loop,priority,notes
WordFound3.wav,Accepted 3-letter word,0.20,48000,24,mono,no,P1,Preferred take
CoinsSmall.wav,Confirmed credit of 20-49 coins,0.35,48000,24,mono,no,P1,Same family as CoinsTiny
```

No need to measure technical statistics yourself. Codex can check properties, peaks/silence and durations, organize previews, then import approved assets. Listening judgments must be distinguished from automatic file checks.

## Integration Acceptance Checklist

- [ ] Inventory files, actual codec/rate/channels/duration, clipping/silence and duplicates.
- [ ] Audition core family before bulk wiring; never judge sound from metadata alone.
- [ ] Import data assets / WAV support. Current loose-file fallback loads MP3 only; simply dropping WAVs into a folder won't wire them.
- [ ] Replace system placeholders, don't double-play old/new cues.
- [ ] Implement mute, debounce, deduplication, scene visibility, interruption and loop controls.
- [ ] Cover all eight modes and each gameplay context; no hidden-answer hints.
- [ ] Save/claim/equip sounds after success, currency after actual net credit. Sound never mutates gameplay or wallet state.
- [ ] Test zero/large/adjusted rewards, canceled/pending purchases, failed claims, restores and simultaneous milestones.
- [ ] No repeat rewards on refresh, sign-in, reopening, reconnect or another device's update.
- [ ] Verify timer boundaries, resume under ten seconds, submitted waiting players, background and settings.
- [ ] Test phone speaker/headphones, Silent Mode, other music, accessibility and busy result screens.
- [ ] Update delivered/approved/integrated status; run Swift parse/build/diff checks after code integration.

## Source Audit References

- `RKDP/Services/SoundManager.swift`: assets, system placeholders, combo, volumes, audio session.
- `RKDP/ViewModels/AnagramViewModel.swift`, `WordHuntViewModel.swift`, `WordleViewModel.swift`, `HangmanViewModel.swift`: word actions and timing.
- `RKDP/ViewModels/KakuroViewModel.swift` is Color Link; `KenKenViewModel.swift` is Solitaire (legacy names).
- `RKDP/ViewModels/SudokuViewModel.swift`, `MinesweeperViewModel.swift`: notes/hints/conflicts and reveal/flag/chord.
- `RKDP/Views/Multiplayer/MatchmakingView.swift`: search, countdown, music/results.
- `RKDP/Views/Home/HomeView.swift`: embedded PartyRoomView, finish window and playlist screens.
- `RKDP/Views/Profile/TournamentView.swift`: current Daily UI plus retained tournament code.
- `RKDP/Views/Profile/ProfileView.swift`: owned cosmetics and earned badge/title/frame equip.
- `RKDP/Models/CoinEconomy.swift`, `GAME_ACHIEVEMENTS_PLAN.md`: policy values and explicitly future claims.

This is an event/source audit, not a fresh complete gameplay/acoustic QA pass. No new mechanics, economy changes or audio hooks are implemented by this document.
