import Foundation
import Combine

@MainActor
final class GridlockViewModel: ObservableObject {
    @Published var board: GridlockBoard
    @Published var selectedVehicleID: String?
    @Published var elapsedSeconds: Int = 0
    @Published var moveCount: Int = 0
    @Published var isComplete = false

    let difficulty: Difficulty
    private var timer: AnyCancellable?

    var progress: Double { board.escapeProgress }

    init(difficulty: Difficulty, seed: Int? = nil) {
        self.difficulty = difficulty
        self.board = GridlockGenerator.generate(difficulty: difficulty, seed: seed)
        self.selectedVehicleID = board.target?.id
        startTimer()
    }

    func selectVehicle(id: String) {
        selectedVehicleID = id
    }

    func moveSelected(delta: Int) {
        guard let selectedVehicleID, !isComplete else { return }
        if board.move(vehicleID: selectedVehicleID, delta: delta) {
            moveCount += 1
            if board.isSolved {
                isComplete = true
                timer?.cancel()
            }
        }
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    func stop() { timer?.cancel() }
}
