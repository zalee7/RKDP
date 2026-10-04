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
    case casual
    case exhibition
    case asyncExhibition
    case party
}

struct PostMatchRewardSnapshot {
    var sessionID: String
    var startingCoins: Int
    var endingCoins: Int
    var coinDelta: Int
    var startingRank: RankInfo
    var endingRank: RankInfo
    var rankDelta: Int
    var rankPerformanceBonus: Int
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
            rankPerformanceBonus: 0,
            didPromote: endingPosition > startingPosition,
            didDemote: endingPosition < startingPosition,
            mode: session.mode,
            difficulty: session.difficulty,
            outcome: outcome,
            shouldAnimate: didApplyRewards
        )
    }

    static func staticSnapshot(session: GameSession, user: AppUser, recordedCoinReward: Int? = nil) -> PostMatchRewardSnapshot {
        let rank = user.rank(for: session.mode)
        let outcome = session.result(for: user.id) ?? .draw
        // Show only a committed reward, never a predicted payout after a failed save.
        let coinDelta = recordedCoinReward ?? session.rankedCoinRewards?[user.id] ?? 0
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
            rankPerformanceBonus: wordGuessPerformanceBonus(session: session, userID: user.id),
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

    private static func wordGuessPerformanceBonus(session: GameSession, userID: String) -> Int {
        guard session.mode == .wordle,
              session.winnerID == userID,
              let result = session.playerResults?[userID],
              result.completed else { return 0 }
        let guessBonus: Int
        switch result.totalGuesses {
        case 1: guessBonus = 6
        case 2: guessBonus = 4
        case 3: guessBonus = 2
        default: guessBonus = 0
        }
        let speedBonus = result.elapsedSeconds > 0 && result.elapsedSeconds < 30 ? 1 : 0
        return min(6, guessBonus + speedBonus)
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
    var avatarStyle: AvatarStyle = .default
    var hasRankPointSnapshot = true

    init(userID: String, username: String, wager: Int, finishTime: Int? = nil, rankTier: RankTier, rankPoints: Int = 0, isBot: Bool = false, avatarStyle: AvatarStyle = .default) {
        self.userID = userID
        self.username = username
        self.wager = wager
        self.finishTime = finishTime
        self.rankTier = rankTier
        self.rankPoints = rankPoints
        self.isBot = isBot
        self.avatarStyle = avatarStyle
    }

    enum CodingKeys: String, CodingKey {
        case userID, username, wager, finishTime, rankTier, rankPoints, isBot, avatarStyle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(String.self, forKey: .userID)
        username = try c.decode(String.self, forKey: .username)
        wager = try c.decode(Int.self, forKey: .wager)
        finishTime = try c.decodeIfPresent(Int.self, forKey: .finishTime)
        rankTier = try c.decode(RankTier.self, forKey: .rankTier)
        let savedRankPoints = try c.decodeIfPresent(Int.self, forKey: .rankPoints)
        rankPoints = savedRankPoints ?? 0
        hasRankPointSnapshot = savedRankPoints != nil
        isBot = try c.decodeIfPresent(Bool.self, forKey: .isBot) ?? false
        avatarStyle = try c.decodeIfPresent(AvatarStyle.self, forKey: .avatarStyle) ?? .default
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userID, forKey: .userID)
        try c.encode(username, forKey: .username)
        try c.encode(wager, forKey: .wager)
        try c.encodeIfPresent(finishTime, forKey: .finishTime)
        try c.encode(rankTier, forKey: .rankTier)
        if hasRankPointSnapshot { try c.encode(rankPoints, forKey: .rankPoints) }
        try c.encode(isBot, forKey: .isBot)
        try c.encode(avatarStyle, forKey: .avatarStyle)
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
    var rewardEvidenceJSON: String? = nil

    var longestWordLength: Int { Int(summary["longestWordLength"] ?? "0") ?? 0 }
    var wordCount: Int { Int(summary["wordCount"] ?? "0") ?? 0 }
    var solvedRounds: Int { Int(summary["solvedRounds"] ?? "0") ?? 0 }
    var totalGuesses: Int { Int(summary["totalGuesses"] ?? "0") ?? 0 }
    var failedRounds: Int { Int(summary["failedRounds"] ?? "0") ?? 0 }
    var wordleRoundCount: Int { Int(summary["roundCount"] ?? "0") ?? 0 }
    var isFinalWordleResult: Bool {
        guard mode == .wordle else { return true }
        if let explicitFinal = summary["isFinal"] { return explicitFinal == "true" }
        return solvedRounds >= 2 || failedRounds >= 2
    }
    var hitMine: Bool { summary["hitMine"] == "true" }
    var moveCount: Int { Int(summary["moves"] ?? "0") ?? 0 }
    var foundationCount: Int { Int(summary["foundationCount"] ?? "\(Int((progress * 52).rounded()))") ?? 0 }
    var solvedPairs: Int { Int(summary["solvedPairs"] ?? "0") ?? 0 }
    var wrongGuessCount: Int { Int(summary["wrongGuessCount"] ?? "0") ?? 0 }
    var revealedLetterCount: Int { Int(summary["revealedLetterCount"] ?? "\(score)") ?? score }
    var maxWrongGuesses: Int { Int(summary["maxWrongGuesses"] ?? "6") ?? 6 }
    var hangmanGuessCount: Int { (summary["correctLetters"]?.count ?? 0) + (summary["wrongLetters"]?.count ?? 0) }

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

struct SoloResultSection: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var items: [String]
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
    var wrongGuesses: Int? = nil
    var stats: [SoloResultStat]
    var details: [String] = []
    var sections: [SoloResultSection] = []
    var rewardEvidenceJSON: String? = nil
}

// A run-start snapshot keeps result comparisons stable after the user record updates.
struct SoloRunProgress {
    var previousBest: SoloPersonalBest?
    var completedDifficulties: Set<Difficulty>

    func newlyUnlockedDifficulty(for result: SoloGameResult) -> Difficulty? {
        guard result.completed, !completedDifficulties.contains(result.difficulty),
              let next = result.difficulty.next,
              !completedDifficulties.contains(next) else { return nil }
        return next
    }

    func bestComparison(for result: SoloGameResult) -> SoloBestComparison? {
        guard let candidate = SoloPersonalBest(result: result) else { return nil }
        return SoloBestComparison(current: candidate, previous: previousBest, mode: result.mode)
    }
}

struct SoloBestComparison {
    var current: SoloPersonalBest
    var previous: SoloPersonalBest?
    var mode: GameMode

    var isNewBest: Bool {
        guard let previous else { return true }
        return current.isBetter(than: previous, mode: mode)
    }

    var title: String {
        guard let previous else { return "First Personal Best" }
        if !isNewBest && !previous.isBetter(than: current, mode: mode) { return "Personal Best Matched" }
        return isNewBest ? "New Personal Best" : "Personal Best"
    }

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
    var preGameCountdownStartedAt: Date? = nil
    var startedAt: Date?
    var finishedAt: Date?
    var winnerID: String?
    var playerResults: [String: MatchPlayerResult]?
    var winnerReason: String?
    var matchKind: SessionKind = .ranked
    var rankedCoinRewards: [String: Int]? = nil

    var usesServerAuthority: Bool { id.hasPrefix("v1_") }
    var usesVerifiedSocial: Bool { id.hasPrefix("sv1_") }
    var usesVerifiedResults: Bool { usesServerAuthority || usesVerifiedSocial }

    static func needsMatchEvidence(_ sessionID: String?) -> Bool {
        guard let sessionID else { return false }
        return sessionID.hasPrefix("v1_") || sessionID.hasPrefix("sv1_")
    }

    var totalPot: Int { players.reduce(0) { $0 + $1.wager } }
    var isRanked: Bool { matchKind == .ranked }
    var isCasual: Bool { matchKind == .casual }
    var isExhibition: Bool { matchKind == .exhibition || matchKind == .asyncExhibition }
    var isLiveExhibition: Bool { matchKind == .exhibition }
    var isAsyncExhibition: Bool { matchKind == .asyncExhibition }
    var isParty: Bool { matchKind == .party }
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
        case id, mode, difficulty, status, players, playerIDs, seed, puzzleData, createdAt, preGameCountdownStartedAt, startedAt, finishedAt, winnerID, playerResults, winnerReason, matchKind, rankedCoinRewards
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
        preGameCountdownStartedAt = try c.decodeIfPresent(Date.self, forKey: .preGameCountdownStartedAt)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
        winnerID = try c.decodeIfPresent(String.self, forKey: .winnerID)
        playerResults = try c.decodeIfPresent([String: MatchPlayerResult].self, forKey: .playerResults)
        winnerReason = try c.decodeIfPresent(String.self, forKey: .winnerReason)
        matchKind = (try? c.decode(SessionKind.self, forKey: .matchKind)) ?? .ranked
        rankedCoinRewards = try c.decodeIfPresent([String: Int].self, forKey: .rankedCoinRewards)
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
        try c.encodeIfPresent(preGameCountdownStartedAt, forKey: .preGameCountdownStartedAt)
        try c.encodeIfPresent(startedAt, forKey: .startedAt)
        try c.encodeIfPresent(finishedAt, forKey: .finishedAt)
        try c.encodeIfPresent(winnerID, forKey: .winnerID)
        try c.encodeIfPresent(playerResults, forKey: .playerResults)
        try c.encodeIfPresent(winnerReason, forKey: .winnerReason)
        try c.encode(matchKind, forKey: .matchKind)
        try c.encodeIfPresent(rankedCoinRewards, forKey: .rankedCoinRewards)
    }
}

