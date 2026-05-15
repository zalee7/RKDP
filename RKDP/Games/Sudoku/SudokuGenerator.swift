import Foundation

struct SudokuGenerator {
    static func generate(difficulty: Difficulty, seed: Int? = nil) -> (puzzle: [[Int]], solution: [[Int]]) {
        var rng = SeededRNG(seed: seed ?? Int.random(in: 0..<Int.max))
        let solution = generateFullBoard(rng: &rng)
        let puzzle = createPuzzle(from: solution, clues: difficulty.sudokuClues, rng: &rng)
        return (puzzle, solution)
    }

    private static func generateFullBoard(rng: inout SeededRNG) -> [[Int]] {
        var g = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for box in 0..<3 { fillBox(&g, boxRow: box, boxCol: box, rng: &rng) }
        _ = solveWithShuffle(&g, rng: &rng)
        return g
    }

    private static func fillBox(_ grid: inout [[Int]], boxRow: Int, boxCol: Int, rng: inout SeededRNG) {
        var nums = rng.shuffled(Array(1...9))
        let sr = boxRow * 3, sc = boxCol * 3
        for r in 0..<3 { for c in 0..<3 { grid[sr + r][sc + c] = nums.removeFirst() } }
    }

    private static func solveWithShuffle(_ g: inout [[Int]], rng: inout SeededRNG) -> Bool {
        guard let (row, col) = nextEmpty(g) else { return true }
        for num in rng.shuffled(Array(1...9)) {
            if SudokuSolver.isValid(g, row: row, col: col, num: num) {
                g[row][col] = num
                if solveWithShuffle(&g, rng: &rng) { return true }
                g[row][col] = 0
            }
        }
        return false
    }

    private static func nextEmpty(_ g: [[Int]]) -> (Int, Int)? {
        for r in 0..<9 { for c in 0..<9 { if g[r][c] == 0 { return (r, c) } } }
        return nil
    }

    private static func createPuzzle(from solution: [[Int]], clues: Int, rng: inout SeededRNG) -> [[Int]] {
        var puzzle = solution
        var positions = rng.shuffled(Array(0..<81))
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

