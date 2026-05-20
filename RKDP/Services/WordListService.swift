import Foundation

enum WordListService {
    static let wordBankVersion = "2026-05-20-word-expansion-v1"

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

    static let hangmanWords: [String] = loadList(named: "hangman_words", minimumLength: 5, fallback: [
        "CROWN", "PUZZLE", "VICTORY", "ADVENTURE"
    ])

    static func hangmanWords(for difficulty: Difficulty) -> [String] {
        let filtered = hangmanWords.filter { word in
            switch difficulty {
            case .easy: return word.count == 5
            case .medium: return word.count == 6
            case .hard: return word.count == 7
            case .expert: return word.count >= 8
            }
        }
        return filtered.isEmpty ? hangmanWords : filtered
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

struct HangmanPuzzleData: Codable {
    let wordBankVersion: String
    let targetWord: String
    let difficulty: String
    let maxWrongGuesses: Int
}

enum MultiplayerPuzzleDataFactory {
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
            let data = HangmanPuzzleData(
                wordBankVersion: WordListService.wordBankVersion,
                targetWord: HangmanGame.targetWord(difficulty: difficulty, seed: seed),
                difficulty: difficulty.rawValue,
                maxWrongGuesses: 6
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
