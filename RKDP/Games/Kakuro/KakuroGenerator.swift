import Foundation

struct ColorLinkGenerator {
    static func generate(difficulty: Difficulty, seed: Int? = nil) -> ColorLinkBoard {
        var rng = SeededRNG(seed: seed ?? Int.random(in: 0..<Int.max))
        let size = boardSize(for: difficulty)
        let pairCount = pairCount(for: difficulty)
        let path = transformedPath(size: size, rng: &rng)
        let cuts = cutPoints(totalCells: path.count, pairCount: pairCount, rng: &rng)

        let pairs = (0..<pairCount).map { index in
            let segment = Array(path[cuts[index]..<cuts[index + 1]])
            return ColorLinkPair(
                id: index,
                start: segment.first ?? ColorLinkPosition(row: 0, col: 0),
                end: segment.last ?? ColorLinkPosition(row: 0, col: 0),
                solutionPath: segment
            )
        }

        return ColorLinkBoard(size: size, pairs: rng.shuffled(pairs))
    }

    private static func boardSize(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 5
        case .medium: return 6
        case .hard: return 7
        case .expert: return 8
        }
    }

    private static func pairCount(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 5
        case .medium: return 7
        case .hard: return 7
        case .expert: return 8
        }
    }

    private static func transformedPath(size: Int, rng: inout SeededRNG) -> [ColorLinkPosition] {
        let basePath = Int(rng.next()) % 2 == 0 ? snakePath(size: size) : spiralPath(size: size)
        let rotate = Int(rng.next()) % 4
        let mirrorRows = Int(rng.next()) % 2 == 0
        let mirrorCols = Int(rng.next()) % 2 == 0

        var path: [ColorLinkPosition] = []
        for position in basePath {
            var row = position.row
            var col = position.col
            if mirrorRows { row = size - 1 - row }
            if mirrorCols { col = size - 1 - col }
            for _ in 0..<rotate {
                let oldRow = row
                row = col
                col = size - 1 - oldRow
            }
            path.append(ColorLinkPosition(row: row, col: col))
        }
        return path
    }

    private static func snakePath(size: Int) -> [ColorLinkPosition] {
        var path: [ColorLinkPosition] = []
        for row in 0..<size {
            let cols = row.isMultiple(of: 2) ? Array(0..<size) : Array((0..<size).reversed())
            for col in cols {
                path.append(ColorLinkPosition(row: row, col: col))
            }
        }
        return path
    }

    private static func spiralPath(size: Int) -> [ColorLinkPosition] {
        var path: [ColorLinkPosition] = []
        var top = 0
        var bottom = size - 1
        var left = 0
        var right = size - 1

        while top <= bottom && left <= right {
            for col in left...right {
                path.append(ColorLinkPosition(row: top, col: col))
            }
            top += 1

            if top <= bottom {
                for row in top...bottom {
                    path.append(ColorLinkPosition(row: row, col: right))
                }
                right -= 1
            }

            if top <= bottom && left <= right {
                for col in stride(from: right, through: left, by: -1) {
                    path.append(ColorLinkPosition(row: bottom, col: col))
                }
                bottom -= 1
            }

            if top <= bottom && left <= right {
                for row in stride(from: bottom, through: top, by: -1) {
                    path.append(ColorLinkPosition(row: row, col: left))
                }
                left += 1
            }
        }
        return path
    }

    private static func cutPoints(totalCells: Int, pairCount: Int, rng: inout SeededRNG) -> [Int] {
        let minimumSegmentLength = 3
        var remainingCells = totalCells
        var remainingPairs = pairCount
        var cuts = [0]

        while remainingPairs > 1 {
            let maxLength = remainingCells - minimumSegmentLength * (remainingPairs - 1)
            let extraRange = max(1, maxLength - minimumSegmentLength + 1)
            let length = minimumSegmentLength + Int(rng.next()) % extraRange
            cuts.append((cuts.last ?? 0) + length)
            remainingCells -= length
            remainingPairs -= 1
        }

        cuts.append(totalCells)
        return cuts
    }
}
