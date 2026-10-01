import Foundation

// Keep input/game logic tests offline; these stand in only for app services and configuration.
enum Difficulty: CaseIterable { case easy, medium, hard, expert }
enum GameMode { case wordHunt, anagram }
struct WordHuntPuzzleData { let gridRows: [String] }
struct AnagramPuzzleData { let baseWord: String; let letters: String }
enum WordListService {
    static let wordHuntValidWords: Set<String> = ["CAT", "CATS", "CAR", "CART", "ART", "TAR", "RAT", "STAR"]
    static let anagramValidWords = wordHuntValidWords
    static func anagramBaseWords(for difficulty: Difficulty) -> [String] { ["CARTS"] }
}
final class SoundManager {
    static let shared = SoundManager()
    func keyboardPress() {}
    func wordInvalid() {}
    func wordFound(length: Int) {}
    func gameOver() {}
    func resetCombo() {}
}
final class FirestoreService {
    static let shared = FirestoreService()
    func updateBestScore(userID: String, mode: GameMode, score: Int) async throws {}
}

@main
struct WordGameInputChecks {
    @MainActor
    static func main() {
        var count = 0
        func check(_ value: Bool, _ message: String) {
            precondition(value, message)
            count += 1
        }
        func keys(_ cells: [(row: Int, col: Int)]) -> [String] {
            cells.map { "\($0.row),\($0.col)" }
        }
        for size in 4...7 {
            let cellSize = CGFloat(320) / CGFloat(size)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * cellSize, y: y * cellSize)
            }
            func sweep(_ a: CGPoint, _ b: CGPoint) -> [String] {
                keys(WordHuntTraceGeometry.crossedCells(from: a, to: b, cellSize: cellSize, size: size))
            }
            let first = point(0.5, 0.5)
            let corner = point(1.04, 0.96)
            check(sweep(first, corner) == ["0,0"], "Diagonal corner jitter must not grab an orthogonal tile")
            check(sweep(corner, point(1.5, 1.5)) == ["1,1"], "Diagonal destination is accepted without a side tile")
            check(sweep(first, point(3.5, 3.5)) == ["0,0", "1,1", "2,2", "3,3"], "Fast diagonal preserves each crossed center")
            check(sweep(point(3.5, 0.5), point(0.5, 3.5)) == ["0,3", "1,2", "2,1", "3,0"], "Opposite diagonal")
            check(sweep(first, point(3.5, 0.5)) == ["0,0", "0,1", "0,2", "0,3"], "Fast horizontal")
            check(sweep(first, point(0.5, 3.5)) == ["0,0", "1,0", "2,0", "3,0"], "Fast vertical")
            check(sweep(point(-0.1, 0), point(-0.1, 4)).isEmpty, "Outside drags are not clamped to edge tiles")
            check(sweep(point(1, 1), point(1, 1)).isEmpty, "An ambiguous corner alone does not select a tile")
            check(sweep(first, first) == ["0,0"], "Stationary center is valid")
            check(WordHuntTraceGeometry.cell(at: point(-0.1, 0.5), cellSize: cellSize, size: size) == nil, "Start must be inside board")
            check(WordHuntTraceGeometry.cell(at: point(CGFloat(size), 0.5), cellSize: cellSize, size: size) == nil, "Right edge is outside")

