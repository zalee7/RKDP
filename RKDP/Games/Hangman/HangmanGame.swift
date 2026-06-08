import Foundation

struct HangmanGame {
    let targetWord: String
    let category: String
    let maxWrongGuesses: Int
    let starterLetter: Character
    private(set) var correctLetters: Set<Character> = []
    private(set) var wrongLetters: Set<Character> = []

    init(targetWord: String, category: String = "Mystery", maxWrongGuesses: Int = 6, starterLetter: Character? = nil) {
        self.targetWord = targetWord.uppercased()
        self.category = category.isEmpty ? "Mystery" : category
        self.maxWrongGuesses = maxWrongGuesses
        let starter = starterLetter.map { String($0).uppercased().first }.flatMap { $0 } ?? HangmanGame.defaultStarterLetter(for: targetWord)
        self.starterLetter = starter
        if self.targetWord.contains(starter) {
            correctLetters.insert(starter)
        }
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
        puzzle(difficulty: difficulty, seed: seed, puzzleData: puzzleData).word
    }

    static func puzzle(difficulty: Difficulty, seed: Int, puzzleData: HangmanPuzzleData? = nil) -> HangmanPuzzle {
        if let target = puzzleData?.targetWord.uppercased(), !target.isEmpty {
            let rawCategory = puzzleData?.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let category = rawCategory.isEmpty ? "Mystery" : rawCategory
            let starter = puzzleData?.starterLetter?.uppercased().first ?? defaultStarterLetter(for: target)
            return HangmanPuzzle(category: category, word: target, starterLetter: target.contains(starter) ? starter : defaultStarterLetter(for: target))
        }
        let entries = WordListService.hangmanEntries(for: difficulty)
        guard !entries.isEmpty else {
            let word = fallbackWord(for: difficulty)
            return HangmanPuzzle(category: fallbackCategory(for: difficulty), word: word, starterLetter: defaultStarterLetter(for: word))
        }
        var rng = SeededRNG(seed: seed)
        let entry = entries[Int(rng.next() % UInt64(entries.count))]
        let starter = starterLetter(for: entry.word, rng: &rng)
        return HangmanPuzzle(category: entry.category, word: entry.word, starterLetter: starter)
    }

    private static func starterLetter(for word: String, rng: inout SeededRNG) -> Character {
        let uniqueLetters = sortedUniqueLetters(in: word)
        guard !uniqueLetters.isEmpty else { return "A" }
        return uniqueLetters[Int(rng.next() % UInt64(uniqueLetters.count))]
    }

    static func defaultStarterLetter(for word: String) -> Character {
        sortedUniqueLetters(in: word).first ?? "A"
    }

    private static func sortedUniqueLetters(in word: String) -> [Character] {
        Set(word.uppercased()).map(String.init).sorted().compactMap { $0.first }
    }

    private static func fallbackWord(for difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: return "CROWN"
        case .medium: return "PUZZLE"
        case .hard: return "VICTORY"
        case .expert: return "ADVENTURE"
        }
    }

    private static func fallbackCategory(for difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: return "Grid Duel"
        case .medium: return "Puzzle"
        case .hard: return "Competition"
        case .expert: return "Adventure"
        }
    }
}
