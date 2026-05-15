import Foundation
import FirebaseFirestore

// Handles post-match rank + coin updates atomically
final class RankingService {
    static let shared = RankingService()
    private let db = Firestore.firestore()

    private init() {}

    struct MatchOutcome {
        let sessionID: String
        let mode: GameMode
        let difficulty: Difficulty
        let winnerID: String?
        let players: [MatchPlayer]
        let playerResults: [String: MatchPlayerResult]
        let winnerReason: String
    }

    func processOutcome(_ outcome: MatchOutcome) async throws {
        try await applyOutcomeTransaction(outcome)
    }

    private func applyOutcomeTransaction(_ outcome: MatchOutcome) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let sessionRef = self.db.collection("sessions").document(outcome.sessionID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    let sessionDoc = try transaction.getDocument(sessionRef)
                    if sessionDoc.data()?["status"] as? String == SessionStatus.finished.rawValue {
                        return true
                    }

                    let userRefs = outcome.players.map { self.db.collection("users").document($0.userID) }
                    var users: [AppUser] = []
                    for ref in userRefs {
                        users.append(try transaction.getDocument(ref).data(as: AppUser.self))
                    }

                    let pot = outcome.players.reduce(0) { $0 + $1.wager }
                    let encodedResults = try Firestore.Encoder().encode(outcome.playerResults)
                    let finishedAt = Date()

                    for (index, player) in outcome.players.enumerated() {
                        var user = users[index]
                        let isWinner = outcome.winnerID == player.userID
                        let delta = self.rankDelta(for: player.userID, outcome: outcome)

                        var rankInfo = user.ranks[outcome.mode] ?? .empty
                        rankInfo.points = max(0, rankInfo.points + delta)
                        rankInfo.tier = RankTier.tier(for: rankInfo.points)
                        if outcome.winnerID != nil {
                            if isWinner { rankInfo.wins += 1 } else { rankInfo.losses += 1 }
                        }

                        let result = outcome.playerResults[player.userID]
                        let wonByForfeit = result?.status == "Won by forfeit"
                        if isWinner, !wonByForfeit, result?.completed == true, let time = result?.elapsedSeconds {
                            rankInfo.bestTime = min(rankInfo.bestTime ?? Int.max, time)
                        }
                        if isWinner, outcome.mode.isScoreBased, let score = result?.score {
                            rankInfo.bestScore = max(rankInfo.bestScore ?? 0, score)
                        }
                        if isWinner, outcome.mode.isWordle, let guesses = result?.totalGuesses, guesses > 0 {
                            rankInfo.bestGuesses = min(rankInfo.bestGuesses ?? Int.max, guesses)
                        }

                        user.ranks[outcome.mode] = rankInfo
                        if let winnerID = outcome.winnerID {
                            user.coins += (player.userID == winnerID ? pot : -player.wager)
                        }

                        let encodedUser = try Firestore.Encoder().encode(user)
                        transaction.setData(encodedUser, forDocument: userRefs[index], merge: true)

                        let entry = LeaderboardEntry(
                            id: player.userID,
                            username: user.username,
                            avatarURL: user.avatarURL,
                            rankTier: rankInfo.tier,
                            rankPoints: rankInfo.points,
                            wins: rankInfo.wins,
                            bestTime: rankInfo.bestTime,
                            mode: outcome.mode,
                            equippedTitle: user.cosmetics.equippedTitle
                        )
                        let encodedEntry = try Firestore.Encoder().encode(entry)
                        let entryRef = self.db.collection("leaderboards")
                            .document(outcome.mode.rawValue)
                            .collection("entries")
                            .document(player.userID)
                        transaction.setData(encodedEntry, forDocument: entryRef, merge: true)
                    }

                    var sessionData: [String: Any] = [
                        "status": SessionStatus.finished.rawValue,
                        "finishedAt": Timestamp(date: finishedAt),
                        "playerResults": encodedResults,
                        "winnerReason": outcome.winnerReason
                    ]
                    if let winnerID = outcome.winnerID {
                        sessionData["winnerID"] = winnerID
                    } else {
                        sessionData["winnerID"] = FieldValue.delete()
                    }
                    transaction.updateData(sessionData, forDocument: sessionRef)
                    return true
                } catch {
                    return fail(error)
                }
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func rankDelta(for playerID: String, outcome: MatchOutcome) -> Int {
        if let winnerID = outcome.winnerID {
            let isWinner = playerID == winnerID
            var base = isWinner ? 30 : -15
            if isWinner {
                let myPlayer  = outcome.players.first { $0.userID == playerID }
                let oppPlayer = outcome.players.first { $0.userID != playerID }
                if let myPts = myPlayer?.rankPoints, let oppPts = oppPlayer?.rankPoints, oppPts > myPts {
                    base += 5
                }
            }
            return Int(Double(base) * outcome.mode.pointMultiplier(for: outcome.difficulty))
        }
        return Int(Double(5) * outcome.mode.pointMultiplier(for: outcome.difficulty))
    }
}
