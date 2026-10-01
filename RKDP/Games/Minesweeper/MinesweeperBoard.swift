import Foundation

enum CellState: Codable, Equatable {
    case hidden
    case revealed(Int)  // adjacentMines count
    case flagged
    case exploded
}

struct MinesweeperCell: Identifiable, Equatable {
    var id: Int
    var hasMine: Bool
    var state: CellState
    var row: Int
    var col: Int
}

enum MinesweeperStatus: Equatable {
    case idle, playing, won, lost
}

struct MinesweeperConfig {
    let rows: Int
    let cols: Int
    let mines: Int

    static let easy    = MinesweeperConfig(rows: 9,  cols: 9,  mines: 10)
    static let medium  = MinesweeperConfig(rows: 16, cols: 16, mines: 40)
    static let hard    = MinesweeperConfig(rows: 16, cols: 30, mines: 99)
    static let expert  = MinesweeperConfig(rows: 20, cols: 30, mines: 145)

    static func from(_ difficulty: Difficulty) -> MinesweeperConfig {
        switch difficulty {
        case .easy:   return .easy
        case .medium: return .medium
        case .hard:   return .hard
        case .expert: return .expert
        }
    }
}

struct MinesweeperBoard {
    let config: MinesweeperConfig
    var cells: [MinesweeperCell]
    var status: MinesweeperStatus = .idle
    var flagCount: Int = 0
    var revealedCount: Int = 0

    var safeCells: Int { config.rows * config.cols - config.mines }
    var remainingMines: Int { config.mines - flagCount }

    init(config: MinesweeperConfig) {
        self.config = config
        cells = (0..<config.rows * config.cols).map { idx in
            MinesweeperCell(id: idx, hasMine: false, state: .hidden, row: idx / config.cols, col: idx % config.cols)
        }
    }

    var seed: Int?

    // First reveal seeds mines away from firstTap and its neighbours
    mutating func firstReveal(row: Int, col: Int) {
        guard status == .idle, contains(row: row, col: col), cells[row * config.cols + col].state == .hidden else { return }
        placeMines(avoiding: neighbours(row: row, col: col) + [row * config.cols + col], seed: seed)
        status = .playing
        reveal(row: row, col: col)
    }

    mutating func reveal(row: Int, col: Int) {
        guard status == .playing, contains(row: row, col: col) else { return }
        let idx = row * config.cols + col
        guard case .hidden = cells[idx].state else { return }

        if cells[idx].hasMine {
            cells[idx].state = .exploded
            status = .lost
            revealAllMines()
            return
        }

        let adj = adjacentMineCount(row: row, col: col)
        cells[idx].state = .revealed(adj)
        revealedCount += 1

        if adj == 0 {
            for nIdx in neighbours(row: row, col: col) {
                if case .hidden = cells[nIdx].state { reveal(row: nIdx / config.cols, col: nIdx % config.cols) }
            }
        }

        if revealedCount == safeCells { status = .won }
    }

    mutating func toggleFlag(row: Int, col: Int) {
        guard (status == .idle || status == .playing), contains(row: row, col: col) else { return }
        let idx = row * config.cols + col
        switch cells[idx].state {
        case .hidden:
            cells[idx].state = .flagged
            flagCount += 1
        case .flagged:
            cells[idx].state = .hidden
            flagCount -= 1
        default: break
        }
    }

    // Chord-reveal: if cell is revealed and flag count == adj mines, reveal all hidden neighbours
    mutating func chord(row: Int, col: Int) {
        guard status == .playing, contains(row: row, col: col) else { return }
        let idx = row * config.cols + col
        guard case .revealed(let adj) = cells[idx].state else { return }
        let nbrs = neighbours(row: row, col: col)
        let flags = nbrs.filter { if case .flagged = cells[$0].state { return true }; return false }.count
        guard flags == adj else { return }
        for nIdx in nbrs {
            if case .hidden = cells[nIdx].state { reveal(row: nIdx / config.cols, col: nIdx % config.cols) }
        }
    }

    private func contains(row: Int, col: Int) -> Bool {
        (0..<config.rows).contains(row) && (0..<config.cols).contains(col)
    }

    private mutating func placeMines(avoiding excluded: [Int], seed: Int?) {
        let excluded = Set(excluded)
        let allPositions = (0..<config.rows * config.cols).filter { !excluded.contains($0) }
        var positions: [Int]
        if let s = seed {
            var rng = SeededRNG(seed: s)
            positions = rng.shuffled(allPositions)
        } else {
            positions = allPositions.shuffled()
        }
        for _ in 0..<config.mines {
            guard !positions.isEmpty else { break }
            cells[positions.removeFirst()].hasMine = true
        }
    }

    private func adjacentMineCount(row: Int, col: Int) -> Int {
        neighbours(row: row, col: col).filter { cells[$0].hasMine }.count
    }

    private func neighbours(row: Int, col: Int) -> [Int] {
        var result: [Int] = []
        for dr in -1...1 {
            for dc in -1...1 {
                guard !(dr == 0 && dc == 0) else { continue }
                let nr = row + dr, nc = col + dc
                if nr >= 0 && nr < config.rows && nc >= 0 && nc < config.cols {
                    result.append(nr * config.cols + nc)
                }
            }
        }
        return result
    }

    private mutating func revealAllMines() {
        for i in 0..<cells.count where cells[i].hasMine {
            if case .hidden = cells[i].state { cells[i].state = .revealed(0) }
        }
    }
}
