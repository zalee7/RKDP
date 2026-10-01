# Gameplay Review - September 26, 2026

## Changes In This Pass

- Word Hunt drag selection now sweeps through the central areas of tiles instead of immediately selecting every square boundary crossed. Corner grazes leave room for diagonal movement; fast sampled gestures retain crossed letters in order.
- The final finger position is processed on release. Off-board coordinates are not clamped onto edge tiles. Existing adjacency and no-repeated-tile rules remain intact.
- Word Hunt ignores input and late submissions after its timer ends and clears any unfinished trace at timeout.
- Anagrams ignores tile selection, return, shuffle, clear, and submissions after its timer ends. Its underlying controls are disabled beneath the results overlay.
- Word Hunt and Anagrams cancel earlier feedback-dismissal tasks when new feedback appears, preventing an older task from prematurely clearing the newer message.
- Long Word Hunt traces stay on one line rather than pushing outside their layout.
- Lava Rescue hides the duplicate system back button. Its result tiles prioritize Time and Wrong, followed by Word and Category, without duplicating the completed word as a Pattern tile. Singular wrong-letter wording is corrected.
- No seed, dictionary, puzzle generation, scoring, reward, or match rules changed.

## Non-Word Game Follow-Up

- Sudoku, Color Link, Minesweeper, and Solitaire disable gameplay beneath final results or after match submission. Sudoku also rejects finished-game input in the view model, and Color Link cannot clear a finished path.
- Sudoku, Color Link, and Minesweeper stop their timers when leaving the game screen, matching Solitaire's existing cleanup.
- Sudoku results now show Time, Hints, Conflicts, and Filled. Conflicts mean duplicate row/column/box entries, not every answer that differs from the solution. Hints retain the original blank-cell progress denominator.
- Solitaire feedback floats above the board and expires without resizing its status panel. Tall tableau stacks have vertical scrolling instead of extending over the status panel.
- Minesweeper no longer inserts a board-shifting win/loss heading. Flagging works before the first reveal, tapping a flagged starting cell does not start the game, and restart clears flag mode. Board/model input checks also reject invalid coordinates and repeated first-reveal initialization.
- No account access or backend writes were used. The production app was built, but was not reinstalled in this follow-up; the separate offline review app was updated instead.

## Actual Visual And Gameplay Coverage

| Mode | Checked | Still needed |
| --- | --- | --- |
| Word Guess | Signed-in simulator: invalid entry, accepted guesses, successful solve, final time/guess result, difficulty unlock, saved record visible when returning to lobby. Automated win/loss flows at all four guess limits. | Live manual loss and full small-device/accessibility matrix. |
| Lava Rescue | Signed-in simulator: wrong/correct input, successful rescue, replay reset, six-wrong-letter loss, final results. Offline final build: single back button and reordered Time/Wrong/Word/Category result tiles verified. Automated stopwatch, duplicate-letter handling, finished lock, and all four difficulty flows. | Broader device/accessibility matrix. |
| Anagrams | Offline actual game screen: all six tiles fit, tile selection and CAT submission score correctly, fixed board position, zero-score and scored timeout results, replay reset, final controls disabled. Automated valid/invalid/short/repeated inputs and post-timeout lock. | Larger difficulty tile banks, physical-touch review, full long-list scrolling. |
| Word Hunt | Offline actual game screen: board fits, normal 75-second timeout, zero-score results, expanded missed words. Automated diagonal paths, corners, fast gestures, adjacency, scoring, repeat rejection, replay, and post-timeout lock. | Actual finger-drag feel and a manually traced successful round. The UI automation tool failed to inject drags with noWindowsAvailable; do not count these as completed swipes. |
| Color Link | Offline actual screen: near-finish connected-path styling, result callback/overlay, disabled finished controls, replay back to fixture with clock reset. Automated seeded boards, legal full solves, backtracking, clear, invalid input, and completion lock at all four difficulties. | Natural finger-drag playthrough, dense expert board on a physical phone. |
| Solitaire | Offline actual screen: near-finish layout, normal Auto button completes foundations, result/callback, finished controls disabled, replay reset. Invalid foundation action shows floating feedback without shifting piles. Automated seeded deals, unique cards, draw/redeal rules and limits, controlled final foundation moves at all four difficulties. | Natural deal played through, tall-stack scrolling by touch, full legal/illegal move matrix and small-screen coverage. |
| Sudoku | Offline normal board/keypad layout and near-finish actual result/callback, hint/conflict copy, finished input disabled, replay reset. Automated reproducible uniquely solvable puzzles, notes, conflicts, erase, hints/progress, full solves through digit input and completion lock at all four difficulties. | Full manual solve, physical touch and larger accessibility text sizes. |
| Minesweeper | Offline near-finish actual win callback/result, finished controls disabled and replay reset. Automated first-tap safety, pre-start flags, exact mine count, seed reproducibility with the same starting cell, full wins, mine-hit losses, restart and lock at all four difficulties. | Manual mine-hit result, chord/long-press feel, scrolling larger boards on a physical phone. |

The updated main game was built and installed in Simulator. It returned to sign-in after installation. At the user's request, remaining review moved to a separate offline app with actual production views/game logic, real word lists, controlled sample puzzles, no account, no ads, and no backend calls. Offline result callbacks are not persistence tests.

Non-word visual completion checks used controlled near-finish fixtures, then real game actions and the production result views. Replay recreated those fixtures with fresh timers; these checks are not four natural start-to-finish manual playthroughs. Automated tests separately exercise original generated boards, with a near-finish fixture for Solitaire's win path. An initial Minesweeper fixture incorrectly chord-tapped an already-revealed cell beside its deliberate safe-cell flag; that test setup was corrected before the successful visual check.

## Repeatable Checks

- `bash scripts/check-word-game-input.sh`: 90 checks against production Word Hunt/Anagram game logic and view models, with a small fixture dictionary and no-op sound/backend dependencies.
- `bash scripts/check-word-solve-flows.sh`: 66 Word Guess/Lava Rescue checks using production games/view models and bundled word lists, including real timer/reveal completion.
- `bash scripts/check-solo-presentation.sh`: 225 shared solo record/presentation assertions.
- `bash scripts/check-match-resolution.sh`: 38 tie-resolution assertions.
- `bash scripts/check-board-game-flows.sh`: 158 production-model checks across Color Link, Solitaire, Sudoku, and Minesweeper at all four difficulties, including completion timer shutdown. Sound/preferences are stubbed; no Firebase dependency.
- All five suites were rerun successfully for the non-word follow-up: 577 checks total.
- Full Debug simulator build, normal/DEBUG Swift parse, and diff whitespace checks passed.

## Remaining Follow-Up

1. User confirmed Word Hunt diagonals feel much better on September 26. Full 6x6/7x7 and physical-device coverage remains broader release validation.
2. Finish natural/manual playthrough and physical-device coverage listed above, including tall Solitaire stacks and Minesweeper loss/chord interaction. All eight modes now have targeted gameplay checks, not exhaustive manual certification.
3. User confirmed records persist after signing out/in on September 26. Online tie-breaks on two clients remain deferred for the user's later test.
4. Review accepted word-list coverage: TOILS was rejected during the live Word Guess test. Dictionary scope was not changed in this input/layout pass.
5. Initial earned status work has started; see `COSMETIC_RELEASE_PLAN.md` for implemented rewards and remaining validation.
