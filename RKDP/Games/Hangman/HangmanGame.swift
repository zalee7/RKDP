import Foundation

struct HangmanGame {
    let targetWord: String
    let maxWrongGuesses: Int
    private(set) var correctLetters: Set<Character> = []
    private(set) var wrongLetters: Set<Character> = []

    init(targetWord: String, maxWrongGuesses: Int = 6) {
        self.targetWord = targetWord.uppercased()
        self.maxWrongGuesses = maxWrongGuesses
    }

    var guessedLetters: Set<Character> { correctLetters.union(wrongLetters) }
    var wrongGuessCount: Int { wrongLetters.count }
    var isSolved: Bool { Set(targetWord).isSubset(of: correctLetters) }
    var isLost: Bool { wrongGuessCount >= maxWrongGuesses && !isSolved }
    var isFinished: Bool { isSolved || isLost }

    var revealedPattern: String {
        targetWord.map { correctLetters.contains($0) ? String($0) : "_" }.joined()
    }

    var revealedUniqueCount: Int {
        Set(targetWord).filter { correctLetters.contains($0) }.count
    }

    var progress: Double {
        let unique = Set(targetWord).count
        guard unique > 0 else { return 0 }
        return Double(revealedUniqueCount) / Double(unique)
    }

    mutating func guess(_ letter: Character) -> Bool {
        guard let normalized = String(letter).uppercased().first,
              let scalar = String(normalized).unicodeScalars.first,
              CharacterSet.uppercaseLetters.contains(scalar),
              !guessedLetters.contains(normalized),
              !isFinished else { return false }
        if targetWord.contains(normalized) {
            correctLetters.insert(normalized)
        } else {
            wrongLetters.insert(normalized)
        }
        return true
    }

    static func targetWord(difficulty: Difficulty, seed: Int, puzzleData: HangmanPuzzleData? = nil) -> String {
        if let target = puzzleData?.targetWord.uppercased(), !target.isEmpty { return target }
        let words = WordListService.hangmanWords(for: difficulty)
        guard !words.isEmpty else { return fallbackWord(for: difficulty) }
        var rng = SeededRNG(seed: seed)
        return words[Int(rng.next() % UInt64(words.count))]
    }

    private static func fallbackWord(for difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: return "CROWN"
        case .medium: return "PUZZLE"
        case .hard: return "VICTORY"
        case .expert: return "ADVENTURE"
        }
    }
}
