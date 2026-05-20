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

    struct AppliedPlayerOutcome {
        let user: AppUser
        let didApplyRewards: Bool
    }

    func processOutcome(_ outcome: MatchOutcome) async throws {
        try await finishSessionIfNeeded(outcome)
    }

    @discardableResult
    func applyFinishedSession(_ session: GameSession, for userID: String) async throws -> AppliedPlayerOutcome {
        guard session.isRanked,
              session.status == .finished,
              session.players.contains(where: { $0.userID == userID }) else {
            let user = try await db.collection("users").document(userID).getDocument(as: AppUser.self)
            return AppliedPlayerOutcome(user: user, didApplyRewards: false)
        }
        return try await applyPlayerOutcome(session: session, userID: userID)
    }

    static func rankDelta(
        for playerID: String,
        mode: GameMode,
        difficulty: Difficulty,
        winnerID: String?,
        players: [MatchPlayer]
    ) -> Int {
        let isWinner = winnerID == playerID
        if players.contains(where: \.isBot) {
            guard winnerID != nil else { return 0 }
            return isWinner ? 15 : -8
        }
        let base: Int
        if winnerID == nil {
            base = 5
        } else {
            base = isWinner ? 30 : -15
        }

        let adjustedBase = adjustedRankBase(base, playerID: playerID, isWinner: isWinner, winnerID: winnerID, players: players)
        let scaled = Int(Double(adjustedBase) * mode.pointMultiplier(for: difficulty))
        if winnerID == nil { return max(0, scaled) }
        return isWinner ? max(1, scaled) : min(0, scaled)
    }

    private func finishSessionIfNeeded(_ outcome: MatchOutcome) async throws {
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

                    let encodedResults = try Firestore.Encoder().encode(outcome.playerResults)
                    let finishedAt = Date()

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

    private func applyPlayerOutcome(session: GameSession, userID: String) async throws -> AppliedPlayerOutcome {
        let appliedOutcome = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppliedPlayerOutcome, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    if user.appliedRankedOutcomes[session.id] == true {
                        return AppliedPlayerOutcome(user: user, didApplyRewards: false)
                    }
                    let leaderboardRef = self.db.collection("leaderboards")
                        .document(session.mode.rawValue)
                        .collection("entries")
                        .document(userID)

                    let isRewardedBotWin = session.containsBot && session.winnerID == userID
                    let canApplyBotWinReward = !isRewardedBotWin || user.botMatchProgress.rewardedWinsRemaining() > 0
                    let delta = canApplyBotWinReward ? Self.rankDelta(
                        for: userID,
                        mode: session.mode,
                        difficulty: session.difficulty,
                        winnerID: session.winnerID,
                        players: session.players
                    ) : 0

                    var rankInfo = user.ranks[session.mode] ?? .empty
                    rankInfo.points = max(0, rankInfo.points + delta)
                    rankInfo.tier = RankTier.tier(for: rankInfo.points)
                    if canApplyBotWinReward, let winnerID = session.winnerID {
                        if winnerID == userID {
                            rankInfo.wins += 1
                        } else {
                            rankInfo.losses += 1
                        }
                    }

                    let result = session.playerResults?[userID]
                    let isWinner = session.winnerID == userID
                    let wonByForfeit = result?.status == "Won by forfeit"
                    if isWinner, !wonByForfeit, result?.completed == true, let time = result?.elapsedSeconds {
                        rankInfo.bestTime = min(rankInfo.bestTime ?? Int.max, time)
                    }
                    if isWinner, session.mode.isScoreBased, let score = result?.score {
                        rankInfo.bestScore = max(rankInfo.bestScore ?? 0, score)
                    }
                    if isWinner, session.mode.isWordle, let guesses = result?.totalGuesses, guesses > 0 {
                        rankInfo.bestGuesses = min(rankInfo.bestGuesses ?? Int.max, guesses)
                    }

                    user.ranks[session.mode] = rankInfo
                    if canApplyBotWinReward,
                       let winnerID = session.winnerID,
                       let player = session.players.first(where: { $0.userID == userID }) {
                        let opponentWager = session.players.first(where: { $0.userID != userID })?.wager ?? player.wager
                        user.coins += winnerID == userID ? opponentWager : -player.wager
                    }
                    if isRewardedBotWin, canApplyBotWinReward {
                        _ = user.botMatchProgress.recordRewardedWin()
                    }
                    user.appliedRankedOutcomes[session.id] = true

                    let encodedUser = try Firestore.Encoder().encode(user)
                    let leaderboardEntry = LeaderboardEntry(
                        id: user.id,
                        username: user.username,
                        avatarURL: user.avatarURL,
                        rankTier: rankInfo.displayTier,
                        rankPoints: rankInfo.points,
                        wins: rankInfo.wins,
                        bestTime: rankInfo.bestTime,
                        mode: session.mode,
                        equippedTitle: CosmeticCatalog.allTitles.first { $0.id == user.cosmetics.equippedTitle }?.name,
                        avatarStyle: user.cosmetics.avatarStyle
                    )
                    let encodedEntry = try Firestore.Encoder().encode(leaderboardEntry)
                    transaction.setData(encodedUser, forDocument: userRef, merge: true)
                    transaction.setData(encodedEntry, forDocument: leaderboardRef, merge: true)
                    return AppliedPlayerOutcome(user: user, didApplyRewards: true)
                } catch {
                    return fail(error)
                }
            }, completion: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let outcome = result as? AppliedPlayerOutcome {
                    continuation.resume(returning: outcome)
                } else {
                    continuation.resume(throwing: FirestoreServiceError.missingUpdatedUser)
                }
            })
        }

        return appliedOutcome
    }

    private static func adjustedRankBase(
        _ base: Int,
        playerID: String,
        isWinner: Bool,
        winnerID: String?,
        players: [MatchPlayer]
    ) -> Int {
        guard winnerID != nil,
              let player = players.first(where: { $0.userID == playerID }),
              let opponent = players.first(where: { $0.userID != playerID }) else {
            return base
        }

        let diff = divisionScore(opponent) - divisionScore(player)
        guard diff != 0 else { return base }

        let capped = max(-2, min(2, diff))
        if isWinner {
            return max(10, base + capped * 5)
        }
        return min(-5, base + capped * 3)
    }

    private static func divisionScore(_ player: MatchPlayer) -> Int {
        let info = RankInfo(
            points: player.rankPoints,
            tier: RankTier.tier(for: player.rankPoints),
            wins: 0,
            losses: 0,
            bestTime: nil,
            bestScore: nil
        )
        return info.displayTier.rawValue * 3 + info.division.rawValue
    }
}
