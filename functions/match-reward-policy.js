/* eslint require-jsdoc: "off", max-len: "off" */
"use strict";

const {check, validUID} = require("./wallet-ledger");
const presets = {sudoku: "medium", minesweeper: "medium", colorLink: "expert", gridlock: "easy",
  anagram: "medium", wordHunt: "easy", wordle: "medium", hangman: "medium"};
const thresholds = [0, 600, 1800, 3600, 7200, 12000];
const wins = [20, 30, 40, 50, 60, 75];
const integer = (value) => Number.isSafeInteger(value) && value >= 0;
const stat = (r, key, fallback = 0) => Number(r.summary[key] ?? fallback);
const tier = (points) => thresholds.findLastIndex((n) => points >= n);
const raceModes = ["sudoku", "gridlock", "colorLink", "minesweeper"];

function finalResult(r) {
  if (r.mode === "wordle") {
    return r.summary.isFinal === "true" ||
    (r.summary.isFinal === undefined && (stat(r, "solvedRounds") >= 2 || stat(r, "failedRounds") >= 2));
  }
  if (r.mode === "hangman") {
    if (r.summary.final !== undefined) return r.summary.final === "true";
    return stat(r, "solvedRounds") >= 2 ||
      (r.summary.totalRounds !== undefined && stat(r, "roundCount") >= stat(r, "totalRounds")) ||
      r.completed || r.status !== "In progress";
  }
  return true;
}

function isForfeit(r) {
  return r && (r.summary.forfeit === "true" || r.summary.forfeitWin === "true" || /forfeit|abandon/i.test(r.status));
}

// Only call with a private, server-verified snapshot. Schema validation is NOT
// puzzle-proof validation and must never be used to bless a public session.
function validateMatch(m, id, now) {
  check(m?.version === 1 && m.verifierVersion === "match-v1" && m.sessionID === id && m.status === "finished",
      "Verified match required");
  check(["ranked", "casual"].includes(m.matchKind) && Object.hasOwn(presets, m.mode) && presets[m.mode] === m.difficulty,
      "Unsupported match rules");
  check(integer(m.startedAtMs) && integer(m.finishedAtMs) && m.finishedAtMs >= m.startedAtMs && m.finishedAtMs <= now,
      "Invalid match clock");
  check(Array.isArray(m.players) && m.players.length === 2 && new Set(m.players.map((p) => p.userID)).size === 2 &&
    m.players.every((p) => validUID(p.userID) && typeof p.isBot === "boolean" && integer(p.rankPoints)), "Invalid participants");
  const ids = m.players.map((p) => p.userID);
  const bots = m.players.filter((p) => p.isBot);
  check(bots.length <= 1 && (!bots.length || (m.matchKind === "ranked" && m.players.every((p) => tier(p.rankPoints) === 0))),
      "Invalid training match");
  check(Array.isArray(m.playedUserIDs) && new Set(m.playedUserIDs).size === m.playedUserIDs.length &&
    m.playedUserIDs.every((uid) => m.players.some((p) => p.userID === uid && !p.isBot)), "Invalid participation");
  check(Array.isArray(m.forfeitedIDs) && m.forfeitedIDs.length <= 1 && m.forfeitedIDs.every((uid) => ids.includes(uid)),
      "Invalid forfeits");
  check(m.playerResults && typeof m.playerResults === "object" && !Array.isArray(m.playerResults) &&
    Object.keys(m.playerResults).length <= 2, "Invalid results");
  for (const [uid, r] of Object.entries(m.playerResults)) {
    check(ids.includes(uid) && r.userID === uid && r.mode === m.mode && typeof r.completed === "boolean" &&
      integer(r.elapsedSeconds) && integer(r.score) && Number.isFinite(r.progress) && r.progress >= 0 && r.progress <= 1 &&
      typeof r.status === "string" && r.status.length <= 200 && r.summary && typeof r.summary === "object" && !Array.isArray(r.summary),
    "Invalid result metrics");
    check(Object.keys(r.summary).length <= 80 && Object.values(r.summary).every((s) => typeof s === "string" && s.length <= 16000),
        "Invalid result summary");
    for (const key of ["solvedRounds", "failedRounds", "totalGuesses", "roundCount", "totalRounds", "wrongGuessCount",
      "revealedLetterCount", "wordCount", "longestWordLength", "moves", "foundationCount", "solvedPairs"]) {
      if (r.summary[key] !== undefined) check(/^\d+$/.test(r.summary[key]) && integer(stat(r, key)), "Invalid summary metric");
    }
    check(!isForfeit(r) || m.forfeitedIDs.length === 1, "Unverified forfeit");
  }
}

