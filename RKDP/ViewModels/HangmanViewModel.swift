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
        self.game = HangmanGame(
            targetWord: HangmanGame.targetWord(difficulty: difficulty, seed: s, puzzleData: puzzleData),
            maxWrongGuesses: puzzleData?.maxWrongGuesses ?? 6
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

    func guess(_ letter: Character) {
        guard !isFinished else { return }
        let accepted = game.guess(letter)
        guard accepted else {
            message = "Already guessed"
            clearMessageSoon()
            return
        }
        SoundManager.shared.keyboardPress()
        if game.isSolved {
            finish(message: "Rescued!")
        } else if game.isLost {
            finish(message: "The word was \(game.targetWord)")
        } else if game.targetWord.contains(letter) {
            message = "Nice guess"
            clearMessageSoon()
        } else {
            message = "Miss"
            clearMessageSoon()
            SoundManager.shared.wordInvalid()
        }
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