extension RankedCoinRewards {
    static func amount(in session: GameSession, for userID: String, botWinRewardAvailable: Bool) -> Int {
        guard session.isRanked, session.status == .finished,
              session.players.count == 2, Set(session.players.map(\.userID)).count == 2,
              let player = session.players.first(where: { $0.userID == userID }), !player.isBot,
              let results = session.playerResults, !results.isEmpty,
              results.allSatisfy({ key, result in
                  key == result.userID && result.mode == session.mode &&
                  session.players.contains(where: { $0.userID == key })
              }) else { return 0 }

        // Synthetic forfeit results are not completed attempts, including the auto-win.
        func isForfeit(_ result: MatchPlayerResult) -> Bool {
            result.summary["forfeit"] == "true" || result.summary["forfeitWin"] == "true" ||
            ["forfeit", "abandon"].contains(where: { result.status.lowercased().contains($0) })
        }
        if let local = results[userID], isForfeit(local) { return 0 }
        let hasForfeit = results.values.contains(where: isForfeit) ||
            ["forfeit", "abandon"].contains(where: { (session.winnerReason ?? "").lowercased().contains($0) })
        if hasForfeit {
            guard session.winnerID == userID, let local = results[userID],
                  local.completed, MatchResolver.isFinalResult(local) else { return 0 }
        } else {
            guard MatchResolver.canResolve(session: session, results: results),
                  MatchResolver.resolve(session: session, results: results).winnerID == session.winnerID else { return 0 }
        }
        if session.containsBot {
            guard session.winnerID == userID, botWinRewardAvailable else { return 0 }
        }
        if session.winnerID == userID {
            let tier = player.hasRankPointSnapshot ? RankTier.tier(for: player.rankPoints) : player.rankTier
            return win(for: tier)
        }
        // A normal first-finisher race can end before the other player submits.
        // That is a completed match, unlike a forfeit or abandoned attempt.
        return session.winnerID == nil ? draw : loss
    }
}

