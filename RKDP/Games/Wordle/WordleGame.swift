import Foundation

// MARK: - Result types

enum WordleLetterResult: Equatable {
    case correct   // green  — right letter, right position
    case present   // yellow — right letter, wrong position
    case absent    // gray   — letter not in word
}

struct WordleGuess: Identifiable {
    let id = UUID()
    let word: String          // 5 uppercase chars
    let result: [WordleLetterResult]
    var isSolved: Bool { result.allSatisfy { $0 == .correct } }
}

// MARK: - Game

struct WordleGame {
    let targetWord: String    // 5 uppercase letters
    let seed: Int
    let round: Int

    init(seed: Int, round: Int, targetWords: [String]? = nil) {
        self.seed = seed
        self.round = round
        if let targetWords, targetWords.indices.contains(round) {
            self.targetWord = targetWords[round].uppercased()
        } else {
            self.targetWord = Self.targetWord(seed: seed, round: round)
        }
    }

    func evaluate(guess raw: String) -> [WordleLetterResult] {
        let guess  = Array(raw.uppercased())
        let target = Array(targetWord)
        var result     = Array(repeating: WordleLetterResult.absent, count: 5)
        var targetUsed = Array(repeating: false, count: 5)
        var guessUsed  = Array(repeating: false, count: 5)

        // Pass 1: correct positions
        for i in 0..<5 {
            if guess[i] == target[i] {
                result[i]     = .correct
                targetUsed[i] = true
                guessUsed[i]  = true
            }
        }
        // Pass 2: present (wrong position)
        for i in 0..<5 {
            guard !guessUsed[i] else { continue }
            for j in 0..<5 {
                if !targetUsed[j] && guess[i] == target[j] {
                    result[i]    = .present
                    targetUsed[j] = true
                    break
                }
            }
        }
        return result
    }

    static func isValidGuess(_ word: String) -> Bool {
        let w = word.uppercased()
        return w.count == 5 && WordListService.wordleValidGuesses.contains(w)
    }

    static func targetWord(seed: Int, round: Int) -> String {
        let answers = wordBank
        guard !answers.isEmpty else { return "CROWN" }
        var rng = SeededRNG(seed: seed &+ round &* 1_000_003)
        return rng.shuffled(answers)[0]
    }

    // MARK: - Word bank

    static var wordBank: [String] { WordListService.wordleAnswers }
}
