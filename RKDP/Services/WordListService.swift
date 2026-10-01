import Foundation

enum WordListService {
    static let wordBankVersion = "2026-05-21-lava-rescue-v1"

    static let wordleAnswers: [String] = loadList(named: "wordle_answers", expectedLength: 5, fallback: [
        "CROWN", "BLOCK", "GRIDS", "TRACE", "LINKS"
    ])

    static let wordleValidGuesses: Set<String> = {
        let guesses = loadList(named: "wordle_valid_guesses", expectedLength: 5, fallback: wordleAnswers)
        return Set((guesses + wordleAnswers).map { $0.uppercased() })
    }()

    static let anagramValidWords: Set<String> = Set(loadList(named: "anagram_valid_words", minimumLength: 3, fallback: [
        "CAT", "ACT", "CAR", "ARC", "ART", "TAR", "STAR", "RATS"
    ]))

    static let wordHuntValidWords: Set<String> = Set(loadList(named: "word_hunt_valid_words", minimumLength: 3, fallback: Array(anagramValidWords)))

    static let hangmanWordEntries: [HangmanWordEntry] = loadCategorizedList(named: "hangman_words", minimumLength: 5, fallback: [
        HangmanWordEntry(category: "Solitaire", word: "CROWN"),
        HangmanWordEntry(category: "Puzzle", word: "PUZZLE"),
        HangmanWordEntry(category: "Competition", word: "VICTORY"),
        HangmanWordEntry(category: "Adventure", word: "ADVENTURE")
    ])

    static let hangmanWords: [String] = hangmanWordEntries.map(\.word)

    static func hangmanEntries(for difficulty: Difficulty) -> [HangmanWordEntry] {
        let filtered = hangmanWordEntries.filter { entry in
            switch difficulty {
            case .easy: return entry.word.count == 5
            case .medium: return entry.word.count == 6
            case .hard: return entry.word.count == 7
            case .expert: return entry.word.count >= 8
            }
        }
        let categorized = filtered.filter { $0.category != "Mystery" }
        if !categorized.isEmpty { return categorized }
        return filtered.isEmpty ? hangmanWordEntries : filtered
    }

    static func hangmanWords(for difficulty: Difficulty) -> [String] {
        hangmanEntries(for: difficulty).map(\.word)
    }

    static func anagramBaseWords(for difficulty: Difficulty) -> [String] {
        let length: Int
        switch difficulty {
        case .easy: length = 6
        case .medium: length = 7
        case .hard: length = 8
        case .expert: length = 9
        }
        let fallbackByLength = [
            6: ["CASTLE", "PLANET", "SILVER"],
            7: ["PAINTER", "CAPTAIN", "LANTERN"],
            8: ["ABSOLUTE", "BRANCHES", "STRANGER"],
            9: ["CARPENTER", "TRANSLATE", "IMPORTANT"]
        ]
        return loadList(named: "anagram_base_\(length)", expectedLength: length, fallback: fallbackByLength[length] ?? ["CASTLE"])
    }


    private static func loadCategorizedList(named name: String, minimumLength: Int, fallback: [HangmanWordEntry]) -> [HangmanWordEntry] {
        let resourceURL = Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "WordLists")
            ?? Bundle.main.url(forResource: name, withExtension: "txt")
        guard let url = resourceURL,
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return normalizeCategorized(fallback, minimumLength: minimumLength)
        }
        let entries = raw.components(separatedBy: .newlines).compactMap { line -> HangmanWordEntry? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            let pieces = trimmed.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if pieces.count == 2 {
                return HangmanWordEntry(category: pieces[0], word: pieces[1])
            }
            return HangmanWordEntry(category: "Mystery", word: trimmed)
        }
        let loaded = normalizeCategorized(entries, minimumLength: minimumLength)
        return loaded.isEmpty ? normalizeCategorized(fallback, minimumLength: minimumLength) : loaded
    }

    private static func normalizeCategorized(_ entries: [HangmanWordEntry], minimumLength: Int) -> [HangmanWordEntry] {
        var seen = Set<String>()
        var output: [HangmanWordEntry] = []
        for entry in entries {
            let category = entry.category.trimmingCharacters(in: .whitespacesAndNewlines).ifBlank("Mystery")
            let word = entry.word.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard word.count >= minimumLength,
                  word.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }),
                  !seen.contains(word) else { continue }
            seen.insert(word)
            output.append(HangmanWordEntry(category: category, word: word))
        }
        return output
    }

    private static func loadList(named name: String, expectedLength: Int? = nil, minimumLength: Int = 1, fallback: [String]) -> [String] {
        let resourceURL = Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "WordLists")
            ?? Bundle.main.url(forResource: name, withExtension: "txt")
        guard let url = resourceURL,
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return normalize(fallback, expectedLength: expectedLength, minimumLength: minimumLength)
        }
        let tokens = raw.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;")))
        let loaded = normalize(tokens, expectedLength: expectedLength, minimumLength: minimumLength)
        return loaded.isEmpty ? normalize(fallback, expectedLength: expectedLength, minimumLength: minimumLength) : loaded
    }

    private static func normalize(_ words: [String], expectedLength: Int?, minimumLength: Int) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for raw in words {
            let word = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard word.count >= minimumLength,
                  expectedLength.map({ word.count == $0 }) ?? true,
                  word.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }),
                  !seen.contains(word) else { continue }
            seen.insert(word)
            output.append(word)
        }
        return output
    }
}

