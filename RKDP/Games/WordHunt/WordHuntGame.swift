import Foundation

struct WordHuntGame {
    let grid: [[Character]]
    let seed: Int
    let size: Int
    private(set) var validWords: Set<String> = []

    static let defaultGridSize = 4
    private static let maximumTraceLength = 10

    init(grid: [[Character]], seed: Int) {
        self.grid = grid
        self.seed = seed
        self.size = grid.count
        self.validWords = Self.findAllWords(in: grid)
    }

    // MARK: - Path validation

    /// Returns true if `word` can be traced as a valid forward-only adjacency path in the grid.
    func canForm(_ word: String) -> Bool {
        let chars = Array(word.uppercased())
        guard chars.count >= 3, chars.count <= Self.maximumTraceLength else { return false }
        for r in 0..<size {
            for c in 0..<size {
                if grid[r][c] == chars[0] {
                    var visited = [[Bool]](repeating: [Bool](repeating: false, count: size), count: size)
                    visited[r][c] = true
                    if dfs(chars: chars, index: 1, row: r, col: c, visited: &visited) { return true }
                }
            }
        }
        return false
    }

    private func dfs(chars: [Character], index: Int, row: Int, col: Int, visited: inout [[Bool]]) -> Bool {
        if index == chars.count { return true }
        for (nr, nc) in Self.neighbors(row: row, col: col, size: size) {
            guard !visited[nr][nc], grid[nr][nc] == chars[index] else { continue }
            visited[nr][nc] = true
            if dfs(chars: chars, index: index + 1, row: nr, col: nc, visited: &visited) { return true }
            visited[nr][nc] = false
        }
        return false
    }

    static func gridSize(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 4
        case .medium: return 5
        case .hard: return 6
        case .expert: return 7
        }
    }

    static func neighbors(row: Int, col: Int, size: Int) -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        for dr in -1...1 {
            for dc in -1...1 {
                guard dr != 0 || dc != 0 else { continue }
                let nr = row + dr, nc = col + dc
                if nr >= 0 && nr < size && nc >= 0 && nc < size {
                    result.append((nr, nc))
                }
            }
        }
        return result
    }

    // MARK: - Score

    static func score(for word: String) -> Int {
        switch word.count {
        case 3:      return 1
        case 4:      return 2
        case 5:      return 3
        case 6:      return 4
        default:     return 5
        }
    }

    // MARK: - Grid generation

    static func generate(difficulty: Difficulty, seed: Int) -> WordHuntGame {
        let size = gridSize(for: difficulty)
        var bestGame: WordHuntGame?
        for attempt in 0..<attemptCount(for: size) {
            let attemptSeed = seed &+ attempt &* 9_973
            let grid = generatedGrid(seed: attemptSeed, size: size)
            let game = WordHuntGame(grid: grid, seed: seed)
            if isHighQuality(game) {
                return game
            }
            let longerWords = game.validWords.filter { $0.count >= 5 }.count
            let bestWordCount = bestGame?.validWords.count ?? -1
            let bestLongerCount = bestGame?.validWords.filter { $0.count >= 5 }.count ?? -1
            if game.validWords.count > bestWordCount || (game.validWords.count == bestWordCount && longerWords > bestLongerCount) {
                bestGame = game
            }
        }
        return bestGame ?? WordHuntGame(grid: generatedGrid(seed: seed, size: size), seed: seed)
    }

    private static func generatedGrid(seed: Int, size: Int) -> [[Character]] {
        let bag: [Character] = Array(
            "AAAAAAAAABBCCDDDDEEEEEEEEEEEEFFGGGHHIIIIIIIIJKLLLLMMNNNNNNOOOOOOOOPPQRRRRRRSSSSTTTTTTTUUUUVVWWXYYZ"
        )
        var s = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        var flat: [Character] = []
        for _ in 0..<(size * size) {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            flat.append(bag[Int(s >> 33) % bag.count])
        }
        return (0..<size).map { row in Array(flat[(row * size)..<(row * size + size)]) }
    }

    private static func isHighQuality(_ game: WordHuntGame) -> Bool {
        let longerWords = game.validWords.filter { $0.count >= 5 }.count
        let minimumWords = max(22, game.size * game.size + 6)
        let minimumLongWords = max(4, game.size - 1)
        return game.validWords.count >= minimumWords && longerWords >= minimumLongWords
    }

    private static func attemptCount(for size: Int) -> Int {
        size <= 5 ? 24 : 12
    }

    // MARK: - Pre-compute all valid words in this grid

    private static func findAllWords(in grid: [[Character]]) -> Set<String> {
        let size = grid.count
        guard size > 0, grid.allSatisfy({ $0.count == size }) else { return [] }
        var found = Set<String>()
        var visited = [[Bool]](repeating: [Bool](repeating: false, count: size), count: size)
        let maxLength = min(WordHuntLexicon.maxWordLength, Self.maximumTraceLength)

        func search(row: Int, col: Int, current: String) {
            guard row >= 0, row < size, col >= 0, col < size, !visited[row][col] else { return }
            let next = current + String(grid[row][col])
            guard next.count <= maxLength, WordHuntLexicon.prefixes.contains(next) else { return }
            if WordHuntLexicon.words.contains(next) { found.insert(next) }

            visited[row][col] = true
            for (nextRow, nextCol) in Self.neighbors(row: row, col: col, size: size) {
                search(row: nextRow, col: nextCol, current: next)
            }
            visited[row][col] = false
        }

        for row in 0..<size {
            for col in 0..<size {
                search(row: row, col: col, current: "")
            }
        }
        return found
    }

    // Private init used during pre-computation
    private init(grid: [[Character]], seed: Int, validWords: Set<String>) {
        self.grid = grid
        self.seed = seed
        self.size = grid.count
        self.validWords = validWords
    }
}

private enum WordHuntLexicon {
    static let words: Set<String> = WordListService.wordHuntValidWords
    static let maxWordLength: Int = words.map(\.count).max() ?? 10
    static let prefixes: Set<String> = {
        var output = Set<String>()
        for word in words {
            let chars = Array(word)
            guard !chars.isEmpty else { continue }
            for length in 1...min(chars.count, 10) {
                output.insert(String(chars.prefix(length)))
            }
        }
        return output
    }()
}
