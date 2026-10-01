# Solo Experience - September 25, 2026

## Lobby And Results Pass

The initial lobby/results pass kept puzzle generation, scoring, unlock rules, rewards, and online presets unchanged. The later match tie-break changes are documented below.

- Solo lobby now shows solo progression instead of the online rank summary.
- Shows completed difficulty count, the next unlock, and the mode's actual completion requirement.
- Selects the first available unfinished difficulty when entering the solo lobby; existing completed difficulties remain replayable.
- Difficulty cards show the saved best instead of a completed badge, and use Unlocked/Locked for difficulties without a completion. Earlier completions without difficulty-specific records say Replay to set best. Locked requirements remain readable, including long Solitaire formats.
- Correct solo timing labels: Anagrams 60 seconds, Word Hunt 75 seconds, Lava Rescue untimed, other modes no time limit.
- Personal bests are now recorded separately for each difficulty. Existing overall records remain intact; old records are not assigned invented difficulties.
- Results compare against a run-start snapshot, before the user record is updated. First records, improvements, ties, and non-record runs have distinct copy.
- Failed solves cannot claim time/guess records. Zero-score word runs do not celebrate a first record. Lava Rescue now measures elapsed time without a time limit and records wrong letters plus time.
- First successful completion offers direct play of the newly unlocked difficulty. Other runs emphasize Play Again. Both create fresh game view state through the existing routing/reset mechanism.
- Sharing, Friends, Daily, Ranked, and Home remain available in a secondary More menu.
- Word/guess/letter breakdowns are expandable and preserve every supplied entry. Long guesses wrap rather than shrinking into tiny text.
- Progress labels describe the metric (possible words found, safe cells, foundations, etc.). Word Guess no longer shows a redundant binary progress bar.
- Four main statistic tiles maximum; additional statistics remain visible as compact rows.

## Scope Boundaries

- Next-difficulty and personal-best context is supplied only by the normal solo lobby. Party, ranked, casual, daily challenge, and tournament callers do not receive that progression context.
- Existing reporting and persistence paths and coin boosts remain in use. The follow-up adds difficulty-specific records and changes word-match finalization as documented below.
- Sudoku, Color Link, and Solitaire currently report solo results on completion, not on leaving an unfinished game. This pass does not turn abandonment into a completion.
- Anagrams and Word Hunt retain their existing progression rule: a positive score when the round ends completes the difficulty.

## Verification

- Repeatable check: `bash scripts/check-solo-presentation.sh`.
- 225 assertions cover all eight modes and four difficulties, first/repeated completions, failure, the final difficulty, time/score/guess comparisons, ties, coherent per-difficulty records, legacy decoding, and recording/encoding every mode/difficulty combination.
- The check compiles production presentation types separately from Firebase, with stubs only for unrelated dependencies. It is not a persistence or gameplay integration test.
- Full simulator app build, regular/DEBUG Swift parse, and diff whitespace checks are run for the pass.
- Isolated native preview uses the actual result view and AppTheme, with sample data and no account access. Checked normal and 320-point widths, success/failure, next-action callback, timed results, and expanded Word Guess text.
- Resumed after unlocking the Mac and checked the actual lobby summary/card components in the isolated preview: partial progress, fully completed progression, locked requirements, and long Solitaire labels at 320 points. Fixed system-disabled styling that had faded locked text too heavily.
- Verified the More menu retains sharing, Friends, Daily, Ranked, and Home. No live-account completions, reward claims, or inventory changes were used for this review.
- An end-to-end playthrough of every game and accessibility text-size/device coverage remain manual release checks.

## Next Work

The word-game and four non-word-game gameplay passes are tracked in `GAMEPLAY_REVIEW.md`, including completed checks, fixes, and remaining manual coverage. All eight modes have targeted offline gameplay coverage; natural playthroughs, physical-touch checks, and signed-in persistence are still distinguished from automated/fixture checks.

1. Play each mode end to end, prioritizing small-screen boards, keyboards, and completion/failure feedback.
2. Improve weak mode-specific breakdowns using real recorded facts, not inferred accuracy or invented performance grades.
3. User confirmed per-difficulty records survive sign-out/sign-in on September 26. Two-client tie resolution remains a later user test.
4. Initial earned titles, badges, and rank frames are implemented; see `COSMETIC_RELEASE_PLAN.md`. Most body skins remain aesthetic purchases. Account-backed equip/reload and live pre-match validation remain open.

## Per-Difficulty Records And Tie-Break Follow-Up

- Optional `ranks.{mode}.soloBestsByDifficulty.{difficulty}` stores one successful run's metrics. Existing rank documents decode without the field; existing aggregate soloBest remains compatible with Home/Profile.
- Records prioritize score for timed word games, fewer guesses for Word Guess, fewer wrong letters for Lava Rescue, fewer moves for Solitaire, and time for other puzzle modes. Time breaks equal primary metrics. Metrics from separate runs are never mixed into one difficulty record.
- Normal solo result reporting updates these records; merely opening/leaving a game does not. Failed attempts cannot replace successful records.
- Word Guess/Lava Rescue live matches now wait for both players' final turns. The previous early-clinch path could end a match before guesses/time could be compared.
- Word Guess uses solved words, guesses on solved words, then elapsed seconds. Exact ties draw; two players with no solves also draw rather than rewarding a quick failure.
- Existing party Word Guess time comparison is retained, with no-solve draw behavior aligned. Lava Rescue party comparison now considers rescued-word count before its existing wrong-letter/progress/time checks.
- Explicit nonfinal flags are respected even if a partial update already contains two solved words. Legacy final records without flags remain compatible.
- Submitted boards are locked while waiting in ranked/casual as well as friend matches. Word Guess stops its clock at the final input, excluding the final reveal animation delay.
- Time precision remains whole seconds. No new server clock, millisecond fields, or anti-cheat guarantees were added. Match finalization is still the app's existing client-driven system; older app builds can retain older behavior until updated.
- Repeatable tie checks: `bash scripts/check-match-resolution.sh` (38 assertions). Live two-device matching and test-account persistence remain manual integration checks.
- Final follow-up verification: full Debug simulator build, regular/DEBUG parse, and diff whitespace checks passed. Isolated native previews confirmed Word Guess result comparisons and difficulty-specific records at 320 points, including updating the summary when switching difficulties.
- No database/rules/function deployment was performed. Database edition was confirmed read-only as Standard on the configured default instance.

Sound production is tracked separately in `SOUND_PRODUCTION_CHECKLIST.md`.
