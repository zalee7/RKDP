import Foundation

// Handles post-match rank + coin updates atomically
final class RankingService {
    static let shared = RankingService()
    private let firestore = FirestoreService.shared

    private init() {}

    struct MatchOutcome {
        let sessionID: String
        let mode: GameMode
        let difficulty: Difficulty
        let winnerID: String?
        let players: [MatchPlayer]
        let playerResults: [String: MatchPlayerResult]
        let winnerReason: String
    }

    func processOutcome(_ outcome: MatchOutcome) async throws {
        let existing = try await firestore.fetchSession(id: outcome.sessionID)
        guard existing.status != .finished else { return }

        // Compute deltas directly from outcome — do NOT rely on the fetched session status,
        // which is still .inProgress until finishSession is called below.
        func delta(for playerID: String) -> Int {
            if let winnerID = outcome.winnerID {
                let isWinner = playerID == winnerID
                var base = isWinner ? 30 : -15
                // Division boost: winner gets +5 if they beat a higher-division player (same tier)
                if isWinner {
                    let myPlayer  = outcome.players.first { $0.userID == playerID }
                    let oppPlayer = outcome.players.first { $0.userID != playerID }
                    if let myPts = myPlayer?.rankPoints, let oppPts = oppPlayer?.rankPoints, oppPts > myPts {
                        base += 5
                    }
                }
                return Int(Double(base) * outcome.difficulty.pointMultiplier)
            }
            return Int(Double(5) * outcome.difficulty.pointMultiplier)  // draw
        }

        for player in outcome.players {
            var user = try await firestore.fetchUser(id: player.userID)
            let isWinner = outcome.winnerID == player.userID
            let d = delta(for: player.userID)

            var rankInfo = user.ranks[outcome.mode] ?? .empty
            rankInfo.points = max(0, rankInfo.points + d)
            rankInfo.tier = RankTier.tier(for: rankInfo.points)
            if let _ = outcome.winnerID {
                if isWinner { rankInfo.wins += 1 } else { rankInfo.losses += 1 }
            }
            let result = outcome.playerResults[player.userID]
            if isWinner, result?.completed == true, let time = result?.elapsedSeconds {
                rankInfo.bestTime = min(rankInfo.bestTime ?? Int.max, time)
            }
            if isWinner, outcome.mode.isScoreBased, let score = result?.score {
                rankInfo.bestScore = max(rankInfo.bestScore ?? 0, score)
            }
            user.ranks[outcome.mode] = rankInfo

            if let winnerID = outcome.winnerID {
                let pot = outcome.players.reduce(0) { $0 + $1.wager }
                user.coins += (player.userID == winnerID ? pot : -player.wager)
            }

            try await firestore.updateUser(user)
            try await firestore.updateRankEntry(
                userID: player.userID,
                mode: outcome.mode,
                info: rankInfo,
                username: user.username
            )
        }

        try await firestore.finishSession(
            id: outcome.sessionID,
            winnerID: outcome.winnerID,
            finishedAt: Date(),
            playerResults: outcome.playerResults,
            winnerReason: outcome.winnerReason
        )
    }
}
