import Foundation

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case declined
    case canceled
}

struct FriendRequest: Codable, Identifiable, Equatable {
    var id: String
    var fromID: String
    var fromUsername: String
    var toID: String
    var toUsername: String
    var status: FriendRequestStatus
    var createdAt: Date

    func otherUserID(currentUserID: String) -> String {
        fromID == currentUserID ? toID : fromID
    }

    func otherUsername(currentUserID: String) -> String {
        fromID == currentUserID ? toUsername : fromUsername
    }
}

struct Friendship: Codable, Identifiable, Equatable {
    var id: String
    var userIDs: [String]
    var usernames: [String: String]
    var createdAt: Date

    func friendID(for currentUserID: String) -> String? {
        userIDs.first { $0 != currentUserID }
    }

    func friendUsername(for currentUserID: String) -> String {
        guard let id = friendID(for: currentUserID) else { return "Friend" }
        return usernames[id] ?? "Friend"
    }
}

struct FriendSummary: Identifiable, Equatable {
    var id: String { userID }
    var userID: String
    var username: String
    var avatarStyle: AvatarStyle = .default
}

enum ExhibitionInviteStatus: String, Codable {
    case pending
    case accepted
    case declined
    case expired
    case canceled
    case completed
}

enum ExhibitionInviteType: String, Codable {
    case playNow
    case playLater
}

struct ExhibitionInvite: Codable, Identifiable, Equatable {
    var id: String
    var fromID: String
    var fromUsername: String
    var toID: String
    var toUsername: String
    var mode: GameMode
    var difficulty: Difficulty
    var status: ExhibitionInviteStatus
    var createdAt: Date
    var expiresAt: Date
    var sessionID: String?
    var inviteType: ExhibitionInviteType?

    var kind: ExhibitionInviteType { inviteType ?? .playNow }
    var isExpired: Bool { Date() >= expiresAt }
    var isPlayLater: Bool { kind == .playLater }

    func otherUsername(currentUserID: String) -> String {
        fromID == currentUserID ? toUsername : fromUsername
    }
}

enum PartyRoomStatus: String, Codable {
    case lobby
    case inProgress
    case finished
    case canceled
    case expired
}

enum PartyStageRoundStatus: String, Codable {
    case waiting
    case inProgress
    case finished
}

struct PartyStageRoundConfiguration: Codable, Identifiable, Equatable {
    var id: Int { index }
    var index: Int
    var mode: GameMode
    var difficulty: Difficulty

    static var quickStage: [PartyStageRoundConfiguration] {
        [
            PartyStageRoundConfiguration(index: 0, mode: .colorLink, difficulty: .medium),
            PartyStageRoundConfiguration(index: 1, mode: .wordle, difficulty: .medium),
            PartyStageRoundConfiguration(index: 2, mode: .hangman, difficulty: .medium)
        ]
    }
}

struct PartyStageRoundScore: Codable, Identifiable, Equatable {
    var id: String { userID }
    var userID: String
    var username: String
    var placement: Int
    var roundPoints: Int
    var cumulativePoints: Int
    var resultSummary: String
}

struct PartyStageRound: Codable, Identifiable, Equatable {
    var id: Int { index }
    var index: Int
    var mode: GameMode
    var difficulty: Difficulty
    var seed: Int
    var puzzleData: String
    var status: PartyStageRoundStatus
    var startedAt: Date?
    var finishedAt: Date?
    var finishWindowStartedAt: Date?
    var finishWindowDeadline: Date?
    var finishWindowStarterID: String?
    var results: [String: MatchPlayerResult]
    var scoreRows: [PartyStageRoundScore]?
}

struct PartyPlayer: Codable, Identifiable, Equatable {
    var id: String { userID }
    var userID: String
    var username: String
    var avatarStyle: AvatarStyle
    var joinedAt: Date
    var isHost: Bool
    var result: MatchPlayerResult?
    var abandoned: Bool
}

struct PartyInvite: Codable, Identifiable, Equatable {
    var id: String
    var roomCode: String
    var fromID: String
    var fromUsername: String
    var toID: String
    var toUsername: String
    var mode: GameMode
    var difficulty: Difficulty
    var createdAt: Date
    var expiresAt: Date
}

