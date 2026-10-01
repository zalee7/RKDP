import Foundation

enum DailyChallengeCategory: String, Codable, CaseIterable, Hashable, Identifiable {
    case quick
    case word
    case logic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quick: return "Quick"
        case .word: return "Word"
        case .logic: return "Logic"
        }
    }

    var icon: String {
        switch self {
        case .quick: return "bolt.fill"
        case .word: return "textformat.abc"
        case .logic: return "brain.head.profile"
        }
    }
}

struct DailyChallengeSet: Identifiable, Codable, Equatable {
    static let completionBonus = 50

    var id: String
    var dayKey: String
    var challenges: [DailyChallenge]
    var createdAt: Date

    static func today(date: Date = Date(), includePuzzleData: Bool = true) -> DailyChallengeSet {
        make(dayKey: RankedAccess.todayKey(date: date), date: date, includePuzzleData: includePuzzleData)
    }

    static func make(dayKey: String, date: Date = Date(), includePuzzleData: Bool = true) -> DailyChallengeSet {
        let challenges = GameMode.allCases.map {
            makeChallenge(mode: $0, dayKey: dayKey, includePuzzleData: includePuzzleData)
        }

        return DailyChallengeSet(
            id: dayKey,
            dayKey: dayKey,
            challenges: challenges,
            createdAt: startOfUTCDay(for: date)
        )
    }

    private static func makeChallenge(mode: GameMode, dayKey: String, includePuzzleData: Bool) -> DailyChallenge {
        let difficulty = mode.onlinePresetDifficulty
        let id = "\(dayKey)_\(mode.rawValue)"
        let seed = stableSeed(from: "daily_\(id)_\(mode.rawValue)_\(difficulty.rawValue)")
        let puzzleData = includePuzzleData ? MultiplayerPuzzleDataFactory.onlinePayload(mode: mode, difficulty: difficulty, seed: seed, context: "daily") : ""
        return DailyChallenge(
            id: id,
            dayKey: dayKey,
            category: category(for: mode),
            mode: mode,
            difficulty: difficulty,
            seed: seed,
            puzzleData: puzzleData
        )
    }

    private static func category(for mode: GameMode) -> DailyChallengeCategory {
        switch mode {
        case .colorLink, .minesweeper:
            return .quick
        case .wordle, .anagram, .wordHunt, .hangman:
            return .word
        case .gridlock, .sudoku:
            return .logic
        }
    }

    private static func startOfUTCDay(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: comps) ?? date
    }

    private static func stableSeed(from string: String) -> Int {
        var hash: UInt64 = 1469598103934665603
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int(hash % UInt64(Int.max))
    }
}

struct DailyChallenge: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var dayKey: String
    var category: DailyChallengeCategory
    var mode: GameMode
    var difficulty: Difficulty
    var seed: Int
    var puzzleData: String

    func preparedForPlay() -> DailyChallenge {
        guard puzzleData.isEmpty else { return self }
        var prepared = self
        prepared.puzzleData = MultiplayerPuzzleDataFactory.onlinePayload(mode: mode, difficulty: difficulty, seed: seed, context: "daily")
        return prepared
    }
}

struct DailyChallengeEntry: Identifiable, Codable, Equatable {
    var id: String
    var dayKey: String
    var challengeID: String
    var category: DailyChallengeCategory
    var mode: GameMode
    var difficulty: Difficulty
    var userID: String
    var username: String
    var avatarStyle: AvatarStyle
    var submittedAt: Date
    var result: DailyChallengeResult
}

struct DailyChallengeResult: Codable, Equatable {
    var completed: Bool
    var elapsedSeconds: Int
    var score: Int
    var progress: Double
    var moves: Int?
    var guesses: Int?
    var wordCount: Int?
    var longestWord: Int?
    var title: String

