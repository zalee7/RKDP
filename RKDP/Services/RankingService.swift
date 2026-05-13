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
    }

    func processOutcome(_ outcome: MatchOutcome) async throws {
        let session = try await firestore.fetchSession(id: outcome.sessionID)

        for player in outcome.players {
            var user = try await firestore.fetchUser(id: player.userID)
            let delta = session.rankPointsDelta(for: player.userID)
            let isWinner = outcome.winnerID == player.userID

            // Update rank info
            var rankInfo = user.ranks[outcome.mode] ?? .empty
            rankInfo.points = max(0, rankInfo.points + delta)
            rankInfo.tier = RankTier.tier(for: rankInfo.points)
            if isWinner { rankInfo.wins += 1 } else { rankInfo.losses += 1 }
            if isWinner, let time = player.finishTime {
                rankInfo.bestTime = min(rankInfo.bestTime ?? Int.max, time)
            }
            user.ranks[outcome.mode] = rankInfo

            // Update coins: winner takes loser's wager; tie returns wagers
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
            finishedAt: Date()
        )
    }
}
