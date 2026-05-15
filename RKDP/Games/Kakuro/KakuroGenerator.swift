import Foundation

struct ColorLinkGenerator {
    static func generate(difficulty: Difficulty, seed: Int? = nil) -> ColorLinkBoard {
        var rng = SeededRNG(seed: seed ?? Int.random(in: 0..<Int.max))
        let size = boardSize(for: difficulty)
        let vertical = Int(rng.next()) % 2 == 0
        let reversed = Int(rng.next()) % 2 == 0
        let order = rng.shuffled(Array(0..<size))

        let pairs = order.enumerated().map { index, lane in
            let start: ColorLinkPosition
            let end: ColorLinkPosition
            if vertical {
                start = ColorLinkPosition(row: reversed ? size - 1 : 0, col: lane)
                end = ColorLinkPosition(row: reversed ? 0 : size - 1, col: lane)
            } else {
                start = ColorLinkPosition(row: lane, col: reversed ? size - 1 : 0)
                end = ColorLinkPosition(row: lane, col: reversed ? 0 : size - 1)
            }
            return ColorLinkPair(id: index, start: start, end: end)
        }

        return ColorLinkBoard(size: size, pairs: pairs)
    }

    private static func boardSize(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 5
        case .medium: return 6
        case .hard: return 7
        case .expert: return 8
        }
    }
}
