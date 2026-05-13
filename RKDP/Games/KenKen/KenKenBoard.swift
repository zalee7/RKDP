import Foundation

enum KenKenOperation: String, Codable {
    case add      = "+"
    case subtract = "-"
    case multiply = "×"
    case divide   = "÷"
    case given    = ""   // single-cell cage with a given value

    func apply(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        switch self {
        case .add:
            return values.reduce(0, +)
        case .subtract:
            guard values.count == 2 else { return nil }
            return abs(values[0] - values[1])
        case .multiply:
            return values.reduce(1, *)
        case .divide:
            guard values.count == 2 else { return nil }
            let (a, b) = (max(values[0], values[1]), min(values[0], values[1]))
            return b == 0 ? nil : (a % b == 0 ? a / b : nil)
        case .given:
            return values.count == 1 ? values[0] : nil
        }
    }
}

struct KenKenCage: Identifiable {
    var id: Int
    var target: Int
    var operation: KenKenOperation
    var cellIDs: [Int]
}

struct KenKenCell: Identifiable {
    var id: Int
    var row: Int
    var col: Int
    var value: Int      // 0 = empty
    var cageID: Int
    var isSelected: Bool
    var isInvalid: Bool
    var notes: Set<Int>
    var isTopLeft: Bool  // whether this cell shows the cage label
}

struct KenKenBoard {
    let size: Int        // 4, 5, or 6
    var cells: [KenKenCell]
    var cages: [KenKenCage]

    var isSolved: Bool {
        guard cells.allSatisfy({ $0.value != 0 }) else { return false }
        // All rows and columns valid
        for i in 0..<size {
            let row = (0..<size).map { cells[i * size + $0].value }
            let col = (0..<size).map { cells[$0 * size + i].value }
            let expected = Set(1...size)
            if Set(row) != expected || Set(col) != expected { return false }
        }
        // All cage targets satisfied
        return cages.allSatisfy { cage in
            let vals = cage.cellIDs.map { cells[$0].value }
            return cage.operation.apply(vals) == cage.target
        }
    }

    mutating func setValue(_ value: Int, at id: Int) {
        cells[id].value = value
        markInvalid()
    }

    mutating func markInvalid() {
        var invalid = Set<Int>()

        // Row / column uniqueness
        for i in 0..<size {
            let rowIDs = (0..<size).map { i * size + $0 }
            let colIDs = (0..<size).map { $0 * size + i }
            markDups(rowIDs, into: &invalid)
            markDups(colIDs, into: &invalid)
        }

        // Cage overshoot or completed with wrong target
        for cage in cages {
            let vals = cage.cellIDs.map { cells[$0].value }
            let filled = vals.filter { $0 != 0 }
            let partial = cage.operation.apply(filled)
            if let result = cage.operation.apply(vals), result != cage.target {
                cage.cellIDs.forEach { invalid.insert($0) }
            } else if let p = partial, vals.allSatisfy({ $0 != 0 }), p != cage.target {
                cage.cellIDs.forEach { invalid.insert($0) }
            }
        }

        for i in 0..<cells.count { cells[i].isInvalid = invalid.contains(i) }
    }

    private func markDups(_ ids: [Int], into set: inout Set<Int>) {
        var seen: [Int: Int] = [:]
        for id in ids {
            let v = cells[id].value
            guard v != 0 else { continue }
            if let prev = seen[v] { set.insert(prev); set.insert(id) }
            else { seen[v] = id }
        }
    }
}
