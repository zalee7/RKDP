import SwiftUI

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case sudoku
    case minesweeper
    case kakuro
    case kenken
    case anagram
    case wordHunt

    var accentColor: Color { AppTheme.modeAccent(self) }

    var id: String { rawValue }
    var isComingSoon: Bool { false }

    var displayName: String {
        switch self {
        case .sudoku:      return "Sudoku"
        case .minesweeper: return "Minesweeper"
        case .kakuro:      return "Kakuro"
        case .kenken:      return "KenKen"
        case .anagram:     return "Anagram"
        case .wordHunt:    return "Word Hunt"
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
            return "Unscramble the letters to find the hidden word before your opponent."
        case .wordHunt:
            return "Find as many words as possible in the letter grid before time runs out."
        }
    }

    var icon: String {
        switch self {
        case .sudoku:      return "grid"
        case .minesweeper: return "scope"
        case .kakuro:      return "plus.forwardslash.minus"
        case .kenken:      return "function"
        case .anagram:     return "textformat.abc"
        case .wordHunt:    return "magnifyingglass"
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
