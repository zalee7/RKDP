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
    var equippedTitle: String?
    var avatarStyle: AvatarStyle = .default

    enum CodingKeys: String, CodingKey {
        case id, username, avatarURL, rankTier, rankPoints, wins, bestTime, mode, equippedTitle, avatarStyle
    }

    init(
        id: String,
        username: String,
        avatarURL: String?,
        rankTier: RankTier,
        rankPoints: Int,
        wins: Int,
        bestTime: Int?,
        mode: GameMode,
        equippedTitle: String? = nil,
        avatarStyle: AvatarStyle = .default
    ) {
        self.id = id
        self.username = username
        self.avatarURL = avatarURL
        self.rankTier = rankTier
        self.rankPoints = rankPoints
        self.wins = wins
        self.bestTime = bestTime
        self.mode = mode
        self.equippedTitle = equippedTitle
        self.avatarStyle = avatarStyle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        avatarURL = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        rankTier = try c.decode(RankTier.self, forKey: .rankTier)
        rankPoints = try c.decode(Int.self, forKey: .rankPoints)
        wins = try c.decode(Int.self, forKey: .wins)
        bestTime = try c.decodeIfPresent(Int.self, forKey: .bestTime)
        mode = try c.decode(GameMode.self, forKey: .mode)
        equippedTitle = try c.decodeIfPresent(String.self, forKey: .equippedTitle)
        avatarStyle = try c.decodeIfPresent(AvatarStyle.self, forKey: .avatarStyle) ?? .default
    }
}
