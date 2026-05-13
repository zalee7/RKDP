import Foundation

struct SudokuGenerator {
    static func generate(difficulty: Difficulty) -> (puzzle: [[Int]], solution: [[Int]]) {
        let solution = generateFullBoard()
        let puzzle = createPuzzle(from: solution, clues: difficulty.sudokuClues)
        return (puzzle, solution)
    }

    private static func generateFullBoard() -> [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        // Seed the diagonal 3×3 boxes (they're independent of each other)
        for box in 0..<3 {
            fillBox(&grid, boxRow: box, boxCol: box)
        }
        _ = SudokuSolver.solve(grid) // fills the rest deterministically via backtrack
        // Re-solve with shuffle for randomness
        var g = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for box in 0..<3 { fillBox(&g, boxRow: box, boxCol: box) }
        _ = solveWithShuffle(&g)
        return g
    }

    private static func fillBox(_ grid: inout [[Int]], boxRow: Int, boxCol: Int) {
        var nums = (1...9).shuffled()
        let sr = boxRow * 3, sc = boxCol * 3
        for r in 0..<3 { for c in 0..<3 { grid[sr + r][sc + c] = nums.removeFirst() } }
    }

    private static func solveWithShuffle(_ g: inout [[Int]]) -> Bool {
        guard let (row, col) = nextEmpty(g) else { return true }
        for num in (1...9).shuffled() {
            if SudokuSolver.isValid(g, row: row, col: col, num: num) {
                g[row][col] = num
                if solveWithShuffle(&g) { return true }
                g[row][col] = 0
            }
        }
        return false
    }

    private static func nextEmpty(_ g: [[Int]]) -> (Int, Int)? {
        for r in 0..<9 { for c in 0..<9 { if g[r][c] == 0 { return (r, c) } } }
        return nil
    }

    private static func createPuzzle(from solution: [[Int]], clues: Int) -> [[Int]] {
        var puzzle = solution
        var positions = (0..<81).shuffled()
        var removed = 0
        let target = 81 - clues

        while removed < target, !positions.isEmpty {
            let idx = positions.removeFirst()
            let r = idx / 9, c = idx % 9
            let backup = puzzle[r][c]
            puzzle[r][c] = 0
            if SudokuSolver.hasUniqueSolution(puzzle) {
                removed += 1
            } else {
                puzzle[r][c] = backup
            }
        }
        return puzzle
    }
}
