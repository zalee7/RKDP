import Foundation

struct SudokuCell: Identifiable, Equatable {
    var id: Int             // row * 9 + col
    var value: Int          // 0 = empty
    var isGiven: Bool
    var notes: Set<Int>
    var isSelected: Bool
    var isHighlighted: Bool
    var isInvalid: Bool

    var row: Int { id / 9 }
    var col: Int { id % 9 }
    var box: Int { (row / 3) * 3 + (col / 3) }
}

struct SudokuBoard {
    var cells: [SudokuCell]

    init(given: [[Int]]) {
        cells = (0..<81).map { idx in
            let row = idx / 9, col = idx % 9
            let v = given[row][col]
            return SudokuCell(
                id: idx, value: v, isGiven: v != 0,
                notes: [], isSelected: false, isHighlighted: false, isInvalid: false
            )
        }
    }

    subscript(row: Int, col: Int) -> SudokuCell {
        get { cells[row * 9 + col] }
        set { cells[row * 9 + col] = newValue }
    }

    var isSolved: Bool {
        for idx in 0..<81 where cells[idx].value == 0 { return false }
        return !hasConflicts
    }

    var hasConflicts: Bool {
        for i in 0..<9 {
            if rowConflict(i) || colConflict(i) || boxConflict(i) { return true }
        }
        return false
    }

    private func rowConflict(_ row: Int) -> Bool {
        let vals = (0..<9).map { cells[row * 9 + $0].value }.filter { $0 != 0 }
        return vals.count != Set(vals).count
    }

    private func colConflict(_ col: Int) -> Bool {
        let vals = (0..<9).map { cells[$0 * 9 + col].value }.filter { $0 != 0 }
        return vals.count != Set(vals).count
    }

    private func boxConflict(_ box: Int) -> Bool {
        let startRow = (box / 3) * 3, startCol = (box % 3) * 3
        var vals: [Int] = []
        for r in startRow..<startRow+3 {
            for c in startCol..<startCol+3 {
                let v = cells[r * 9 + c].value
                if v != 0 { vals.append(v) }
            }
        }
        return vals.count != Set(vals).count
    }

    mutating func updateHighlights(selected: Int?) {
        guard let sel = selected else {
            for i in 0..<81 { cells[i].isHighlighted = false; cells[i].isSelected = false }
            return
        }
        let selRow = sel / 9, selCol = sel % 9, selBox = (selRow / 3) * 3 + (selCol / 3)
        let selVal = cells[sel].value
        for i in 0..<81 {
            let r = i / 9, c = i % 9, b = (r / 3) * 3 + (c / 3)
            cells[i].isSelected = (i == sel)
            cells[i].isHighlighted = r == selRow || c == selCol || b == selBox
                || (selVal != 0 && cells[i].value == selVal)
        }
    }

    mutating func markInvalidCells() {
        var invalid = Set<Int>()
        for i in 0..<9 {
            markConflicts(in: (0..<9).map { i * 9 + $0 }, into: &invalid)
            markConflicts(in: (0..<9).map { $0 * 9 + i }, into: &invalid)
            let sr = (i / 3) * 3, sc = (i % 3) * 3
            let boxIds = (0..<3).flatMap { r in (0..<3).map { c in (sr + r) * 9 + (sc + c) } }
            markConflicts(in: boxIds, into: &invalid)
        }
        for i in 0..<81 { cells[i].isInvalid = invalid.contains(i) }
    }

    private func markConflicts(in ids: [Int], into set: inout Set<Int>) {
        var seen: [Int: Int] = [:]
        for id in ids {
            let v = cells[id].value
            guard v != 0 else { continue }
            if let prev = seen[v] { set.insert(prev); set.insert(id) }
            else { seen[v] = id }
        }
    }

    func toGrid() -> [[Int]] {
        (0..<9).map { row in (0..<9).map { col in cells[row * 9 + col].value } }
    }
}
