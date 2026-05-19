import Foundation

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

    static func make(mode: GameMode, tier: RankTier, date: Date = Date()) -> DailyTournament {
        let dayKey = CoinWallet.todayKey(date: date)
        let difficulty = mode.rankedDifficulties.first ?? mode.defaultDifficulty
        let id = "daily_\(dayKey)_\(tier.rawValue)_\(mode.rawValue)"
        let seed = stableSeed(from: id)
        return DailyTournament(
            id: id,
            dayKey: dayKey,
            mode: mode,
            difficulty: difficulty,
            rankTier: tier,
            entryFee: Wager.tournamentEntryFee(for: tier),
            seed: seed,
            puzzleData: MultiplayerPuzzleDataFactory.encoded(mode: mode, difficulty: difficulty, seed: seed),
            createdAt: date,
            closesAt: endOfUTCDay(for: date)
        )
    }

    private static func endOfUTCDay(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? date.addingTimeInterval(86_400)
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
        let wordCount = result.stats.first(where: { $0.label == "Words" })?.value.flatMap(Int.init)
        let longestWord = result.stats.first(where: { $0.label == "Longest" })?.value.flatMap(Int.init)
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
        case .gridlock:
            if lhs.completed != rhs.completed { return lhs.completed }
            if lhs.completed, (lhs.moves ?? Int.max) != (rhs.moves ?? Int.max) { return (lhs.moves ?? Int.max) < (rhs.moves ?? Int.max) }
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
