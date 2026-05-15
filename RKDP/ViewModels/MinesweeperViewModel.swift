import Foundation
import Combine

@MainActor
final class MinesweeperViewModel: ObservableObject {
    @Published var board: MinesweeperBoard
    @Published var elapsedSeconds: Int = 0
    @Published var isFlagMode = false

    let difficulty: Difficulty
    private var started = false
    private var timer: AnyCancellable?

    var status: MinesweeperStatus { board.status }
    var isFinished: Bool { board.status == .won || board.status == .lost }

    init(difficulty: Difficulty, seed: Int? = nil) {
        self.difficulty = difficulty
        var b = MinesweeperBoard(config: MinesweeperConfig.from(difficulty))
        b.seed = seed
        board = b
    }

    func tap(row: Int, col: Int) {
        guard !isFinished else { return }
        if isFlagMode {
            board.toggleFlag(row: row, col: col)
            return
        }
        if !started {
            started = true
            board.firstReveal(row: row, col: col)
            startTimer()
        } else {
            let idx = row * board.config.cols + col
            if case .revealed = board.cells[idx].state {
                board.chord(row: row, col: col)
            } else {
                board.reveal(row: row, col: col)
            }
        }
        if isFinished { timer?.cancel() }
    }

    func longPress(row: Int, col: Int) {
        guard !isFinished else { return }
        board.toggleFlag(row: row, col: col)
    }

    func restart() {
        board = MinesweeperBoard(config: MinesweeperConfig.from(difficulty))
        elapsedSeconds = 0
        started = false
        timer?.cancel()
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    func stop() { timer?.cancel() }
}
