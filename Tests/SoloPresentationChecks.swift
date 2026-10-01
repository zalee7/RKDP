import Foundation

// Dependencies used only by unrelated methods in the extracted production types.
enum AppPreferenceKeys {
    static let reduceExtraAnimations = "reduceExtraAnimations"
}

struct MatchPlayerResult {
    var completed: Bool
    var elapsedSeconds: Int
    var score: Int
    var moveCount: Int
    var progress: Double
    var totalGuesses: Int
}

@main
struct SoloPresentationChecks {
    static func main() throws {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        func result(_ mode: GameMode, _ difficulty: Difficulty = .easy, completed: Bool = true) -> SoloGameResult {
            SoloGameResult(mode: mode, difficulty: difficulty, completed: completed,
                           title: "Result", message: "", elapsedSeconds: 60,
                           score: 10, guesses: 3, stats: [])
        }

        let fresh = SoloRunProgress(previousBest: nil, completedDifficulties: [])
        for mode in GameMode.allCases {
            for difficulty in Difficulty.allCases {
                let success = result(mode, difficulty)
                check(fresh.newlyUnlockedDifficulty(for: success) == difficulty.next, "First completion unlocks the immediate next step")
                check(fresh.newlyUnlockedDifficulty(for: result(mode, difficulty, completed: false)) == nil, "Failure never unlocks")
                let replay = SoloRunProgress(previousBest: nil, completedDifficulties: [difficulty])
                check(replay.newlyUnlockedDifficulty(for: success) == nil, "Replay must not announce an old unlock")
                check(!mode.soloCompletionRequirement.isEmpty, "Every mode describes success")
            }
        }

        var priorRun = result(.wordle)
        priorRun.elapsedSeconds = 70
        priorRun.score = 15
        priorRun.guesses = 4
        let prior = SoloRunProgress(previousBest: SoloPersonalBest(result: priorRun), completedDifficulties: [])
        for mode in [GameMode.colorLink, .sudoku, .gridlock, .minesweeper] {
            check(prior.bestComparison(for: result(mode))?.isNewBest == true, "Faster solve is a record")
            check(prior.bestComparison(for: result(mode, completed: false)) == nil, "Fast failed attempt is not a record")
        }
        check(prior.bestComparison(for: result(.wordle))?.isNewBest == true, "Fewer guesses wins")
        check(prior.bestComparison(for: result(.wordle, completed: false)) == nil, "Failed word is not a guess record")
        check(prior.bestComparison(for: result(.hangman)) == nil, "Legacy Lava Rescue missing wrong-letter data cannot create a new record")
        var rescue = result(.hangman)
        rescue.wrongGuesses = 1
        check(fresh.bestComparison(for: rescue)?.isNewBest == true, "Lava Rescue records a real timed attempt without a time limit")
        for mode in [GameMode.anagram, .wordHunt] {
            var scored = result(mode)
            check(prior.bestComparison(for: scored)?.isNewBest == false, "Lower score is not a record")
            scored.score = 20
            check(prior.bestComparison(for: scored)?.isNewBest == true, "Higher score is a record")
            scored.score = 0
            check(fresh.bestComparison(for: scored) == nil, "Zero words must not celebrate a first record")
        }
        let same = SoloPersonalBest(result: result(.sudoku))!
        let tie = SoloBestComparison(current: same, previous: same, mode: .sudoku)
        check(!tie.isNewBest && tie.title == "Personal Best Matched", "Ties are explicit")
        var singleGuess = result(.wordle)
        singleGuess.guesses = 1
        check(SoloPersonalBest(result: singleGuess)!.displayText(for: .wordle).hasPrefix("1 guess ·"), "Singular guess")
        check(fresh.bestComparison(for: result(.sudoku))?.title == "First Personal Best", "First valid solve")
        check(GameMode.hangman.soloTimingDescription == "Untimed", "Lava Rescue timing")
        check(GameMode.sudoku.soloTimingDescription == "No time limit", "Online clock must not leak into solo lobby")
        check(GameMode.anagram.soloTimingDescription == "60-second round", "Anagram timing")
        check(GameMode.wordHunt.soloTimingDescription == "75-second round", "Word Hunt timing")

        var ranks = RankInfo.empty
        for mode in GameMode.allCases {
            var modeRank = RankInfo.empty
            for (index, difficulty) in Difficulty.allCases.enumerated() {
                var completedRun = result(mode, difficulty)
                completedRun.elapsedSeconds = 60 + index
                completedRun.wrongGuesses = 1
                completedRun.moves = 30
                modeRank.recordSoloBest(completedRun)
                check(modeRank.soloBest(for: difficulty)?.elapsedSeconds == 60 + index,
                      "Every mode saves a completed run under its actual difficulty")
            }
            let restored = try JSONDecoder().decode(RankInfo.self, from: JSONEncoder().encode(modeRank))
            for (index, difficulty) in Difficulty.allCases.enumerated() {
                check(restored.soloBest(for: difficulty)?.elapsedSeconds == 60 + index,
                      "Every mode retains each difficulty's record through encoding")
            }
        }
        ranks.soloBest = BestStat(time: 5)
        var easy = result(.wordle)
        easy.guesses = 2
        easy.elapsedSeconds = 50
        ranks.recordSoloBest(easy)
        var fastButWorse = easy
        fastButWorse.guesses = 3
        fastButWorse.elapsedSeconds = 10
        ranks.recordSoloBest(fastButWorse)
        check(ranks.soloBest(for: .easy)?.elapsedSeconds == 50, "Do not combine fastest time and fewest guesses from different runs")
        var fasterTie = easy
        fasterTie.elapsedSeconds = 40
        ranks.recordSoloBest(fasterTie)
        check(ranks.soloBest(for: .easy)?.elapsedSeconds == 40, "Equal guesses use faster time")
        var hard = easy
        hard.difficulty = .hard
        hard.elapsedSeconds = 90
        ranks.recordSoloBest(hard)
        check(ranks.soloBest(for: .hard)?.elapsedSeconds == 90, "Difficulties have independent records")
        check(ranks.soloBest(for: .medium) == nil, "No fabricated record for an unplayed difficulty")
        check(ranks.soloBest?.time == 5, "Legacy aggregate preserved")
        let encoded = try JSONEncoder().encode(ranks)
        let decoded = try JSONDecoder().decode(RankInfo.self, from: encoded)
        check(decoded.soloBestsByDifficulty == ranks.soloBestsByDifficulty, "New records round-trip")
        let legacy = Data(#"{"points":0,"tier":0,"wins":0,"losses":0,"soloBest":{"time":12}}"#.utf8)
        let oldUserRank = try JSONDecoder().decode(RankInfo.self, from: legacy)
        check(oldUserRank.soloBestsByDifficulty == nil && oldUserRank.soloBest?.time == 12, "Existing users decode without migration")
        var loss = easy
        loss.completed = false
        loss.elapsedSeconds = 0
        ranks.recordSoloBest(loss)
        check(ranks.soloBest(for: .easy)?.elapsedSeconds == 40, "Failure cannot replace a successful record")
        print("Passed \(checks) solo presentation checks across all eight modes.")
    }
}
