import Foundation

struct GridlockGenerator {
    static func generate(difficulty: Difficulty, seed: Int? = nil) -> GridlockBoard {
        var rng = SeededRNG(seed: seed ?? Int.random(in: 0..<Int.max))
        let size = boardSize(for: difficulty)
        let colorCount = colorCount(for: difficulty)
        var board = solvedBoard(size: size, colorCount: colorCount, rng: &rng)
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

    private static func solvedBoard(size: Int, colorCount: Int, rng: inout SeededRNG) -> GridlockBoard {
        var tiles = Array(repeating: Array(repeating: -1, count: size), count: size)
        let colorOffset = Int(rng.next()) % colorCount
        var orbitIndex = 0

        for row in 0..<size {
            for col in 0..<size where tiles[row][col] == -1 {
                let orbit = symmetryOrbit(row: row, col: col, size: size)
                let color = (orbitIndex + colorOffset) % colorCount
                for position in orbit {
                    tiles[position.row][position.col] = color
                }
                orbitIndex += 1
            }
        }

        return GridlockBoard(size: size, colorCount: colorCount, tiles: tiles)
    }

    private static func symmetryOrbit(row: Int, col: Int, size: Int) -> Set<GridDuelPosition> {
        [
            GridDuelPosition(row: row, col: col),
            GridDuelPosition(row: row, col: size - 1 - col),
            GridDuelPosition(row: size - 1 - row, col: col),
            GridDuelPosition(row: size - 1 - row, col: size - 1 - col)
        ]
    }

    private static func scramble(_ board: inout GridlockBoard, difficulty: Difficulty, rng: inout SeededRNG) {
        let moveCount: Int
        switch difficulty {
        case .easy: moveCount = 8
        case .medium: moveCount = 14
        case .hard: moveCount = 22
        case .expert: moveCount = 32
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

private struct GridDuelPosition: Hashable {
    var row: Int
    var col: Int
}
