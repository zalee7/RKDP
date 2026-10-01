import SwiftUI

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case sudoku
    case minesweeper
    case colorLink
    case gridlock
    case anagram
    case wordHunt
    case wordle
    case hangman

    var accentColor: Color { AppTheme.modeAccent(self) }

    static var allCases: [GameMode] {
        [.colorLink, .gridlock, .sudoku, .minesweeper, .wordle, .hangman, .wordHunt, .anagram]
    }

    var id: String { rawValue }
    var isComingSoon: Bool { false }

    var displayName: String {
        switch self {
        case .sudoku:      return "Sudoku"
        case .minesweeper: return "Minesweeper"
        case .colorLink:   return "Color Link"
        case .gridlock:    return "Solitaire"
        case .anagram:     return "Anagrams"
        case .wordHunt:    return "Word Hunt"
        case .wordle:      return "Word Guess"
        case .hangman:     return "Lava Rescue"
        }
    }

    var description: String {
        switch self {
        case .sudoku:
            return "Fill the 9×9 grid so every row, column, and 3×3 box contains digits 1–9."
        case .minesweeper:
            return "Uncover every safe cell without triggering a mine."
        case .colorLink:
            return "Connect matching colors with paths that cover the board."
        case .gridlock:
            return "Play classic Klondike Solitaire: build all four foundations from Ace to King."
        case .anagram:
            return "Make the most valid words from the letters. Longer words score more."
        case .wordHunt:
            return "Find as many words as possible before time runs out. Difficulty changes board size only."
        case .wordle:
            return "Guess the hidden 5-letter word within the guess limit. Green = right spot, Yellow = wrong spot."
        case .hangman:
            return "Use the category and starter letter to rescue the puzzle piece before lava fills the arena."
        }
    }

    var icon: String {
        switch self {
        case .sudoku:      return "grid"
        case .minesweeper: return "scope"
        case .colorLink:   return "point.3.connected.trianglepath.dotted"
        case .gridlock:    return "suit.spade.fill"
        case .anagram:     return "textformat.abc"
        case .wordHunt:    return "magnifyingglass"
        case .wordle:      return "character.cursor.ibeam"
        case .hangman:     return "flame.fill"
        }
    }

    var isScoreBased: Bool { self == .anagram || self == .wordHunt }
    var isWordle: Bool { self == .wordle }

    var winConditionText: String {
        switch self {
        case .sudoku:      return "Complete the puzzle; progress then time break timeout ties"
        case .minesweeper: return "Avoid mines; clears, safe cells, then time decide"
        case .colorLink:   return "Complete the board; fill, pairs, then time break ties"
        case .gridlock:    return "Build all foundations; foundation progress, score, moves, then time decide"
        case .anagram:     return "Timer ends; score, word count, then longest word decide"
        case .wordHunt:    return "Timer ends; score, word count, then longest word decide"
        case .wordle:      return "Most words solved, then fewer guesses; equal guesses go to the faster finish"
        case .hangman:     return "Most words rescued, then fewer wrong letters; time breaks remaining ties"
        }
    }

    var defaultDifficulty: Difficulty {
        self == .wordle ? .medium : .easy
    }

    var onlinePresetDifficulty: Difficulty {
        switch self {
        case .sudoku, .minesweeper:
            return .medium
        case .colorLink:
            return .expert
        case .gridlock:
            return .easy
        case .anagram:
            return .medium
        case .wordHunt:
            return .easy
        case .wordle:
            return .medium
        case .hangman:
            return .medium
        }
    }

    func pointMultiplier(for difficulty: Difficulty) -> Double {
        if self == .wordle {
            switch difficulty {
            case .easy:   return 0.8
            case .medium: return 1.0
            case .hard:   return 1.5
            case .expert: return 2.0
            }
        }
        return difficulty.pointMultiplier
    }
}

enum Difficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard
    case expert

    var displayName: String { rawValue.capitalized }

    var previous: Difficulty? {
        switch self {
        case .easy: return nil
        case .medium: return .easy
        case .hard: return .medium
        case .expert: return .hard
        }
    }

    var next: Difficulty? {
        switch self {
        case .easy: return .medium
        case .medium: return .hard
        case .hard: return .expert
        case .expert: return nil
        }
    }

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
    var soloCompletionRequirement: String {
        switch self {
        case .sudoku: return "Fill the Sudoku correctly to complete this difficulty."
        case .minesweeper: return "Reveal every safe cell without hitting a mine."
        case .colorLink: return "Connect every pair and fill the entire board."
        case .gridlock: return "Move all 52 cards to the four foundations."
        case .anagram, .wordHunt: return "Find at least one word and finish the timer."
        case .wordle: return "Solve the word within the guess limit."
        case .hangman: return "Rescue the word before the lava reaches the puzzle."
        }
    }

    var soloTimingDescription: String {
        switch self {
        case .anagram: return "60-second round"
        case .wordHunt: return "75-second round"
        case .hangman: return "Untimed"
        default: return "No time limit"
        }
    }

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
        if self == .wordHunt {
            switch d {
            case .easy:   return "4×4 Board"
            case .medium: return "5×5 Board"
            case .hard:   return "6×6 Board"
            case .expert: return "7×7 Board"
            }
        }
        if self == .hangman {
            switch d {
            case .easy:   return "5 Letters"
            case .medium: return "6 Letters"
            case .hard:   return "7 Letters"
            case .expert: return "8+ Letters"
            }
        }
        if self == .gridlock {
            switch d {
            case .easy:   return "Draw 1"
            case .medium: return "Draw 3"
            case .hard:   return "Draw 3 · 3 Redeals"
            case .expert: return "Draw 3 · 1 Redeal"
            }
        }
        return d.displayName
    }

    var rankedDifficulties: [Difficulty] {
        [onlinePresetDifficulty]
    }

    func rankedLockReason(for difficulty: Difficulty) -> String? {
        rankedDifficulties.contains(difficulty) ? nil : "Ranked uses \(rankedDifficulties.map { difficultyLabel($0) }.joined(separator: ", "))"
    }

    var casualDifficulties: [Difficulty] {
        rankedDifficulties
    }

    func casualLockReason(for difficulty: Difficulty) -> String? {
        casualDifficulties.contains(difficulty) ? nil : "Casual uses \(casualDifficulties.map { difficultyLabel($0) }.joined(separator: ", "))"
    }
}
