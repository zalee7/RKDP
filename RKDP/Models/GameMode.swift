import SwiftUI

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case sudoku
    case minesweeper
    case kakuro
    case kenken
    case anagram

    var id: String { rawValue }

    var isComingSoon: Bool { false }

    var displayName: String {
        switch self {
        case .sudoku:      return "Sudoku"
        case .minesweeper: return "Minesweeper"
        case .kakuro:      return "Kakuro"
        case .kenken:      return "KenKen"
        case .anagram:     return "Anagram"
        }
    }

    var description: String {
        switch self {
        case .sudoku:
            return "Fill the 9×9 grid so every row, column, and 3×3 box contains digits 1–9."
        case .minesweeper:
            return "Uncover every safe cell without triggering a mine."
        case .kakuro:
            return "Fill the grid so each run of cells sums to the clue with no repeated digits."
        case .kenken:
            return "Place digits in each row and column; each cage must hit its arithmetic target."
        case .anagram:
            return "Unscramble words faster than your opponent in this ranked word battle."
        }
    }

    var icon: String {
        switch self {
        case .sudoku:      return "grid"
        case .minesweeper: return "scope"
        case .kakuro:      return "plus.forwardslash.minus"
        case .kenken:      return "function"
        case .anagram:     return "textformat.abc"
        }
    }

    var accentColor: Color {
        switch self {
        case .sudoku:      return .blue
        case .minesweeper: return .red
        case .kakuro:      return .green
        case .kenken:      return .orange
        case .anagram:     return .pink
        }
    }
}

enum Difficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard
    case expert

    var displayName: String { rawValue.capitalized }

    var pointMultiplier: Double {
        switch self {
        case .easy:   return 1.0
        case .medium: return 1.5
        case .hard:   return 2.5
        case .expert: return 4.0
        }
    }

    var sudokuClues: Int {
        switch self {
        case .easy:   return 45
        case .medium: return 35
        case .hard:   return 27
        case .expert: return 22
        }
    }
}