struct HangmanWordEntry {
    let category: String
    let word: String
}

struct HangmanPuzzle {
    let category: String
    let word: String
    let starterLetter: Character
}

private extension String {
    func ifBlank(_ fallback: String) -> String { isEmpty ? fallback : self }
}

struct WordlePuzzleData: Codable {
    let wordBankVersion: String
    let targets: [String]
}

struct AnagramPuzzleData: Codable {
    let wordBankVersion: String
    let baseWord: String
    let letters: String
    let difficulty: String
}

struct WordHuntPuzzleData: Codable {
    let wordBankVersion: String
    let gridRows: [String]
}

struct HangmanRoundPuzzleData: Codable {
    let targetWord: String
    let category: String
    let starterLetter: String
}

struct HangmanPuzzleData: Codable {
    let wordBankVersion: String
    let targetWord: String
    let difficulty: String
    let maxWrongGuesses: Int
    let category: String?
    let starterLetter: String?
    let rounds: [HangmanRoundPuzzleData]?
}

enum MultiplayerPuzzleDataFactory {
    static func requiresStoredPuzzleData(for mode: GameMode) -> Bool {
        switch mode {
        case .wordle, .anagram, .wordHunt, .hangman:
            return true
        default:
            return false
        }
    }

    static func onlinePayload(mode: GameMode, difficulty: Difficulty, seed: Int, rounds: Int? = nil, context: String) -> String {
        let payload = encoded(mode: mode, difficulty: difficulty, seed: seed, rounds: rounds)
        if requiresStoredPuzzleData(for: mode), payload.isEmpty {
            print("Puzzle data warning: missing \(mode.rawValue) payload for \(context)")
        }
        return payload
    }

    static func encoded(mode: GameMode, difficulty: Difficulty, seed: Int, rounds: Int? = nil) -> String {
        switch mode {
        case .wordle:
            let targetCount = rounds ?? 3
            let data = WordlePuzzleData(
                wordBankVersion: WordListService.wordBankVersion,
                targets: (0..<targetCount).map { WordleGame.targetWord(seed: seed, round: $0) }
            )
            return encode(data)
        case .anagram:
            let game = AnagramGame.generate(difficulty: difficulty, seed: seed)
            let data = AnagramPuzzleData(
                wordBankVersion: WordListService.wordBankVersion,
                baseWord: game.baseWord,
                letters: String(game.letters),
                difficulty: difficulty.rawValue
            )
            return encode(data)
        case .wordHunt:
            let game = WordHuntGame.generate(difficulty: difficulty, seed: seed)
            let data = WordHuntPuzzleData(
                wordBankVersion: WordListService.wordBankVersion,
                gridRows: game.grid.map { String($0) }
            )
            return encode(data)
        case .hangman:
            let targetCount = rounds ?? 3
            let puzzles = (0..<targetCount).map { index in
                HangmanGame.puzzle(difficulty: difficulty, seed: seed &+ (index * 7_919))
            }
            let first = puzzles.first ?? HangmanGame.puzzle(difficulty: difficulty, seed: seed)
            let data = HangmanPuzzleData(
                wordBankVersion: WordListService.wordBankVersion,
                targetWord: first.word,
                difficulty: difficulty.rawValue,
                maxWrongGuesses: 6,
                category: first.category,
                starterLetter: String(first.starterLetter),
                rounds: puzzles.map {
                    HangmanRoundPuzzleData(
                        targetWord: $0.word,
                        category: $0.category,
                        starterLetter: String($0.starterLetter)
                    )
                }
            )
            return encode(data)
        default:
            return ""
        }
    }

    static func decodeWordle(_ raw: String?) -> WordlePuzzleData? {
        decode(WordlePuzzleData.self, from: raw)
    }

    static func decodeAnagram(_ raw: String?) -> AnagramPuzzleData? {
        decode(AnagramPuzzleData.self, from: raw)
    }

    static func decodeWordHunt(_ raw: String?) -> WordHuntPuzzleData? {
        decode(WordHuntPuzzleData.self, from: raw)
    }

    static func decodeHangman(_ raw: String?) -> HangmanPuzzleData? {
        decode(HangmanPuzzleData.self, from: raw)
    }

    private static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func decode<T: Decodable>(_ type: T.Type, from raw: String?) -> T? {
        guard let raw, !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
