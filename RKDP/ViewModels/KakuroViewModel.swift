import Foundation
import Combine

@MainActor
final class KakuroViewModel: ObservableObject {
    @Published var board: KakuroBoard
    @Published var selectedID: Int?
    @Published var elapsedSeconds: Int = 0
    @Published var isComplete = false
    @Published var isNoteMode = false

    let difficulty: Difficulty
    private var timer: AnyCancellable?

    var progress: Double {
        let entries = board.cells.filter { if case .entry = $0.type { return true }; return false }
        guard !entries.isEmpty else { return isComplete ? 1 : 0 }
        let validFilled = entries.filter { $0.value != 0 && !$0.isInvalid }.count
        return Double(validFilled) / Double(entries.count)
    }

    init(difficulty: Difficulty, seed: Int? = nil) {
        self.difficulty = difficulty
        self.board = KakuroGenerator.generate(difficulty: difficulty, seed: seed)
        startTimer()
    }

    func selectCell(id: Int) {
        guard case .entry = board.cells[id].type else { selectedID = nil; return }
        selectedID = (selectedID == id) ? nil : id
    }

    func enterDigit(_ digit: Int) {
        guard let id = selectedID else { return }
        if isNoteMode {
            if board.cells[id].notes.contains(digit) {
                board.cells[id].notes.remove(digit)
            } else {
                board.cells[id].notes.insert(digit)
            }
        } else {
            board.setValue(digit, at: id)
            if board.isSolved { isComplete = true; timer?.cancel() }
        }
    }

    func erase() {
        guard let id = selectedID else { return }
        board.cells[id].value = 0
        board.cells[id].notes = []
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    func stop() { timer?.cancel() }
}