function resolveMatch(m) {
  if (m.forfeitedIDs.length) return m.players.find((p) => !m.forfeitedIDs.includes(p.userID)).userID;
  const results = m.players.map((p) => m.playerResults[p.userID]).filter(Boolean);
  if (results.length === 1 && raceModes.includes(m.mode) && results[0].completed) return results[0].userID;
  check(results.length === 2 && results.every(finalResult), "Match is not finished");
  const [a, b] = results;
  const compare = (values) => {
    for (const [x, y, direction = 1] of values) {
      if (x !== y) return (x > y ? direction : -direction) > 0 ? a.userID : b.userID;
    }
    return null;
  };
  const time = [a.elapsedSeconds, b.elapsedSeconds, -1];
  const completion = [Number(a.completed), Number(b.completed)];
  const summary = (key, direction = 1, fallbackA = 0, fallbackB = 0) => [stat(a, key, fallbackA), stat(b, key, fallbackB), direction];
  switch (m.mode) {
    case "wordle":
      if (stat(a, "solvedRounds") === 0 && stat(b, "solvedRounds") === 0) return null;
      return compare([summary("solvedRounds"), summary("totalGuesses", -1), time]);
    case "hangman":
      return compare([summary("solvedRounds"), completion, summary("wrongGuessCount", -1),
        summary("revealedLetterCount", 1, a.score, b.score), time]);
    case "anagram": case "wordHunt":
      return compare([[a.score, b.score], summary("wordCount"), summary("longestWordLength")]);
    case "sudoku":
      return compare([completion, ...(a.completed && b.completed ? [] : [[a.progress, b.progress]]), time]);
    case "colorLink":
      return compare([completion, ...(a.completed && b.completed ? [] : [[a.progress, b.progress], summary("solvedPairs")]), time]);
    case "gridlock":
      return compare([completion, ...(a.completed && b.completed ? [] : [
        summary("foundationCount", 1, Math.round(a.progress * 52), Math.round(b.progress * 52)),
        [a.score, b.score], [a.progress, b.progress]]), summary("moves", -1), time]);
    case "minesweeper":
      return compare([[Number(a.summary.hitMine === "true"), Number(b.summary.hitMine === "true"), -1],
        completion, [a.score, b.score], time]);
    default: throw new Error("Unsupported match rules");
  }
}

function rankDelta(m, uid, winnerID) {
  const win = winnerID === uid;
  if (m.players.some((p) => p.isBot)) return winnerID === null ? 0 : win ? 15 : -8;
  let base = winnerID === null ? 5 : win ? 30 : -15;
  const division = (p) => {
    const t = tier(p.rankPoints);
    const size = t === 5 ? 500 : (thresholds[t + 1] - thresholds[t]) / 3;
    return t * 3 + Math.min(2, Math.floor((p.rankPoints - thresholds[t]) / size)) + 1;
  };
  if (winnerID !== null) {
    const diff = Math.max(-2, Math.min(2, division(m.players.find((p) => p.userID !== uid)) - division(m.players.find((p) => p.userID === uid))));
    base = win ? Math.max(10, base + diff * 5) : Math.min(-5, base + diff * 3);
  }
  const multiplier = m.mode === "wordle" ? 1 : {easy: 1, medium: 1.5, expert: 4}[m.difficulty];
  return Math.trunc(base * multiplier);
}

function matchCoins(m, uid, winnerID, botAvailable) {
  const result = m.playerResults[uid];
  if (m.forfeitedIDs.includes(uid) || isForfeit(result)) return 0;
  if (m.forfeitedIDs.length && !(winnerID === uid && result?.completed && finalResult(result))) return 0;
  if (m.players.some((p) => p.isBot) && !(winnerID === uid && botAvailable)) return 0;
  if (m.matchKind === "casual") return winnerID === uid ? 15 : 5;
  return winnerID === uid ? wins[tier(m.players.find((p) => p.userID === uid).rankPoints)] : winnerID === null ? 10 : 5;
}

function onlineBest(current, r, mode) {
  if (!r || isForfeit(r)) return current;
  const result = {...current};
  const update = (key, value, minimize) => {
    if (value !== undefined) result[key] = result[key] === undefined ? value : (minimize ? Math.min : Math.max)(result[key], value);
  };
  update("time", r.completed ? r.elapsedSeconds : undefined, true);
  update("score", ["anagram", "wordHunt", "gridlock"].includes(mode) ? r.score : undefined, false);
  update("moves", stat(r, "moves") > 0 ? stat(r, "moves") : undefined, true);
  update("progress", r.progress > 0 ? r.progress : undefined, false);
  update("guesses", mode === "wordle" && stat(r, "totalGuesses") > 0 ? stat(r, "totalGuesses") : undefined, true);
  return result;
}

module.exports = {presets, validateMatch, resolveMatch, rankDelta, matchCoins, onlineBest, tier, isForfeit};