extension AppUser {
    /// Credit only a real resolved human win, using the ranks captured in the session.
    @discardableResult
    mutating func recordCompetitiveBadgeWin(from session: GameSession) -> Bool {
        guard session.status == .finished, session.winnerID == id,
              session.isRanked || session.isExhibition,
              session.players.count == 2, !session.containsBot,
              let local = session.players.first(where: { $0.userID == id }),
              let opponent = session.players.first(where: { $0.userID != id }),
              !earnedShowcase.creditedWinSessionIDs.contains(session.id),
              let results = session.playerResults, !results.isEmpty,
              results.allSatisfy({ key, result in
                  key == result.userID && result.mode == session.mode &&
                  session.players.contains(where: { $0.userID == key }) &&
                  result.summary["forfeit"] != "true" && result.summary["forfeitWin"] != "true" &&
                  !["forfeit", "abandon"].contains(where: { result.status.lowercased().contains($0) })
              }),
              !(session.winnerReason ?? "").lowercased().contains("forfeit"),
              MatchResolver.canResolve(session: session, results: results),
              MatchResolver.resolve(session: session, results: results).winnerID == id else { return false }

        let friendly = session.isExhibition && earnedShowcase.friendlyWins < 100
        // Ignore inconsistent legacy snapshots rather than guessing an opponent's old division.
        let validRanks = local.hasRankPointSnapshot && opponent.hasRankPointSnapshot &&
            local.rankPoints >= 0 && opponent.rankPoints >= 0 &&
            local.rankTier == RankTier.tier(for: local.rankPoints) &&
            opponent.rankTier == RankTier.tier(for: opponent.rankPoints)
        let localPosition = local.rankTier.rawValue * 3 + local.rankTier.division(for: local.rankPoints).index
        let opponentPosition = opponent.rankTier.rawValue * 3 + opponent.rankTier.division(for: opponent.rankPoints).index
        let underdog = session.isRanked && validRanks && opponentPosition > localPosition && earnedShowcase.underdogWins < 100
        guard friendly || underdog else { return false }
        if friendly { earnedShowcase.friendlyWins += 1 }
        if underdog { earnedShowcase.underdogWins += 1 }
        earnedShowcase.creditedWinSessionIDs.insert(session.id)
        reconcileEarnedRewards()
        return true
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
            case .easy: return 600
            case .medium: return 720
            case .hard: return 900
            case .expert: return 1_080
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
        case .hangman:
            return 90
        }
    }
}
