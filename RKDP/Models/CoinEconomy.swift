import Foundation

struct CoinPackProduct: Identifiable, Codable, Equatable {
    var id: String
    var coins: Int
    var fallbackPrice: String
    var title: String
    var subtitle: String

    static let all: [CoinPackProduct] = [
        CoinPackProduct(id: "com.gridduel.coins.small", coins: 1_000, fallbackPrice: "$0.99", title: "Small Pack", subtitle: "A quick boost for wagers and cosmetics."),
        CoinPackProduct(id: "com.gridduel.coins.medium", coins: 3_300, fallbackPrice: "$2.99", title: "Medium Pack", subtitle: "Best for a few themes or higher stakes."),
        CoinPackProduct(id: "com.gridduel.coins.large", coins: 6_000, fallbackPrice: "$4.99", title: "Large Pack", subtitle: "A strong stash for ranked and shop drops."),
        CoinPackProduct(id: "com.gridduel.coins.mega", coins: 13_500, fallbackPrice: "$9.99", title: "Mega Pack", subtitle: "Maximum value for heavy play.")
    ]

    static var productIDs: [String] { all.map(\.id) }

    static func pack(for productID: String) -> CoinPackProduct? {
        all.first { $0.id == productID }
    }
}

struct CoinDailyCounter: Codable, Equatable {
    var dayKey: String
    var count: Int

    static let empty = CoinDailyCounter(dayKey: "", count: 0)
}

struct CoinWallet: Codable, Equatable {
    static let dailyClaimAmount = 100
    static let rewardedAdAmount = 75
    static let rewardedAdsPerDay = 5
    static let casualWinReward = 10
    static let casualOtherReward = 3
    static let casualRewardDailyCap = 100

    var claimedDailyCoinDay: String? = nil
    var rewardedCoinAds: CoinDailyCounter = .empty
    var casualRewards: CoinDailyCounter = .empty
    var processedTransactions: [String: Bool] = [:]

    static let empty = CoinWallet()

    enum CodingKeys: String, CodingKey {
        case claimedDailyCoinDay, rewardedCoinAds, casualRewards, processedTransactions
    }

    init(
        claimedDailyCoinDay: String? = nil,
        rewardedCoinAds: CoinDailyCounter = .empty,
        casualRewards: CoinDailyCounter = .empty,
        processedTransactions: [String: Bool] = [:]
    ) {
        self.claimedDailyCoinDay = claimedDailyCoinDay
        self.rewardedCoinAds = rewardedCoinAds
        self.casualRewards = casualRewards
        self.processedTransactions = processedTransactions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        claimedDailyCoinDay = try c.decodeIfPresent(String.self, forKey: .claimedDailyCoinDay)
        rewardedCoinAds = (try? c.decode(CoinDailyCounter.self, forKey: .rewardedCoinAds)) ?? .empty
        casualRewards = (try? c.decode(CoinDailyCounter.self, forKey: .casualRewards)) ?? .empty
        processedTransactions = (try? c.decode([String: Bool].self, forKey: .processedTransactions)) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(claimedDailyCoinDay, forKey: .claimedDailyCoinDay)
        try c.encode(rewardedCoinAds, forKey: .rewardedCoinAds)
        try c.encode(casualRewards, forKey: .casualRewards)
        try c.encode(processedTransactions, forKey: .processedTransactions)
    }

    static func todayKey(date: Date = Date()) -> String {
        RankedAccess.todayKey(date: date)
    }

    func canClaimDaily(dayKey: String = todayKey()) -> Bool {
        claimedDailyCoinDay != dayKey
    }

    func rewardedAdsRemaining(dayKey: String = todayKey()) -> Int {
        let used = rewardedCoinAds.dayKey == dayKey ? rewardedCoinAds.count : 0
        return max(0, Self.rewardedAdsPerDay - used)
    }

    mutating func recordDailyClaim(dayKey: String = todayKey()) -> Bool {
        guard canClaimDaily(dayKey: dayKey) else { return false }
        claimedDailyCoinDay = dayKey
        return true
    }

    mutating func recordRewardedAd(dayKey: String = todayKey()) -> Bool {
        guard rewardedAdsRemaining(dayKey: dayKey) > 0 else { return false }
        let used = rewardedCoinAds.dayKey == dayKey ? rewardedCoinAds.count : 0
        rewardedCoinAds = CoinDailyCounter(dayKey: dayKey, count: used + 1)
        return true
    }

    func casualRewardRemaining(dayKey: String = todayKey()) -> Int {
        let earned = casualRewards.dayKey == dayKey ? casualRewards.count : 0
        return max(0, Self.casualRewardDailyCap - earned)
    }

    mutating func recordCasualReward(_ amount: Int, dayKey: String = todayKey()) -> Int {
        let grant = min(max(0, amount), casualRewardRemaining(dayKey: dayKey))
        guard grant > 0 else { return 0 }
        let earned = casualRewards.dayKey == dayKey ? casualRewards.count : 0
        casualRewards = CoinDailyCounter(dayKey: dayKey, count: earned + grant)
        return grant
    }
}

enum CoinWalletError: LocalizedError {
    case dailyAlreadyClaimed
    case rewardedAdLimitReached
    case unknownPack

    var errorDescription: String? {
        switch self {
        case .dailyAlreadyClaimed: return "Daily coins are already claimed today."
        case .rewardedAdLimitReached: return "You have reached today's rewarded coin ad limit."
        case .unknownPack: return "That coin pack is not available yet."
        }
    }
}
