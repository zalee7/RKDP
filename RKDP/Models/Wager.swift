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
            label: "Division",
            amount: amount(for: info.displayTier, division: info.division)
        )
    }

    static func amount(for tier: RankTier, division: RankDivision) -> Int {
        switch tier {
        case .bronze:
            switch division {
            case .three: return 25
            case .two:   return 35
            case .one:   return 50
            }
        case .silver:
            switch division {
            case .three: return 75
            case .two:   return 100
            case .one:   return 150
            }
        case .gold:
            switch division {
            case .three: return 225
            case .two:   return 300
            case .one:   return 450
            }
        case .platinum:
            switch division {
            case .three: return 650
            case .two:   return 900
            case .one:   return 1_200
            }
        case .diamond:
            switch division {
            case .three: return 1_800
            case .two:   return 2_500
            case .one:   return 3_500
            }
        case .master:
            switch division {
            case .three: return 5_000
            case .two:   return 7_500
            case .one:   return 10_000
            }
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
        [WagerTier(rank: tier, label: "Division", amount: amount(for: tier, division: .three))]
    }

    static func maxAllowed(coins: Int, tier: RankTier) -> Int {
        min(coins, amount(for: tier, division: .one))
    }
}
