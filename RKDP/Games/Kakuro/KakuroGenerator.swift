import Foundation

struct KakuroGenerator {
    // Pre-defined puzzle layouts as (rows, cols, layout string, clues)
    // Layout key: '#' = black, '.' = white entry, digits in black cells = clue markers
    // For simplicity, we ship a set of hand-crafted layouts per difficulty.

    static func generate(difficulty: Difficulty) -> KakuroBoard {
        switch difficulty {
        case .easy:   return buildBoard(layout: easyLayout)
        case .medium: return buildBoard(layout: mediumLayout)
        case .hard:   return buildBoard(layout: hardLayout)
        case .expert: return buildBoard(layout: expertLayout)
        }
    }

    // MARK: - Board builder from flat layout descriptor

    struct LayoutDescriptor {
        let rows: Int
        let cols: Int
        // Each element: nil = entry cell, (across, down) = clue black cell, (-1,-1) = plain black
        let cells: [(across: Int?, down: Int?)?]
    }

    private static func buildBoard(layout: LayoutDescriptor) -> KakuroBoard {
        var kakuroCells: [KakuroCell] = []
        var clues: [KakuroClue] = []
        var clueID = 0

        for idx in 0..<layout.cells.count {
            let row = idx / layout.cols, col = idx % layout.cols
            if let descriptor = layout.cells[idx] {
                // Black / clue cell
                kakuroCells.append(KakuroCell(
                    id: idx, row: row, col: col,
                    type: .white(acrossClue: descriptor.across, downClue: descriptor.down),
                    value: 0, isSelected: false, isInvalid: false, notes: []
                ))
            } else {
                // Entry cell
                kakuroCells.append(KakuroCell(
                    id: idx, row: row, col: col,
                    type: .entry, value: 0, isSelected: false, isInvalid: false, notes: []
                ))
            }
        }

        // Build across clues
        for row in 0..<layout.rows {
            var runStart: Int? = nil
            var runIDs: [Int] = []
            for col in 0..<layout.cols {
                let idx = row * layout.cols + col
                if case .entry = kakuroCells[idx].type {
                    if runStart == nil { runStart = idx }
                    runIDs.append(idx)
                } else {
                    if runIDs.count >= 2 {
                        if let clueIdx = runStart.map({ $0 - 1 }),
                           clueIdx >= 0,
                           case .white(let ac, _) = kakuroCells[clueIdx].type,
                           let sum = ac {
                            clues.append(KakuroClue(id: clueID, sum: sum, cellIDs: runIDs, isAcross: true))
                            clueID += 1
                        }
                    }
                    runStart = nil; runIDs = []
                }
            }
        }

        // Build down clues
        for col in 0..<layout.cols {
            var runStart: Int? = nil
            var runIDs: [Int] = []
            for row in 0..<layout.rows {
                let idx = row * layout.cols + col
                if case .entry = kakuroCells[idx].type {
                    if runStart == nil { runStart = idx }
                    runIDs.append(idx)
                } else {
                    if runIDs.count >= 2 {
                        let clueIdx = (runStart.map { $0 / layout.cols } ?? 0 - 1) * layout.cols + col
                        if clueIdx >= 0,
                           case .white(_, let dc) = kakuroCells[clueIdx].type,
                           let sum = dc {
                            clues.append(KakuroClue(id: clueID, sum: sum, cellIDs: runIDs, isAcross: false))
                            clueID += 1
                        }
                    }
                    runStart = nil; runIDs = []
                }
            }
        }

        return KakuroBoard(cells: kakuroCells, clues: clues, rows: layout.rows, cols: layout.cols)
    }

    // MARK: - Layouts

    // Compact helper: nil = entry, some((a,d)) = clue cell
    private typealias C = (across: Int?, down: Int?)?

    private static var easyLayout: LayoutDescriptor {
        // 6×6 board
        let B: C = (nil, nil) as C  // plain black
        let E: C = nil              // entry
        let cells: [C] = [
            B,        (nil,3),  (nil,4),  B,        (nil,6),  (nil,7),
            (4,nil),  E,        E,        (3,nil),  E,        E,
            (7,nil),  E,        E,        E,        E,        E,
            B,        (nil,6),  (nil,3),  B,        (nil,5),  (nil,4),
            (6,nil),  E,        E,        (5,nil),  E,        E,
            (5,nil),  E,        E,        (7,nil),  E,        E,
        ]
        return LayoutDescriptor(rows: 6, cols: 6, cells: cells)
    }

    private static var mediumLayout: LayoutDescriptor {
        let B: C = (nil, nil) as C
        let E: C = nil
        let cells: [C] = [
            B,        B,        (nil,10), (nil,15), B,        (nil,7),  (nil,8),  B,
            B,        (16,nil), E,        E,        (11,nil), E,        E,        E,
            (17,nil), E,        E,        E,        E,        B,        (nil,9),  B,
            (15,nil), E,        E,        B,        (nil,8),  (nil,6),  E,        (nil,5),
            B,        (nil,6),  (nil,9),  (13,nil), E,        E,        E,        E,
            (12,nil), E,        E,        E,        E,        (7,nil),  E,        E,
            (8,nil),  E,        E,        B,        (6,nil),  E,        E,        B,
            B,        (10,nil), E,        (9,nil),  E,        E,        B,        B,
        ]
        return LayoutDescriptor(rows: 8, cols: 8, cells: cells)
    }

    private static var hardLayout: LayoutDescriptor {
        // Reuse medium layout for now with shuffled sums (placeholder)
        mediumLayout
    }

    private static var expertLayout: LayoutDescriptor {
        mediumLayout
    }
}
