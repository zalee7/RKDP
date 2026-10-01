import Foundation

enum AppPreferenceKeys { static let reduceExtraAnimations = "reduceExtraAnimations" }
final class SoundManager {
    static let shared = SoundManager()
    func keyboardPress() {}
    func wordInvalid() {}
    func gameOver() {}
}
struct MatchPlayerResult {
    let userID: String
    let mode: GameMode
    let completed: Bool
    let elapsedSeconds: Int
    let score: Int
    let progress: Double
    let status: String
    let summary: [String: String]
    let details: [String]
}

@main
struct WordSolveFlowChecks {
    @MainActor
    static func main() {
        var count = 0
        func check(_ value: Bool, _ message: String) {
            precondition(value, message)
            count += 1
        }
        func runTimers(_ seconds: TimeInterval) {
            RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        }
        let winners = Difficulty.allCases.map { WordleViewModel(difficulty: $0, seed: 42, totalRounds: 1, targetWords: ["BELTS"]) }
        for vm in winners {
            for letter in "QQQQQ" { vm.addLetter(letter) }
            vm.submitGuess()
            check(vm.guesses.isEmpty && vm.message == "Not in word list", "Invalid word doesn't consume a guess")
            for _ in 0..<5 { vm.deleteLetter() }
            for letter in "BELTS" { vm.addLetter(letter) }
            vm.submitGuess()
            check(vm.didSolveRound && vm.guesses.count == 1, "Correct answer solves in one guess")
            vm.addLetter("X")
            vm.submitGuess()
            check(vm.guesses.count == 1 && vm.currentInput.isEmpty, "Input is locked during the final reveal")
        }
        runTimers(3.4)
        for vm in winners {
            check(vm.isMatchOver && vm.roundResults.count == 1 && vm.roundResults[0].solved, "Solo success reaches a final result after reveal")
            check(vm.elapsedSeconds == 0, "Final reveal time is excluded from recorded time")
            vm.stop()
        }

        let losses = Difficulty.allCases.map { WordleViewModel(difficulty: $0, seed: 42, totalRounds: 1, targetWords: ["BELTS"]) }
        for round in 0..<7 {
            for vm in losses where round < vm.maxGuesses {
                for letter in "CRANE" { vm.addLetter(letter) }
                vm.submitGuess()
            }
            runTimers(2.0)
        }
        runTimers(1.4)
        for vm in losses {
            check(vm.isMatchOver && vm.roundResults.count == 1 && !vm.roundResults[0].solved, "Every guess limit produces a final loss")
            check(vm.guesses.count == vm.maxGuesses, "No guess after the configured limit")
            check(vm.message == "The word was BELTS", "Failure reveals the correct answer")
            vm.stop()
        }
        let duplicateLetters = WordleGame(seed: 1, round: 0, targetWords: ["APPLE"])
        check(duplicateLetters.evaluate(guess: "ALLEY") == [.correct, .present, .absent, .present, .absent], "Repeated letters consume each target occurrence only once")

        let puzzle = HangmanPuzzleData(wordBankVersion: "test", targetWord: "SHARK", difficulty: "easy", maxWrongGuesses: 6, category: "Animals", starterLetter: "K", rounds: nil)
        let rescues = Difficulty.allCases.map { HangmanViewModel(difficulty: $0, seed: 42, puzzleData: puzzle) }
        runTimers(1.2)
        for vm in rescues {
            check(vm.totalSeconds == nil && vm.elapsedSeconds >= 1, "Solo rescue measures time without a deadline")
            check(!vm.guess("K") && vm.game.wrongGuessCount == 0, "Repeated starter letter doesn't raise lava")
            check(vm.guess("X") && vm.game.wrongGuessCount == 1, "Wrong letter raises lava once")
            check(!vm.guess("X") && vm.game.wrongGuessCount == 1, "Repeated wrong letter cannot double-penalize")
            for letter in "SHAR" { vm.guess(letter) }
            check(vm.isFinished && vm.game.isSolved && vm.roundResults.count == 1, "Successful solo rescue finalizes once")
            check(!vm.guess("Z") && vm.game.wrongGuessCount == 1, "No guessing after rescue")
        }
        let times = rescues.map(\.elapsedSeconds)
        runTimers(1.2)
        check(rescues.map(\.elapsedSeconds) == times, "Lava stopwatch stops on completion")
        for difficulty in Difficulty.allCases {
            let vm = HangmanViewModel(difficulty: difficulty, seed: 42, puzzleData: puzzle)
            check(vm.elapsedSeconds == 0 && vm.game.wrongGuessCount == 0 && !vm.isFinished, "New rescue starts clean")
            for letter in "QZXVJW" { vm.guess(letter) }
            check(vm.isFinished && vm.game.isLost && vm.roundResults.count == 1, "Six wrong letters end a solo run")
            vm.stop()
        }
        print("Passed \(count) Word Guess/Lava Rescue flow checks using bundled word lists.")
    }
}
