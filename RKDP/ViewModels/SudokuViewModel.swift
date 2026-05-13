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

    let difficulty: Difficulty
    private let solution: [[Int]]
    private var timer: AnyCancellable?

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        let (puzzle, sol) = SudokuGenerator.generate(difficulty: difficulty)
        self.solution = sol
        self.board = SudokuBoard(given: puzzle)
        startTimer()
    }

    // MARK: - Input

    func selectCell(id: Int) {
        selectedID = (selectedID == id) ? nil : id
        board.updateHighlights(selected: selectedID)
    }

    func enterDigit(_ digit: Int) {
        guard let id = selectedID, !board.cells[id].isGiven else { return }
        if isNoteMode {
            if board.cells[id].notes.contains(digit) {
                board.cells[id].notes.remove(digit)
            } else {
                board.cells[id].notes.insert(digit)
            }
        } else {
            board.cells[id].value = digit
            board.cells[id].notes = []
            board.markInvalidCells()
            checkCompletion()
        }
    }

    func erase() {
        guard let id = selectedID, !board.cells[id].isGiven else { return }
        board.cells[id].value = 0
        board.cells[id].notes = []
        board.markInvalidCells()
    }

    func useHint() {
        guard let id = selectedID else { return }
        let row = id / 9, col = id % 9
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
