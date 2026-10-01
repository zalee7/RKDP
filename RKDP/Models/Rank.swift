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
            return "\(division.label) \(start) to \(end - 1)"
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

struct BestStat: Codable, Equatable {
    var time: Int? = nil
    var score: Int? = nil
    var moves: Int? = nil
    var progress: Double? = nil
    var guesses: Int? = nil

    static func from(solo result: SoloGameResult) -> BestStat {
        BestStat(
            time: result.completed ? result.elapsedSeconds : nil,
            score: result.score,
            moves: result.moves,
            progress: result.progress,
            guesses: result.completed ? result.guesses : nil
        )
    }

    static func from(match result: MatchPlayerResult, mode: GameMode) -> BestStat {
        BestStat(
            time: result.completed ? result.elapsedSeconds : nil,
            score: (mode.isScoreBased || mode == .gridlock) ? result.score : nil,
            moves: result.moveCount > 0 ? result.moveCount : nil,
            progress: result.progress > 0 ? result.progress : nil,
            guesses: mode.isWordle ? result.totalGuesses : nil
        )
    }

    static func updated(_ current: BestStat?, with candidate: BestStat) -> BestStat {
        guard var best = current else { return candidate }
        if let value = candidate.time {
            best.time = min(best.time ?? Int.max, value)
        }
        if let value = candidate.score {
            best.score = max(best.score ?? 0, value)
        }
        if let value = candidate.moves {
            best.moves = min(best.moves ?? Int.max, value)
        }
        if let value = candidate.progress {
            best.progress = max(best.progress ?? 0, value)
        }
        if let value = candidate.guesses, value > 0 {
            best.guesses = min(best.guesses ?? Int.max, value)
        }
        return best
    }

    func displayText(for mode: GameMode) -> String {
        switch mode {
        case .gridlock:
            if let time { return formattedTime(time) }
            if let score { return "\(score) pts" }
            if let progress { return "\(Int((progress * 100).rounded()))%" }
            if let moves { return "\(moves) moves" }
        case .wordle:
            if let guesses { return "\(guesses) guesses" }
            if let time { return formattedTime(time) }
        case .hangman:
            if let time { return formattedTime(time) }
        case .anagram, .wordHunt:
            if let score { return "\(score) pts" }
        case .colorLink:
            if let time { return formattedTime(time) }
        case .minesweeper:
            if let time { return formattedTime(time) }
            if let progress { return "\(Int((progress * 100).rounded()))%" }
        case .sudoku:
            if let time { return formattedTime(time) }
        }
        return "--"
    }

    private func formattedTime(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

// Unlike legacy aggregate bests, these metrics all belong to the same solo run.
struct SoloPersonalBest: Codable, Equatable {
    var elapsedSeconds: Int
    var score: Int?
    var guesses: Int?
    var wrongGuesses: Int?
    var moves: Int?

    init?(result: SoloGameResult) {
        guard result.completed, result.elapsedSeconds >= 0 else { return nil }
        if result.mode.isScoreBased && (result.score ?? 0) <= 0 { return nil }
        if result.mode == .wordle && (result.guesses ?? 0) <= 0 { return nil }
        if result.mode == .hangman && result.wrongGuesses == nil { return nil }
        elapsedSeconds = result.elapsedSeconds
        score = result.score
        guesses = result.guesses
        wrongGuesses = result.wrongGuesses
        moves = result.moves
    }

    func isBetter(than other: SoloPersonalBest, mode: GameMode) -> Bool {
        switch mode {
        case .anagram, .wordHunt:
            if score != other.score { return (score ?? 0) > (other.score ?? 0) }
        case .wordle:
            if guesses != other.guesses { return (guesses ?? Int.max) < (other.guesses ?? Int.max) }
        case .hangman:
            if wrongGuesses != other.wrongGuesses { return (wrongGuesses ?? Int.max) < (other.wrongGuesses ?? Int.max) }
        case .gridlock:
            if moves != other.moves { return (moves ?? Int.max) < (other.moves ?? Int.max) }
        case .sudoku, .minesweeper, .colorLink:
            break
        }
        return elapsedSeconds < other.elapsedSeconds
    }

    func displayText(for mode: GameMode) -> String {
        let time = "\(elapsedSeconds / 60):\(String(format: "%02d", elapsedSeconds % 60))"
        switch mode {
        case .anagram, .wordHunt: return "\(score ?? 0) pts"
        case .wordle: return "\(guesses ?? 0) guess\((guesses ?? 0) == 1 ? "" : "es") · \(time)"
        case .hangman: return "\(wrongGuesses ?? 0) wrong · \(time)"
        case .gridlock: return "\(moves ?? 0) moves · \(time)"
        default: return time
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
    var soloBest: BestStat? = nil
    var soloBestsByDifficulty: [String: SoloPersonalBest]? = nil
    var onlineBest: BestStat? = nil

    func soloBest(for difficulty: Difficulty) -> SoloPersonalBest? {
        soloBestsByDifficulty?[difficulty.rawValue]
    }

    mutating func recordSoloBest(_ result: SoloGameResult) {
        guard let candidate = SoloPersonalBest(result: result) else { return }
        if let current = soloBest(for: result.difficulty), !candidate.isBetter(than: current, mode: result.mode) { return }
        var records = soloBestsByDifficulty ?? [:]
        records[result.difficulty.rawValue] = candidate
        soloBestsByDifficulty = records
    }

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
