import Foundation

struct SudokuSolver {
    // Returns a solved copy of the grid, or nil if unsolvable
    static func solve(_ grid: [[Int]]) -> [[Int]]? {
        var g = grid
        return backtrack(&g) ? g : nil
    }

    // Returns true if the puzzle has exactly one solution
    static func hasUniqueSolution(_ grid: [[Int]]) -> Bool {
        var g = grid
        var count = 0
        countSolutions(&g, count: &count, limit: 2)
        return count == 1
    }

    private static func backtrack(_ g: inout [[Int]]) -> Bool {
        guard let (row, col) = nextEmpty(g) else { return true }
        for num in 1...9 {
            if isValid(g, row: row, col: col, num: num) {
                g[row][col] = num
                if backtrack(&g) { return true }
                g[row][col] = 0
            }
        }
        return false
    }

    private static func countSolutions(_ g: inout [[Int]], count: inout Int, limit: Int) {
        guard count < limit else { return }
        guard let (row, col) = nextEmpty(g) else { count += 1; return }
        for num in 1...9 {
            if isValid(g, row: row, col: col, num: num) {
                g[row][col] = num
                countSolutions(&g, count: &count, limit: limit)
                g[row][col] = 0
            }
        }
    }

    private static func nextEmpty(_ g: [[Int]]) -> (Int, Int)? {
        for r in 0..<9 { for c in 0..<9 { if g[r][c] == 0 { return (r, c) } } }
        return nil
    }

    static func isValid(_ g: [[Int]], row: Int, col: Int, num: Int) -> Bool {
        if g[row].contains(num) { return false }
        if (0..<9).contains(where: { g[$0][col] == num }) { return false }
        let sr = (row / 3) * 3, sc = (col / 3) * 3
        for r in sr..<sr+3 { for c in sc..<sc+3 { if g[r][c] == num { return false } } }
        return true
    }
}
