import Foundation

struct WagerTier: Identifiable {
    var id: String { "\(rank.rawValue)-\(label)-\(amount)" }
    let rank: RankTier
    let label: String
    let amount: Int
}

enum Wager {
    static func fixed(for info: RankInfo) -> WagerTier {
        WagerTier(
            rank: info.displayTier,
            label: "Tier",
            amount: amount(for: info.displayTier)
        )
    }

    static func amount(for tier: RankTier) -> Int {
        switch tier {
        case .bronze:   return 35
        case .silver:   return 100
        case .gold:     return 300
        case .platinum: return 900
        case .diamond:  return 2_500
        case .master:   return 7_500
        }
    }

    static func tournamentEntryFee(for tier: RankTier) -> Int {
        switch tier {
        case .bronze:   return 50
        case .silver:   return 150
        case .gold:     return 400
        case .platinum: return 1_000
        case .diamond:  return 2_500
        case .master:   return 6_000
        }
    }

    // Compatibility for older call sites. Ranked UI should use fixed(for:).
    static func options(for tier: RankTier) -> [WagerTier] {
        [WagerTier(rank: tier, label: "Tier", amount: amount(for: tier))]
    }

    static func maxAllowed(coins: Int, tier: RankTier) -> Int {
        min(coins, amount(for: tier))
    }
}
