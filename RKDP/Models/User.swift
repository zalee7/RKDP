import Foundation

struct BotMatchProgress: Codable, Equatable {
    static let rewardedWinsPerDay = 3

    var rewardedBotWins: RankedDailyCounter = .empty

    static let empty = BotMatchProgress()

    func rewardedWinsRemaining(dayKey: String = RankedAccess.todayKey()) -> Int {
        let used = rewardedBotWins.dayKey == dayKey ? rewardedBotWins.count : 0
        return max(0, Self.rewardedWinsPerDay - used)
    }

    mutating func recordRewardedWin(dayKey: String = RankedAccess.todayKey()) -> Bool {
        guard rewardedWinsRemaining(dayKey: dayKey) > 0 else { return false }
        let used = rewardedBotWins.dayKey == dayKey ? rewardedBotWins.count : 0
        rewardedBotWins = RankedDailyCounter(dayKey: dayKey, count: used + 1)
        return true
    }
}

struct AppUser: Codable, Identifiable {
    var id: String
    var username: String
    var email: String
    var avatarURL: String?
    var coins: Int
    var createdAt: Date
    var ranks: [GameMode: RankInfo]
    var cosmetics: OwnedCosmetics = .default
    var soloCompletions: [GameMode: [Difficulty]] = [:]
    var appliedRankedOutcomes: [String: Bool] = [:]
    var rankedAccess: RankedAccess = .empty
    var coinWallet: CoinWallet = .empty
    var botMatchProgress: BotMatchProgress = .empty

    var totalRankPoints: Int { ranks.values.reduce(0) { $0 + $1.points } }

    func rank(for mode: GameMode) -> RankInfo {
        var info = ranks[mode] ?? .empty
        info.tier = RankTier.tier(for: info.points)
        return info
    }

    func completedSoloDifficulties(for mode: GameMode) -> Set<Difficulty> {
        Set(soloCompletions[mode] ?? [])
    }

    func isSoloDifficultyUnlocked(mode: GameMode, difficulty: Difficulty) -> Bool {
        guard let prerequisite = difficulty.previous else { return true }
        return completedSoloDifficulties(for: mode).contains(prerequisite)
    }

    func soloUnlockReason(mode: GameMode, difficulty: Difficulty) -> String? {
        guard !isSoloDifficultyUnlocked(mode: mode, difficulty: difficulty),
              let prerequisite = difficulty.previous else { return nil }
        return "Complete \(mode.difficultyLabel(prerequisite)) solo first"
    }

    mutating func recordSoloCompletion(mode: GameMode, difficulty: Difficulty) {
        var completed = completedSoloDifficulties(for: mode)
        completed.insert(difficulty)
        soloCompletions[mode] = Difficulty.allCases.filter { completed.contains($0) }
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
        case id, username, email, avatarURL, coins, createdAt, ranks, cosmetics, soloCompletions, appliedRankedOutcomes, rankedAccess, coinWallet, botMatchProgress
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        username  = try c.decode(String.self, forKey: .username)
        email     = try c.decode(String.self, forKey: .email)
        avatarURL = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        coins     = try c.decode(Int.self, forKey: .coins)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        cosmetics = (try? c.decode(OwnedCosmetics.self, forKey: .cosmetics)) ?? .default

        let rawRanks = try c.decode([String: RankInfo].self, forKey: .ranks)
        var decoded: [GameMode: RankInfo] = [:]
        for (key, value) in rawRanks {
            if let mode = GameMode(rawValue: key) { decoded[mode] = value }
        }
        ranks = decoded

        let rawSolo = (try? c.decode([String: [String]].self, forKey: .soloCompletions)) ?? [:]
        soloCompletions = rawSolo.reduce(into: [GameMode: [Difficulty]]()) { partial, item in
            guard let mode = GameMode(rawValue: item.key) else { return }
            partial[mode] = item.value.compactMap { Difficulty(rawValue: $0) }
        }
        appliedRankedOutcomes = (try? c.decode([String: Bool].self, forKey: .appliedRankedOutcomes)) ?? [:]
        rankedAccess = (try? c.decode(RankedAccess.self, forKey: .rankedAccess)) ?? .empty
        coinWallet = (try? c.decode(CoinWallet.self, forKey: .coinWallet)) ?? .empty
        botMatchProgress = (try? c.decode(BotMatchProgress.self, forKey: .botMatchProgress)) ?? .empty
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,        forKey: .id)
        try c.encode(username,  forKey: .username)
        try c.encode(email,     forKey: .email)
        try c.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try c.encode(coins,     forKey: .coins)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(cosmetics, forKey: .cosmetics)

        var rawRanks: [String: RankInfo] = [:]
        for (mode, info) in ranks { rawRanks[mode.rawValue] = info }
        try c.encode(rawRanks, forKey: .ranks)

        var rawSolo: [String: [String]] = [:]
        for (mode, difficulties) in soloCompletions {
            rawSolo[mode.rawValue] = difficulties.map(\.rawValue)
        }
        try c.encode(rawSolo, forKey: .soloCompletions)
        try c.encode(appliedRankedOutcomes, forKey: .appliedRankedOutcomes)
        try c.encode(rankedAccess, forKey: .rankedAccess)
        try c.encode(coinWallet, forKey: .coinWallet)
        try c.encode(botMatchProgress, forKey: .botMatchProgress)
    }
}
