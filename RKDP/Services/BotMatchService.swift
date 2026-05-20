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
        case .hangman:
            return 91
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
            isBot: true,
            avatarStyle: AvatarStyle(head: "avatar_head_headphones", face: "avatar_face_focused", outfit: "avatar_outfit_hoodie", aura: "avatar_aura_teal", pose: "avatar_pose_ready")
        )
    }

    static func makeResult(for session: GameSession, bot: MatchPlayer, elapsedSeconds: Int) -> MatchPlayerResult {
        var rng = SeededRNG(seed: session.seed ^ bot.userID.hashValue ^ 0xB07)
        let strongBot = int(in: 0...99, rng: &rng) >= 82
        switch session.mode {
        case .wordle:
            return wordleResult(session: session, bot: bot, strongBot: strongBot, elapsedSeconds: elapsedSeconds, rng: &rng)
        case .anagram:
            return wordScoreResult(mode: .anagram, session: session, bot: bot, strongBot: strongBot, elapsedSeconds: 60, rng: &rng)
        case .wordHunt:
            return wordScoreResult(mode: .wordHunt, session: session, bot: bot, strongBot: strongBot, elapsedSeconds: 75, rng: &rng)
        case .hangman:
            return hangmanResult(session: session, bot: bot, strongBot: strongBot, elapsedSeconds: elapsedSeconds, rng: &rng)
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

    private static func hangmanResult(session: GameSession, bot: MatchPlayer, strongBot: Bool, elapsedSeconds: Int, rng: inout SeededRNG) -> MatchPlayerResult {
        let puzzle = MultiplayerPuzzleDataFactory.decodeHangman(session.puzzleData)
        let target = HangmanGame.targetWord(difficulty: session.difficulty, seed: session.seed, puzzleData: puzzle)
        let uniqueLetters = Set(target).map(String.init).sorted().compactMap { $0.first }
        let solved = strongBot
        let maxWrong = puzzle?.maxWrongGuesses ?? 6
        let wrongCount = solved ? int(in: 0...2, rng: &rng) : int(in: 3...maxWrong, rng: &rng)
        let revealedCount = solved ? uniqueLetters.count : min(uniqueLetters.count - 1, int(in: 1...max(1, min(4, uniqueLetters.count)), rng: &rng))
        let correctLetters = solved ? uniqueLetters : Array(uniqueLetters.prefix(revealedCount))
        let wrongLetters = botWrongLetters(excluding: Set(target), count: wrongCount, rng: &rng)
        let pattern = target.map { correctLetters.contains($0) ? String($0) : "_" }.joined()
        let elapsed = solved ? int(in: 42...min(88, max(42, elapsedSeconds)), rng: &rng) : elapsedSeconds

        return MatchPlayerResult(
            userID: bot.userID,
            mode: .hangman,
            completed: solved,
            elapsedSeconds: elapsed,
            score: revealedCount,
            progress: Double(revealedCount) / Double(max(1, uniqueLetters.count)),
            status: solved ? "Solved" : "Timed out",
            summary: [
                "targetWord": target,
                "correctLetters": correctLetters.map(String.init).joined(),
                "wrongLetters": wrongLetters.map(String.init).joined(),
                "wrongGuessCount": "\(wrongCount)",
                "revealedPattern": pattern,
                "revealedLetterCount": "\(revealedCount)",
                "maxWrongGuesses": "\(maxWrong)",
                "solved": solved ? "true" : "false",
                "botResult": "true"
            ],
            details: [
                "Word: \(target)",
                "Pattern: \(pattern.map { $0 == "_" ? "_" : String($0) }.joined(separator: " "))",
                "Wrong guesses: \(wrongLetters.map(String.init).joined(separator: ", "))"
            ]
        )
    }

    private static func botWrongLetters(excluding targetLetters: Set<Character>, count: Int, rng: inout SeededRNG) -> [Character] {
        var pool = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").filter { !targetLetters.contains($0) }
        pool = shuffledWords(pool.map(String.init), rng: &rng).compactMap { $0.first }
        return Array(pool.prefix(count))
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

    private static func wordScoreResult(mode: GameMode, session: GameSession, bot: MatchPlayer, strongBot: Bool, elapsedSeconds: Int, rng: inout SeededRNG) -> MatchPlayerResult {
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

        let selectedWords = botWords(
            mode: mode,
            session: session,
            wordCountRange: wordCountRange,
            scoreRange: scoreRange,
            longestRange: longestRange,
            rng: &rng
        )
        let score = selectedWords.reduce(0) { $0 + wordScore(mode: mode, word: $1) }
        let wordCount = selectedWords.count
        let longest = selectedWords.map(\.count).max() ?? longestRange.lowerBound
        let details = selectedWords.isEmpty
            ? ["Training bot found 0 words."]
            : selectedWords.prefix(50).map { "\($0.capitalized) (+\(wordScore(mode: mode, word: $0)))" }
        let averageLength = selectedWords.isEmpty ? "-" : String(format: "%.1f", Double(selectedWords.reduce(0) { $0 + $1.count }) / Double(selectedWords.count))

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
                "averageWordLength": averageLength,
                "topWord": selectedWords.first ?? "",
                "wordsByLength": wordsByLength(selectedWords),
                "foundWords": selectedWords.prefix(80).joined(separator: "|"),
                "botResult": "true"
            ],
            details: details
        )
    }


    private static func wordsByLength(_ words: [String]) -> String {
        Dictionary(grouping: words, by: { $0.count })
            .map { "\($0.key):\($0.value.count)" }
            .sorted()
            .joined(separator: ",")
    }

    private static func botWords(
        mode: GameMode,
        session: GameSession,
        wordCountRange: ClosedRange<Int>,
        scoreRange: ClosedRange<Int>,
        longestRange: ClosedRange<Int>,
        rng: inout SeededRNG
    ) -> [String] {
        let candidates = botWordCandidates(mode: mode, session: session)
            .filter { longestRange.contains($0.count) || $0.count < longestRange.lowerBound }
            .sorted { lhs, rhs in
                if wordScore(mode: mode, word: lhs) == wordScore(mode: mode, word: rhs) { return lhs < rhs }
                return wordScore(mode: mode, word: lhs) < wordScore(mode: mode, word: rhs)
            }
        guard !candidates.isEmpty else { return [] }

        for _ in 0..<80 {
            let desiredCount = int(in: wordCountRange, rng: &rng)
            let shuffled = shuffledWords(candidates, rng: &rng)
            var chosen: [String] = []
            var total = 0

            for word in shuffled {
                guard chosen.count < desiredCount else { break }
                let points = wordScore(mode: mode, word: word)
                if total + points <= scoreRange.upperBound {
                    chosen.append(word)
                    total += points
                }
            }

            let longest = chosen.map(\.count).max() ?? 0
            if chosen.count == desiredCount,
               scoreRange.contains(total),
               longestRange.contains(longest) {
                return chosen.sorted { wordScore(mode: mode, word: $0) > wordScore(mode: mode, word: $1) }
            }
        }

        var fallback: [String] = []
        var total = 0
        for word in candidates where fallback.count < wordCountRange.upperBound {
            let points = wordScore(mode: mode, word: word)
            guard total + points <= scoreRange.upperBound else { continue }
            fallback.append(word)
            total += points
            if fallback.count >= wordCountRange.lowerBound, total >= scoreRange.lowerBound { break }
        }
        return fallback.sorted { wordScore(mode: mode, word: $0) > wordScore(mode: mode, word: $1) }
    }

    private static func botWordCandidates(mode: GameMode, session: GameSession) -> [String] {
        switch mode {
        case .anagram:
            let puzzle = MultiplayerPuzzleDataFactory.decodeAnagram(session.puzzleData)
            return Array(AnagramGame.generate(difficulty: session.difficulty, seed: session.seed, puzzleData: puzzle).validWords)
        case .wordHunt:
            if let puzzle = MultiplayerPuzzleDataFactory.decodeWordHunt(session.puzzleData), !puzzle.gridRows.isEmpty {
                let grid = puzzle.gridRows.map { Array($0.uppercased()) }
                return Array(WordHuntGame(grid: grid, seed: session.seed).validWords)
            }
            return Array(WordHuntGame.generate(difficulty: session.difficulty, seed: session.seed).validWords)
        default:
            return []
        }
    }

    private static func shuffledWords(_ words: [String], rng: inout SeededRNG) -> [String] {
        var output = words
        guard output.count > 1 else { return output }
        for index in stride(from: output.count - 1, through: 1, by: -1) {
            let swapIndex = int(in: 0...index, rng: &rng)
            if index != swapIndex { output.swapAt(index, swapIndex) }
        }
        return output
    }

    private static func wordScore(mode: GameMode, word: String) -> Int {
        switch mode {
        case .anagram: return AnagramGame.score(for: word)
        case .wordHunt: return WordHuntGame.score(for: word)
        default: return 0
        }
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
            status: completed ? "Pattern matched" : "\(Int(progress * 100))% pattern match",
            summary: ["moves": "\(moves)", "botResult": "true"],
            details: ["Moves: \(moves)", "Pattern: \(Int(progress * 100))%"]
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
        case .hangman: return 90
        }
    }
}
