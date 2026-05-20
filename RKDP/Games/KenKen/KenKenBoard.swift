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
    var targetTiles: [[Int]]

    init(size: Int, colorCount: Int, tiles: [[Int]], targetTiles: [[Int]]? = nil) {
        self.size = size
        self.colorCount = colorCount
        self.tiles = tiles
        self.targetTiles = targetTiles ?? tiles
    }

    private enum CodingKeys: String, CodingKey {
        case size
        case colorCount
        case tiles
        case targetTiles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        size = try container.decode(Int.self, forKey: .size)
        colorCount = try container.decode(Int.self, forKey: .colorCount)
        tiles = try container.decode([[Int]].self, forKey: .tiles)
        targetTiles = (try? container.decode([[Int]].self, forKey: .targetTiles)) ?? tiles
    }

    var isSolved: Bool {
        tiles == targetTiles
    }


    var patternProgress: Double {
        let total = max(1, size * size)
        return Double(matchingCellCount) / Double(total)
    }

    var solvedPairCount: Int {
        matchingCellCount
    }

    var totalPairCount: Int {
        size * size
    }

    var matchingCellCount: Int {
        guard targetTiles.count == size else { return 0 }
        var count = 0
        for row in 0..<size {
            guard row < tiles.count, row < targetTiles.count else { continue }
            for col in 0..<size {
                guard col < tiles[row].count, col < targetTiles[row].count else { continue }
                if tiles[row][col] == targetTiles[row][col] {
                    count += 1
                }
            }
        }
        return count
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
}
