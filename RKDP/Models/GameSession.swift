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

enum SessionKind: String, Codable {
    case ranked
    case exhibition
}

struct PostMatchRewardSnapshot {
    var sessionID: String
    var startingCoins: Int
    var endingCoins: Int
    var coinDelta: Int
    var startingRank: RankInfo
    var endingRank: RankInfo
    var rankDelta: Int
    var didPromote: Bool
    var didDemote: Bool
    var mode: GameMode
    var difficulty: Difficulty
    var outcome: SessionResult
    var shouldAnimate: Bool

    static func make(
        session: GameSession,
        userID: String,
        before: AppUser,
        after: AppUser,
        didApplyRewards: Bool
    ) -> PostMatchRewardSnapshot {
        let startingRank = before.rank(for: session.mode)
        let endingRank = after.rank(for: session.mode)
        let startingPosition = rankPosition(startingRank)
        let endingPosition = rankPosition(endingRank)
        let outcome = session.result(for: userID) ?? .draw
        return PostMatchRewardSnapshot(
            sessionID: session.id,
            startingCoins: before.coins,
            endingCoins: after.coins,
            coinDelta: after.coins - before.coins,
            startingRank: startingRank,
            endingRank: endingRank,
            rankDelta: endingRank.points - startingRank.points,
            didPromote: endingPosition > startingPosition,
            didDemote: endingPosition < startingPosition,
            mode: session.mode,
            difficulty: session.difficulty,
            outcome: outcome,
            shouldAnimate: didApplyRewards
        )
    }

    static func staticSnapshot(session: GameSession, user: AppUser) -> PostMatchRewardSnapshot {
        let rank = user.rank(for: session.mode)
        let outcome = session.result(for: user.id) ?? .draw
        let wager = session.players.first(where: { $0.userID == user.id })?.wager ?? 0
        let opponentWager = session.players.first(where: { $0.userID != user.id })?.wager ?? wager
        let coinDelta: Int
        switch outcome {
        case .win: coinDelta = session.isRanked ? opponentWager : 0
        case .loss, .abandoned: coinDelta = session.isRanked ? -wager : 0
        case .draw: coinDelta = 0
        }
        return PostMatchRewardSnapshot(
            sessionID: session.id,
            startingCoins: user.coins,
            endingCoins: user.coins,
            coinDelta: coinDelta,
            startingRank: rank,
            endingRank: rank,
            rankDelta: session.isRanked ? RankingService.rankDelta(
                for: user.id,
                mode: session.mode,
                difficulty: session.difficulty,
                winnerID: session.winnerID,
                players: session.players
            ) : 0,
            didPromote: false,
            didDemote: false,
            mode: session.mode,
            difficulty: session.difficulty,
            outcome: outcome,
            shouldAnimate: false
        )
    }

    private static func rankPosition(_ rank: RankInfo) -> Int {
        rank.displayTier.rawValue * 3 + rank.division.rawValue
    }
}

struct MatchPlayer: Codable {
    var userID: String
    var username: String
    var wager: Int
    var finishTime: Int?    // seconds from puzzle start; nil = not finished
    var rankTier: RankTier
    var rankPoints: Int = 0
    var isBot: Bool = false

    init(userID: String, username: String, wager: Int, finishTime: Int? = nil, rankTier: RankTier, rankPoints: Int = 0, isBot: Bool = false) {
        self.userID = userID
        self.username = username
        self.wager = wager
        self.finishTime = finishTime
        self.rankTier = rankTier
        self.rankPoints = rankPoints
        self.isBot = isBot
    }

