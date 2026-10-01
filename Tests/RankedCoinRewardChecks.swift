import Foundation

enum AppPreferenceKeys { static let reduceExtraAnimations = "reduceExtraAnimations" }

@main struct RankedCoinRewardChecks {
    static func main() throws {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        func result(_ id: String, mode: GameMode, seconds: Int = 30) -> MatchPlayerResult {
            MatchPlayerResult(userID: id, mode: mode, completed: true, elapsedSeconds: seconds,
                              score: 100, progress: 1, status: "Finished",
                              summary: ["isFinal": "true", "final": "true", "solvedRounds": "2",
                                        "roundCount": "2", "totalGuesses": "6", "foundationCount": "52",
                                        "solvedPairs": "6", "wordCount": "10"], details: [])
        }
        func session(_ tier: RankTier = .bronze, mode: GameMode = .sudoku) -> GameSession {
            let players = [
                MatchPlayer(userID: "a", username: "A", wager: 7_500, rankTier: tier, rankPoints: tier.pointsRequired),
                MatchPlayer(userID: "b", username: "B", wager: 7_500, rankTier: tier, rankPoints: tier.pointsRequired)
            ]
            let results = ["a": result("a", mode: mode), "b": result("b", mode: mode, seconds: 40)]
            var value = GameSession(id: "reward-test", mode: mode, difficulty: mode.onlinePresetDifficulty,
                                    status: .finished, players: players, seed: 123, puzzleData: "", createdAt: Date(),
                                    winnerID: "a", playerResults: results)
            if mode.isScoreBased {
                value.playerResults?["b"]?.score = 50
            }
            return value
        }
        func coins(_ value: GameSession, _ userID: String = "a", botAvailable: Bool = true) -> Int {
            RankedCoinRewards.amount(in: value, for: userID, botWinRewardAvailable: botAvailable)
        }

        for (index, tier) in RankTier.allCases.enumerated() {
            let expected = [20, 30, 40, 50, 60, 75][index]
            check(RankedCoinRewards.win(for: tier) == expected, "Win ladder")
            for mode in GameMode.allCases {
                let game = session(tier, mode: mode)
                check(coins(game) == expected, "\(mode) win at \(tier)")
                check(coins(game, "b") == 5, "Completed losses gain 5, never deduct legacy wagers")
                var draw = game
                draw.playerResults?["b"] = result("b", mode: mode)
                draw.winnerID = nil
                check(coins(draw) == 10 && coins(draw, "b") == 10, "\(mode) draw rewards both")
            }
            for division in RankDivision.progression {
                var game = session(tier)
                game.players[0].rankPoints = tier.divisionStart(for: division)
                game.players[0].rankTier = .bronze
                check(coins(game) == expected, "Use match-start rank points, not stale tier")
            }
        }
        var game = session()
        game.playerResults?.removeValue(forKey: "b")
        check(coins(game) == 20 && coins(game, "b") == 5, "First-finisher race pays normal losing participant")
        game.status = .inProgress
        check(coins(game) == 0, "No active-game rewards")
        game.status = .abandoned
        check(coins(game) == 0, "No abandoned-game rewards")
        game = session()
        for kind in [SessionKind.casual, .exhibition, .asyncExhibition, .party] {
            game.matchKind = kind
            check(coins(game) == 0, "No ranked coins outside ranked")
        }
        game = session()
        check(coins(game, "outsider") == 0, "No nonparticipant rewards")
        game.playerResults = nil
        check(coins(game) == 0, "No evidence, no reward")
        game = session()
        game.winnerID = "b"
        check(coins(game) == 0, "Inconsistent winner rejected")
        game = session(mode: .wordle)
        game.playerResults?["b"]?.summary["isFinal"] = "false"
        check(coins(game) == 0 && coins(game, "b") == 0, "Partial Word Guess isn't settled")
        game = session()
        game.playerResults?["a"]?.userID = "outsider"
        check(coins(game) == 0, "Mismatched result identity rejected")

        game = session()
        game.playerResults?["b"]?.status = "Forfeited"
        game.playerResults?["b"]?.summary["forfeit"] = "true"
        game.winnerReason = "Opponent forfeited"
        check(coins(game, "b") == 0, "Quitter earns no coins")
        check(coins(game) == 20, "An already completed winning attempt still counts")
        game.playerResults?["a"]?.status = "Won by forfeit"
        game.playerResults?["a"]?.summary["forfeitWin"] = "true"
        check(coins(game) == 0, "Synthetic auto-wins cannot farm coins")

        game = session()
        game.players[1].isBot = true
        check(coins(game) == 20, "Eligible Bronze bot win pays 20")
        check(coins(game, botAvailable: false) == 0, "Exhausted bot allowance pays nothing")
        check(coins(game, "b") == 0, "Bot account never receives currency")
        game.playerResults?["a"]?.elapsedSeconds = 50
        game.winnerID = "b"
        check(coins(game) == 0, "No repeat bot-loss farming or coin loss")
        game.playerResults?["a"]?.elapsedSeconds = 40
        game.winnerID = nil
        check(coins(game) == 0, "No bot-draw farming")
        var progress = BotMatchProgress.empty
        for _ in 0..<3 { check(progress.recordRewardedWin(), "Three bot wins allowed") }
        check(!progress.recordRewardedWin(), "Fourth bot win denied")

        game = session(.master)
        check((0..<100).reduce(0) { total, _ in total + coins(game) } == 7_500, "Human rewards have no daily cap")
        let encoded = try JSONEncoder().encode(game)
        let legacy = try JSONDecoder().decode(GameSession.self, from: encoded)
        check(legacy.rankedCoinRewards == nil, "Old sessions without receipts remain decodable")
        game.rankedCoinRewards = ["a": 75, "b": 5]
        let restored = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(game))
        check(restored.rankedCoinRewards == ["a": 75, "b": 5], "Committed receipts survive reload")
        print("Passed \(checks) ranked coin reward checks.")
    }
}
