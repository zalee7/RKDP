import Foundation
import Combine

@MainActor
final class AnagramViewModel: ObservableObject {
    @Published private(set) var game: AnagramGame
    @Published private(set) var bank: [(id: Int, letter: Character)]   // letters still available
    @Published private(set) var placed: [(id: Int, letter: Character)] // current word being built
    @Published private(set) var foundWords: [String] = []
    @Published private(set) var score = 0
    @Published var elapsedSeconds = 0
    @Published var isFinished = false
    @Published var lastResult: SubmitResult?
    @Published var showHint = false

    let difficulty: Difficulty
    private var timer: AnyCancellable?

    enum SubmitResult: Equatable {
        case valid(String, Int)
        case invalid
        case alreadyFound
        case tooShort
    }

    init(difficulty: Difficulty, seed: Int? = nil) {
        self.difficulty = difficulty
        let g = AnagramGame.generate(difficulty: difficulty, seed: seed)
        self.game = g
        self.bank = g.letters.enumerated().map { ($0.offset, $0.element) }
        self.placed = []
        startTimer()
    }

    var timeRemaining: Int { max(0, AnagramGame.totalSeconds(for: difficulty) - elapsedSeconds) }
    var totalSeconds: Int { AnagramGame.totalSeconds(for: difficulty) }

    // MARK: - Tile actions

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

    // MARK: - Submit current word

    func submit() {
        let word = String(placed.map(\.letter)).uppercased()

        defer {
            clearPlaced()
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                lastResult = nil
            }
        }

        if word.count < 3 {
            lastResult = .tooShort
            return
        }
        if foundWords.contains(word) {
            lastResult = .alreadyFound
            return
        }
        if game.validWords.contains(word) {
            foundWords.append(word)
            let pts = AnagramGame.score(for: word)
            score += pts
            lastResult = .valid(word, pts)
        } else {
            lastResult = .invalid
        }
    }

    // MARK: - Hint: reveal one un-found word

    var hintWord: String? {
        game.validWords.subtracting(Set(foundWords)).sorted { $0.count > $1.count }.first
    }

    // MARK: - Timer

    private func startTimer() {
        let total = AnagramGame.totalSeconds(for: difficulty)
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                if self.elapsedSeconds >= total {
                    self.isFinished = true
                    self.timer?.cancel()
                }
            }
    }

    func stop() { timer?.cancel() }

    var sortedFoundWords: [String] {
        foundWords.sorted { AnagramGame.score(for: $0) > AnagramGame.score(for: $1) }
    }

    var missedWords: [String] {
        Array(game.validWords.subtracting(Set(foundWords))).sorted()
    }
}
