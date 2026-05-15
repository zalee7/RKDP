import SwiftUI

enum RankTier: Int, Codable, CaseIterable, Comparable {
    case bronze = 0
    case silver = 1
    case gold = 2
    case platinum = 3
    case diamond = 4
    case master = 5

    static func < (lhs: RankTier, rhs: RankTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var displayName: String {
        switch self {
        case .bronze:   return "Bronze"
        case .silver:   return "Silver"
        case .gold:     return "Gold"
        case .platinum: return "Platinum"
        case .diamond:  return "Diamond"
        case .master:   return "Master"
        }
    }

    var color: Color {
        switch self {
        case .bronze:   return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver:   return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .gold:     return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .platinum: return Color(red: 0.6, green: 0.9, blue: 0.9)
        case .diamond:  return Color(red: 0.4, green: 0.7, blue: 1.0)
        case .master:   return Color(red: 0.7, green: 0.2, blue: 0.9)
        }
    }

    var icon: String {
        switch self {
        case .bronze:   return "🥉"
        case .silver:   return "🥈"
        case .gold:     return "🥇"
        case .platinum: return "💠"
        case .diamond:  return "💎"
        case .master:   return "👑"
        }
    }

    var pointsRequired: Int {
        switch self {
        case .bronze:   return 0
        case .silver:   return 500
        case .gold:     return 1500
        case .platinum: return 3500
        case .diamond:  return 7000
        case .master:   return 12000
        }
    }

    static func tier(for points: Int) -> RankTier {
        return allCases.reversed().first { points >= $0.pointsRequired } ?? .bronze
    }
}

enum RankDivision: Int, Codable, CaseIterable {
    case three = 1  // entry level within a tier
    case two   = 2
    case one   = 3  // top of tier (closest to promotion)

    var label: String {
        switch self {
        case .three: return "III"
        case .two:   return "II"
        case .one:   return "I"
        }
    }
}

struct RankInfo: Codable {
    var points: Int
    var tier: RankTier
    var wins: Int
    var losses: Int
    var bestTime: Int?    // best completion time in seconds (time-based modes)
    var bestScore: Int?   // best points total (score-based modes: Anagram, Word Hunt)

    var winRate: Double {
        guard wins + losses > 0 else { return 0 }
        return Double(wins) / Double(wins + losses)
    }

    var pointsToNextTier: Int? {
        guard let next = RankTier(rawValue: tier.rawValue + 1) else { return nil }
        return next.pointsRequired - points
    }

    /// Division within the current tier (III = entry, I = top).
    var division: RankDivision {
        let lo = tier.pointsRequired
        let hi = RankTier(rawValue: tier.rawValue + 1)?.pointsRequired ?? (lo + 1500)
        let span = hi - lo
        let progress = points - lo
        switch progress * 3 / span {
        case 0:  return .three
        case 1:  return .two
        default: return .one
        }
    }

    /// e.g. "Bronze III", "Gold I", "Master I"
    var fullDisplayName: String { "\(tier.displayName) \(division.label)" }

    static let empty = RankInfo(points: 0, tier: .bronze, wins: 0, losses: 0, bestTime: nil, bestScore: nil)
}
