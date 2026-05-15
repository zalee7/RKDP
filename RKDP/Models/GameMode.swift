import SwiftUI

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case sudoku
    case minesweeper
    case kakuro
    case kenken
    case anagram
    case wordHunt
    case wordle

    var accentColor: Color { AppTheme.modeAccent(self) }

    var id: String { rawValue }
    var isComingSoon: Bool { false }

    var displayName: String {
        switch self {
        case .sudoku:      return "Sudoku"
        case .minesweeper: return "Minesweeper"
        case .kakuro:      return "Kakuro"
        case .kenken:      return "KenKen"
        case .anagram:     return "Anagrams"
        case .wordHunt:    return "Word Hunt"
        case .wordle:      return "Wordle"
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
        case .wordle:
            return "Guess the hidden 5-letter word in up to 6 tries. Green = right spot, Yellow = wrong spot."
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
        case .wordle:      return "character.cursor.ibeam"
        }
    }

    var isScoreBased: Bool { self == .anagram || self == .wordHunt }
    var isWordle: Bool { self == .wordle }

    var winConditionText: String {
        switch self {
        case .sudoku:      return "Fastest to complete the puzzle wins"
        case .minesweeper: return "Most cells uncovered wins (fastest if both finish)"
        case .kakuro:      return "Fastest to complete the grid wins"
        case .kenken:      return "Fastest to complete the grid wins"
        case .anagram:     return "Most points from words wins"
        case .wordHunt:    return "Most points from found words wins"
        case .wordle:      return "First to solve the word wins"
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

extension GameMode {
    /// Difficulty label customised per mode — Anagram shows letter count instead of Easy/Hard.
    func difficultyLabel(_ d: Difficulty) -> String {
        if self == .anagram {
            switch d {
            case .easy:   return "6 Letters"
            case .medium: return "7 Letters"
            case .hard:   return "8 Letters"
            case .expert: return "9 Letters"
            }
        }
        if self == .wordle {
            switch d {
            case .easy:   return "7 Guesses"
            case .medium: return "6 Guesses"
            case .hard:   return "5 Guesses"
            case .expert: return "4 Guesses"
            }
        }
        return d.displayName
    }
}
