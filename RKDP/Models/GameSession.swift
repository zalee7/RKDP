import Foundation

enum SessionStatus: String, Codable {
    case waiting      // in lobby, waiting for opponent
    case inProgress
    case finished
    case abandoned
}

enum SessionResult: String, Codable {
    case win
    case loss
    case draw
    case abandoned
}

struct MatchPlayer: Codable {
    var userID: String
    var username: String
    var wager: Int
    var finishTime: Int?    // seconds from puzzle start; nil = not finished
    var rankTier: RankTier
    var rankPoints: Int = 0
}

struct MatchPlayerResult: Codable, Equatable {
    var userID: String
    var mode: GameMode
    var completed: Bool
    var elapsedSeconds: Int
    var score: Int
    var progress: Double
    var status: String
    var summary: [String: String]
    var details: [String]

    var longestWordLength: Int { Int(summary["longestWordLength"] ?? "0") ?? 0 }
    var wordCount: Int { Int(summary["wordCount"] ?? "0") ?? 0 }
    var solvedRounds: Int { Int(summary["solvedRounds"] ?? "0") ?? 0 }
    var totalGuesses: Int { Int(summary["totalGuesses"] ?? "0") ?? 0 }
    var hitMine: Bool { summary["hitMine"] == "true" }
    var moveCount: Int { Int(summary["moves"] ?? "0") ?? 0 }
    var solvedPairs: Int { Int(summary["solvedPairs"] ?? "0") ?? 0 }

    var realtimeValue: [String: Any] {
        [
            "userID": userID,
            "mode": mode.rawValue,
            "completed": completed,
            "elapsedSeconds": elapsedSeconds,
            "score": score,
            "progress": progress,
            "status": status,
            "summary": summary,
            "details": details
        ]
    }

    static func fromRealtimeValue(_ value: Any) -> MatchPlayerResult? {
        guard let dict = value as? [String: Any],
              let userID = dict["userID"] as? String,
              let modeRaw = dict["mode"] as? String,
              let mode = GameMode(rawValue: modeRaw) else { return nil }

        let completed = dict["completed"] as? Bool ?? false
        let elapsed = dict["elapsedSeconds"] as? Int ?? 0
        let score = dict["score"] as? Int ?? 0
        let progress = dict["progress"] as? Double ?? Double(dict["progress"] as? Int ?? 0)
        let status = dict["status"] as? String ?? ""
        let rawSummary = dict["summary"] as? [String: Any] ?? [:]
        let summary = rawSummary.reduce(into: [String: String]()) { partial, item in
            partial[item.key] = "\(item.value)"
        }
        let details: [String]
        if let array = dict["details"] as? [Any] {
            details = array.compactMap { $0 as? String }
        } else if let keyed = dict["details"] as? [String: Any] {
            details = keyed.keys.sorted().compactMap { keyed[$0] as? String }
        } else {
            details = []
        }

        return MatchPlayerResult(
            userID: userID,
            mode: mode,
            completed: completed,
            elapsedSeconds: elapsed,
            score: score,
            progress: progress,
            status: status,
            summary: summary,
            details: details
        )
    }
}

struct SoloResultStat: Identifiable, Equatable {
    let id = UUID()
    var label: String
    var value: String
}

struct SoloGameResult: Identifiable, Equatable {
    let id = UUID()
    var mode: GameMode
    var difficulty: Difficulty
    var completed: Bool
    var title: String
    var message: String
    var elapsedSeconds: Int
    var score: Int? = nil
    var progress: Double? = nil
    var moves: Int? = nil
    var guesses: Int? = nil
    var stats: [SoloResultStat]
    var details: [String] = []
}

struct GameSession: Codable, Identifiable {
    var id: String
    var mode: GameMode
    var difficulty: Difficulty
    var status: SessionStatus
    var players: [MatchPlayer]
    var seed: Int               // shared puzzle seed — both players get identical puzzle
    var puzzleData: String      // JSON-encoded puzzle snapshot
    var createdAt: Date
    var startedAt: Date?
    var finishedAt: Date?
    var winnerID: String?
    var playerResults: [String: MatchPlayerResult]?
    var winnerReason: String?

    var totalPot: Int { players.reduce(0) { $0 + $1.wager } }

    func result(for userID: String) -> SessionResult? {
        guard status == .finished else { return nil }
        if let wid = winnerID { return wid == userID ? .win : .loss }
        return .draw
    }

    // Rank points awarded per outcome, scaled by difficulty and time
    func rankPointsDelta(for userID: String) -> Int {
        guard let result = result(for: userID) else { return 0 }
        let base: Int
        switch result {
        case .win:       base = 30
        case .loss:      base = -15
        case .draw:      base = 5
        case .abandoned: base = -20
        }
        return Int(Double(base) * mode.pointMultiplier(for: difficulty))
    }
}

extension Difficulty {
    func rankedTimeLimit(for mode: GameMode) -> Int {
        switch mode {
        case .sudoku:
            switch self {
            case .easy: return 600
            case .medium: return 720
            case .hard: return 900
            case .expert: return 1_200
            }
        case .gridlock:
            switch self {
            case .easy: return 300
            case .medium: return 420
            case .hard: return 600
            case .expert: return 780
            }
        case .colorLink:
            switch self {
            case .easy: return 240
            case .medium: return 300
            case .hard: return 420
            case .expert: return 540
            }
        case .minesweeper:
            switch self {
            case .easy: return 180
            case .medium: return 300
            case .hard: return 420
            case .expert: return 600
            }
        case .anagram:
            return AnagramGame.totalSeconds(for: self)
        case .wordHunt:
            switch self {
            case .easy: return 120
            case .medium: return 90
            case .hard: return 75
            case .expert: return 60
            }
        case .wordle:
            return 0
        }
    }
}
