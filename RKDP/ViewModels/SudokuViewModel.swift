import Foundation
import Combine

@MainActor
final class SudokuViewModel: ObservableObject {
    @Published var board: SudokuBoard
    @Published var selectedID: Int?
    @Published var elapsedSeconds: Int = 0
    @Published var isComplete = false
    @Published var isNoteMode = false
    @Published var mistakeCount = 0
    @Published private(set) var hintsUsed = 0

    let difficulty: Difficulty
    private let solution: [[Int]]
    private let startingBlankIDs: Set<Int>
    private var timer: AnyCancellable?

    var progress: Double {
        let fillable = board.cells.filter { startingBlankIDs.contains($0.id) }
        guard !fillable.isEmpty else { return isComplete ? 1 : 0 }
        let validFilled = fillable.filter { $0.value != 0 && !$0.isInvalid }.count
        return Double(validFilled) / Double(fillable.count)
    }

    init(difficulty: Difficulty, seed: Int? = nil) {
        self.difficulty = difficulty
        let (puzzle, sol) = SudokuGenerator.generate(difficulty: difficulty, seed: seed)
        let board = SudokuBoard(given: puzzle)
        self.solution = sol
        self.board = board
        self.startingBlankIDs = Set(board.cells.filter { !$0.isGiven }.map(\.id))
        startTimer()
    }

    // MARK: - Input

    func selectCell(id: Int) {
        guard !isComplete, board.cells.indices.contains(id) else { return }
        selectedID = id
        board.updateHighlights(selected: selectedID)
    }

    func enterDigit(_ digit: Int) {
        guard !isComplete, (1...9).contains(digit), let id = selectedID,
              board.cells.indices.contains(id), !board.cells[id].isGiven else { return }
        if isNoteMode {
            if board.cells[id].notes.contains(digit) {
                board.cells[id].notes.remove(digit)
            } else {
                board.cells[id].notes.insert(digit)
            }
        } else {
            let changed = board.cells[id].value != digit
            board.cells[id].value = digit
            board.cells[id].notes = []
            board.markInvalidCells()
            if changed && board.cells[id].isInvalid { mistakeCount += 1 }
            checkCompletion()
        }
    }

    func erase() {
        guard !isComplete, let id = selectedID,
              board.cells.indices.contains(id), !board.cells[id].isGiven else { return }
        board.cells[id].value = 0
        board.cells[id].notes = []
        board.markInvalidCells()
    }

    func useHint() {
        guard !isComplete, let id = selectedID,
              board.cells.indices.contains(id), !board.cells[id].isGiven else { return }
        let row = id / 9, col = id % 9
        guard board.cells[id].value != solution[row][col] else { return }
        hintsUsed += 1
        board.cells[id].value = solution[row][col]
        board.cells[id].isGiven = true
        board.cells[id].notes = []
        board.markInvalidCells()
        checkCompletion()
    }

    // MARK: - State

    private func checkCompletion() {
        if board.isSolved {
            isComplete = true
            timer?.cancel()
        }
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    func stop() { timer?.cancel() }
}
