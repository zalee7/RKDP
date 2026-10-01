/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";

const {createHash} = require("node:crypto");
const difficulties = ["easy", "medium", "hard", "expert"];
const rates = Object.freeze({
  colorLink: [3, 4, 5, 7], wordle: [4, 5, 7, 9],
  hangman: [4, 5, 7, 9], anagram: [4, 5, 6, 8],
  wordHunt: [4, 5, 6, 8], minesweeper: [4, 6, 9, 12],
  gridlock: [5, 7, 10, 14], sudoku: [5, 8, 12, 18],
});

function requireValue(ok, message) {
  if (!ok) throw new Error(message);
}
function rewardAmount(mode, difficulty) {
  requireValue(Object.hasOwn(rates, mode) && difficulties.includes(difficulty), "Unsupported game or difficulty");
  return rates[mode][difficulties.indexOf(difficulty)];
}
function integers(value, max, limit) {
  requireValue(Array.isArray(value) && value.length <= limit &&
    value.every((n) => Number.isSafeInteger(n) && n >= 0 && n < max), "Invalid cell list");
  return value;
}
function distinct(value) {
  return new Set(value).size === value.length;
}
function words(value, limit = 500, allowRepeats = false) {
  requireValue(Array.isArray(value) && value.length <= limit &&
    value.every((w) => typeof w === "string" && /^[A-Z]{3,30}$/.test(w)), "Invalid word list");
  requireValue(allowRepeats || distinct(value), "Repeated words");
  return value;
}
function same(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

// Identity deliberately excludes difficulty, seed and version. Repackaging the same
// puzzle at another difficulty must not create another payable puzzle.
function puzzleIdentity(p) {
  let content;
  switch (p.mode) {
    case "sudoku": content = p.givens; break;
    case "colorLink": content = [p.size, p.pairs.map((pair) => [pair.start, pair.end].sort((a, b) => a - b)).sort((a, b) => a[0] - b[0])]; break;
    case "wordle": case "hangman": content = p.target; break;
    case "anagram": content = p.letters.split("").sort().join(""); break;
    case "wordHunt": content = p.grid; break;
    case "minesweeper": content = [p.rows, p.cols, p.seed, p.mines]; break;
    case "gridlock": content = p.deck; break;
    default: throw new Error("Unsupported puzzle");
  }
  return createHash("sha256").update(JSON.stringify([p.mode, content])).digest("hex");
}

function validateCompletion(p, evidence, elapsedMilliseconds) {
  rewardAmount(p.mode, p.difficulty);
  requireValue(evidence && typeof evidence === "object" && !Array.isArray(evidence) &&
    Buffer.byteLength(JSON.stringify(evidence)) <= 100000, "Invalid evidence");
  requireValue(Number.isSafeInteger(elapsedMilliseconds) && elapsedMilliseconds >= 0, "Invalid server time");
  let won = true;
  switch (p.mode) {
    case "sudoku": {
      const cells = integers(evidence.cells, 10, 81);
      requireValue(cells.length === 81 && cells.every((v) => v > 0), "Incomplete Sudoku");
      requireValue(p.givens.length === 81 && p.givens.every((v, i) => v === 0 || v === cells[i]), "Changed givens");
      for (let n = 0; n < 9; n++) {
        requireValue(distinct(cells.slice(n * 9, n * 9 + 9)), "Invalid row");
        requireValue(distinct(Array.from({length: 9}, (_, i) => cells[i * 9 + n])), "Invalid column");
        requireValue(distinct(Array.from({length: 9}, (_, i) => cells[(Math.floor(n / 3) * 3 + Math.floor(i / 3)) * 9 + (n % 3) * 3 + i % 3])), "Invalid box");
      }
      break;
    }
    case "colorLink": {
      requireValue(evidence.paths && Object.keys(evidence.paths).length === p.pairs.length, "Missing paths");
      const used = new Set();
      for (const pair of p.pairs) {
        const path = integers(evidence.paths[String(pair.id)], p.size * p.size, p.size * p.size);
        requireValue(path.length >= 2 && ((path[0] === pair.start && path.at(-1) === pair.end) ||
          (path[0] === pair.end && path.at(-1) === pair.start)), "Wrong endpoints");
        for (let i = 0; i < path.length; i++) {
          const cell = path[i];
          requireValue(!used.has(cell), "Overlapping paths");
          used.add(cell);
          if (i) {
            const last = path[i - 1];
            requireValue(Math.abs(Math.floor(cell / p.size) - Math.floor(last / p.size)) + Math.abs(cell % p.size - last % p.size) === 1, "Disconnected path");
          }
        }
      }
      requireValue(used.size === p.size * p.size, "Board not filled");
      break;
    }
    case "wordle": {
      const maxGuesses = [7, 6, 5, 4][difficulties.indexOf(p.difficulty)];
      const guesses = words(evidence.guesses, maxGuesses, true);
      requireValue(guesses.every((w) => w.length === 5 && p.validGuesses.includes(w)), "Invalid guess");
      requireValue(!guesses.slice(0, -1).includes(p.target), "Guesses after solve");
      won = guesses.at(-1) === p.target;
      requireValue(won || guesses.length === maxGuesses, "Word attempt not finished");
      break;
    }
    case "hangman": {
      requireValue(typeof evidence.letters === "string" && /^[A-Z]{1,26}$/.test(evidence.letters) && distinct([...evidence.letters]), "Invalid letters");
      const correct = new Set([p.starter]);
      let wrong = 0;
      for (const letter of evidence.letters) {
        requireValue(wrong < p.maxWrong, "Guesses after loss");
        requireValue(![...p.target].every((value) => correct.has(value)), "Guesses after solve");
        requireValue(letter !== p.starter, "Starter letter was already revealed");
        if (p.target.includes(letter)) correct.add(letter);
        else wrong++;
      }
      won = [...p.target].every((letter) => correct.has(letter));
      requireValue(won || wrong === p.maxWrong, "Lava attempt not finished");
      break;
    }
    case "anagram": case "wordHunt": {
      const minimum = p.mode === "anagram" ? 60000 : 75000;
      requireValue(elapsedMilliseconds >= minimum, "Timed round not finished");
      requireValue(words(evidence.words).every((w) => p.validWords.includes(w)), "Invalid found words");
      won = evidence.words.length > 0;
      break;
    }
    case "minesweeper": won = validateMines(p, evidence); break;
    case "gridlock": validateSolitaire(p, evidence); break;
    default: throw new Error("Unsupported game");
  }
  return won ? rewardAmount(p.mode, p.difficulty) : 0;
}

// Matches the production Swift LCG. Only server-assigned safe-integer seeds enter it.
function shuffled(input, seed) {
  const mask = (1n << 64n) - 1n;
  const a = 6364136223846793005n;
  const c = 1442695040888963407n;
  let state = (BigInt(seed) * a + c) & mask;
  const next = () => {
    state = (state * a + c) & mask; return Number(state >> 33n);
  };
  next();
  const result = [...input];
  for (let i = result.length - 1; i > 0; i--) {
    const j = next() % (i + 1);
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

function validateMines(p, e) {
  const count = p.rows * p.cols;
  const first = integers([e.firstCell], count, 1)[0];
  const excluded = new Set();
  for (let r = 0; r < p.rows; r++) {
    for (let c = 0; c < p.cols; c++) {
      if (Math.abs(r - Math.floor(first / p.cols)) <= 1 && Math.abs(c - first % p.cols) <= 1) excluded.add(r * p.cols + c);
    }
  }
  const candidates = Array.from({length: count}, (_, i) => i).filter((i) => !excluded.has(i));
  const mines = new Set(shuffled(candidates, p.seed).slice(0, p.mines));
  const revealed = integers(e.revealed, count, count);
  requireValue(distinct(revealed), "Repeated revealed cells");
  if (e.explodedCell !== undefined) {
    integers([e.explodedCell], count, 1);
    requireValue(mines.has(e.explodedCell) && revealed.includes(first) && revealed.every((i) => !mines.has(i)), "Invalid lost attempt");
    return false;
  }
  requireValue(distinct(revealed) && revealed.length === count - p.mines && revealed.includes(first) &&
    revealed.every((i) => !mines.has(i)), "Unsafe or incomplete board");
  return true;
}

function validateSolitaire(p, e, requireComplete = true) {
  requireValue(Array.isArray(e.moves) && e.moves.length <= 10000 && (!requireComplete || e.moves.length > 0), "Invalid move history");
  requireValue(integers(p.deck, 52, 52).length === 52 && distinct(p.deck), "Invalid server deck");
  const rank = (c) => c % 13 + 1;
  const suit = (c) => Math.floor(c / 13);
  const red = (c) => suit(c) < 2;
  const tableau = [];
  let cursor = 0;
  for (let column = 0; column < 7; column++) {
    tableau.push(p.deck.slice(cursor, cursor + column + 1).map((card, i) => ({card, up: i === column})));
    cursor += column + 1;
  }
  let stock = p.deck.slice(cursor);
  let waste = [];
  const foundations = [[], [], [], []];
  const drawCount = p.difficulty === "easy" ? 1 : 3;
  const maxRedeals = {hard: 3, expert: 1}[p.difficulty] ?? Infinity;
  let redeals = 0;
  const flip = (column) => {
    if (tableau[column].length) tableau[column].at(-1).up = true;
  };
  for (const move of e.moves) {
    requireValue(Array.isArray(move) && move.every(Number.isSafeInteger), "Invalid move");
    if (same(move, [0])) {
      if (stock.length) {
        for (let n = 0; n < drawCount && stock.length; n++) waste.push(stock.pop());
      } else {
        requireValue(waste.length && redeals < maxRedeals, "Invalid redeal");
        stock = waste.reverse(); waste = []; redeals++;
      }
      continue;
    }
    // [1, sourceColumn (-1 waste), sourceIndex, destination (-1 foundation)]
    requireValue(move.length === 4 && move[0] === 1, "Unsupported move");
    const [, source, index, destination] = move;
    requireValue(source >= -1 && source < 7 && destination >= -1 && destination < 7 &&
      (destination === -1 || source !== destination), "Invalid piles");
    const pile = source === -1 ? waste.map((card) => ({card, up: true})) : tableau[source];
    requireValue(index >= 0 && index < pile.length && pile.slice(index).every((c) => c.up), "Hidden or missing card");
    if (source === -1) requireValue(index === pile.length - 1, "Only top waste card moves");
    const moving = pile.slice(index).map((c) => c.card);
    const first = moving[0];
    if (destination === -1) {
      requireValue(moving.length === 1 && rank(first) === foundations[suit(first)].length + 1, "Invalid foundation move");
      foundations[suit(first)].push(first);
    } else {
      const target = tableau[destination].at(-1);
      requireValue(target ? target.up && red(target.card) !== red(first) && rank(target.card) === rank(first) + 1 : rank(first) === 13, "Invalid tableau move");
      for (let i = 1; i < moving.length; i++) requireValue(red(moving[i - 1]) !== red(moving[i]) && rank(moving[i - 1]) === rank(moving[i]) + 1, "Invalid sequence");
      tableau[destination].push(...moving.map((card) => ({card, up: true})));
    }
    if (source === -1) waste.pop();
    else {
      tableau[source].splice(index); flip(source);
    }
  }
  const completed = foundations.every((pile) => pile.length === 13);
  if (requireComplete) requireValue(completed, "Solitaire not completed");
  const foundationCount = foundations.reduce((sum, pile) => sum + pile.length, 0);
  const faceUp = tableau.flat().filter((card) => card.up).length;
  return {completed, foundationCount, moves: e.moves.length, score: Math.max(0, foundationCount * 10 + faceUp * 2 - e.moves.length)};
}

module.exports = {rates, rewardAmount, puzzleIdentity, validateCompletion, shuffled, validateSolitaire};
