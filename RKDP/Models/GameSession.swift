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
}

struct GameSession: Codable, Identifiable {
    var id: String
    var mode: GameMode
    var difficulty: Difficulty
    var status: SessionStatus
    var players: [MatchPlayer]
    var puzzleData: String      // JSON-encoded puzzle snapshot
    var createdAt: Date
    var startedAt: Date?
    var finishedAt: Date?
    var winnerID: String?

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
        return Int(Double(base) * difficulty.pointMultiplier)
    }
}
