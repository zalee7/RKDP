import Foundation

struct GridlockGenerator {
    static func generate(difficulty: Difficulty, seed: Int? = nil) -> GridlockBoard {
        var rng = SeededRNG(seed: seed ?? Int.random(in: 0..<Int.max))
        let boards = puzzles(for: difficulty)
        let index = Int(rng.next()) % boards.count
        return boards[index]
    }

    private static func puzzles(for difficulty: Difficulty) -> [GridlockBoard] {
        switch difficulty {
        case .easy:
            return [
                board([
                    car("A", 2, 0, 2, .horizontal, true, 0),
                    car("B", 1, 3, 2, .vertical, false, 1),
                    car("C", 0, 0, 2, .horizontal, false, 2),
                    car("D", 4, 1, 3, .horizontal, false, 3),
                    car("E", 3, 5, 2, .vertical, false, 4)
                ]),
                board([
                    car("A", 2, 1, 2, .horizontal, true, 0),
                    car("B", 0, 4, 3, .vertical, false, 1),
                    car("C", 0, 0, 3, .horizontal, false, 2),
                    car("D", 4, 2, 2, .horizontal, false, 3),
                    car("E", 3, 0, 2, .vertical, false, 4)
                ])
            ]
        case .medium:
            return [
                board([
                    car("A", 2, 0, 2, .horizontal, true, 0),
                    car("B", 0, 2, 3, .vertical, false, 1),
                    car("C", 1, 4, 3, .vertical, false, 2),
                    car("D", 0, 0, 2, .horizontal, false, 3),
                    car("E", 3, 2, 2, .horizontal, false, 4),
                    car("F", 4, 5, 2, .vertical, false, 5)
                ]),
                board([
                    car("A", 2, 0, 2, .horizontal, true, 0),
                    car("B", 1, 3, 2, .vertical, false, 1),
                    car("C", 0, 4, 3, .vertical, false, 2),
                    car("D", 3, 0, 3, .horizontal, false, 3),
                    car("E", 4, 2, 2, .vertical, false, 4),
                    car("F", 5, 3, 2, .horizontal, false, 5)
                ])
            ]
        case .hard:
            return [
                board([
                    car("A", 2, 0, 2, .horizontal, true, 0),
                    car("B", 0, 2, 3, .vertical, false, 1),
                    car("C", 0, 3, 2, .horizontal, false, 2),
                    car("D", 1, 5, 3, .vertical, false, 3),
                    car("E", 3, 1, 2, .horizontal, false, 4),
                    car("F", 3, 4, 2, .vertical, false, 5),
                    car("G", 5, 0, 3, .horizontal, false, 6)
                ]),
                board([
                    car("A", 2, 1, 2, .horizontal, true, 0),
                    car("B", 0, 3, 3, .vertical, false, 1),
                    car("C", 0, 0, 2, .vertical, false, 2),
                    car("D", 0, 4, 2, .horizontal, false, 3),
                    car("E", 3, 1, 3, .horizontal, false, 4),
                    car("F", 3, 5, 3, .vertical, false, 5),
                    car("G", 5, 2, 2, .horizontal, false, 6)
                ])
            ]
        case .expert:
            return [
                board([
                    car("A", 2, 0, 2, .horizontal, true, 0),
                    car("B", 0, 2, 3, .vertical, false, 1),
                    car("C", 0, 3, 2, .horizontal, false, 2),
                    car("D", 1, 5, 3, .vertical, false, 3),
                    car("E", 3, 0, 2, .horizontal, false, 4),
                    car("F", 3, 3, 2, .vertical, false, 5),
                    car("G", 4, 1, 3, .horizontal, false, 6),
                    car("H", 5, 4, 2, .horizontal, false, 7)
                ]),
                board([
                    car("A", 2, 0, 2, .horizontal, true, 0),
                    car("B", 1, 2, 2, .vertical, false, 1),
                    car("C", 0, 3, 3, .vertical, false, 2),
                    car("D", 0, 4, 2, .horizontal, false, 3),
                    car("E", 3, 0, 2, .vertical, false, 4),
                    car("F", 3, 2, 3, .horizontal, false, 5),
                    car("G", 4, 5, 2, .vertical, false, 6),
                    car("H", 5, 1, 3, .horizontal, false, 7)
                ])
            ]
        }
    }

    private static func board(_ vehicles: [GridlockVehicle]) -> GridlockBoard {
        GridlockBoard(size: 6, exitRow: 2, vehicles: vehicles)
    }

    private static func car(
        _ id: String,
        _ row: Int,
        _ col: Int,
        _ length: Int,
        _ orientation: GridlockOrientation,
        _ isTarget: Bool,
        _ colorIndex: Int
    ) -> GridlockVehicle {
        GridlockVehicle(
            id: id,
            row: row,
            col: col,
            length: length,
            orientation: orientation,
            isTarget: isTarget,
            colorIndex: colorIndex
        )
    }
}
