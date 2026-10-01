import Foundation

enum AppPreferenceKeys { static let reduceExtraAnimations = "reduceExtraAnimations" }
struct MatchPlayer { let userID: String }
struct GameSession {
    var mode: GameMode
    var isParty = false
    var isAsyncExhibition = false
    var players = [MatchPlayer(userID: "a"), MatchPlayer(userID: "b")]
}

@main struct MatchResolutionChecks {
    static func main() {
        var count = 0
        func check(_ value: Bool, _ message: String) {
            precondition(value, message)
            count += 1
        }
        func result(_ id: String, mode: GameMode = .wordle, solves: Int = 2, guesses: Int = 6, seconds: Int = 40, final: Bool = true) -> MatchPlayerResult {
            MatchPlayerResult(userID: id, mode: mode, completed: solves >= 2, elapsedSeconds: seconds,
                              score: solves, progress: Double(solves) / 3, status: final ? "Finished" : "In progress",
                              summary: ["solvedRounds": "\(solves)", "totalGuesses": "\(guesses)",
                                        "wrongGuessCount": "2", "revealedLetterCount": "8", "roundCount": "2",
                                        "isFinal": "\(final)", "final": "\(final)"], details: [])
        }
        for mode in [GameMode.wordle, .hangman] {
            for async in [false, true] {
                let session = GameSession(mode: mode, isAsyncExhibition: async)
                let a = result("a", mode: mode)
                let b = result("b", mode: mode, seconds: 50)
                check(!MatchResolver.canResolve(session: session, results: ["a": a]), "A first finisher must wait")
                let partial = result("b", mode: mode, final: false)
                check(!MatchResolver.canResolve(session: session, results: ["a": a, "b": partial]), "Two solves in a partial report must not finalize")
                check(MatchResolver.canResolve(session: session, results: ["a": a, "b": b]), "Both final reports resolve")
                check(MatchResolver.resolve(session: session, results: ["a": a, "b": b]).winnerID == "a", "Time breaks an otherwise equal result")
                check(MatchResolver.resolve(session: session, results: ["a": a, "b": result("b", mode: mode)]).winnerID == nil, "Exact ties remain draws")
                check(PartyScoring.compare(a, b, mode: mode) < 0, "Party scoring agrees on faster finish")
                check(PartyScoring.compare(b, a, mode: mode) > 0, "Comparison is symmetric")
            }
        }
        let session = GameSession(mode: .wordle)
        let fewer = result("a", guesses: 5, seconds: 70)
        let faster = result("b", guesses: 6, seconds: 20)
        check(MatchResolver.resolve(session: session, results: ["a": fewer, "b": faster]).winnerID == "a", "Fewer guesses outranks speed")
        check(PartyScoring.compare(fewer, faster, mode: .wordle) < 0, "Party preserves guess priority")
        let moreSolves = result("a", solves: 2, guesses: 10, seconds: 70)
        let fewerSolves = result("b", solves: 1, guesses: 1, seconds: 10)
        check(MatchResolver.resolve(session: session, results: ["a": moreSolves, "b": fewerSolves]).winnerID == "a", "More solves outranks guesses")
        let noSolveA = result("a", solves: 0, guesses: 0, seconds: 10)
        let noSolveB = result("b", solves: 0, guesses: 0, seconds: 70)
        check(MatchResolver.resolve(session: session, results: ["a": noSolveA, "b": noSolveB]).winnerID == nil, "Faster failure is not a Word Guess win")
        check(PartyScoring.compare(noSolveA, noSolveB, mode: .wordle) == 0, "Party also draws on no solves")
        var legacy = result("a")
        legacy.summary.removeValue(forKey: "isFinal")
        check(legacy.isFinalWordleResult, "Legacy final reports remain readable")
        legacy.mode = .hangman
        legacy.summary.removeValue(forKey: "final")
        check(MatchResolver.isFinalHangmanResult(legacy), "Legacy Lava Rescue final reports remain readable")
        let partial = result("a", final: false)
        check(!partial.isFinalWordleResult, "Explicit nonfinal flag wins over solve count")
        let sudoku = result("a", mode: .sudoku)
        check(MatchResolver.canResolve(session: GameSession(mode: .sudoku), results: ["a": sudoku]), "Existing first-complete Sudoku behavior unchanged")
        let wordScoreSession = GameSession(mode: .anagram)
        var scored = result("a", mode: .anagram)
        var tied = result("b", mode: .anagram, seconds: 30)
        scored.summary["wordCount"] = "3"
        tied.summary["wordCount"] = "3"
        check(MatchResolver.resolve(session: wordScoreSession, results: ["a": scored, "b": tied]).winnerID == nil, "Fixed-duration word-score rules unchanged")
        print("Passed \(count) match resolution checks.")
    }
}
