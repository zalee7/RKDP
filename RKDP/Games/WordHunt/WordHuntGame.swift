import Foundation

struct WordHuntGame {
    let grid: [[Character]]   // 4×4
    let seed: Int
    private(set) var validWords: Set<String> = []

    static let gridSize = 4

    init(grid: [[Character]], seed: Int) {
        self.grid = grid
        self.seed = seed
        self.validWords = Self.findAllWords(in: grid)
    }

    // MARK: - Path validation

    /// Returns true if `word` can be traced as a valid adjacency path in the grid.
    func canForm(_ word: String) -> Bool {
        let chars = Array(word.uppercased())
        guard chars.count >= 3 else { return false }
        for r in 0..<Self.gridSize {
            for c in 0..<Self.gridSize {
                if grid[r][c] == chars[0] {
                    var visited = [[Bool]](repeating: [Bool](repeating: false, count: Self.gridSize), count: Self.gridSize)
                    visited[r][c] = true
                    if dfs(chars: chars, index: 1, row: r, col: c, visited: &visited) { return true }
                }
            }
        }
        return false
    }

    private func dfs(chars: [Character], index: Int, row: Int, col: Int, visited: inout [[Bool]]) -> Bool {
        if index == chars.count { return true }
        for (nr, nc) in Self.neighbors(row: row, col: col) {
            guard !visited[nr][nc], grid[nr][nc] == chars[index] else { continue }
            visited[nr][nc] = true
            if dfs(chars: chars, index: index + 1, row: nr, col: nc, visited: &visited) { return true }
            visited[nr][nc] = false
        }
        return false
    }

    static func neighbors(row: Int, col: Int) -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        for dr in -1...1 {
            for dc in -1...1 {
                guard dr != 0 || dc != 0 else { continue }
                let nr = row + dr, nc = col + dc
                if nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize {
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

    static func generate(seed: Int) -> WordHuntGame {
        var bestGame: WordHuntGame?
        for attempt in 0..<24 {
            let attemptSeed = seed &+ attempt &* 9_973
            let grid = generatedGrid(seed: attemptSeed)
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
        return bestGame ?? WordHuntGame(grid: generatedGrid(seed: seed), seed: seed)
    }

    private static func generatedGrid(seed: Int) -> [[Character]] {
        let bag: [Character] = Array(
            "AAAAAAAAABBCCDDDDEEEEEEEEEEEEFFGGGHHIIIIIIIIJKLLLLMMNNNNNNOOOOOOOOPPQRRRRRRSSSSTTTTTTTUUUUVVWWXYYZ"
        )
        var s = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        var flat: [Character] = []
        for _ in 0..<(gridSize * gridSize) {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            flat.append(bag[Int(s >> 33) % bag.count])
        }
        return (0..<gridSize).map { row in Array(flat[(row * gridSize)..<(row * gridSize + gridSize)]) }
    }

    private static func isHighQuality(_ game: WordHuntGame) -> Bool {
        let longerWords = game.validWords.filter { $0.count >= 5 }.count
        return game.validWords.count >= 22 && longerWords >= 4
    }

    // MARK: - Pre-compute all valid words in this grid

    private static func findAllWords(in grid: [[Character]]) -> Set<String> {
        var found = Set<String>()
        var visited = [[Bool]](repeating: [Bool](repeating: false, count: Self.gridSize), count: Self.gridSize)
        let maxLength = WordHuntLexicon.maxWordLength

        func search(row: Int, col: Int, current: String) {
            guard row >= 0, row < Self.gridSize, col >= 0, col < Self.gridSize, !visited[row][col] else { return }
            let next = current + String(grid[row][col])
            guard next.count <= maxLength, WordHuntLexicon.prefixes.contains(next) else { return }
            if WordHuntLexicon.words.contains(next) { found.insert(next) }

            visited[row][col] = true
            for (nextRow, nextCol) in Self.neighbors(row: row, col: col) {
                search(row: nextRow, col: nextCol, current: next)
            }
            visited[row][col] = false
        }

        for row in 0..<Self.gridSize {
            for col in 0..<Self.gridSize {
                search(row: row, col: col, current: "")
            }
        }
        return found
    }

    // Private init used during pre-computation
    private init(grid: [[Character]], seed: Int, validWords: Set<String>) {
        self.grid = grid
        self.seed = seed
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
            for length in 1...chars.count {
                output.insert(String(chars.prefix(length)))
            }
        }
        return output
    }()
}
