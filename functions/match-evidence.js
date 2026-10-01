/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";
const {check} = require("./wallet-ledger");
const {validateCompletion, validateSolitaire, shuffled} = require("./solo-reward-policy");
const limits = {sudoku: 720, colorLink: 540, minesweeper: 300, gridlock: 600, wordle: 0, hangman: 90, anagram: 60, wordHunt: 75};
const unique = (a) => new Set(a).size === a.length;
function cells(a, size) {
  check(Array.isArray(a) && a.length <= size && a.every((n) => Number.isSafeInteger(n) && n >= 0 && n < size) && unique(a), "Invalid cells");
  return a;
}

// Reconstruct every competitive metric from evidence and the private canonical
// puzzle. No caller-supplied score, completion, time, rank or target is used.
function verifyResult(p, uid, e, elapsedMs, timeLimit = limits[p.mode]) {
  check(e && typeof e === "object" && !Array.isArray(e) && Buffer.byteLength(JSON.stringify(e)) <= 180000, "Invalid evidence");
  check(Number.isSafeInteger(elapsedMs) && elapsedMs >= 0, "Match has not started");
  const elapsed = Math.floor(elapsedMs / 1000);
  const timeout = timeLimit > 0 && elapsed >= timeLimit;
  const r = {userID: uid, mode: p.mode, completed: false, elapsedSeconds: elapsed, score: 0, progress: 0,
    status: "Finished", summary: {}, details: []};
  let played = false;
  switch (p.mode) {
    case "sudoku": {
      check(Array.isArray(e.cells) && e.cells.length === 81 && e.cells.every((n) => Number.isInteger(n) && n >= 0 && n <= 9), "Invalid Sudoku cells");
      check(p.givens.every((n, i) => !n || e.cells[i] === n), "Changed givens");
      let filled = 0; let blanks = 0;
      e.cells.forEach((n, i) => {
        if (p.givens[i]) return;
        blanks++; if (n) played = true;
        const row = Math.floor(i / 9); const col = i % 9;
        const valid = n && !e.cells.some((value, j) => j !== i && value === n &&
          (Math.floor(j / 9) === row || j % 9 === col ||
            (Math.floor(j / 27) === Math.floor(row / 3) && Math.floor((j % 9) / 3) === Math.floor(col / 3))));
        if (valid) filled++;
      });
      r.progress = filled / Math.max(1, blanks); r.completed = filled === blanks;
      if (r.completed) validateCompletion(p, e, elapsedMs);
      r.score = Math.round(r.progress * 100);
      r.summary = {progressPercent: String(r.score), boardSize: "9", boardRows: Array.from({length: 9}, (_, i) => e.cells.slice(i * 9, i * 9 + 9).join("")).join("|")};
      break;
    }
    case "colorLink": {
      check(e.paths && typeof e.paths === "object" && !Array.isArray(e.paths) && Object.keys(e.paths).length <= p.pairs.length, "Invalid paths");
      const occupied = new Map();
      for (const pair of p.pairs) {
        occupied.set(pair.start, pair.id); occupied.set(pair.end, pair.id);
      }
      let solved = 0;
      for (const [id, raw] of Object.entries(e.paths)) {
        const pair = p.pairs.find((item) => String(item.id) === id); check(pair, "Unknown color");
        const path = cells(raw, p.size * p.size);
        check(path.length > 0 && [pair.start, pair.end].includes(path[0]), "Invalid path start");
        const end = path[0] === pair.start ? pair.end : pair.start;
        path.forEach((cell, i) => {
          check(!occupied.has(cell) || occupied.get(cell) === pair.id, "Overlapping colors");
          check(cell !== end || i === path.length - 1, "Path continues past endpoint");
          if (i) check(Math.abs(Math.floor(cell / p.size) - Math.floor(path[i - 1] / p.size)) + Math.abs(cell % p.size - path[i - 1] % p.size) === 1, "Disconnected path");
          occupied.set(cell, pair.id);
        });
        if (path.at(-1) === end) solved++;
        if (path.length > 1) played = true;
      }
      r.score = occupied.size; r.progress = occupied.size / (p.size * p.size);
      r.completed = solved === p.pairs.length && r.progress === 1;
      r.summary = {solvedPairs: String(solved), filledCells: String(r.score), totalCells: String(p.size * p.size)};
      break;
    }
    case "gridlock": {
      const state = validateSolitaire(p, e, false);
      r.completed = state.completed; r.score = state.score; r.progress = state.foundationCount / 52;
      r.summary = {moves: String(state.moves), foundationCount: String(state.foundationCount)};
      played = state.moves > 0;
      break;
    }
    case "minesweeper": {
      const size = p.rows * p.cols;
      const revealed = cells(e.revealed, size);
      if (e.firstCell === -1 && !revealed.length && e.explodedCell === undefined) break;
      cells([e.firstCell], size);
      const candidates = Array.from({length: size}, (_, i) => i).filter((i) =>
        Math.abs(Math.floor(i / p.cols) - Math.floor(e.firstCell / p.cols)) > 1 || Math.abs(i % p.cols - e.firstCell % p.cols) > 1);
      const mines = new Set(shuffled(candidates, p.seed).slice(0, p.mines));
      check(revealed.includes(e.firstCell) && revealed.every((i) => !mines.has(i)), "Invalid revealed cells");
      const hit = e.explodedCell !== undefined;
      if (hit) check(mines.has(e.explodedCell), "Invalid explosion");
      r.completed = !hit && revealed.length === size - p.mines;
      r.score = revealed.length; r.progress = revealed.length / (size - p.mines);
      r.summary = {hitMine: String(hit), safeCells: String(r.score), totalSafeCells: String(size - p.mines)};
      played = true;
      break;
    }
    case "anagram": case "wordHunt": {
      validateCompletion(p, e, elapsedMs);
      r.completed = true; r.elapsedSeconds = limits[p.mode];
      r.score = e.words.reduce((sum, word) => sum + Math.min(5, word.length - 2), 0); r.progress = 1;
      r.summary = {wordCount: String(e.words.length), longestWordLength: String(Math.max(0, ...e.words.map((w) => w.length))), foundWords: e.words.join("|")};
      r.details = e.words.map((w) => `${w} (+${Math.min(5, w.length - 2)})`);
      played = e.words.length > 0;
      break;
    }
    case "wordle": {
      check(Array.isArray(e.rounds) && e.rounds.length >= 2 && e.rounds.length <= 3, "Incomplete Word Guess match");
      let solved = 0; let failed = 0; let guesses = 0;
      for (const [i, round] of e.rounds.entries()) {
        check(solved < 2 && failed < 2, "Extra Word Guess round");
        const win = validateCompletion({...p, target: p.targets[i]}, {guesses: round}, elapsedMs) > 0;
        if (win) {
          solved++; guesses += round.length;
        } else failed++;
        r.summary[`round${i + 1}Target`] = p.targets[i];
        r.summary[`round${i + 1}Solved`] = String(win);
        r.summary[`round${i + 1}GuessCount`] = String(round.length);
        // Evaluation is recomputed for post-game breakdowns, never trusted input.
        r.summary[`round${i + 1}Guesses`] = round.map((word) => `${word}:${evaluateWord(word, p.targets[i])}`).join(";");
      }
      check(solved >= 2 || failed >= 2, "Unfinished Word Guess match");
      r.completed = solved >= 2; r.score = solved; r.progress = solved / 3; played = true;
      Object.assign(r.summary, {solvedRounds: String(solved), failedRounds: String(failed), totalGuesses: String(guesses), roundCount: String(e.rounds.length), isFinal: "true"});
      break;
    }
    case "hangman": {
      check(Array.isArray(e.rounds) && e.rounds.length > 0 && e.rounds.length <= 3, "Invalid Lava rounds");
      let solved = 0; let wrong = 0; let revealed = 0;
      for (const [i, letters] of e.rounds.entries()) {
        check(solved < 2 && typeof letters === "string" && /^[A-Z]{0,26}$/.test(letters) && unique([...letters]), "Invalid Lava letters");
        const target = p.rounds[i]; const correct = new Set([target.starter]); let misses = "";
        for (const letter of letters) {
          check(letter !== target.starter && misses.length < p.maxWrong && ![...target.target].every((c) => correct.has(c)), "Letters after final state");
          if (target.target.includes(letter)) correct.add(letter); else misses += letter;
        }
        const win = [...target.target].every((c) => correct.has(c));
        const terminal = win || misses.length === p.maxWrong;
        check(terminal || (timeout && i === e.rounds.length - 1), "Unfinished Lava round");
        if (win) solved++;
        wrong += misses.length; revealed += correct.size;
        if (letters.length) played = true;
        Object.assign(r.summary, {[`round${i + 1}TargetWord`]: target.target, [`round${i + 1}Category`]: target.category,
          [`round${i + 1}StarterLetter`]: target.starter, [`round${i + 1}Solved`]: String(win),
          [`round${i + 1}WrongLetters`]: misses, [`round${i + 1}CorrectLetters`]: [...correct].join("")});
      }
      check(solved >= 2 || e.rounds.length === 3 || timeout, "Unfinished Lava match");
      r.completed = solved >= 2; r.score = solved; r.progress = Math.min(1, solved / 2);
      Object.assign(r.summary, {solvedRounds: String(solved), wrongGuessCount: String(wrong), revealedLetterCount: String(revealed),
        roundCount: String(e.rounds.length), totalRounds: "3", final: "true"});
      break;
    }
    default: throw new Error("Unsupported game");
  }
  const naturallyFinal = r.completed || r.summary.hitMine === "true" || r.summary.isFinal === "true" || r.summary.final === "true";
  check(naturallyFinal || timeout, "Round is still active");
  if (timeout && !r.completed) r.status = "Time expired";
  return {result: r, played};
}

function evaluateWord(word, target) {
  const marks = [...word].map((letter, i) => letter === target[i] ? "C" : "A");
  const remaining = [...target].filter((_, i) => marks[i] !== "C");
  [...word].forEach((letter, i) => {
    if (marks[i] === "C") return;
    const index = remaining.indexOf(letter);
    if (index >= 0) {
      marks[i] = "P"; remaining.splice(index, 1);
    }
  });
  return marks.join("");
}
module.exports = {verifyResult, limits};
