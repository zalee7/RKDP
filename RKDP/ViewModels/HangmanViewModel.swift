import Foundation
import Combine

struct HangmanRoundResult {
    let targetWord: String
    let category: String
    let starterLetter: Character
    let correctLetters: Set<Character>
    let wrongLetters: Set<Character>
    let wrongGuessCount: Int
    let revealedPattern: String
    let revealedUniqueCount: Int
    let maxWrongGuesses: Int
    let elapsedSeconds: Int
    let solved: Bool
    let guessHistory: String
}

@MainActor
final class HangmanViewModel: ObservableObject {
    @Published private(set) var game: HangmanGame
    @Published var elapsedSeconds = 0
    @Published var isFinished = false
    @Published var message: String?
    @Published private(set) var roundResults: [HangmanRoundResult] = []
    @Published private(set) var currentRound = 0

    let difficulty: Difficulty
    let totalSeconds: Int?
    let totalRounds: Int
    private let puzzles: [HangmanPuzzle]
    private let maxWrongGuesses: Int
    private(set) var rewardGuessHistory = ""
    private var currentRoundGuessHistory = ""
    private var timer: AnyCancellable?

    init(difficulty: Difficulty, userID: String? = nil, priorBest: Int? = nil, seed: Int? = nil, puzzleData: HangmanPuzzleData? = nil, timed: Bool = false) {
        self.difficulty = difficulty
        self.totalSeconds = timed ? 90 : nil
        let s = seed ?? Int.random(in: 0..<Int.max)
        self.maxWrongGuesses = puzzleData?.maxWrongGuesses ?? 6
        self.puzzles = Self.makePuzzles(difficulty: difficulty, seed: s, puzzleData: puzzleData, timed: timed)
        self.totalRounds = timed ? min(3, max(1, puzzles.count)) : 1
        let puzzle = puzzles.first ?? HangmanGame.puzzle(difficulty: difficulty, seed: s, puzzleData: puzzleData)
        self.game = HangmanGame(
            targetWord: puzzle.word,
            category: puzzle.category,
            maxWrongGuesses: maxWrongGuesses,
            starterLetter: puzzle.starterLetter
        )
        startTimer()
    }

    var timeRemaining: Int? {
        guard let totalSeconds else { return nil }
        return max(0, totalSeconds - elapsedSeconds)
    }

    var alphabetRows: [[Character]] {
        [Array("QWERTYUIOP"), Array("ASDFGHJKL"), Array("ZXCVBNM")]
    }

    var solvedRoundCount: Int { roundResults.filter(\.solved).count }
    var failedRoundCount: Int { roundResults.filter { !$0.solved }.count }
    var roundDisplayText: String { totalRounds > 1 ? "Round \(min(currentRound + 1, totalRounds))/\(totalRounds)" : "Solo" }