    static func fromSoloResult(_ result: SoloGameResult) -> DailyChallengeResult {
        let tournamentResult = TournamentResult.fromSoloResult(result)
        return DailyChallengeResult(
            completed: tournamentResult.completed,
            elapsedSeconds: tournamentResult.elapsedSeconds,
            score: tournamentResult.score,
            progress: tournamentResult.progress,
            moves: tournamentResult.moves,
            guesses: tournamentResult.guesses,
            wordCount: tournamentResult.wordCount,
            longestWord: tournamentResult.longestWord,
            title: result.title
        )
    }

    var tournamentResult: TournamentResult {
        TournamentResult(
            completed: completed,
            elapsedSeconds: elapsedSeconds,
            score: score,
            progress: progress,
            moves: moves,
            guesses: guesses,
            wordCount: wordCount,
            longestWord: longestWord
        )
    }
}

enum DailyChallengeScoring {
    static func sortedEntries(_ entries: [DailyChallengeEntry], mode: GameMode) -> [DailyChallengeEntry] {
        entries.sorted { lhs, rhs in
            TournamentScoring.compare(lhs.result.tournamentResult, rhs.result.tournamentResult, mode: mode)
        }
    }
}

struct DailyTournament: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var dayKey: String
    var mode: GameMode
    var difficulty: Difficulty
    var rankTier: RankTier
    var entryFee: Int
    var seed: Int
    var puzzleData: String
    var createdAt: Date
    var closesAt: Date

    var isClosed: Bool { Date() >= closesAt }

    static func make(mode: GameMode, tier: RankTier, date: Date = Date(), includePuzzleData: Bool = true) -> DailyTournament {
        let hourKey = utcHourKey(for: date)
        let difficulty = mode.rankedDifficulties.first ?? mode.defaultDifficulty
        let id = "hourly_\(hourKey)_\(tier.rawValue)_\(mode.rawValue)"
        let seed = stableSeed(from: id)
        let puzzleData = includePuzzleData ? MultiplayerPuzzleDataFactory.onlinePayload(mode: mode, difficulty: difficulty, seed: seed, context: "tournament") : ""
        return DailyTournament(
            id: id,
            dayKey: hourKey,
            mode: mode,
            difficulty: difficulty,
            rankTier: tier,
            entryFee: Wager.tournamentEntryFee(for: tier),
            seed: seed,
            puzzleData: puzzleData,
            createdAt: startOfUTCHour(for: date),
            closesAt: nextUTCHour(after: date)
        )
    }

    static func previous(mode: GameMode, tier: RankTier, date: Date = Date(), includePuzzleData: Bool = true) -> DailyTournament {
        make(mode: mode, tier: tier, date: date.addingTimeInterval(-3_600), includePuzzleData: includePuzzleData)
    }

    func preparedForPlay() -> DailyTournament {
        guard puzzleData.isEmpty else { return self }
        var prepared = self
        prepared.puzzleData = MultiplayerPuzzleDataFactory.onlinePayload(mode: mode, difficulty: difficulty, seed: seed, context: "tournament")
        return prepared
    }

    static func utcHourKey(for date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return String(format: "%04d-%02d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0, comps.hour ?? 0)
    }

    private static func startOfUTCHour(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return calendar.date(from: comps) ?? date
    }

    private static func nextUTCHour(after date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let start = startOfUTCHour(for: date)
        return calendar.date(byAdding: .hour, value: 1, to: start) ?? date.addingTimeInterval(3_600)
    }

    private static func stableSeed(from string: String) -> Int {
        var hash: UInt64 = 1469598103934665603
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int(hash % UInt64(Int.max))
    }
}

struct TournamentEntry: Identifiable, Codable, Equatable {
    var id: String
    var tournamentID: String
    var userID: String
    var username: String
    var rankTier: RankTier
    var enteredAt: Date
    var result: TournamentResult?
    var prizeClaimed: Bool = false
    var prizeAmount: Int = 0
}

struct TournamentResult: Codable, Equatable {
    var completed: Bool
    var elapsedSeconds: Int
    var score: Int
    var progress: Double
    var moves: Int?
    var guesses: Int?
    var wordCount: Int?
    var longestWord: Int?

