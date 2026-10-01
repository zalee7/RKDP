import SwiftUI
import Combine

// MARK: - Keyboard letter state

enum WordleKeyState {
    case unused, absent, present, correct
    var priority: Int {
        switch self { case .unused: 0; case .absent: 1; case .present: 2; case .correct: 3 }
    }
    var color: Color {
        switch self {
        case .unused:  return Color.white.opacity(0.15)
        case .absent:  return Color(hex: "3A3A3C")
        case .present: return Color(hex: "B59F3B")
        case .correct: return Color(hex: "538D4E")
        }
    }
    init(from r: WordleLetterResult) {
        switch r { case .correct: self = .correct; case .present: self = .present; case .absent: self = .absent }
    }
}

// MARK: - Round result

struct WordleRoundResult {
    let targetWord: String
    let guessCount: Int    // 0 = failed
    let solved: Bool
    let guesses: [WordleGuess]
}

// MARK: - ViewModel

@MainActor
final class WordleViewModel: ObservableObject {

    // Config
    let difficulty: Difficulty
    let maxGuesses: Int
    let totalRounds: Int    // One solo word; up to three shared online words.
    private let baseSeed: Int
    private let targetWords: [String]?

    // Current round state
    @Published var game: WordleGame
    @Published var guesses: [WordleGuess] = []
    @Published var currentInput: String = ""
    @Published var letterStates: [Character: WordleKeyState] = [:]
    @Published var message: String? = nil
    @Published var shakeRow: Bool = false
    @Published var revealingRow: Int? = nil

    // Match state
    @Published var roundResults: [WordleRoundResult] = []
    @Published var isMatchOver: Bool = false
    @Published var elapsedSeconds: Int = 0
    private var timer: AnyCancellable?

    var currentRound: Int { roundResults.count }
    var playerWins:   Int { roundResults.filter(\.solved).count }

    var isRoundOver: Bool {
        guesses.last?.isSolved == true || guesses.count >= maxGuesses
    }
    var didSolveRound: Bool { guesses.last?.isSolved == true }

    init(difficulty: Difficulty, seed: Int? = nil, totalRounds: Int = 3, targetWords: [String]? = nil) {
        self.difficulty   = difficulty
        self.totalRounds  = totalRounds
        self.baseSeed     = seed ?? Int.random(in: 0..<Int.max)
        self.targetWords  = targetWords
        self.maxGuesses   = {
            switch difficulty {
            case .easy:   return 7
            case .medium: return 6
            case .hard:   return 5
            case .expert: return 4
            }
        }()
        self.game = WordleGame(seed: self.baseSeed, round: 0, targetWords: targetWords)
        startTimer()
    }

    // MARK: - Input

    func addLetter(_ c: Character) {
        guard currentInput.count < 5, !isRoundOver, revealingRow == nil else { return }
        currentInput.append(c.uppercased().first ?? c)
        message = nil
    }

    func deleteLetter() {
        guard !currentInput.isEmpty, !isRoundOver, revealingRow == nil else { return }
        currentInput.removeLast()
    }

    func submitGuess() {
        guard currentInput.count == 5, !isRoundOver, revealingRow == nil else { return }
        let word = currentInput.uppercased()

        guard WordleGame.isValidGuess(word) else {
            message = "Not in word list"
            triggerShake()
            return
        }

        let result = game.evaluate(guess: word)
        let guess  = WordleGuess(word: word, result: result)
        let rowIndex = guesses.count

        withAnimation { guesses.append(guess) }
        currentInput = ""
        updateLetterStates(guess: guess)

        // Final reveal animations should not inflate the recorded solve time.
        let threshold = (totalRounds / 2) + 1
        let wins = playerWins + (didSolveRound ? 1 : 0)
        let losses = roundResults.filter { !$0.solved }.count + (isRoundOver && !didSolveRound ? 1 : 0)
        if isRoundOver && (wins >= threshold || losses >= threshold || currentRound + 1 >= totalRounds) {
            timer?.cancel()
        }

        // Brief reveal delay so flip animation plays before we move on
        revealingRow = rowIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.revealingRow = nil
            if self?.isRoundOver == true {
                self?.finishRound()
            }
        }
    }

    // MARK: - Round management

    private func finishRound() {
        let solved = didSolveRound
        if !solved {
            message = "The word was \(game.targetWord)"
        }
        roundResults.append(WordleRoundResult(
            targetWord: game.targetWord,
            guessCount: solved ? guesses.count : 0,
            solved: solved,
            guesses: guesses
        ))

        let wins   = roundResults.filter(\.solved).count
        let losses = roundResults.filter { !$0.solved }.count
        let winThreshold = (totalRounds / 2) + 1

        if wins >= winThreshold || losses >= winThreshold || roundResults.count >= totalRounds {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.isMatchOver = true
                self?.timer?.cancel()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startNextRound()
            }
        }
    }

    func startNextRound() {
        game         = WordleGame(seed: baseSeed, round: currentRound, targetWords: targetWords)
        guesses      = []
        currentInput = ""
        letterStates = [:]
        message      = nil
        isMatchOver  = false
    }

    // MARK: - Helpers

    private func updateLetterStates(guess: WordleGuess) {
        for (i, char) in guess.word.enumerated() {
            let new = WordleKeyState(from: guess.result[i])
            if let existing = letterStates[char] {
                if new.priority > existing.priority { letterStates[char] = new }
            } else {
                letterStates[char] = new
            }
        }
    }

    private func triggerShake() {
        shakeRow = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.shakeRow = false }
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    func stop() { timer?.cancel() }
}
