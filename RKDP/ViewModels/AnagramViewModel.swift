import Foundation
import Combine

@MainActor
final class AnagramViewModel: ObservableObject {
    // The puzzle
    @Published private(set) var puzzle: AnagramPuzzle
    // Letters still in the bank (not yet placed)
    @Published private(set) var bank: [(id: Int, letter: Character)]
    // Letters the player has placed as their answer
    @Published private(set) var placed: [(id: Int, letter: Character)]

    @Published var elapsedSeconds: Int = 0
    @Published var isCorrect = false
    @Published var isWrong = false      // flashes red on bad submit
    @Published var penaltySeconds = 0   // accumulated penalty (ranked)
    @Published var showHint = false

    let difficulty: Difficulty
    private var timer: AnyCancellable?

    init(difficulty: Difficulty, seed: Int? = nil) {
        self.difficulty = difficulty
        let p = AnagramPuzzle.generate(difficulty: difficulty, seed: seed)
        self.puzzle = p
        self.bank = p.scrambled.enumerated().map { ($0.offset, $0.element) }
        self.placed = []
        startTimer()
    }

    // MARK: - Player actions

    func pickFromBank(id: Int) {
        guard let idx = bank.firstIndex(where: { $0.id == id }) else { return }
        let tile = bank.remove(at: idx)
        placed.append(tile)
    }

    func returnToBank(id: Int) {
        guard let idx = placed.firstIndex(where: { $0.id == id }) else { return }
        let tile = placed.remove(at: idx)
        bank.append(tile)
    }

    func clearPlaced() {
        bank.append(contentsOf: placed)
        placed = []
    }

    func shuffleBank() {
        bank.shuffle()
    }

    func submit() {
        let attempt = String(placed.map(\.letter))
        if attempt.uppercased() == puzzle.word.uppercased() {
            isCorrect = true
            timer?.cancel()
        } else {
            isWrong = true
            penaltySeconds += 5
            // Flash wrong state then clear
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                isWrong = false
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    func stop() { timer?.cancel() }

    var effectiveTime: Int { elapsedSeconds + penaltySeconds }
}
