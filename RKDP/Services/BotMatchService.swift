import Foundation

enum BotMatchService {
    static let botIDPrefix = "bot_"

    static func canOfferBot(to user: AppUser, mode: GameMode) -> Bool {
        user.rank(for: mode).displayTier == .bronze && user.botMatchProgress.rewardedWinsRemaining() > 0
    }

    static func fallbackDelaySeconds(seed: Int = Int.random(in: 0..<Int.max)) -> Int {
        var rng = SeededRNG(seed: seed)
        let humanOnlyWait = int(in: 8...14, rng: &rng)
        let botFillWait = int(in: 2...5, rng: &rng)
        return humanOnlyWait + botFillWait
    }

    static func resultDelaySeconds(for session: GameSession) -> Int {
        switch session.mode {
        case .anagram:
            return 61
        case .wordHunt:
            return 76
        case .wordle:
            return 35
        case .sudoku:
            return 55
        case .minesweeper:
            return 42
        case .gridlock, .colorLink:
            return 48
        }
    }

    static func makeBotPlayer(mode: GameMode, wager: Int, searchID: String, seed: Int) -> MatchPlayer {
        var rng = SeededRNG(seed: seed)
        let names = ["RookieBot", "Grid Rookie", "Bronze Buddy", "Puzzle Pal", "Training Bot"]
        let name = names[int(in: 0...(names.count - 1), rng: &rng)]
        let cleanSearch = searchID.replacingOccurrences(of: "-", with: "").prefix(10)
        return MatchPlayer(
            userID: "\(botIDPrefix)\(mode.rawValue)_\(cleanSearch)",
            username: name,
            wager: wager,
            rankTier: .bronze,
            rankPoints: int(in: 40...420, rng: &rng),
            isBot: true
        )
    }

    static func makeResult(for session: GameSession, bot: MatchPlayer, elapsedSeconds: Int) -> MatchPlayerResult {
        var rng = SeededRNG(seed: session.seed ^ bot.userID.hashValue ^ 0xB07)
        let strongBot = int(in: 0...99, rng: &rng) >= 82
        switch session.mode {
        case .wordle:
            return wordleResult(session: session, bot: bot, strongBot: strongBot, elapsedSeconds: elapsedSeconds, rng: &rng)
        case .anagram:
            return wordScoreResult(mode: .anagram, bot: bot, strongBot: strongBot, elapsedSeconds: 60, rng: &rng)
        case .wordHunt:
            return wordScoreResult(mode: .wordHunt, bot: bot, strongBot: strongBot, elapsedSeconds: 75, rng: &rng)
        case .sudoku:
            return completionResult(mode: .sudoku, bot: bot, strongBot: strongBot, elapsedSeconds: elapsedSeconds, rng: &rng)
        case .gridlock:
            return gridDuelResult(bot: bot, strongBot: strongBot, elapsedSeconds: elapsedSeconds, rng: &rng)
        case .colorLink:
            return colorLinkResult(bot: bot, strongBot: strongBot, elapsedSeconds: elapsedSeconds, rng: &rng)
        case .minesweeper:
            return minesweeperResult(bot: bot, strongBot: strongBot, elapsedSeconds: elapsedSeconds, rng: &rng)
        }
    }

