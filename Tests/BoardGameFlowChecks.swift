import Foundation

enum AppPreferenceKeys { static let reduceExtraAnimations = "reduceExtraAnimations" }
final class SoundManager {
    static let shared = SoundManager()
    func keyboardPress() {}
    func gameOver() {}
}

@main
struct BoardGameFlowChecks {
    @MainActor static func main() {
        var count = 0
        func check(_ value: Bool, _ message: String) {
            precondition(value, message)
            count += 1
        }
        var completedSudoku: [SudokuViewModel] = []
        var completedColor: [ColorLinkViewModel] = []
        var completedMines: [MinesweeperViewModel] = []
        var completedSolitaire: [GridlockViewModel] = []

        for difficulty in Difficulty.allCases {
            let seed = 42
            let generated = SudokuGenerator.generate(difficulty: difficulty, seed: seed)
            let vm = SudokuViewModel(difficulty: difficulty, seed: seed)
            check(vm.board.toGrid() == generated.puzzle, "Sudoku seed reproducibility")
            check(SudokuSolver.hasUniqueSolution(generated.puzzle), "Sudoku has one solution")
            let blanks = vm.board.cells.filter { !$0.isGiven }.map(\.id)
            let first = blanks[0]
            vm.selectCell(id: first)
            vm.isNoteMode = true
            vm.enterDigit(3)
            check(vm.board.cells[first].value == 0 && vm.board.cells[first].notes == [3], "Notes don't enter digits")
            vm.enterDigit(3)
            check(vm.board.cells[first].notes.isEmpty, "Notes toggle")
            vm.isNoteMode = false
            vm.enterDigit(0)
            vm.enterDigit(12)
            check(vm.board.cells[first].value == 0, "Invalid digits rejected")
            let rowGiven = vm.board.cells.first { $0.row == first / 9 && $0.value != 0 }!
            vm.enterDigit(rowGiven.value)
            check(vm.board.cells[first].isInvalid && vm.mistakeCount == 1, "Conflicting entry is flagged and counted")
            vm.enterDigit(rowGiven.value)
            check(vm.mistakeCount == 1, "Identical repeated entry isn't another conflict")
            vm.erase()
            check(!vm.board.cells[first].isInvalid && vm.board.cells[first].value == 0, "Erase clears the conflict")
            vm.useHint()
            check(vm.hintsUsed == 1 && vm.board.cells[first].value == generated.solution[first / 9][first % 9], "Hint uses the real solution")
            check(abs(vm.progress - 1 / Double(blanks.count)) < 0.0001, "Hint progress uses original number of blank cells")
            vm.useHint()
            check(vm.hintsUsed == 1, "Repeated hint doesn't inflate the count")
            for id in blanks.dropFirst() {
                vm.selectCell(id: id)
                vm.enterDigit(generated.solution[id / 9][id % 9])
            }
            check(vm.isComplete && vm.progress == 1, "Sudoku completes through digit input")
            let solved = vm.board.cells
            vm.erase(); vm.enterDigit(1); vm.useHint(); vm.selectCell(id: first)
            check(vm.board.cells == solved && vm.hintsUsed == 1, "Completed Sudoku is immutable through controls")
            completedSudoku.append(vm)

            let link = ColorLinkViewModel(difficulty: difficulty, seed: seed)
            check(link.board == ColorLinkGenerator.generate(difficulty: difficulty, seed: seed), "Color Link deterministic board")
            let pair = link.board.pairs[0]
            link.beginDraw(row: pair.start.row, col: pair.start.col)
            let before = link.paths
            link.continueDraw(row: -1, col: -1)
            check(link.paths == before, "Off-board path rejected")
            let other = link.board.pairs[1].start
            link.continueDraw(row: other.row, col: other.col)
            check(link.paths == before, "Cannot enter another pair endpoint")
            let step = pair.solutionPath[1]
            link.continueDraw(row: step.row, col: step.col)
            link.continueDraw(row: pair.start.row, col: pair.start.col)
            check(link.paths[pair.id]?.count == 1, "Backtracking truncates an unfinished path")
            link.clearActivePath()
            check(link.paths[pair.id] == nil, "Clear removes current path")
            for pair in link.board.pairs {
                link.beginDraw(row: pair.start.row, col: pair.start.col)
                for cell in pair.solutionPath.dropFirst() { link.continueDraw(row: cell.row, col: cell.col) }
            }
            check(link.isComplete && link.fillProgress == 1 && link.solvedPairCount == link.board.pairs.count, "Generated Color Link solves through legal adjacent moves")
            let paths = link.paths
            link.beginDraw(row: pair.start.row, col: pair.start.col); link.clearActivePath()
            check(link.paths == paths, "Completed Color Link stays locked")
            completedColor.append(link)

            let mine = MinesweeperViewModel(difficulty: difficulty, seed: seed)
            mine.longPress(row: 0, col: 0)
            check(mine.board.cells[0].state == .flagged && mine.status == .idle, "Flagging before first reveal works without starting clock")
            mine.tap(row: 0, col: 0)
            check(mine.status == .idle, "Flagged first tap doesn't initialize the board")
            mine.longPress(row: 0, col: 0)
            mine.tap(row: 0, col: 0)
            check(mine.status == .playing && mine.board.cells[0].state == .revealed(0), "First reveal and neighbors are safe")
            check(mine.board.cells.filter(\.hasMine).count == mine.board.config.mines, "Exact mine count")
            let same = MinesweeperViewModel(difficulty: difficulty, seed: seed)
            same.tap(row: 0, col: 0)
            check(mine.board.cells == same.board.cells, "Same seed and starting cell reproduce Minesweeper")
            same.stop()
            let mines = mine.board.cells.filter(\.hasMine).map(\.id)
            let layout = mine.board.cells.map(\.hasMine)
            mine.board.firstReveal(row: 1, col: 1)
            check(layout == mine.board.cells.map(\.hasMine), "First reveal cannot reseed an active board")
            for cell in mine.board.cells where !cell.hasMine { mine.tap(row: cell.row, col: cell.col) }
            check(mine.status == .won && mine.board.revealedCount == mine.board.safeCells, "Revealing every safe cell wins")
            let won = mine.board.cells
            mine.tap(row: mines[0] / mine.board.config.cols, col: mines[0] % mine.board.config.cols)
            mine.longPress(row: 0, col: 0)
            check(mine.board.cells == won, "Won board ignores input")
            completedMines.append(mine)
            let loss = MinesweeperViewModel(difficulty: difficulty, seed: seed)
            loss.tap(row: 0, col: 0)
            let bomb = loss.board.cells.first(where: \.hasMine)!
            loss.tap(row: bomb.row, col: bomb.col)
            check(loss.status == .lost && loss.board.cells[bomb.id].state == .exploded, "Mine hit ends the game")
            loss.isFlagMode = true
            loss.restart()
            check(loss.status == .idle && loss.elapsedSeconds == 0 && loss.board.flagCount == 0 && !loss.isFlagMode, "Restart resets board, clock and input mode")
            loss.stop()

            let cards = GridlockViewModel(difficulty: difficulty, seed: seed)
            let originalStock = cards.stock
            let originalTableau = cards.tableau
            check(cards.stock.count == 24 && cards.tableau.map(\.count) == [1,2,3,4,5,6,7], "Klondike deal counts")
            check(Set((cards.stock + cards.tableau.flatMap { $0 }).map(\.id)).count == 52, "Deal contains 52 unique cards")
            check(cards.faceUpTableauCount == 7, "Exactly one face-up card per starting lane")
            let sameCards = GridlockViewModel(difficulty: difficulty, seed: seed)
            check(sameCards.stock == originalStock && sameCards.tableau == originalTableau, "Solitaire seed reproducibility")
            sameCards.stop()
            cards.drawFromStock()
            check(cards.waste.count == cards.rules.drawCount && cards.moveCount == 1, "Draw count follows difficulty")
            while !cards.stock.isEmpty { cards.drawFromStock() }
            cards.drawFromStock()
            check(cards.stock.map(\.id) == originalStock.map(\.id) && cards.waste.isEmpty && cards.redealsUsed == 1, "Redeal preserves stock order")
            if let limit = cards.rules.maxRedeals {
                for _ in 1..<limit {
                    while !cards.stock.isEmpty { cards.drawFromStock() }
                    cards.drawFromStock()
                }
                while !cards.stock.isEmpty { cards.drawFromStock() }
                let moves = cards.moveCount
                cards.drawFromStock()
                check(cards.stock.isEmpty && cards.redealsUsed == limit && cards.moveCount == moves, "Redeal cap enforced without consuming an invalid move")
            }
            cards.stop()
            // Controlled near-finish fixture exercises real foundation moves, not a fabricated win flag.
            let finish = GridlockViewModel(difficulty: difficulty, seed: seed)
            finish.stock = []; finish.waste = []
            finish.tableau = Array(repeating: [], count: 7)
            for (index, suit) in SolitaireSuit.allCases.enumerated() {
                finish.foundations[suit] = SolitaireRank.allCases.filter { $0 != .king }.map { SolitaireCard(suit: suit, rank: $0, isFaceUp: true) }
                finish.tableau[index] = [SolitaireCard(suit: suit, rank: .king, isFaceUp: true)]
            }
            finish.autoMoveToFoundations()
            check(finish.isComplete && finish.foundationCount == 52 && finish.progress == 1, "Final legal foundation moves complete Solitaire")
            let moveCount = finish.moveCount
            finish.drawFromStock(); finish.autoMoveToFoundations(); finish.tapTableau(column: 0, index: nil)
            check(finish.moveCount == moveCount && finish.foundationCount == 52, "Completed Solitaire rejects input")
            completedSolitaire.append(finish)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        check(completedSudoku.allSatisfy { $0.elapsedSeconds == 0 }, "Sudoku clock stops on win")
        check(completedColor.allSatisfy { $0.elapsedSeconds == 0 }, "Color Link clock stops on win")
        check(completedMines.allSatisfy { $0.elapsedSeconds == 0 }, "Minesweeper clock stops on win")
        check(completedSolitaire.allSatisfy { $0.elapsedSeconds == 0 }, "Solitaire clock stops on win")
        print("Passed \(count) board-game flow checks across four modes and four difficulties.")
    }
}
