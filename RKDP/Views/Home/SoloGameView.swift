import SwiftUI

// Routes to the correct game view. In multiplayer, pass seed so both players get identical puzzles.
struct SoloGameView: View {
    let mode: GameMode
    let difficulty: Difficulty
    let user: AppUser?
    var sessionID: String? = nil
    var seed: Int? = nil
    var onMatchResult: (MatchPlayerResult) -> Void = { _ in }

    var body: some View {
        Group {
            switch mode {
            case .sudoku:
                SudokuView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: seed, onMatchResult: onMatchResult)
            case .minesweeper:
                MinesweeperView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: seed, onMatchResult: onMatchResult)
            case .colorLink:
                ColorLinkView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: seed, onMatchResult: onMatchResult)
            case .gridlock:
                GridlockView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: seed, onMatchResult: onMatchResult)
            case .anagram:
                AnagramView(difficulty: difficulty, user: user, sessionID: sessionID, seed: seed, onMatchResult: onMatchResult)
            case .wordHunt:
                WordHuntView(difficulty: difficulty, user: user, sessionID: sessionID, seed: seed, onMatchResult: onMatchResult)
            case .wordle:
                WordleView(difficulty: difficulty, user: user, sessionID: sessionID, seed: seed, onMatchResult: onMatchResult)
            }
        }
        .environment(\.boardCosmetics, user?.cosmetics ?? .default)
    }
}
