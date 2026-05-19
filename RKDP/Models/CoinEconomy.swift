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

    var claimedDailyCoinDay: String? = nil
    var rewardedCoinAds: CoinDailyCounter = .empty
    var processedTransactions: [String: Bool] = [:]

    static let empty = CoinWallet()

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