    enum CodingKeys: String, CodingKey {
        case userID, username, wager, finishTime, rankTier, rankPoints, isBot
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(String.self, forKey: .userID)
        username = try c.decode(String.self, forKey: .username)
        wager = try c.decode(Int.self, forKey: .wager)
        finishTime = try c.decodeIfPresent(Int.self, forKey: .finishTime)
        rankTier = try c.decode(RankTier.self, forKey: .rankTier)
        rankPoints = try c.decodeIfPresent(Int.self, forKey: .rankPoints) ?? 0
        isBot = try c.decodeIfPresent(Bool.self, forKey: .isBot) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userID, forKey: .userID)
        try c.encode(username, forKey: .username)
        try c.encode(wager, forKey: .wager)
        try c.encodeIfPresent(finishTime, forKey: .finishTime)
        try c.encode(rankTier, forKey: .rankTier)
        try c.encode(rankPoints, forKey: .rankPoints)
        try c.encode(isBot, forKey: .isBot)
    }
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
    var failedRounds: Int { Int(summary["failedRounds"] ?? "0") ?? 0 }
    var wordleRoundCount: Int { Int(summary["roundCount"] ?? "0") ?? 0 }
    var isFinalWordleResult: Bool {
        guard mode == .wordle else { return true }
        return summary["isFinal"] == "true" || solvedRounds >= 2 || failedRounds >= 2 || wordleRoundCount >= 3
    }
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
    var playerIDs: [String]? = nil
    var seed: Int               // shared puzzle seed — both players get identical puzzle
    var puzzleData: String      // JSON-encoded puzzle snapshot
    var createdAt: Date
    var startedAt: Date?
    var finishedAt: Date?
    var winnerID: String?
    var playerResults: [String: MatchPlayerResult]?
    var winnerReason: String?
    var matchKind: SessionKind = .ranked

    var totalPot: Int { players.reduce(0) { $0 + $1.wager } }
    var isRanked: Bool { matchKind == .ranked }
    var isExhibition: Bool { matchKind == .exhibition }
    var containsBot: Bool { players.contains(where: \.isBot) }
    var botPlayer: MatchPlayer? { players.first(where: \.isBot) }

    func result(for userID: String) -> SessionResult? {
        guard status == .finished else { return nil }
        if let wid = winnerID { return wid == userID ? .win : .loss }
        return .draw
    }

    // Rank points awarded per outcome, scaled by difficulty and time
    func rankPointsDelta(for userID: String) -> Int {
        guard isRanked, let result = result(for: userID) else { return 0 }
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

extension GameSession {
    enum CodingKeys: String, CodingKey {
        case id, mode, difficulty, status, players, playerIDs, seed, puzzleData, createdAt, startedAt, finishedAt, winnerID, playerResults, winnerReason, matchKind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        mode = try c.decode(GameMode.self, forKey: .mode)
        difficulty = try c.decode(Difficulty.self, forKey: .difficulty)
        status = try c.decode(SessionStatus.self, forKey: .status)
        players = try c.decode([MatchPlayer].self, forKey: .players)
        playerIDs = try c.decodeIfPresent([String].self, forKey: .playerIDs)
        seed = try c.decode(Int.self, forKey: .seed)
        puzzleData = try c.decodeIfPresent(String.self, forKey: .puzzleData) ?? ""
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
        winnerID = try c.decodeIfPresent(String.self, forKey: .winnerID)
        playerResults = try c.decodeIfPresent([String: MatchPlayerResult].self, forKey: .playerResults)
        winnerReason = try c.decodeIfPresent(String.self, forKey: .winnerReason)
        matchKind = (try? c.decode(SessionKind.self, forKey: .matchKind)) ?? .ranked
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(mode, forKey: .mode)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(status, forKey: .status)
        try c.encode(players, forKey: .players)
        try c.encodeIfPresent(playerIDs, forKey: .playerIDs)
        try c.encode(seed, forKey: .seed)
        try c.encode(puzzleData, forKey: .puzzleData)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(startedAt, forKey: .startedAt)
        try c.encodeIfPresent(finishedAt, forKey: .finishedAt)
        try c.encodeIfPresent(winnerID, forKey: .winnerID)
        try c.encodeIfPresent(playerResults, forKey: .playerResults)
        try c.encodeIfPresent(winnerReason, forKey: .winnerReason)
        try c.encode(matchKind, forKey: .matchKind)
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
            return 60
        case .wordHunt:
            return 75
        case .wordle:
            return 0
        }
    }
}
