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

    func moveVehicle(id vehicleID: String, steps: Int) {
        guard !isComplete, steps != 0 else { return }
        selectedVehicleID = vehicleID
        let direction = steps > 0 ? 1 : -1
        for _ in 0..<abs(steps) {
            guard board.move(vehicleID: vehicleID, delta: direction) else { break }
            moveCount += 1
            if board.isSolved {
                isComplete = true
                timer?.cancel()
                break
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
