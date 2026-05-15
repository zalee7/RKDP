import SwiftUI

// Routes to the correct game view. In multiplayer, pass seed so both players get identical puzzles.
struct SoloGameView: View {
    let mode: GameMode
    let difficulty: Difficulty
    let user: AppUser?
    var seed: Int? = nil

    var body: some View {
        Group {
            switch mode {
            case .sudoku:
                SudokuView(difficulty: difficulty, sessionID: nil, seed: seed)
            case .minesweeper:
                MinesweeperView(difficulty: difficulty, sessionID: nil, seed: seed)
            case .kakuro:
                KakuroView(difficulty: difficulty, sessionID: nil)
            case .kenken:
                KenKenView(difficulty: difficulty, sessionID: nil)
            case .anagram:
                AnagramView(difficulty: difficulty, user: user)
            case .wordHunt:
                WordHuntView(difficulty: difficulty, user: user)
            case .wordle:
                WordleView(difficulty: difficulty, user: user, seed: seed)
            }
        }
        .environment(\.boardCosmetics, user?.cosmetics ?? .default)
    }
}
