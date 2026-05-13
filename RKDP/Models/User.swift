import Foundation

struct AppUser: Codable, Identifiable {
    var id: String
    var username: String
    var email: String
    var avatarURL: String?
    var coins: Int
    var createdAt: Date
    var ranks: [GameMode: RankInfo]

    var totalRankPoints: Int { ranks.values.reduce(0) { $0 + $1.points } }

    func rank(for mode: GameMode) -> RankInfo {
        ranks[mode] ?? .empty
    }

    static func makeNew(id: String, username: String, email: String) -> AppUser {
        var ranks: [GameMode: RankInfo] = [:]
        for mode in GameMode.allCases {
            ranks[mode] = .empty
        }
        return AppUser(
            id: id,
            username: username,
            email: email,
            avatarURL: nil,
            coins: 500,
            createdAt: Date(),
            ranks: ranks
        )
    }
}

extension AppUser {
    enum CodingKeys: String, CodingKey {
        case id, username, email, avatarURL, coins, createdAt, ranks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        username  = try c.decode(String.self, forKey: .username)
        email     = try c.decode(String.self, forKey: .email)
        avatarURL = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        coins     = try c.decode(Int.self, forKey: .coins)
        createdAt = try c.decode(Date.self, forKey: .createdAt)

        let rawRanks = try c.decode([String: RankInfo].self, forKey: .ranks)
        var decoded: [GameMode: RankInfo] = [:]
        for (key, value) in rawRanks {
            if let mode = GameMode(rawValue: key) { decoded[mode] = value }
        }
        ranks = decoded
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,        forKey: .id)
        try c.encode(username,  forKey: .username)
        try c.encode(email,     forKey: .email)
        try c.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try c.encode(coins,     forKey: .coins)
        try c.encode(createdAt, forKey: .createdAt)

        var rawRanks: [String: RankInfo] = [:]
        for (mode, info) in ranks { rawRanks[mode.rawValue] = info }
        try c.encode(rawRanks, forKey: .ranks)
    }
}
