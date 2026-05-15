import Foundation

struct ColorLinkPosition: Codable, Hashable, Identifiable {
    var row: Int
    var col: Int

    var id: String { "\(row)-\(col)" }

    func isAdjacent(to other: ColorLinkPosition) -> Bool {
        abs(row - other.row) + abs(col - other.col) == 1
    }
}

struct ColorLinkPair: Identifiable, Codable, Equatable {
    var id: Int
    var start: ColorLinkPosition
    var end: ColorLinkPosition
    var solutionPath: [ColorLinkPosition] = []
}

struct ColorLinkBoard: Codable, Equatable {
    var size: Int
    var pairs: [ColorLinkPair]

    var totalCells: Int { size * size }

    func contains(_ position: ColorLinkPosition) -> Bool {
        position.row >= 0 && position.row < size && position.col >= 0 && position.col < size
    }

    func pairID(at position: ColorLinkPosition) -> Int? {
        pairs.first { pair in
            pair.start == position || pair.end == position
        }?.id
    }

    func pair(for id: Int) -> ColorLinkPair? {
        pairs.first { $0.id == id }
    }
}
