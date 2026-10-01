import Foundation

enum AppPreferenceKeys { static let reduceExtraAnimations = "reduceExtraAnimations" }

@main struct SoloRewardCatalogExport {
    static func main() throws {
        let count = Int(CommandLine.arguments.dropFirst().first ?? "4") ?? 4
        precondition((1...200).contains(count))
        let includeProofs = CommandLine.arguments.contains("--test-proofs")
        let social = CommandLine.arguments.contains("--social")
        let online = social || CommandLine.arguments.contains("--online")
        var puzzles: [[String: Any]] = []
        for mode in GameMode.allCases {
            for difficulty in Difficulty.allCases {
                if online && !social && difficulty != mode.onlinePresetDifficulty { continue }
                for index in 0..<count {
                    let seed = 928_000 + index
                    let id = "\(online ? "match" : "solo")_v1_\(mode.rawValue)_\(difficulty.rawValue)_\(seed)"
                    var p: [String: Any] = ["id": id, "mode": mode.rawValue,
                        "difficulty": difficulty.rawValue, "seed": seed, "protocolVersion": online ? "match-v1" : "solo-v1"]
                    if online {
                        p["puzzleData"] = MultiplayerPuzzleDataFactory.onlinePayload(mode: mode, difficulty: difficulty, seed: seed, context: "server catalog")
                    }
                    switch mode {
                    case .sudoku:
                        let generated = SudokuGenerator.generate(difficulty: difficulty, seed: seed)
                        p["givens"] = generated.puzzle.flatMap { $0 }
                        if includeProofs { p["testEvidence"] = ["cells": generated.solution.flatMap { $0 }] }
                    case .colorLink:
                        let board = ColorLinkGenerator.generate(difficulty: difficulty, seed: seed)
                        p["size"] = board.size
                        p["pairs"] = board.pairs.map { pair in
                            ["id": pair.id, "start": pair.start.row * board.size + pair.start.col,
                             "end": pair.end.row * board.size + pair.end.col]
                        }
                        if includeProofs {
                            p["testEvidence"] = ["paths": Dictionary(uniqueKeysWithValues: board.pairs.map {
                                (String($0.id), $0.solutionPath.map { $0.row * board.size + $0.col })
                            })]
                        }
                    case .minesweeper:
                        let c = MinesweeperConfig.from(difficulty)
                        p["rows"] = c.rows; p["cols"] = c.cols; p["mines"] = c.mines
                        if includeProofs {
                            var board = MinesweeperBoard(config: c)
                            board.seed = seed
                            board.firstReveal(row: 0, col: 0)
                            p["testEvidence"] = ["firstCell": 0, "revealed": board.cells.filter { !$0.hasMine }.map(\.id)]
                        }
                    case .wordle:
                        p["target"] = WordleGame.targetWord(seed: seed, round: 0)
                        p["validGuesses"] = WordListService.wordleValidGuesses.sorted()
                        if includeProofs { p["testEvidence"] = ["guesses": [WordleGame.targetWord(seed: seed, round: 0)]] }
                        if online {
                            let targets = (0..<3).map { WordleGame.targetWord(seed: seed, round: $0) }
                            p["targets"] = targets
                            if includeProofs { p["testEvidence"] = ["rounds": targets.prefix(2).map { [$0] }] }
                        }
                    case .hangman:
                        let puzzle = HangmanGame.puzzle(difficulty: difficulty, seed: seed)
                        p["target"] = puzzle.word; p["starter"] = String(puzzle.starterLetter); p["maxWrong"] = 6
                        if includeProofs { p["testEvidence"] = ["letters": String(Set(puzzle.word).subtracting([puzzle.starterLetter]).sorted())] }
                        if online {
                            let rounds = (0..<3).map { HangmanGame.puzzle(difficulty: difficulty, seed: seed + $0 * 7_919) }
                            p["rounds"] = rounds.map { ["target": $0.word, "starter": String($0.starterLetter), "category": $0.category] }
                            if includeProofs { p["testEvidence"] = ["rounds": rounds.prefix(2).map { String(Set($0.word).subtracting([$0.starterLetter]).sorted()) }] }
                        }
                    case .anagram:
                        let game = AnagramGame.generate(difficulty: difficulty, seed: seed)
                        p["letters"] = String(game.letters); p["validWords"] = game.validWords.sorted()
                        if includeProofs { p["testEvidence"] = ["words": Array(game.validWords.sorted().prefix(3))] }
                    case .wordHunt:
                        let game = WordHuntGame.generate(difficulty: difficulty, seed: seed)
                        p["grid"] = game.grid.map { String($0) }; p["validWords"] = game.validWords.sorted()
                        if includeProofs { p["testEvidence"] = ["words": Array(game.validWords.sorted().prefix(3))] }
                    case .gridlock:
                        var rng = SeededRNG(seed: seed)
                        p["deck"] = rng.shuffled(Array(0..<52))
                    }
                    puzzles.append(p)
                }
            }
        }
        let data = try JSONSerialization.data(withJSONObject: puzzles, options: [.sortedKeys])
        FileHandle.standardOutput.write(data)
    }
}
