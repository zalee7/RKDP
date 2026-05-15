import Foundation

struct AnagramGame {
    let baseWord: String           // the source word whose letters are used
    let letters: [Character]       // shuffled letters given to the player
    let validWords: Set<String>    // all words formable from these letters (3+ letters)
    let difficulty: Difficulty
    let seed: Int

    // MARK: - Generation

    static func generate(difficulty: Difficulty, seed: Int? = nil) -> AnagramGame {
        let pool = wordPool(for: difficulty)
        let s = seed ?? Int.random(in: 0..<Int.max)
        let idx = abs(s) % pool.count
        let base = pool[idx]
        let shuffled = shuffleLetters(Array(base), seed: s)
        let words = findValidWords(in: Array(base))
        return AnagramGame(baseWord: base, letters: shuffled, validWords: words, difficulty: difficulty, seed: s)
    }

    // MARK: - Validation

    /// True if `word` can be spelled using only the available letters (respecting counts).
    func canForm(_ word: String) -> Bool {
        Self.canForm(word.uppercased(), from: Array(baseWord))
    }

    static func canForm(_ word: String, from letters: [Character]) -> Bool {
        var remaining = letters
        for ch in word.uppercased() {
            guard let idx = remaining.firstIndex(of: ch) else { return false }
            remaining.remove(at: idx)
        }
        return true
    }

    // MARK: - Scoring

    static func score(for word: String) -> Int {
        switch word.count {
        case 3:    return 1
        case 4:    return 2
        case 5:    return 3
        case 6:    return 4
        default:   return 5
        }
    }

    // MARK: - Timer per difficulty

    static func totalSeconds(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy:   return 120
        case .medium: return 100
        case .hard:   return 90
        case .expert: return 75
        }
    }

    // MARK: - Internals

    private static func findValidWords(in letters: [Character]) -> Set<String> {
        var found = Set<String>()
        for word in WordDictionary.words where word.count >= 3 {
            if canForm(word, from: letters) { found.insert(word) }
        }
        return found
    }

    private static func shuffleLetters(_ chars: [Character], seed: Int) -> [Character] {
        var arr = chars
        var s = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        for i in stride(from: arr.count - 1, through: 1, by: -1) {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(s >> 33) % (i + 1)
            if i != j { arr.swapAt(i, j) }
        }
        return arr
    }

    // MARK: - Word pools (longer base words → more sub-words)

    private static func wordPool(for difficulty: Difficulty) -> [String] {
        switch difficulty {
        case .easy:      // 6-letter words
            return [
                "CASTLE", "PLANET", "SILVER", "GARDEN",
                "BRIDGE", "ORANGE", "FINGER", "CANDLE",
                "HUNTER", "ISLAND", "LANCER", "MIRROR",
                "ROCKET", "TIMBER", "NEEDLE", "DANGER",
                "GENTLE", "FLOWER", "SINGLE", "MOTHER"
            ]
        case .medium:    // 7-letter words
            return [
                "PAINTER", "CAPTAIN", "LANTERN", "MONSTER",
                "STRANGE", "SHELTER", "THUNDER", "KITCHEN",
                "MACHINE", "HISTORY", "BALANCE", "NETWORK",
                "SOLDIER", "PARTNER", "CENTRAL", "MINERAL",
                "CHAPTER", "MINERAL", "SILENCE", "PLANTER"
            ]
        case .hard:      // 8-letter words
            return [
                "ABSOLUTE", "BRANCHES", "STRANGER", "TROUBLES",
                "ELECTRON", "PRESENTS", "CHILDREN", "TOGETHER",
                "COMPLETE", "PERSONAL", "SMALLEST", "DAUGHTER",
                "STANDARD", "STRAIGHT", "STRENGTH", "RELATIVE",
                "CONSIDER", "POINTING", "SCRAMBLE", "CRIMINAL"
            ]
        case .expert:    // 9-letter words
            return [
                "CARPENTER", "TRANSLATE", "IMPORTANT", "LANDSCAPE",
                "CHALLENGE", "STRANGEST", "REMAINDER", "PASSENGER",
                "YESTERDAY", "UNCERTAIN", "WONDERFUL", "CELEBRATE",
                "DETECTIVE", "CALCULATE", "BEAUTIFUL", "LISTENING",
                "NIGHTMARE", "SOMEWHERE", "COMPLAINS", "ALERTNESS"
            ]
        }
    }
}
