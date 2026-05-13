import Foundation

struct LeaderboardEntry: Codable, Identifiable {
    var id: String          // userID
    var username: String
    var avatarURL: String?
    var rankTier: RankTier
    var rankPoints: Int
    var wins: Int
    var bestTime: Int?      // seconds
    var mode: GameMode
}