    private static func wordleResult(session: GameSession, bot: MatchPlayer, strongBot: Bool, elapsedSeconds: Int, rng: inout SeededRNG) -> MatchPlayerResult {
        let targets = MultiplayerPuzzleDataFactory.decodeWordle(session.puzzleData)?.targets ?? (0..<3).map { WordleGame.targetWord(seed: session.seed, round: $0) }
        let solvedTarget = strongBot ? 2 : int(in: 0...1, rng: &rng)
        var summary: [String: String] = [
            "solvedRounds": "\(solvedTarget)",
            "failedRounds": "\(max(0, 3 - solvedTarget))",
            "roundCount": "3",
            "maxGuesses": "\(wordleGuessLimit(for: session.difficulty))",
            "isFinal": "true",
            "botResult": "true"
        ]
        var details: [String] = []
        var totalSolvedGuesses = 0

        for roundIndex in 0..<3 {
            let target = targets.indices.contains(roundIndex) ? targets[roundIndex].uppercased() : WordleGame.targetWord(seed: session.seed, round: roundIndex)
            let solved = roundIndex < solvedTarget
            let guessCount = solved ? int(in: (strongBot ? 3 : 4)...min(6, wordleGuessLimit(for: session.difficulty)), rng: &rng) : wordleGuessLimit(for: session.difficulty)
            let encodedGuesses = encodedWordleGuesses(target: target, guessCount: guessCount, solved: solved, rng: &rng)
            if solved { totalSolvedGuesses += guessCount }
            let round = roundIndex + 1
            summary["round\(round)Target"] = target
            summary["round\(round)Solved"] = solved ? "true" : "false"
            summary["round\(round)GuessCount"] = "\(guessCount)"
            summary["round\(round)Guesses"] = encodedGuesses
            details.append(solved ? "Round \(round): \(target) in \(guessCount)" : "Round \(round): \(target) failed")
        }
        summary["totalGuesses"] = "\(totalSolvedGuesses)"

        return MatchPlayerResult(
            userID: bot.userID,
            mode: .wordle,
            completed: solvedTarget >= 2,
            elapsedSeconds: elapsedSeconds,
            score: solvedTarget,
            progress: Double(solvedTarget) / 3.0,
            status: "\(solvedTarget)/3 solved",
            summary: summary,
            details: details
        )
    }

    private static func wordScoreResult(mode: GameMode, bot: MatchPlayer, strongBot: Bool, elapsedSeconds: Int, rng: inout SeededRNG) -> MatchPlayerResult {
        let scoreRange: ClosedRange<Int>
        let wordCountRange: ClosedRange<Int>
        let longestRange: ClosedRange<Int>
        switch mode {
        case .anagram:
            scoreRange = strongBot ? 7...13 : 1...5
            wordCountRange = strongBot ? 4...7 : 1...4
            longestRange = strongBot ? 4...6 : 3...5
        case .wordHunt:
            scoreRange = strongBot ? 8...15 : 2...6
            wordCountRange = strongBot ? 5...9 : 2...5
            longestRange = strongBot ? 4...7 : 3...5
        default:
            scoreRange = strongBot ? 7...13 : 1...5
            wordCountRange = strongBot ? 4...7 : 1...4
            longestRange = strongBot ? 4...6 : 3...5
        }
        let score = int(in: scoreRange, rng: &rng)
        let wordCount = int(in: wordCountRange, rng: &rng)
        let longest = int(in: longestRange, rng: &rng)
        return MatchPlayerResult(
            userID: bot.userID,
            mode: mode,
            completed: true,
            elapsedSeconds: elapsedSeconds,
            score: score,
            progress: 1,
            status: "Score \(score)",
            summary: [
                "wordCount": "\(wordCount)",
                "longestWordLength": "\(longest)",
                "botResult": "true"
            ],
            details: ["Training bot found \(wordCount) words.", "Longest word length: \(longest)."]
        )
    }

    private static func completionResult(mode: GameMode, bot: MatchPlayer, strongBot: Bool, elapsedSeconds: Int, rng: inout SeededRNG) -> MatchPlayerResult {
        let completed = strongBot
        let progress = completed ? 1.0 : Double(int(in: 42...78, rng: &rng)) / 100.0
        return MatchPlayerResult(
            userID: bot.userID,
            mode: mode,
            completed: completed,
            elapsedSeconds: completed ? elapsedSeconds : sessionLikeTimeout(mode: mode),
            score: Int((progress * 100).rounded()),
            progress: progress,
            status: completed ? "Completed" : "\(Int(progress * 100))% progress",
            summary: ["botResult": "true"],
            details: [completed ? "Training bot completed the puzzle." : "Training bot timed out with partial progress."]
        )
    }

