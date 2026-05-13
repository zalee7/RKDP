import Foundation

// A run of cells sharing a sum constraint
struct KakuroClue: Identifiable {
    var id: Int
    var sum: Int
    var cellIDs: [Int]      // indices into KakuroBoard.cells
    var isAcross: Bool
}

enum KakuroCellType: Codable, Equatable {
    case black                          // wall / clue cell
    case white(acrossClue: Int?, downClue: Int?)   // playable cell; carries the sum labels
    case entry                          // user-enterable white cell (no clue label)
}

struct KakuroCell: Identifiable {
    var id: Int
    var row: Int
    var col: Int
    var type: KakuroCellType
    var value: Int          // 0 = empty (only meaningful for entry cells)
    var isSelected: Bool
    var isInvalid: Bool
    var notes: Set<Int>
}

struct KakuroBoard {
    var cells: [KakuroCell]
    var clues: [KakuroClue]
    let rows: Int
    let cols: Int

    var isSolved: Bool {
        clues.allSatisfy { clue in
            let vals = clue.cellIDs.map { cells[$0].value }
            return !vals.contains(0)
                && vals.reduce(0, +) == clue.sum
                && vals.count == Set(vals).count
        }
    }

    mutating func setValue(_ value: Int, at id: Int) {
        cells[id].value = value
        validateClues(containing: id)
    }

    private mutating func validateClues(containing cellID: Int) {
        let affected = clues.filter { $0.cellIDs.contains(cellID) }
        var invalidCells = Set<Int>()

        for clue in affected {
            let vals = clue.cellIDs.map { cells[$0].value }.filter { $0 != 0 }
            let hasDuplicates = vals.count != Set(vals).count
            let overSum = vals.reduce(0, +) > clue.sum

            if hasDuplicates || overSum {
                clue.cellIDs.forEach { invalidCells.insert($0) }
            }
        }

        for i in 0..<cells.count {
            cells[i].isInvalid = invalidCells.contains(i)
        }
    }
}
