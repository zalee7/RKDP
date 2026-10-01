import Foundation
import Combine

@MainActor
final class MinesweeperViewModel: ObservableObject {
    @Published var board: MinesweeperBoard
    @Published var elapsedSeconds: Int = 0
    @Published var isFlagMode = false

    let difficulty: Difficulty
    private let seed: Int?
    private let ranked: Bool
    private var started = false
    private(set) var firstCell: Int?
    private var timer: AnyCancellable?

    var status: MinesweeperStatus { board.status }
    var isFinished: Bool { board.status == .won || board.status == .lost }

    init(difficulty: Difficulty, seed: Int? = nil, ranked: Bool = false) {
        self.difficulty = difficulty
        self.seed = seed
        self.ranked = ranked
        var b = MinesweeperBoard(config: MinesweeperConfig.from(difficulty))
        b.seed = seed
        board = b
        if ranked {
            started = true
            firstCell = (board.config.rows / 2) * board.config.cols + board.config.cols / 2
            board.firstReveal(row: board.config.rows / 2, col: board.config.cols / 2)
            startTimer()
        }
    }

    func tap(row: Int, col: Int) {
        guard !isFinished, (0..<board.config.rows).contains(row), (0..<board.config.cols).contains(col) else { return }
        if isFlagMode {
            board.toggleFlag(row: row, col: col)
            return
        }
        if !started {
            guard board.cells[row * board.config.cols + col].state != .flagged else { return }
            started = true
            firstCell = row * board.config.cols + col
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
        guard !isFinished, (0..<board.config.rows).contains(row), (0..<board.config.cols).contains(col) else { return }
        board.toggleFlag(row: row, col: col)
    }

    func restart() {
        guard !ranked else { return }
        board = MinesweeperBoard(config: MinesweeperConfig.from(difficulty))
        board.seed = seed
        elapsedSeconds = 0
        isFlagMode = false
        started = false
        firstCell = nil
        timer?.cancel()
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    func stop() { timer?.cancel() }
}
