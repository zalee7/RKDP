import Foundation
import FirebaseFirestore

enum FirestoreServiceError: LocalizedError {
    case insufficientCoins
    case missingUpdatedUser

    var errorDescription: String? {
        switch self {
        case .insufficientCoins:
            return "You do not have enough coins for that item."
        case .missingUpdatedUser:
            return "Could not refresh your shop purchase. Please try again."
        }
    }
}

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Users

    func createUser(_ user: AppUser) async throws {
        try db.collection("users").document(user.id).setData(from: user)
    }

    func fetchUser(id: String) async throws -> AppUser {
        try await db.collection("users").document(id).getDocument(as: AppUser.self)
    }

    func updateUser(_ user: AppUser) async throws {
        try db.collection("users").document(user.id).setData(from: user, merge: true)
    }

    func updateCoins(userID: String, delta: Int) async throws {
        try await db.collection("users").document(userID).updateData([
            "coins": FieldValue.increment(Int64(delta))
        ])
    }

    func updateCosmetics(userID: String, cosmetics: OwnedCosmetics) async throws {
        let encoded = try Firestore.Encoder().encode(cosmetics)
        try await db.collection("users").document(userID).updateData(["cosmetics": encoded])
    }

    func purchaseCosmetic(userID: String, item: CosmeticItem) async throws -> AppUser {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    if !user.cosmetics.purchasedIDs.contains(item.id) {
                        guard user.coins >= item.price else { return fail(FirestoreServiceError.insufficientCoins) }
                        user.coins -= item.price
                        user.cosmetics.purchasedIDs.insert(item.id)
                    }
                    user.cosmetics.equip(item)

                    let encodedUser = try Firestore.Encoder().encode(user)
                    transaction.setData(encodedUser, forDocument: userRef, merge: true)
                    return user
                } catch {
                    return fail(error)
                }
            }, completion: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let user = result as? AppUser {
                    continuation.resume(returning: user)
                } else {
                    continuation.resume(throwing: FirestoreServiceError.missingUpdatedUser)
                }
            })
        }
    }

    // MARK: - Rankings / Leaderboards

    func fetchLeaderboard(mode: GameMode, limit: Int = 50) async throws -> [LeaderboardEntry] {
        let snapshot = try await db.collection("leaderboards")
            .document(mode.rawValue)
            .collection("entries")
            .order(by: "rankPoints", descending: true)
            .limit(to: limit)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: LeaderboardEntry.self) }
    }

    func updateRankEntry(userID: String, mode: GameMode, info: RankInfo, username: String) async throws {
        let entry = LeaderboardEntry(
            id: userID, username: username, avatarURL: nil,
            rankTier: info.displayTier, rankPoints: info.points,
            wins: info.wins, bestTime: info.bestTime, mode: mode
        )
        try db.collection("leaderboards")
            .document(mode.rawValue)
            .collection("entries")
            .document(userID)
            .setData(from: entry)
    }

    // MARK: - Game Sessions

    func createSession(_ session: GameSession) async throws -> String {
        let ref = db.collection("sessions").document(session.id)
        try ref.setData(from: session)
        return session.id
    }

    func fetchSession(id: String) async throws -> GameSession {
        try await db.collection("sessions").document(id).getDocument(as: GameSession.self)
    }

    func fetchUnappliedFinishedSessions(for user: AppUser, limit: Int = 10) async throws -> [GameSession] {
        let snapshot = try await db.collection("sessions")
            .whereField("playerIDs", arrayContains: user.id)
            .whereField("status", isEqualTo: SessionStatus.finished.rawValue)
            .limit(to: limit)
            .getDocuments()

        return try snapshot.documents
            .map { try $0.data(as: GameSession.self) }
            .filter { user.appliedRankedOutcomes[$0.id] != true }
    }

    func listenForSession(id: String, onChange: @escaping (GameSession) -> Void) -> ListenerRegistration {
        db.collection("sessions").document(id)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot, let session = try? snapshot.data(as: GameSession.self) else { return }
                onChange(session)
            }
    }

    func updateSession(_ session: GameSession) async throws {
        try db.collection("sessions").document(session.id).setData(from: session, merge: true)
    }

    func finishSession(
        id: String,
        winnerID: String?,
        finishedAt: Date,
        playerResults: [String: MatchPlayerResult] = [:],
        winnerReason: String? = nil
    ) async throws {
        let encodedResults = try Firestore.Encoder().encode(playerResults)
        var data: [String: Any] = [
            "status": SessionStatus.finished.rawValue,
            "finishedAt": Timestamp(date: finishedAt),
            "playerResults": encodedResults
        ]
        if let winnerID {
            data["winnerID"] = winnerID
        } else {
            data["winnerID"] = FieldValue.delete()
        }
        if let winnerReason {
            data["winnerReason"] = winnerReason
        } else {
            data["winnerReason"] = FieldValue.delete()
        }
        try await db.collection("sessions").document(id).updateData(data)
    }

    // MARK: - Matchmaking

    /// Write this player into the queue, then attempt to pair with anyone already waiting.
    /// The player with the lexicographically larger userID always creates the session,
    /// guaranteeing exactly one session even if both arrive simultaneously.
    func joinAndPair(user: AppUser, mode: GameMode, difficulty: Difficulty, wager: Int, searchID: String) async throws {
        let tier = user.rank(for: mode).tier
        let queueRef = queueCollection(mode: mode, difficulty: difficulty)

        // 1. Write own entry (merge so a concurrent delete doesn't resurrect us)
        try await queueRef.document(user.id).setData([
            "userID":     user.id,
            "username":   user.username,
            "wager":      wager,
            "rankTier":   tier.rawValue,
            "rankPoints": user.rank(for: mode).points,
            "searchID":   searchID
        ])

        // 2. Look for anyone else in the queue with the same tier AND same wager
        let snapshot = try await queueRef.getDocuments()
        let myTier = tier.rawValue
        let others = snapshot.documents.filter {
            $0.documentID != user.id &&
            ($0.data()["rankTier"] as? Int ?? -1) == myTier &&
            ($0.data()["wager"]    as? Int ?? -1) == wager
        }
        guard let opponentDoc = others.first else { return }  // alone — wait for queue listener

        let opponentID = opponentDoc.documentID

        // 3. Only the player with the LARGER uid creates the session (deterministic tiebreak)
        guard user.id > opponentID else { return }

        try await createAndNotify(
            hostUser: user, wager: wager, tier: tier, searchID: searchID,
            opponentDoc: opponentDoc,
            mode: mode, difficulty: difficulty,
            queueRef: queueRef
        )
    }

    /// Watch the queue; if a second player appears AND this user has the larger uid,
    /// create the session and notify both players.
    func listenForQueueMatch(
        user: AppUser, mode: GameMode, difficulty: Difficulty, wager: Int, searchID: String,
        onPaired: @escaping (String) -> Void
    ) -> ListenerRegistration {
        let queueRef = queueCollection(mode: mode, difficulty: difficulty)

        let myTier = user.rank(for: mode).tier.rawValue
        return queueRef.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let snapshot else { return }
            let others = snapshot.documents.filter {
                $0.documentID != user.id &&
                ($0.data()["rankTier"] as? Int ?? -1) == myTier &&
                ($0.data()["wager"]    as? Int ?? -1) == wager
            }
            guard let opponentDoc = others.first else { return }

            // Only the larger-uid player creates
            guard user.id > opponentDoc.documentID else { return }
            let tier = user.rank(for: mode).tier

            Task {
                do {
                    try await self.createAndNotify(
                        hostUser: user, wager: wager, tier: tier, searchID: searchID,
                        opponentDoc: opponentDoc,
                        mode: mode, difficulty: difficulty,
                        queueRef: queueRef
                    )
                } catch {
                    // Session may have already been created by a re-fire — ignore
                }
            }
        }
    }

    private func createAndNotify(
        hostUser: AppUser, wager: Int, tier: RankTier, searchID: String,
        opponentDoc: QueryDocumentSnapshot,
        mode: GameMode, difficulty: Difficulty,
        queueRef: CollectionReference
    ) async throws {
        let opponentID       = opponentDoc.documentID

        // A listener callback may already be in flight when a player cancels.
        // Re-read both queue entries and only create a session for the current search.
        let hostQueueDoc = try await queueRef.document(hostUser.id).getDocument()
        let opponentQueueDoc = try await queueRef.document(opponentID).getDocument()
        guard let hostQueue = hostQueueDoc.data(),
              let opponentQueue = opponentQueueDoc.data(),
              (hostQueue["searchID"] as? String) == searchID,
              (hostQueue["wager"] as? Int) == wager,
              (hostQueue["rankTier"] as? Int) == tier.rawValue,
              (opponentQueue["wager"] as? Int) == wager,
              (opponentQueue["rankTier"] as? Int) == tier.rawValue,
              let opponentSearchID = opponentQueue["searchID"] as? String else {
            return
        }

        let opponentUsername = opponentQueue["username"] as? String ?? "Opponent"
        let opponentWager    = opponentQueue["wager"]    as? Int    ?? wager
        let opponentTierRaw  = opponentQueue["rankTier"] as? Int    ?? 0
        let opponentTier     = RankTier(rawValue: opponentTierRaw) ?? .bronze

        // Derive a deterministic session ID so simultaneous creates are idempotent
        let pair = [hostUser.id, opponentID].sorted().joined(separator: "_")
        var sessionID = "\(pair)_\(mode.rawValue)_\(difficulty.rawValue)"

        let opponentRankPoints = opponentQueue["rankPoints"] as? Int ?? 0

        // Allow rematches: only block if a session between these players is actively in progress
        let existing = try await db.collection("sessions").document(sessionID).getDocument()
        if existing.exists {
            let status = existing.data()?["status"] as? String ?? ""
            if status == SessionStatus.inProgress.rawValue || status == SessionStatus.waiting.rawValue {
                return  // concurrent duplicate create — bail
            }
            // Previous session is finished/abandoned — use a time-bucketed ID for the rematch
            let bucket = Int(Date().timeIntervalSince1970 / 300)  // 5-minute window keeps idempotency
            sessionID = "\(sessionID)_r\(bucket)"
            let rematchDoc = try await db.collection("sessions").document(sessionID).getDocument()
            guard !rematchDoc.exists else { return }
        }

        let seed = Int.random(in: 0..<Int.max)
        var session = GameSession(
            id: sessionID,
            mode: mode,
            difficulty: difficulty,
            status: .inProgress,
            players: [
                MatchPlayer(userID: hostUser.id, username: hostUser.username, wager: wager, rankTier: tier, rankPoints: hostUser.rank(for: mode).points),
                MatchPlayer(userID: opponentID,  username: opponentUsername,  wager: opponentWager, rankTier: opponentTier, rankPoints: opponentRankPoints)
            ],
            seed: seed,
            puzzleData: "",
            createdAt: Date()
        )
        session.playerIDs = [hostUser.id, opponentID]

        // Create session
        try db.collection("sessions").document(sessionID).setData(from: session)

        // Notify both players by writing pendingSessionID to their user docs
        try await db.collection("users").document(hostUser.id).updateData([
            "pendingSessionID": sessionID,
            "pendingSearchID": searchID
        ])
        try await db.collection("users").document(opponentID).updateData([
            "pendingSessionID": sessionID,
            "pendingSearchID": opponentSearchID
        ])

        // Clean up queue
        try await queueRef.document(hostUser.id).delete()
        try await queueRef.document(opponentID).delete()
    }

    func leaveMatchmakingQueue(userID: String, mode: GameMode, difficulty: Difficulty) async throws {
        try await queueCollection(mode: mode, difficulty: difficulty).document(userID).delete()
    }

    /// Clear pendingSessionID after it's been consumed so the listener doesn't re-fire on reconnect
    /// Persist a new best score for a score-based mode (Anagram, Word Hunt).
    /// Only writes if `score` beats the stored value.
    func updateBestScore(userID: String, mode: GameMode, score: Int) async throws {
        try await db.collection("users").document(userID).updateData([
            "ranks.\(mode.rawValue).bestScore": score
        ])
    }

    func clearPendingSession(userID: String) async throws {
        try await db.collection("users").document(userID).updateData([
            "pendingSessionID": FieldValue.delete(),
            "pendingSearchID": FieldValue.delete()
        ])
    }

    /// Listen on the user's own doc for pendingSessionID written by the pairing host
    func listenForMatch(userID: String, onMatch: @escaping (String, String?) -> Void) -> ListenerRegistration {
        db.collection("users").document(userID)
            .addSnapshotListener { snapshot, _ in
                guard let data = snapshot?.data(),
                      let sessionID = data["pendingSessionID"] as? String else { return }
                onMatch(sessionID, data["pendingSearchID"] as? String)
            }
    }

    private func queueCollection(mode: GameMode, difficulty: Difficulty) -> CollectionReference {
        db.collection("matchmaking")
            .document("\(mode.rawValue)_\(difficulty.rawValue)")
            .collection("queue")
    }
}