struct PartyRoom: Codable, Identifiable, Equatable {
    var id: String { code }
    var code: String
    var hostID: String
    var mode: GameMode
    var difficulty: Difficulty
    var status: PartyRoomStatus
    var players: [PartyPlayer]
    var playerIDs: [String]
    var seed: Int
    var puzzleData: String
    var createdAt: Date
    var expiresAt: Date
    var startedAt: Date?
    var finishedAt: Date?
    var winnerID: String?
    var winnerReason: String?
    var readyPlayerIDs: [String]?
    var finishWindowStartedAt: Date?
    var finishWindowDeadline: Date?
    var finishWindowStarterID: String?
    var stageRounds: [PartyStageRound]?
    var currentStageRoundIndex: Int?
    var stageScores: [String: Int]?
    var isStageRoom: Bool?
    var maxPlayers: Int

    var isExpired: Bool {
        status == .lobby && Date() >= expiresAt
    }

    func containsPlayer(_ userID: String) -> Bool {
        playerIDs.contains(userID)
    }

    func isHost(_ userID: String) -> Bool {
        hostID == userID
    }

    var activeStageRound: PartyStageRound? {
        guard isStageRoom == true,
              let rounds = stageRounds,
              let index = currentStageRoundIndex,
              rounds.indices.contains(index) else {
            return nil
        }
        return rounds[index]
    }

    var readyIDs: Set<String> {
        Set(readyPlayerIDs ?? [])
    }

    var readyCount: Int {
        readyIDs.intersection(Set(playerIDs)).count
    }

    var allPlayersReady: Bool {
        players.count >= 2 && Set(playerIDs).isSubset(of: readyIDs)
    }

    func isReady(_ userID: String) -> Bool {
        readyIDs.contains(userID)
    }
}

struct PartyStanding: Identifiable, Equatable {
    var id: String { player.userID }
    var placement: Int
    var player: PartyPlayer
    var result: MatchPlayerResult?
}

enum PartyScoring {
    static func standings(for room: PartyRoom) -> [PartyStanding] {
        let sortedPlayers = room.players.sorted { lhs, rhs in
            compare(lhs.result, rhs.result, mode: room.mode) < 0
        }

        var standings: [PartyStanding] = []
        var previousResult: MatchPlayerResult?
        var currentPlacement = 1

        for (index, player) in sortedPlayers.enumerated() {
            if index > 0,
               compare(player.result, previousResult, mode: room.mode) != 0 {
                currentPlacement = index + 1
            }
            standings.append(PartyStanding(placement: currentPlacement, player: player, result: player.result))
            previousResult = player.result
        }
        return standings
    }

    static func resolvedRoom(_ room: PartyRoom) -> PartyRoom {
        var updated = room
        let ordered = standings(for: room)
        guard let first = ordered.first, first.result != nil else {
            updated.winnerID = nil
            updated.winnerReason = "No submitted results"
            return updated
        }

        if ordered.count > 1,
           ordered[1].result != nil,
           compare(first.result, ordered[1].result, mode: room.mode) == 0 {
            updated.winnerID = nil
            updated.winnerReason = "Top players tied"
        } else {
            updated.winnerID = first.player.userID
            updated.winnerReason = winnerReason(for: room.mode)
        }
        return updated
    }

    static func summary(for result: MatchPlayerResult?, mode: GameMode) -> String {
        guard let result else { return "Waiting for result" }
        if result.status == "Abandoned" { return "Abandoned" }
        if result.summary["partyTimeout"] == "true" { return "Time expired" }
        switch mode {
        case .wordle:
            return "\(result.solvedRounds) rounds · \(result.totalGuesses) guesses · \(timeText(result.elapsedSeconds))"
        case .anagram, .wordHunt:
            return "\(result.score) pts · \(result.wordCount) words · longest \(result.longestWordLength)"
        case .hangman:
            return result.completed
                ? "Rescued · \(result.wrongGuessCount) wrong · \(timeText(result.elapsedSeconds))"
                : "\(result.revealedLetterCount) letters · \(result.wrongGuessCount) wrong"
        case .gridlock:
            return "\(result.foundationCount)/52 foundations · \(result.moveCount) moves · \(timeText(result.elapsedSeconds))"
        case .colorLink:
            return "\(percent(result.progress)) fill · \(result.solvedPairs) pairs · \(timeText(result.elapsedSeconds))"
        case .minesweeper:
            if result.hitMine { return "Mine hit · \(result.score) safe cells" }
            return "\(result.score) safe cells · \(timeText(result.elapsedSeconds))"
        case .sudoku:
            return result.completed
                ? "Solved · \(timeText(result.elapsedSeconds))"
                : "\(percent(result.progress)) complete · \(timeText(result.elapsedSeconds))"
        }
    }

    static func compare(_ lhs: MatchPlayerResult?, _ rhs: MatchPlayerResult?, mode: GameMode) -> Int {
        switch (lhs, rhs) {
        case (.none, .none):
            return 0
        case (.some, .none):
            return -1
        case (.none, .some):
            return 1
        case let (.some(left), .some(right)):
            return compareResults(left, right, mode: mode)
        }
    }