    static func fromSoloResult(_ result: SoloGameResult) -> TournamentResult {
        let wordCountText = result.stats.first(where: { $0.label == "Words" })?.value
        let longestWordText = result.stats.first(where: { $0.label == "Longest" })?.value
        let wordCount = wordCountText.flatMap { Int($0) }
        let longestWord = longestWordText.flatMap { Int($0) }
        return TournamentResult(
            completed: result.completed,
            elapsedSeconds: result.elapsedSeconds,
            score: result.score ?? (result.completed ? 1 : 0),
            progress: result.progress ?? (result.completed ? 1 : 0),
            moves: result.moves,
            guesses: result.guesses,
            wordCount: wordCount,
            longestWord: longestWord
        )
    }
}

struct TournamentPrizePreview {
    var place: Int?
    var prize: Int
    var paidPlaces: Int
}

enum TournamentScoring {
    static func sortedEntries(_ entries: [TournamentEntry], mode: GameMode) -> [TournamentEntry] {
        entries.sorted { lhs, rhs in
            compare(lhs.result, rhs.result, mode: mode)
        }
    }

    static func compare(_ lhs: TournamentResult?, _ rhs: TournamentResult?, mode: GameMode) -> Bool {
        guard let lhs else { return false }
        guard let rhs else { return true }
        switch mode {
        case .anagram, .wordHunt:
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if (lhs.wordCount ?? 0) != (rhs.wordCount ?? 0) { return (lhs.wordCount ?? 0) > (rhs.wordCount ?? 0) }
            if (lhs.longestWord ?? 0) != (rhs.longestWord ?? 0) { return (lhs.longestWord ?? 0) > (rhs.longestWord ?? 0) }
            return lhs.elapsedSeconds < rhs.elapsedSeconds
        case .wordle:
            if lhs.completed != rhs.completed { return lhs.completed }
            if (lhs.guesses ?? Int.max) != (rhs.guesses ?? Int.max) { return (lhs.guesses ?? Int.max) < (rhs.guesses ?? Int.max) }
            return lhs.elapsedSeconds < rhs.elapsedSeconds
        case .hangman:
            if lhs.completed != rhs.completed { return lhs.completed }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.elapsedSeconds < rhs.elapsedSeconds
        case .gridlock:
            if lhs.completed != rhs.completed { return lhs.completed }
            if lhs.completed, (lhs.moves ?? Int.max) != (rhs.moves ?? Int.max) { return (lhs.moves ?? Int.max) < (rhs.moves ?? Int.max) }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.progress != rhs.progress { return lhs.progress > rhs.progress }
            return lhs.elapsedSeconds < rhs.elapsedSeconds
        default:
            if lhs.completed != rhs.completed { return lhs.completed }
            if lhs.progress != rhs.progress { return lhs.progress > rhs.progress }
            return lhs.elapsedSeconds < rhs.elapsedSeconds
        }
    }

    static func prize(for place: Int, entryCount: Int, entryFee: Int) -> Int {
        let paidPlaces = max(1, Int(ceil(Double(entryCount) * 0.30)))
        guard place <= paidPlaces else { return 0 }
        let pool = Int((Double(entryCount * entryFee) * 0.90).rounded(.down))
        guard paidPlaces > 1 else { return pool }
        guard paidPlaces > 2 else { return place == 1 ? Int(Double(pool) * 0.65) : pool - Int(Double(pool) * 0.65) }
        switch place {
        case 1: return Int(Double(pool) * 0.50)
        case 2: return Int(Double(pool) * 0.25)
        case 3: return Int(Double(pool) * 0.15)
        default:
            let remaining = pool - Int(Double(pool) * 0.90)
            return max(0, remaining / max(1, paidPlaces - 3))
        }
    }

    static func paidPlaces(entryCount: Int) -> Int {
        max(1, Int(ceil(Double(entryCount) * 0.30)))
    }
}
