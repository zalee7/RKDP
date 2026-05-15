import Foundation

enum GridDuelAxis: String, Codable, Equatable {
    case row
    case column
}

struct GridDuelMove: Equatable {
    var axis: GridDuelAxis
    var index: Int
    var steps: Int
}

struct GridlockBoard: Codable, Equatable {
    var size: Int
    var colorCount: Int
    var tiles: [[Int]]

    var isSolved: Bool {
        symmetryProgress >= 1
    }

    var symmetryProgress: Double {
        let horizontal = symmetryScore(axis: .row)
        let vertical = symmetryScore(axis: .column)
        return (horizontal + vertical) / 2
    }

    var solvedPairCount: Int {
        solvedPairs(axis: .row) + solvedPairs(axis: .column)
    }

    var totalPairCount: Int {
        pairCount(axis: .row) + pairCount(axis: .column)
    }

    mutating func shift(_ move: GridDuelMove) {
        shift(axis: move.axis, index: move.index, steps: move.steps)
    }

    mutating func shift(axis: GridDuelAxis, index: Int, steps: Int) {
        guard size > 0, index >= 0, index < size else { return }
        let normalized = ((steps % size) + size) % size
        guard normalized != 0 else { return }

        switch axis {
        case .row:
            tiles[index] = shifted(tiles[index], by: normalized)
        case .column:
            var column = (0..<size).map { tiles[$0][index] }
            column = shifted(column, by: normalized)
            for row in 0..<size {
                tiles[row][index] = column[row]
            }
        }
    }

    private func shifted(_ values: [Int], by steps: Int) -> [Int] {
        guard !values.isEmpty else { return values }
        let pivot = values.count - steps
        return Array(values[pivot..<values.count] + values[0..<pivot])
    }

    private func symmetryScore(axis: GridDuelAxis) -> Double {
        let total = pairCount(axis: axis)
        guard total > 0 else { return 1 }
        return Double(solvedPairs(axis: axis)) / Double(total)
    }

    private func solvedPairs(axis: GridDuelAxis) -> Int {
        var count = 0
        for row in 0..<size {
            for col in 0..<size {
                guard shouldCountPair(row: row, col: col, axis: axis) else { continue }
                let mirror = mirrored(row: row, col: col, axis: axis)
                if tiles[row][col] == tiles[mirror.row][mirror.col] {
                    count += 1
                }
            }
        }
        return count
    }

    private func pairCount(axis: GridDuelAxis) -> Int {
        var count = 0
        for row in 0..<size {
            for col in 0..<size where shouldCountPair(row: row, col: col, axis: axis) {
                count += 1
            }
        }
        return count
    }

    private func shouldCountPair(row: Int, col: Int, axis: GridDuelAxis) -> Bool {
        let mirror = mirrored(row: row, col: col, axis: axis)
        return row < mirror.row || (row == mirror.row && col < mirror.col)
    }

    private func mirrored(row: Int, col: Int, axis: GridDuelAxis) -> (row: Int, col: Int) {
        switch axis {
        case .row:
            return (row, size - 1 - col)
        case .column:
            return (size - 1 - row, col)
        }
    }
}
