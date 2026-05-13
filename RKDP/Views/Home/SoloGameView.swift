import SwiftUI

// Routes to the correct game view in solo (unranked) mode
struct SoloGameView: View {
    let mode: GameMode
    let difficulty: Difficulty

    var body: some View {
        switch mode {
        case .sudoku:
            SudokuView(difficulty: difficulty, sessionID: nil)
        case .minesweeper:
            MinesweeperView(difficulty: difficulty, sessionID: nil)
        case .kakuro:
            KakuroView(difficulty: difficulty, sessionID: nil)
        case .kenken:
            KenKenView(difficulty: difficulty, sessionID: nil)
        case .anagram:
            // Placeholder until Anagram is implemented
            ContentUnavailableView("Coming Soon", systemImage: "textformat.abc", description: Text("Anagram mode is in development."))
        }
    }
}