    private static func gridDuelResult(bot: MatchPlayer, strongBot: Bool, elapsedSeconds: Int, rng: inout SeededRNG) -> MatchPlayerResult {
        let completed = strongBot
        let progress = completed ? 1.0 : Double(int(in: 45...84, rng: &rng)) / 100.0
        let moves = completed ? int(in: 18...42, rng: &rng) : int(in: 24...58, rng: &rng)
        return MatchPlayerResult(
            userID: bot.userID,
            mode: .gridlock,
            completed: completed,
            elapsedSeconds: elapsedSeconds,
            score: Int((progress * 100).rounded()),
            progress: progress,
            status: completed ? "Symmetry solved" : "\(Int(progress * 100))% symmetry",
            summary: ["moves": "\(moves)", "botResult": "true"],
            details: ["Moves: \(moves)", "Symmetry: \(Int(progress * 100))%"]
        )
    }

    private static func colorLinkResult(bot: MatchPlayer, strongBot: Bool, elapsedSeconds: Int, rng: inout SeededRNG) -> MatchPlayerResult {
        let completed = strongBot
        let progress = completed ? 1.0 : Double(int(in: 48...86, rng: &rng)) / 100.0
        let pairs = completed ? int(in: 5...7, rng: &rng) : int(in: 2...5, rng: &rng)
        return MatchPlayerResult(
            userID: bot.userID,
            mode: .colorLink,
            completed: completed,
            elapsedSeconds: elapsedSeconds,
            score: Int((progress * 100).rounded()),
            progress: progress,
            status: completed ? "Board filled" : "\(Int(progress * 100))% filled",
            summary: ["solvedPairs": "\(pairs)", "botResult": "true"],
            details: ["Board fill: \(Int(progress * 100))%", "Pairs connected: \(pairs)"]
        )
    }

    private static func minesweeperResult(bot: MatchPlayer, strongBot: Bool, elapsedSeconds: Int, rng: inout SeededRNG) -> MatchPlayerResult {
        let hitMine = !strongBot && int(in: 0...99, rng: &rng) < 45
        let completed = strongBot && int(in: 0...99, rng: &rng) < 45
        let safeCells = completed ? int(in: 54...70, rng: &rng) : int(in: 18...48, rng: &rng)
        return MatchPlayerResult(
            userID: bot.userID,
            mode: .minesweeper,
            completed: completed,
            elapsedSeconds: elapsedSeconds,
            score: safeCells,
            progress: completed ? 1 : Double(safeCells) / 70.0,
            status: hitMine ? "Hit a mine" : (completed ? "Cleared" : "\(safeCells) safe cells"),
            summary: ["hitMine": hitMine ? "true" : "false", "botResult": "true"],
            details: [hitMine ? "Training bot hit a mine." : "Training bot revealed \(safeCells) safe cells."]
        )
    }

    private static func encodedWordleGuesses(target: String, guessCount: Int, solved: Bool, rng: inout SeededRNG) -> String {
        let target = target.uppercased()
        let candidates = WordListService.wordleAnswers.filter { $0 != target }
        let game = WordleGame(seed: 0, round: 0, targetWords: [target])
        var guesses: [String] = []
        for _ in 0..<max(0, guessCount - (solved ? 1 : 0)) {
            let fallback = candidates.isEmpty ? "CROWN" : candidates[int(in: 0...(candidates.count - 1), rng: &rng)]
            guesses.append(fallback == target ? "BLOCK" : fallback)
        }
        if solved { guesses.append(target) }
        return guesses.prefix(guessCount).map { guess in
            let results = game.evaluate(guess: guess).map { result -> String in
                switch result {
                case .correct: return "C"
                case .present: return "P"
                case .absent: return "A"
                }
            }.joined()
            return "\(guess):\(results)"
        }.joined(separator: ";")
    }


    private static func wordleGuessLimit(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 7
        case .medium: return 6
        case .hard: return 5
        case .expert: return 4
        }
    }

    private static func int(in range: ClosedRange<Int>, rng: inout SeededRNG) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(rng.next() % span)
    }

    private static func sessionLikeTimeout(mode: GameMode) -> Int {
        switch mode {
        case .sudoku: return 720
        case .gridlock, .colorLink: return 300
        case .minesweeper: return 240
        case .wordle, .anagram, .wordHunt: return 75
        }
    }
}
