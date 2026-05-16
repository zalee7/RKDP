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
    let totalSeconds: Int
    private let userID: String?
    private let priorBest: Int?
    private var timer: AnyCancellable?

    enum SubmitResult: Equatable {
        case valid(String, Int)
        case invalid
        case alreadyFound
        case tooShort
    }

    init(difficulty: Difficulty, userID: String? = nil, priorBest: Int? = nil, seed: Int? = nil) {
        self.difficulty = difficulty
        self.totalSeconds = seed == nil ? AnagramGame.totalSeconds(for: difficulty) : 60
        self.userID = userID
        self.priorBest = priorBest
        let g = AnagramGame.generate(difficulty: difficulty, seed: seed)
        self.game = g
        self.bank = g.letters.enumerated().map { ($0.offset, $0.element) }
        self.placed = []
        startTimer()
    }

    var timeRemaining: Int { max(0, totalSeconds - elapsedSeconds) }

    // MARK: - Tile actions

    func pickFromBank(id: Int) {
        guard let idx = bank.firstIndex(where: { $0.id == id }) else { return }
        SoundManager.shared.keyboardPress()
        let tile = bank.remove(at: idx)
        placed.append(tile)
    }

    func returnToBank(id: Int) {
        guard let idx = placed.firstIndex(where: { $0.id == id }) else { return }
        SoundManager.shared.keyboardPress()
        let tile = placed.remove(at: idx)
        bank.append(tile)
    }

    func clearPlaced() {
        if !placed.isEmpty { SoundManager.shared.keyboardPress() }
        bank.append(contentsOf: placed)
        placed = []
    }

    func shuffleBank() {
        SoundManager.shared.keyboardPress()
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
            SoundManager.shared.wordInvalid()
            return
        }
        if foundWords.contains(word) {
            lastResult = .alreadyFound
            SoundManager.shared.wordInvalid()
            return
        }
        if game.validWords.contains(word) {
            foundWords.append(word)
            let pts = AnagramGame.score(for: word)
            score += pts
            lastResult = .valid(word, pts)
            SoundManager.shared.wordFound(length: word.count)
        } else {
            lastResult = .invalid
            SoundManager.shared.wordInvalid()
        }
    }

    // MARK: - Hint: reveal one un-found word

    var hintWord: String? {
        game.validWords.subtracting(Set(foundWords)).sorted { $0.count > $1.count }.first
    }

    // MARK: - Timer

    private func startTimer() {
        let total = totalSeconds
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                if self.elapsedSeconds >= total {
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
        Task { try? await FirestoreService.shared.updateBestScore(userID: uid, mode: .anagram, score: score) }
    }

    func stop() { timer?.cancel() }

    var sortedFoundWords: [String] {
        foundWords.sorted { AnagramGame.score(for: $0) > AnagramGame.score(for: $1) }
    }

    var missedWords: [String] {
        Array(game.validWords.subtracting(Set(foundWords))).sorted()
    }
}
