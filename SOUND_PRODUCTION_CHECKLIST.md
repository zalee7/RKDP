# Puzzle Party Sound Checklist

**Full guide:** [Complete Sound Design Guide](SOUND_DESIGN_GUIDE.md) covers every mode, coin amount bands, ranks/XP, cosmetics, badges, achievements, timing, export quality and delivery. It is now the master brief; this file remains the earlier starter inventory. Where they differ, follow the full guide (including 24-bit preferred masters and the split PersonalBest/BadgeUnlock/AchievementReady cues).

Audited September 25, 2026 against SoundManager, game call sites, and bundled audio assets. This is a production list, not a claim that new sound hooks already exist. The existing clips were inventoried, not auditioned for quality.

Updated September 30: added a proposed time-running-low warning, separate from the round-ending cue. This addition is a recording requirement, not an implemented timer hook.

## Already In The App

No need to remake these just to fill a missing slot.

| Asset | Current use |
| --- | --- |
| GameFound.mp3 | Online match found |
| GridVictory.mp3 | Online victory |
| GridLoss.mp3 | Online defeat |
| Matchmaking.mp3 | Matchmaking music loop |
| InOnlineGame.mp3 | Quiet online gameplay music loop |
| OtherKeyboardPress.mp3 | Anagrams, Word Hunt, Lava Rescue input; Solitaire moves |
| WordleTileClick.mp3 | Word Guess keyboard/input |

All seven files exist in Resources/Assets.xcassets and are named in SoundManager. The two input clips are different files, despite having the same file size.

## Make These First: Ten Short Clips

These proposed filenames are delivery names, not existing asset identifiers.

| Suggested filename | Sound direction | Target length | Current gap |
| --- | --- | --- | --- |
| WordFound3.wav | Small soft positive pop | 0.10-0.25 seconds | Three-letter word currently uses a system sound |
| WordFound4.wav | Slightly brighter version | 0.10-0.30 seconds | Four-letter system sound |
| WordFound5.wav | Fuller, satisfying chime | 0.15-0.35 seconds | Five-letter system sound |
| WordFound6.wav | Stronger upward chime | 0.20-0.40 seconds | Six-letter system sound |
| WordFound7Plus.wav | Short premium flourish | 0.25-0.50 seconds | Seven-or-more-letter system sound |
| InvalidInput.wav | Gentle dull tap/bump; not an alarm | 0.10-0.25 seconds | Invalid and repeated words currently share system feedback |
| WordCombo.wav | Compact rising accent | 0.20-0.40 seconds | Combo currently repeats a system ping |
| TimeRunningLow.wav | Two soft, quick ticks or a restrained rising pulse; noticeable, not stressful | 0.30-0.60 seconds | Proposed one-time warning when a timed round reaches 10 seconds remaining; new hook needed |
| RoundTimeUp.wav | Neutral, clear end-of-round cue | 0.40-0.80 seconds | Generic gameOver currently uses a system alert |
| AchievementUnlock.wav | Bright, rewarding mini-fanfare | 0.60-1.00 seconds | New best/difficulty unlock has no dedicated audio hook |

The five word clips should be variations of one sound family, not five unrelated effects. A strong base sound with increasing pitch/detail is enough. The unlock clip can cover both a personal best and a newly unlocked difficulty; play it only once when both happen together.

## Optional Mode Polish: Six More

Make these after the first batch. New event routing is needed; none are currently wired as dedicated custom sounds.

| Suggested filename | Event / character | Target length |
| --- | --- | --- |
| ColorConnected.wav | A satisfying snap when a Color Link pair connects | 0.15-0.35 seconds |
| CardPlace.wav | Soft paper/card placement for Solitaire | 0.08-0.20 seconds |
| MineHit.wav | Short low impact; avoid a harsh explosion | 0.30-0.60 seconds |
| LavaRise.wav | Small bubbling rise when a wrong letter raises lava | 0.15-0.40 seconds |
| LetterRescued.wav | Light positive cue for a correct Lava Rescue letter | 0.10-0.25 seconds |
| MatchDraw.wav | Neutral conclusion, neither victory nor defeat | 0.40-0.80 seconds |

Sudoku number placement and Minesweeper reveal/flag taps can reuse the existing input sound initially. A separate already-found-word sound is optional; the gentle invalid cue is enough for release.

## Wiring Work, Not More Recording

- Reuse GridVictory and GridLoss for solo wins/losses where appropriate. Current solo gameOver does not distinguish a win, loss, and timer ending, and some solve-based games have no sound call at completion.
- Replace the five word-length system sounds and repeated combo pings with the delivered clips.
- Split neutral timer endings from wins/losses. Lava Rescue currently calls the same gameOver method for either outcome.
- Add TimeRunningLow once per timed round when remaining time crosses 10 seconds. Do not loop it, play it every second, replay it on reconnect, or play it over a submitted/result screen. Elapsed-time-only modes do not need it. RoundTimeUp is the separate cue when the timer actually ends.
- Add a single unlock/personal-best event cue to the result flow.
- Route any optional mode effects to their actual events, not every animation frame or repeated state update.
- Keep effects under Sound Effects and loops under Music. Do not add audio to every screen transition.
- Packs are hidden, so pack opening/rarity sounds are not needed for this release.
- Home music, unique music for every mode, and separate sounds for every cosmetic are not launch requirements.

## Delivery Specs

- Supply WAV masters: 48 kHz, 16-bit PCM; mono is enough for short effects. Stereo is fine for music.
- Match perceived loudness across the family. Avoid clipping, long silence at the beginning, abrupt cutoffs, and overly sharp high frequencies.
- Repeated input/word effects should be quieter than victory and unlock cues.
- Keep the natural short decay; do not add several seconds of reverb to frequently repeated sounds.
- Keep any loop seamless. Existing music does not need replacement unless you dislike it.
- Current loose-file fallback loads MP3; WAV delivery will be imported as named data assets or explicitly added to the loader. Do not simply drop loose WAVs into the folder and expect them to play.

Recommended first delivery: the ten priority clips. Optional mode clips can follow separately.
