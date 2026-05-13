import Foundation

struct WagerTier: Identifiable {
    var id: String { "\(rank.rawValue)-\(label)" }
    let rank: RankTier
    let label: String
    let amount: Int
}

enum Wager {
    // Wager options available to a player for a given rank tier
    static func options(for tier: RankTier) -> [WagerTier] {
        switch tier {
        case .bronze:
            return [
                WagerTier(rank: tier, label: "Low",    amount: 10),
                WagerTier(rank: tier, label: "Mid",    amount: 25),
                WagerTier(rank: tier, label: "High",   amount: 50),
            ]
        case .silver:
            return [
                WagerTier(rank: tier, label: "Low",    amount: 50),
                WagerTier(rank: tier, label: "Mid",    amount: 100),
                WagerTier(rank: tier, label: "High",   amount: 200),
            ]
        case .gold:
            return [
                WagerTier(rank: tier, label: "Low",    amount: 200),
                WagerTier(rank: tier, label: "Mid",    amount: 400),
                WagerTier(rank: tier, label: "High",   amount: 750),
            ]
        case .platinum:
            return [
                WagerTier(rank: tier, label: "Low",    amount: 500),
                WagerTier(rank: tier, label: "Mid",    amount: 1_000),
                WagerTier(rank: tier, label: "High",   amount: 2_000),
            ]
        case .diamond:
            return [
                WagerTier(rank: tier, label: "Low",    amount: 1_500),
                WagerTier(rank: tier, label: "Mid",    amount: 3_000),
                WagerTier(rank: tier, label: "High",   amount: 5_000),
            ]
        case .master:
            return [
                WagerTier(rank: tier, label: "Low",    amount: 5_000),
                WagerTier(rank: tier, label: "Mid",    amount: 10_000),
                WagerTier(rank: tier, label: "High",   amount: 25_000),
            ]
        }
    }

    // Maximum wager a player can place given their coins and rank
    static func maxAllowed(coins: Int, tier: RankTier) -> Int {
        let cap = options(for: tier).map(\.amount).max() ?? 0
        return min(coins, cap)
    }
}
