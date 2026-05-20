import Foundation

struct GridlockGenerator {
    static func generate(difficulty: Difficulty, seed: Int? = nil) -> GridlockBoard {
        var rng = SeededRNG(seed: seed ?? Int.random(in: 0..<Int.max))
        let size = boardSize(for: difficulty)
        let colorCount = colorCount(for: difficulty)
        let targetTiles = targetBoard(size: size, colorCount: colorCount, rng: &rng)
        var board = GridlockBoard(size: size, colorCount: colorCount, tiles: targetTiles, targetTiles: targetTiles)
        scramble(&board, difficulty: difficulty, rng: &rng)
        return board
    }

    static func boardSize(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 4
        case .medium: return 5
        case .hard: return 6
        case .expert: return 7
        }
    }

    static func colorCount(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 3
        case .medium: return 4
        case .hard: return 5
        case .expert: return 6
        }
    }

    private static func targetBoard(size: Int, colorCount: Int, rng: inout SeededRNG) -> [[Int]] {
        let colorOffset = Int(rng.next()) % colorCount
        return (0..<size).map { row in
            (0..<size).map { col in
                let jitter = Int(rng.next()) % colorCount
                return (row * 2 + col * 3 + jitter + colorOffset) % colorCount
            }
        }
    }

    private static func scramble(_ board: inout GridlockBoard, difficulty: Difficulty, rng: inout SeededRNG) {
        let moveCount: Int
        switch difficulty {
        case .easy: moveCount = 4
        case .medium: moveCount = 7
        case .hard: moveCount = 12
        case .expert: moveCount = 18
        }

        for moveIndex in 0..<moveCount {
            let axis: GridDuelAxis = Int(rng.next()) % 2 == 0 ? .row : .column
            let index = Int(rng.next()) % board.size
            var steps = 1 + Int(rng.next()) % max(1, board.size - 1)
            if moveIndex.isMultiple(of: 2) { steps *= -1 }
            board.shift(axis: axis, index: index, steps: steps)
        }

        if board.isSolved {
            board.shift(axis: .row, index: 0, steps: 1)
            if board.isSolved, board.size > 1 {
                board.shift(axis: .column, index: 1, steps: 1)
            }
        }
    }
}
