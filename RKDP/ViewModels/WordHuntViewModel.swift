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
    private let userID: String?
    private let priorBest: Int?

    private var timer: AnyCancellable?
    private var feedbackTask: Task<Void, Never>?

    enum WordResult: Equatable {
        case valid(String, Int)
        case invalid
        case alreadyFound
    }

    init(difficulty: Difficulty, userID: String? = nil, priorBest: Int? = nil, seed: Int? = nil, puzzleData: WordHuntPuzzleData? = nil) {
        self.difficulty = difficulty
        self.userID = userID
        self.priorBest = priorBest
        let s = seed ?? Int.random(in: 0..<Int.max)
        if let puzzleData,
           let grid = Self.grid(from: puzzleData) {
            let validWords = puzzleData.validWords.map { Set($0.map { $0.uppercased() }) }
            self.game = WordHuntGame(grid: grid, seed: s, validWords: validWords)
        } else {
            self.game = WordHuntGame.generate(difficulty: difficulty, seed: s)
        }
        self.totalSeconds = 75
        startTimer()
    }

    var timeRemaining: Int { max(0, totalSeconds - elapsedSeconds) }

    private static func grid(from puzzleData: WordHuntPuzzleData) -> [[Character]]? {
        let rows = puzzleData.gridRows.map { Array($0.uppercased()) }
        guard let size = rows.first?.count,
              (4...7).contains(size),
              rows.count == size,
              rows.allSatisfy({ $0.count == size }) else { return nil }
        return rows
    }

    // MARK: - Path tracing

    func startPath(row: Int, col: Int) {
        guard !isFinished, (0..<game.size).contains(row), (0..<game.size).contains(col) else { return }
        SoundManager.shared.keyboardPress()
        currentPath = [(row, col)]
        currentWord = String(game.grid[row][col])
    }

    func extendPath(row: Int, col: Int) {
        guard !isFinished, !currentPath.isEmpty,
              (0..<game.size).contains(row), (0..<game.size).contains(col) else { return }

        guard !currentPath.contains(where: { $0.row == row && $0.col == col }) else { return }

        let last = currentPath.last!
        guard abs(last.row - row) <= 1, abs(last.col - col) <= 1 else { return }

        SoundManager.shared.keyboardPress()
        currentPath.append((row, col))
        currentWord.append(game.grid[row][col])
    }

    func submitPath() {
        let word = currentWord
        defer {
            currentPath = []
            currentWord = ""
        }
        guard !isFinished, word.count >= 3 else { return }

        if foundWords.contains(word) {
            lastWordResult = .alreadyFound
            SoundManager.shared.wordAlreadyUsed()
        } else if game.validWords.contains(word) {
            foundWords.append(word)
            let pts = WordHuntGame.score(for: word)
            score += pts
            lastWordResult = .valid(word, pts)
            SoundManager.shared.wordFound(length: word.count)
        } else {
            lastWordResult = .invalid
            SoundManager.shared.wordInvalid()
        }

        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 800_000_000) } catch { return }
            self?.lastWordResult = nil
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
                    self.cancelPath()
                    self.isFinished = true
                    self.timer?.cancel()
                    SoundManager.shared.gameOver()
                    SoundManager.shared.resetCombo()
                    self.saveBestScoreIfBeaten()
                }
            }
    }

    private func saveBestScoreIfBeaten() {
        guard let uid = userID, score > (priorBest ?? -1) else { return }
        Task { try? await FirestoreService.shared.updateBestScore(userID: uid, mode: .wordHunt, score: score) }
    }

    func stop() {
        timer?.cancel()
        feedbackTask?.cancel()
    }

    var sortedFoundWords: [String] {
        foundWords.sorted { WordHuntGame.score(for: $0) > WordHuntGame.score(for: $1) }
    }

    var missedWords: [String] {
        Array(game.validWords.subtracting(Set(foundWords))).sorted()
    }
}