    @discardableResult
    func guess(_ letter: Character) -> Bool {
        guard !isFinished else { return false }
        let accepted = game.guess(letter)
        guard accepted else {
            message = "Already guessed"
            clearMessageSoon()
            return false
        }
        rewardGuessHistory.append(letter)
        currentRoundGuessHistory.append(letter)
        SoundManager.shared.keyboardPress()
        if game.isSolved {
            finishRound(message: "Puzzle rescued!")
        } else if game.isLost {
            finishRound(message: "Lava reached the puzzle")
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
                    self.finishMatch(message: "Time expired")
                }
            }
    }

    func matchResult(userID: String, final: Bool) -> MatchPlayerResult {
        let snapshots = roundSnapshots(includeCurrent: !isFinished || roundResults.isEmpty)
        let solved = snapshots.filter(\.solved).count
        let failed = snapshots.filter { !$0.solved }.count
        let totalWrong = snapshots.reduce(0) { $0 + $1.wrongGuessCount }
        let revealed = snapshots.reduce(0) { $0 + $1.revealedUniqueCount }
        let current = snapshots.last ?? snapshotCurrentRound()
        var summary: [String: String] = [
            "targetWord": current.targetWord,
            "category": current.category,
            "starterLetter": String(current.starterLetter),
            "correctLetters": sortedLetters(current.correctLetters).joined(),
            "wrongLetters": sortedLetters(current.wrongLetters).joined(),
            "wrongGuessCount": "\(totalWrong)",
            "currentWrongGuessCount": "\(current.wrongGuessCount)",
            "revealedPattern": current.revealedPattern,
            "revealedLetterCount": "\(revealed)",
            "maxWrongGuesses": "\(current.maxWrongGuesses)",
            "lavaLevel": "\(current.wrongGuessCount)",
            "solved": current.solved ? "true" : "false",
            "solvedRounds": "\(solved)",
            "failedRounds": "\(failed)",
            "roundCount": "\(snapshots.count)",
            "totalRounds": "\(totalRounds)",
            "final": final ? "true" : "false"
        ]
        for (index, round) in snapshots.enumerated() {
            let number = index + 1
            summary["round\(number)TargetWord"] = round.targetWord
            summary["round\(number)Category"] = round.category
            summary["round\(number)StarterLetter"] = String(round.starterLetter)
            summary["round\(number)Solved"] = round.solved ? "true" : "false"
            summary["round\(number)WrongLetters"] = sortedLetters(round.wrongLetters).joined()
            summary["round\(number)CorrectLetters"] = sortedLetters(round.correctLetters).joined()
            summary["round\(number)Pattern"] = round.revealedPattern
        }
        return MatchPlayerResult(
            userID: userID,
            mode: .hangman,
            completed: solved >= 2,
            elapsedSeconds: elapsedSeconds,
            score: solved,
            progress: min(1, Double(solved) / 2.0),
            status: final ? finalStatus(solved: solved) : "\(solved)/\(totalRounds) rescued · \(roundDisplayText)",
            summary: summary,
            details: snapshots.enumerated().map { index, round in
                let result = round.solved ? "rescued" : "missed"
                return "Round \(index + 1): \(round.category) · \(round.targetWord) · \(result) · \(round.wrongGuessCount) wrong"
            },
            rewardEvidenceJSON: SoloCoinRewards.evidence(["rounds": snapshots.map(\.guessHistory)])
        )
    }

    private static func makePuzzles(difficulty: Difficulty, seed: Int, puzzleData: HangmanPuzzleData?, timed: Bool) -> [HangmanPuzzle] {
        let targetCount = timed ? 3 : 1
        var rounds: [HangmanPuzzle] = []
        if let stored = puzzleData?.rounds, !stored.isEmpty {
            rounds = stored.map { round in
                let target = round.targetWord.uppercased()
                let starter = round.starterLetter.uppercased().first ?? HangmanGame.defaultStarterLetter(for: target)
                return HangmanPuzzle(
                    category: round.category.isEmpty ? "Mystery" : round.category,
                    word: target,
                    starterLetter: target.contains(starter) ? starter : HangmanGame.defaultStarterLetter(for: target)
                )
            }
        } else if let puzzleData {
            rounds = [HangmanGame.puzzle(difficulty: difficulty, seed: seed, puzzleData: puzzleData)]
        }
        while rounds.count < targetCount {
            rounds.append(HangmanGame.puzzle(difficulty: difficulty, seed: seed &+ (rounds.count * 7_919)))
        }
        return Array(rounds.prefix(targetCount))
    }

    private func finishRound(message: String) {
        guard !isFinished else { return }
        self.message = message
        roundResults.append(snapshotCurrentRound())
        if solvedRoundCount >= 2 || roundResults.count >= totalRounds {
            finishMatch(message: message)
        } else {
            loadNextRound()
            clearMessageSoon()
        }
    }

    private func finishMatch(message: String) {
        guard !isFinished else { return }
        if roundResults.count <= currentRound {
            roundResults.append(snapshotCurrentRound())
        }
        self.message = message
        isFinished = true
        timer?.cancel()
        SoundManager.shared.gameOver()
    }

    private func loadNextRound() {
        currentRoundGuessHistory = ""
        currentRound = min(currentRound + 1, totalRounds - 1)
        let puzzle = puzzles[currentRound]
        game = HangmanGame(
            targetWord: puzzle.word,
            category: puzzle.category,
            maxWrongGuesses: maxWrongGuesses,
            starterLetter: puzzle.starterLetter
        )
    }

    private func snapshotCurrentRound() -> HangmanRoundResult {
        HangmanRoundResult(
            targetWord: game.targetWord,
            category: game.category,
            starterLetter: game.starterLetter,
            correctLetters: game.correctLetters,
            wrongLetters: game.wrongLetters,
            wrongGuessCount: game.wrongGuessCount,
            revealedPattern: game.revealedPattern,
            revealedUniqueCount: game.revealedUniqueCount,
            maxWrongGuesses: game.maxWrongGuesses,
            elapsedSeconds: elapsedSeconds,
            solved: game.isSolved,
            guessHistory: currentRoundGuessHistory
        )
    }

    private func roundSnapshots(includeCurrent: Bool) -> [HangmanRoundResult] {
        var snapshots = roundResults
        if includeCurrent && (snapshots.count <= currentRound || !game.guessedLetters.isEmpty) {
            snapshots.append(snapshotCurrentRound())
        }
        return snapshots
    }

    private func finalStatus(solved: Int) -> String {
        solved >= 2 ? "\(solved)/\(totalRounds) rescued" : "\(solved)/\(totalRounds) rescued"
    }

    private func sortedLetters(_ letters: Set<Character>) -> [String] {
        letters.map(String.init).sorted()
    }

    private func clearMessageSoon() {
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            if !isFinished { message = nil }
        }
    }
}
