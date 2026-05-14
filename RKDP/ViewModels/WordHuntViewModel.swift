import Foundation
import Combine

@MainActor
final class WordHuntViewModel: ObservableObject {
    // Game state
    @Published private(set) var game: WordHuntGame
    @Published private(set) var foundWords: [String] = []
    @Published private(set) var score = 0
    @Published private(set) var currentPath: [(row: Int, col: Int)] = []
    @Published private(set) var currentWord = ""
    @Published var elapsedSeconds = 0
    @Published var isFinished = false
    @Published var lastWordResult: WordResult?

    let difficulty: Difficulty
    let totalSeconds: Int

    private var timer: AnyCancellable?

    enum WordResult: Equatable {
        case valid(String, Int)
        case invalid
        case alreadyFound
    }

    init(difficulty: Difficulty, seed: Int? = nil) {
        self.difficulty = difficulty
        let s = seed ?? Int.random(in: 0..<Int.max)
        self.game = WordHuntGame.generate(seed: s)
        switch difficulty {
        case .easy:   totalSeconds = 120
        case .medium: totalSeconds = 90
        case .hard:   totalSeconds = 75
        case .expert: totalSeconds = 60
        }
        startTimer()
    }

    var timeRemaining: Int { max(0, totalSeconds - elapsedSeconds) }

    // MARK: - Path tracing

    func startPath(row: Int, col: Int) {
        currentPath = [(row, col)]
        currentWord = String(game.grid[row][col])
    }

    func extendPath(row: Int, col: Int) {
        guard !currentPath.isEmpty else { return }
        guard !currentPath.contains(where: { $0.row == row && $0.col == col }) else { return }

        let last = currentPath.last!
        let isAdjacent = abs(last.row - row) <= 1 && abs(last.col - col) <= 1
        guard isAdjacent else { return }

        currentPath.append((row, col))
        currentWord.append(game.grid[row][col])
    }

    func submitPath() {
        let word = currentWord
        defer {
            currentPath = []
            currentWord = ""
        }
        guard word.count >= 3 else { return }

        if foundWords.contains(word) {
            lastWordResult = .alreadyFound
        } else if game.validWords.contains(word) {
            foundWords.append(word)
            let pts = WordHuntGame.score(for: word)
            score += pts
            lastWordResult = .valid(word, pts)
        } else {
            lastWordResult = .invalid
        }

        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            lastWordResult = nil
        }
    }

    func cancelPath() {
        currentPath = []
        currentWord = ""
    }

    func isInPath(row: Int, col: Int) -> Bool {
        currentPath.contains { $0.row == row && $0.col == col }
    }

    func pathIndex(row: Int, col: Int) -> Int? {
        currentPath.firstIndex { $0.row == row && $0.col == col }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                if self.elapsedSeconds >= self.totalSeconds {
                    self.isFinished = true
                    self.timer?.cancel()
                }
            }
    }

    func stop() { timer?.cancel() }

    var sortedFoundWords: [String] {
        foundWords.sorted { WordHuntGame.score(for: $0) > WordHuntGame.score(for: $1) }
    }

    var missedWords: [String] {
        Array(game.validWords.subtracting(Set(foundWords))).sorted()
    }
}
