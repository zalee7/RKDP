import Foundation
import Combine

@MainActor
final class HangmanViewModel: ObservableObject {
    @Published private(set) var game: HangmanGame
    @Published var elapsedSeconds = 0
    @Published var isFinished = false
    @Published var message: String?

    let difficulty: Difficulty
    let totalSeconds: Int?
    private var timer: AnyCancellable?

    init(difficulty: Difficulty, userID: String? = nil, priorBest: Int? = nil, seed: Int? = nil, puzzleData: HangmanPuzzleData? = nil, timed: Bool = false) {
        self.difficulty = difficulty
        self.totalSeconds = timed ? 90 : nil
        let s = seed ?? Int.random(in: 0..<Int.max)
        let puzzle = HangmanGame.puzzle(difficulty: difficulty, seed: s, puzzleData: puzzleData)
        self.game = HangmanGame(
            targetWord: puzzle.word,
            category: puzzle.category,
            maxWrongGuesses: puzzleData?.maxWrongGuesses ?? 6,
            starterLetter: puzzle.starterLetter
        )
        if timed { startTimer() }
    }

    var timeRemaining: Int? {
        guard let totalSeconds else { return nil }
        return max(0, totalSeconds - elapsedSeconds)
    }

    var alphabetRows: [[Character]] {
        [Array("QWERTYUIOP"), Array("ASDFGHJKL"), Array("ZXCVBNM")]
    }

    @discardableResult
    func guess(_ letter: Character) -> Bool {
        guard !isFinished else { return false }
        let accepted = game.guess(letter)
        guard accepted else {
            message = "Already guessed"
            clearMessageSoon()
            return false
        }
        SoundManager.shared.keyboardPress()
        if game.isSolved {
            finish(message: "Puzzle rescued!")
        } else if game.isLost {
            finish(message: "Lava reached the puzzle")
        } else if game.targetWord.contains(letter) {
            message = "Safe letter"
            clearMessageSoon()
        } else {
            message = "Lava rising"
            clearMessageSoon()
            SoundManager.shared.wordInvalid()
        }
        return true
    }

    func stop() { timer?.cancel() }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                if let total = self.totalSeconds, self.elapsedSeconds >= total {
                    self.finish(message: "Time expired")
                }
            }
    }

    private func finish(message: String) {
        guard !isFinished else { return }
        self.message = message
        isFinished = true
        timer?.cancel()
        SoundManager.shared.gameOver()
    }


    private func clearMessageSoon() {
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            if !isFinished { message = nil }
        }
    }
}
