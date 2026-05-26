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
        case .bronze:   return Color(red: 0.70, green: 0.38, blue: 0.14)
        case .silver:   return Color(red: 0.45, green: 0.48, blue: 0.52)
        case .gold:     return Color(red: 0.78, green: 0.53, blue: 0.02)
        case .platinum: return Color(red: 0.10, green: 0.58, blue: 0.62)
        case .diamond:  return Color(red: 0.12, green: 0.42, blue: 0.84)
        case .master:   return Color(red: 0.58, green: 0.16, blue: 0.78)
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
        case .silver:   return 600
        case .gold:     return 1800
        case .platinum: return 3600
        case .diamond:  return 7200
        case .master:   return 12000
        }
    }

    var nextTier: RankTier? {
        RankTier(rawValue: rawValue + 1)
    }

    var divisionSize: Int {
        if let nextTier { return max(1, (nextTier.pointsRequired - pointsRequired) / 3) }
        return 500
    }

    func iconAssetName(division: RankDivision? = nil) -> String {
        let tierName: String
        switch self {
        case .bronze:   tierName = "Bronze"
        case .silver:   tierName = "Silver"
        case .gold:     tierName = "Gold"
        case .platinum: tierName = "Platinum"
        case .diamond:  tierName = "Diamond"
        case .master:   tierName = "Master"
        }
        return "Rank\(tierName)\((division ?? .one).assetSuffix)"
    }

    func division(for points: Int) -> RankDivision {
        let progress = max(0, points - pointsRequired)
        switch progress / divisionSize {
        case 0:  return .three
        case 1:  return .two
        default: return .one
        }
    }

    func divisionStart(for division: RankDivision) -> Int {
        pointsRequired + division.index * divisionSize
    }

    func divisionEndExclusive(for division: RankDivision) -> Int? {
        if self == .master && division == .one { return nil }
        return pointsRequired + (division.index + 1) * divisionSize
    }

    func divisionRangeLabel(for division: RankDivision) -> String {
        let start = divisionStart(for: division)
        if let end = divisionEndExclusive(for: division) {
            return "\(division.label) \(start)-\(end - 1)"
        }
        return "\(division.label) \(start)+"
    }

    static func tier(for points: Int) -> RankTier {
        return allCases.reversed().first { points >= $0.pointsRequired } ?? .bronze
    }
}

enum RankDivision: Int, Codable, CaseIterable {
    case three = 1  // entry level within a tier
    case two   = 2
    case one   = 3  // top of tier (closest to promotion)

    static let progression: [RankDivision] = [.three, .two, .one]

    var index: Int { rawValue - 1 }

    var label: String {
        switch self {
        case .three: return "III"
        case .two:   return "II"
        case .one:   return "I"
        }
    }

    var assetSuffix: String {
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
    var bestMoves: Int? = nil
    var bestProgress: Double? = nil
    var bestGuesses: Int? = nil

    var winRate: Double {
        guard wins + losses > 0 else { return 0 }
        return Double(wins) / Double(wins + losses)
    }

    var displayTier: RankTier {
        RankTier.tier(for: points)
    }

    var pointsToNextTier: Int? {
        guard let next = displayTier.nextTier else { return nil }
        return max(0, next.pointsRequired - points)
    }

    /// Division within the current tier (III = entry, I = top).
    var division: RankDivision {
        displayTier.division(for: points)
    }

    var divisionStart: Int {
        displayTier.divisionStart(for: division)
    }

    var nextDivisionBoundary: Int? {
        displayTier.divisionEndExclusive(for: division)
    }

    var divisionProgress: Double {
        guard let boundary = nextDivisionBoundary else { return 1 }
        let span = max(1, boundary - divisionStart)
        let done = max(0, min(span, points - divisionStart))
        return Double(done) / Double(span)
    }

    var divisionProgressDisplay: String {
        guard let boundary = nextDivisionBoundary else { return "\(points)+ pts" }
        return "\(points) / \(boundary)"
    }

    var nextRankStepText: String {
        guard let boundary = nextDivisionBoundary else { return "Top division" }
        let remaining = max(0, boundary - points)
        let nextName: String
        switch division {
        case .three:
            nextName = "\(displayTier.displayName) II"
        case .two:
            nextName = "\(displayTier.displayName) I"
        case .one:
            if let nextTier = displayTier.nextTier {
                nextName = "\(nextTier.displayName) III"
            } else {
                nextName = "Top division"
            }
        }
        return "\(remaining) pts to \(nextName)"
    }

    /// e.g. "Bronze III", "Gold I", "Master I"
    var fullDisplayName: String { "\(displayTier.displayName) \(division.label)" }

    /// Compact ranked record, shown as wins-losses.
    var recordDisplay: String { "\(wins)-\(losses)" }

    static let empty = RankInfo(
        points: 0,
        tier: .bronze,
        wins: 0,
        losses: 0,
        bestTime: nil,
        bestScore: nil,
        bestMoves: nil,
        bestProgress: nil,
        bestGuesses: nil
    )
}