            // Replay the same slightly imperfect diagonal with different event sampling rates.
            for samples in [1, 4, 16, 64] {
                var path = ["0,0"]
                var previous = first
                for i in 1...samples {
                    let fraction = CGFloat(i) / CGFloat(samples)
                    let current = point(0.5 + 3 * fraction, 0.5 + 2.95 * fraction)
                    for key in sweep(previous, current) where !path.contains(key) { path.append(key) }
                    previous = current
                }
                check(path == ["0,0", "1,1", "2,2", "3,3"], "Diagonal path must not depend on touch update frequency")
            }
        }

        let puzzle = WordHuntPuzzleData(gridRows: ["CXXX", "XAXX", "XXTX", "XXXS"])
        let vm = WordHuntViewModel(difficulty: .easy, seed: 5, puzzleData: puzzle)
        vm.stop()
        vm.startPath(row: -1, col: 0)
        check(vm.currentPath.isEmpty, "Invalid coordinates cannot start a word")
        vm.startPath(row: 0, col: 0)
        vm.extendPath(row: 2, col: 2)
        check(vm.currentWord == "C", "Adjacency still enforced")
        vm.extendPath(row: 1, col: 1)
        vm.extendPath(row: 0, col: 0)
        check(vm.currentWord == "CA", "Forward-only rule: no repeated tile")
        vm.extendPath(row: 2, col: 2)
        vm.submitPath()
        check(vm.score == 1 && vm.foundWords == ["CAT"], "A diagonal word scores")
        check(vm.currentPath.isEmpty && vm.currentWord.isEmpty, "Submission clears the active trace")
        for _ in 0..<2 {
            vm.startPath(row: 0, col: 0)
            vm.extendPath(row: 1, col: 1)
            vm.extendPath(row: 2, col: 2)
            vm.submitPath()
        }
        check(vm.score == 1 && vm.lastWordResult == .alreadyFound, "Repeated words do not add points")
        vm.startPath(row: 0, col: 1)
        vm.extendPath(row: 0, col: 2)
        vm.extendPath(row: 0, col: 3)
        vm.submitPath()
        check(vm.score == 1 && vm.lastWordResult == .invalid, "Invalid words do not add points")
        vm.startPath(row: 0, col: 0)
        vm.extendPath(row: 1, col: 1)
        vm.extendPath(row: 2, col: 2)
        vm.extendPath(row: 3, col: 3)
        vm.isFinished = true
        vm.submitPath()
        vm.startPath(row: 0, col: 0)
        vm.extendPath(row: 1, col: 1)
        check(vm.score == 1 && vm.currentPath.isEmpty, "No input or late submission after time expires")

        let replay = WordHuntViewModel(difficulty: .easy, seed: 5, puzzleData: puzzle)
        replay.stop()
        check(replay.score == 0 && replay.foundWords.isEmpty && !replay.isFinished, "Replay starts fresh")
        check(replay.game.grid == vm.game.grid && replay.game.validWords == vm.game.validWords, "Shared puzzle is deterministic")
        check(replay.game.canForm("CATS"), "Diagonal four-letter word is legal")
        check(!replay.game.canForm("CATAC"), "No reusing tiles in legal paths")
        for difficulty in Difficulty.allCases {
            let first = WordHuntGame.generate(difficulty: difficulty, seed: 42)
            let second = WordHuntGame.generate(difficulty: difficulty, seed: 42)
            check(first.grid == second.grid && first.validWords == second.validWords, "Same seed and difficulty produce same puzzle")
        }
        let anagramPuzzle = AnagramPuzzleData(baseWord: "CARTS", letters: "SCRAT")
        let anagram = AnagramViewModel(difficulty: .easy, seed: 42, puzzleData: anagramPuzzle)
        anagram.stop()
        func enter(_ word: String) {
            for letter in word {
                if let tile = anagram.bank.first(where: { $0.letter == letter }) { anagram.pickFromBank(id: tile.id) }
            }
        }
        enter("CA")
        anagram.submit()
        check(anagram.lastResult == .tooShort && anagram.score == 0, "Short input does not score")
        check(anagram.placed.isEmpty && anagram.bank.count == 5, "Short input returns tiles")
        enter("CAT")
        anagram.submit()
        check(anagram.score == 1 && anagram.foundWords == ["CAT"], "Anagram valid word scores once")
        enter("CAT")
        anagram.submit()
        check(anagram.lastResult == .alreadyFound && anagram.score == 1, "Anagram repeat does not score")
        enter("SCT")
        anagram.submit()
        check(anagram.lastResult == .invalid && anagram.score == 1, "Anagram invalid input does not score")
        enter("CART")
        let bankIDs = anagram.bank.map(\.id)
        let placedIDs = anagram.placed.map(\.id)
        anagram.isFinished = true
        anagram.submit()
        anagram.shuffleBank()
        anagram.clearPlaced()
        if let tile = anagram.bank.first { anagram.pickFromBank(id: tile.id) }
        if let tile = anagram.placed.first { anagram.returnToBank(id: tile.id) }
        check(anagram.score == 1, "Anagram cannot score after time expires")
        check(anagram.bank.map(\.id) == bankIDs && anagram.placed.map(\.id) == placedIDs, "Finished Anagram tiles remain locked")
        let replayAnagram = AnagramViewModel(difficulty: .easy, seed: 42, puzzleData: anagramPuzzle)
        replayAnagram.stop()
        check(replayAnagram.score == 0 && replayAnagram.foundWords.isEmpty && replayAnagram.placed.isEmpty, "Anagram replay is fresh")
        check(replayAnagram.game.letters == anagram.game.letters, "Shared Anagram letters remain deterministic")
        check(!anagram.game.canForm("CATT"), "Anagram respects duplicate letter counts")
        for difficulty in Difficulty.allCases {
            let first = AnagramGame.generate(difficulty: difficulty, seed: 42)
            let second = AnagramGame.generate(difficulty: difficulty, seed: 42)
            check(first.letters == second.letters && first.validWords == second.validWords, "Same Anagram seed produces same puzzle")
        }
        print("Passed \(count) word-game input/game checks.")
    }
}