    private static func compareResults(_ lhs: MatchPlayerResult, _ rhs: MatchPlayerResult, mode: GameMode) -> Int {
        let leftMissing = lhs.summary["partyTimeout"] == "true" || lhs.summary["abandoned"] == "true"
        let rightMissing = rhs.summary["partyTimeout"] == "true" || rhs.summary["abandoned"] == "true"
        if leftMissing != rightMissing { return leftMissing ? 1 : -1 }
        if leftMissing { return 0 }
        switch mode {
        case .wordle:
            if lhs.solvedRounds != rhs.solvedRounds { return rhs.solvedRounds - lhs.solvedRounds }
            guard lhs.solvedRounds > 0 else { return 0 }
            return compareValues([
                lhs.totalGuesses - rhs.totalGuesses,
                lhs.elapsedSeconds - rhs.elapsedSeconds
            ])
        case .anagram, .wordHunt:
            return compareValues([
                rhs.score - lhs.score,
                rhs.wordCount - lhs.wordCount,
                rhs.longestWordLength - lhs.longestWordLength,
                lhs.elapsedSeconds - rhs.elapsedSeconds
            ])
        case .hangman:
            if lhs.solvedRounds != rhs.solvedRounds { return rhs.solvedRounds - lhs.solvedRounds }
            if lhs.completed != rhs.completed { return lhs.completed ? -1 : 1 }
            if lhs.completed {
                return compareValues([
                    lhs.wrongGuessCount - rhs.wrongGuessCount,
                    lhs.elapsedSeconds - rhs.elapsedSeconds
                ])
            }
            return compareValues([
                rhs.revealedLetterCount - lhs.revealedLetterCount,
                lhs.wrongGuessCount - rhs.wrongGuessCount,
                lhs.elapsedSeconds - rhs.elapsedSeconds
            ])
        case .gridlock:
            if lhs.completed != rhs.completed { return lhs.completed ? -1 : 1 }
            if lhs.completed {
                return compareValues([
                    lhs.moveCount - rhs.moveCount,
                    lhs.elapsedSeconds - rhs.elapsedSeconds
                ])
            }
            return compareValues([
                rhs.foundationCount - lhs.foundationCount,
                rhs.score - lhs.score,
                progressCompare(lhs.progress, rhs.progress),
                lhs.moveCount - rhs.moveCount,
                lhs.elapsedSeconds - rhs.elapsedSeconds
            ])
        case .colorLink:
            if lhs.completed != rhs.completed { return lhs.completed ? -1 : 1 }
            if lhs.completed { return lhs.elapsedSeconds - rhs.elapsedSeconds }
            return compareValues([
                progressCompare(lhs.progress, rhs.progress),
                rhs.solvedPairs - lhs.solvedPairs,
                lhs.elapsedSeconds - rhs.elapsedSeconds
            ])
        case .minesweeper:
            if lhs.hitMine != rhs.hitMine { return lhs.hitMine ? 1 : -1 }
            if lhs.completed != rhs.completed { return lhs.completed ? -1 : 1 }
            return compareValues([
                rhs.score - lhs.score,
                lhs.elapsedSeconds - rhs.elapsedSeconds
            ])
        case .sudoku:
            if lhs.completed != rhs.completed { return lhs.completed ? -1 : 1 }
            if lhs.completed { return lhs.elapsedSeconds - rhs.elapsedSeconds }
            return compareValues([
                progressCompare(lhs.progress, rhs.progress),
                lhs.elapsedSeconds - rhs.elapsedSeconds
            ])
        }
    }

    private static func compareValues(_ values: [Int]) -> Int {
        for value in values where value != 0 {
            return value < 0 ? -1 : 1
        }
        return 0
    }

    private static func progressCompare(_ lhs: Double, _ rhs: Double) -> Int {
        let delta = rhs - lhs
        if abs(delta) < 0.0001 { return 0 }
        return delta < 0 ? -1 : 1
    }

    private static func winnerReason(for mode: GameMode) -> String {
        switch mode {
        case .wordle:
            return "Best Word Guess result"
        case .anagram:
            return "Highest Anagrams score"
        case .wordHunt:
            return "Highest Word Hunt score"
        case .hangman:
            return "Best Lava Rescue result"
        case .gridlock:
            return "Best Solitaire result"
        case .colorLink:
            return "Best Color Link result"
        case .minesweeper:
            return "Best Minesweeper clear"
        case .sudoku:
            return "Best Sudoku result"
        }
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func timeText(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
