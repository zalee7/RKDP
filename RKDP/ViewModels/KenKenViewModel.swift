import Foundation
import Combine

@MainActor
final class GridlockViewModel: ObservableObject {
    @Published var board: GridlockBoard
    @Published var elapsedSeconds: Int = 0
    @Published var moveCount: Int = 0
    @Published var isComplete = false

    let difficulty: Difficulty
    private var timer: AnyCancellable?
    private var undoStack: [GridDuelMove] = []

    var progress: Double { board.patternProgress }
    var boardSize: Int { board.size }
    var colorCount: Int { board.colorCount }
    var canUndo: Bool { !undoStack.isEmpty && !isComplete }

    init(difficulty: Difficulty, seed: Int? = nil) {
        self.difficulty = difficulty
        self.board = GridlockGenerator.generate(difficulty: difficulty, seed: seed)
        startTimer()
    }

    func shift(axis: GridDuelAxis, index: Int, steps: Int) {
        guard !isComplete, steps != 0 else { return }
        board.shift(axis: axis, index: index, steps: steps)
        undoStack.append(GridDuelMove(axis: axis, index: index, steps: -steps))
        moveCount += abs(steps)
        SoundManager.shared.keyboardPress()

        if board.isSolved {
            isComplete = true
            timer?.cancel()
            SoundManager.shared.gameOver()
        }
    }

    func undoLastMove() {
        guard canUndo, let move = undoStack.popLast() else { return }
        board.shift(move)
        moveCount = max(0, moveCount - abs(move.steps))
        SoundManager.shared.keyboardPress()
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    func stop() { timer?.cancel() }
}
