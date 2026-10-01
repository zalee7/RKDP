import Foundation

enum AppPreferenceKeys { static let reduceExtraAnimations = "reduceExtraAnimations" }

@main struct MatchWalletPolicyExport {
    static func main() throws {
        var fixtures: [[String: Any]] = []
        for mode in GameMode.allCases {
            for points in [0, 200, 600, 1800, 3600, 7200, 12000] {
                for variant in 0..<8 {
                    let players = [
                        MatchPlayer(userID: "a", username: "A", wager: 0, rankTier: .bronze, rankPoints: points),
                        MatchPlayer(userID: "b", username: "B", wager: 0, rankTier: .bronze, rankPoints: points + 500)
                    ]
                    func result(_ id: String) -> MatchPlayerResult {
                        MatchPlayerResult(userID: id, mode: mode, completed: true, elapsedSeconds: 30,
                                          score: 100, progress: 1, status: "Finished",
                                          summary: ["isFinal": "true", "final": "true", "solvedRounds": "2",
                                                    "totalGuesses": "6", "wordCount": "10", "longestWordLength": "5",
                                                    "wrongGuessCount": "1", "revealedLetterCount": "10", "moves": "100",
                                                    "foundationCount": "52", "solvedPairs": "6"], details: [])
                    }
                    var a = result("a")
                    var b = result("b")
                    switch variant {
                    case 0: b.elapsedSeconds = 40
                    case 1: a.elapsedSeconds = 40
                    case 2: b.completed = false; b.progress = 0.5; b.summary["solvedRounds"] = "1"
                    case 3: a.score = 200; a.summary["totalGuesses"] = "4"; a.summary["wrongGuessCount"] = "0"
                    case 4: b.summary["wordCount"] = "11"; b.summary["moves"] = "90"; b.summary["hitMine"] = "true"
                    case 5: b.summary["longestWordLength"] = "8"; b.summary["revealedLetterCount"] = "12"
                    case 6:
                        a.completed = false; b.completed = false
                        a.progress = 0.2; b.progress = 0.4
                        a.summary["solvedRounds"] = "0"; b.summary["solvedRounds"] = "0"
                        b.summary["foundationCount"] = "10"; a.summary["foundationCount"] = "5"
                    default: break
                    }
                    let results = ["a": a, "b": b]
                    var session = GameSession(id: "contract", mode: mode, difficulty: mode.onlinePresetDifficulty,
                                              status: .finished, players: players, seed: 1, puzzleData: "", createdAt: Date(),
                                              playerResults: results)
                    session.winnerID = MatchResolver.resolve(session: session, results: results).winnerID
                    let encodedResults = try JSONSerialization.jsonObject(with: JSONEncoder().encode(results))
                    let match: [String: Any] = [
                        "version": 1, "verifierVersion": "match-v1", "sessionID": "contract", "status": "finished",
                        "mode": mode.rawValue, "difficulty": mode.onlinePresetDifficulty.rawValue, "matchKind": "ranked",
                        "startedAtMs": 1000, "finishedAtMs": 100000,
                        "players": players.map { ["userID": $0.userID, "isBot": false, "rankPoints": $0.rankPoints] as [String: Any] },
                        "playerResults": encodedResults, "playedUserIDs": ["a", "b"], "forfeitedIDs": [String]()
                    ]
                    fixtures.append([
                        "label": "\(mode.rawValue)-\(points)-\(variant)", "match": match,
                        "winnerID": session.winnerID as Any? ?? NSNull(),
                        "coins": Dictionary(uniqueKeysWithValues: players.map {
                            ($0.userID, RankedCoinRewards.amount(in: session, for: $0.userID, botWinRewardAvailable: true))
                        }),
                        "rankDeltas": Dictionary(uniqueKeysWithValues: players.map {
                            ($0.userID, RankPolicyExport.rankDelta(for: $0.userID, mode: mode, difficulty: session.difficulty,
                                                                winnerID: session.winnerID, players: players))
                        })
                    ])
                }
            }
        }
        let data = try JSONSerialization.data(withJSONObject: fixtures, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
