import Foundation

// Retained for the hidden tournament feature. Ranked play no longer uses wagers.
enum Wager {
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

}
