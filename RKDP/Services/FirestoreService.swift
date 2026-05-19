import Foundation
import FirebaseFirestore

enum FirestoreServiceError: LocalizedError {
    case insufficientCoins
    case missingUpdatedUser
    case rankedAccessUnavailable
    case rewardedAdLimitReached
    case friendRequestAlreadyPending
    case friendshipAlreadyExists
    case invalidFriendAction
    case notFriends
    case exhibitionInviteExpired

    var errorDescription: String? {
        switch self {
        case .insufficientCoins:
            return "You do not have enough coins for that item."
        case .missingUpdatedUser:
            return "Could not refresh your shop purchase. Please try again."
        case .rankedAccessUnavailable:
            return "No ranked entry is available for this mode today."
        case .rewardedAdLimitReached:
            return "You have reached today's rewarded ad limit for ranked entries."
        case .friendRequestAlreadyPending:
            return "A friend request is already pending."
        case .friendshipAlreadyExists:
            return "You are already friends."
        case .invalidFriendAction:
            return "That friend action is no longer available."
        case .notFriends:
            return "You can only invite accepted friends."
        case .exhibitionInviteExpired:
            return "That exhibition invite expired."
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

    // MARK: - Ranked Access

    func syncRankedAccessEntitlements(userID: String, productIDs: Set<String>) async throws -> AppUser {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    user.rankedAccess.applyPurchasedProductIDs(productIDs)
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


    func setTesterRankedAccess(userID: String, enabled: Bool) async throws -> AppUser {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    user.rankedAccess.allModesUnlocked = enabled
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

    func grantRewardedRankedTicket(userID: String, mode: GameMode, dayKey: String = RankedAccess.todayKey()) async throws -> AppUser {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    do {
                        try user.rankedAccess.grantRewardedTicket(for: mode, dayKey: dayKey)
                    } catch RankedAccessError.rewardedLimitReached {
                        return fail(FirestoreServiceError.rewardedAdLimitReached)
                    }
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

    func consumeRankedEntry(userID: String, mode: GameMode, sessionID: String, dayKey: String = RankedAccess.todayKey()) async throws -> AppUser {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    do {
                        _ = try user.rankedAccess.consumeEntry(for: mode, sessionID: sessionID, dayKey: dayKey)
                    } catch RankedAccessError.noEntryAvailable {
                        return fail(FirestoreServiceError.rankedAccessUnavailable)
                    }
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

    func listenForActiveSession(
        userID: String,
        mode: GameMode,
        difficulty: Difficulty,
        onMatch: @escaping (GameSession) -> Void
    ) -> ListenerRegistration {
        db.collection("sessions")
            .whereField("playerIDs", arrayContains: userID)
            .whereField("status", isEqualTo: SessionStatus.inProgress.rawValue)
            .addSnapshotListener { snapshot, error in
                if let error { print("Match discovery listener error: \(error.localizedDescription)") }
                guard let documents = snapshot?.documents else { return }
                let recentCutoff = Date().addingTimeInterval(-600)
                let sessions = documents.compactMap { try? $0.data(as: GameSession.self) }
                guard let session = sessions.first(where: {
                    $0.mode == mode &&
                    $0.difficulty == difficulty &&
                    $0.createdAt >= recentCutoff &&
                    $0.players.contains(where: { $0.userID == userID })
                }) else { return }
                onMatch(session)
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

    func createRematchSession(from oldSession: GameSession) async throws -> GameSession {
        let refreshedPlayers = try await oldSession.players.asyncMap { player -> MatchPlayer in
            let latestUser = try await fetchUser(id: player.userID)
            guard latestUser.coins >= player.wager else { throw FirestoreServiceError.insufficientCoins }
            guard latestUser.rankedAccess.canStartRanked(mode: oldSession.mode) else { throw FirestoreServiceError.rankedAccessUnavailable }
            let rank = latestUser.rank(for: oldSession.mode)
            return MatchPlayer(
                userID: latestUser.id,
                username: latestUser.username,
                wager: player.wager,
                finishTime: nil,
                rankTier: rank.displayTier,
                rankPoints: rank.points
            )
        }

        let suffix = UUID().uuidString.prefix(8)
        let sessionID = "\(oldSession.id)_rematch_\(Int(Date().timeIntervalSince1970))_\(suffix)"
        let seed = Int.random(in: 0..<Int.max)
        var session = GameSession(
            id: sessionID,
            mode: oldSession.mode,
            difficulty: oldSession.difficulty,
            status: .waiting,
            players: refreshedPlayers,
            seed: seed,
            puzzleData: MultiplayerPuzzleDataFactory.encoded(mode: oldSession.mode, difficulty: oldSession.difficulty, seed: seed),
            createdAt: Date()
        )
        session.playerIDs = refreshedPlayers.map(\.userID)
        try db.collection("sessions").document(sessionID).setData(from: session)
        return session
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

        _ = try await createAndNotify(
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
        return queueRef.addSnapshotListener { [weak self] snapshot, error in
            if let error { print("Matchmaking queue listener error: \(error.localizedDescription)") }
            guard let self, let snapshot else { return }
            let others = snapshot.documents.filter {
                $0.documentID != user.id &&
                ($0.data()["rankTier"] as? Int ?? -1) == myTier &&
                ($0.data()["wager"]    as? Int ?? -1) == wager
            }
            guard let opponentDoc = others.first else { return }

            let opponentID = opponentDoc.documentID
            let tier = user.rank(for: mode).tier

            Task {
                do {
                    if user.id > opponentID {
                        if let sessionID = try await self.createAndNotify(
                            hostUser: user, wager: wager, tier: tier, searchID: searchID,
                            opponentDoc: opponentDoc,
                            mode: mode, difficulty: difficulty,
                            queueRef: queueRef
                        ) {
                            onPaired(sessionID)
                        }
                    } else if let creatorSearchID = opponentDoc.data()["searchID"] as? String,
                              let sessionID = try await self.waitForExistingSessionID(
                        userID: user.id,
                        opponentID: opponentID,
                        mode: mode,
                        difficulty: difficulty,
                        creatorSearchID: creatorSearchID
                    ) {
                        onPaired(sessionID)
                    }
                } catch {
                    // A concurrent listener may have already handled this pairing.
                }
            }
        }
    }

    private func createAndNotify(
        hostUser: AppUser, wager: Int, tier: RankTier, searchID: String,
        opponentDoc: QueryDocumentSnapshot,
        mode: GameMode, difficulty: Difficulty,
        queueRef: CollectionReference
    ) async throws -> String? {
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
              opponentQueue["searchID"] is String else {
            return nil
        }

        let opponentUsername = opponentQueue["username"] as? String ?? "Opponent"
        let opponentWager    = opponentQueue["wager"]    as? Int    ?? wager
        let opponentTierRaw  = opponentQueue["rankTier"] as? Int    ?? 0
        let opponentTier     = RankTier(rawValue: opponentTierRaw) ?? .bronze

        // Include this queue attempt in the ID so a new match never reuses old
        // Realtime Database ready/results nodes from a previous game.
        let sessionID = makeSessionID(
            userID: hostUser.id,
            opponentID: opponentID,
            mode: mode,
            difficulty: difficulty,
            creatorSearchID: searchID
        )

        let opponentRankPoints = opponentQueue["rankPoints"] as? Int ?? 0

        let existing = try await db.collection("sessions").document(sessionID).getDocument()
        if existing.exists {
            let status = existing.data()?["status"] as? String ?? ""
            if status == SessionStatus.inProgress.rawValue || status == SessionStatus.waiting.rawValue {
                return sessionID
            }
            return nil
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
            puzzleData: MultiplayerPuzzleDataFactory.encoded(mode: mode, difficulty: difficulty, seed: seed),
            createdAt: Date()
        )
        session.playerIDs = [hostUser.id, opponentID]

        // Create session
        try db.collection("sessions").document(sessionID).setData(from: session)

        // Leave opponent-owned documents untouched. Both players discover the match
        // through their own participant-scoped session listener.
        try? await db.collection("users").document(hostUser.id).updateData([
            "pendingSessionID": sessionID,
            "pendingSearchID": searchID
        ])

        // Each client removes its own queue entry after observing the session.
        try? await queueRef.document(hostUser.id).delete()
        return sessionID
    }

    private func waitForExistingSessionID(
        userID: String,
        opponentID: String,
        mode: GameMode,
        difficulty: Difficulty,
        creatorSearchID: String
    ) async throws -> String? {
        let delays: [UInt64] = [0, 250_000_000, 750_000_000, 1_500_000_000]
        for delay in delays {
            if delay > 0 { try await Task.sleep(nanoseconds: delay) }
            if let sessionID = try await findExistingSessionID(
                userID: userID,
                opponentID: opponentID,
                mode: mode,
                difficulty: difficulty,
                creatorSearchID: creatorSearchID
            ) {
                return sessionID
            }
        }
        return nil
    }

    private func findExistingSessionID(
        userID: String,
        opponentID: String,
        mode: GameMode,
        difficulty: Difficulty,
        creatorSearchID: String
    ) async throws -> String? {
        let sessionID = makeSessionID(
            userID: userID,
            opponentID: opponentID,
            mode: mode,
            difficulty: difficulty,
            creatorSearchID: creatorSearchID
        )
        let document = try await db.collection("sessions").document(sessionID).getDocument()
        guard document.exists,
              let status = document.data()?["status"] as? String,
              status == SessionStatus.inProgress.rawValue || status == SessionStatus.waiting.rawValue,
              let session = try? document.data(as: GameSession.self),
              session.mode == mode,
              session.difficulty == difficulty,
              session.players.contains(where: { $0.userID == userID }) else { return nil }
        return sessionID
    }

    private func makeSessionID(
        userID: String,
        opponentID: String,
        mode: GameMode,
        difficulty: Difficulty,
        creatorSearchID: String
    ) -> String {
        let baseID = sessionIDBase(userID: userID, opponentID: opponentID, mode: mode, difficulty: difficulty)
        let attemptID = String(creatorSearchID.prefix(12)).replacingOccurrences(of: "-", with: "")
        return "\(baseID)_s\(attemptID)"
    }

    private func sessionIDBase(userID: String, opponentID: String, mode: GameMode, difficulty: Difficulty) -> String {
        let pair = [userID, opponentID].sorted().joined(separator: "_")
        return "\(pair)_\(mode.rawValue)_\(difficulty.rawValue)"
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

    // MARK: - Friends / Exhibition

    func searchUsers(username: String, excluding currentUserID: String) async throws -> [AppUser] {
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .limit(to: 10)
            .getDocuments()
        return try snapshot.documents
            .map { try $0.data(as: AppUser.self) }
            .filter { $0.id != currentUserID }
    }

    func sendFriendRequest(from user: AppUser, to target: AppUser) async throws {
        guard user.id != target.id else { throw FirestoreServiceError.invalidFriendAction }
        let requestID = friendshipID(user.id, target.id)
        let requestRef = db.collection("friendRequests").document(requestID)

        if let existing = try? await requestRef.getDocument(as: FriendRequest.self) {
            switch existing.status {
            case .pending:
                throw FirestoreServiceError.friendRequestAlreadyPending
            case .accepted:
                throw FirestoreServiceError.friendshipAlreadyExists
            case .declined, .canceled:
                break
            }
        }

        let request = FriendRequest(
            id: requestID,
            fromID: user.id,
            fromUsername: user.username,
            toID: target.id,
            toUsername: target.username,
            status: .pending,
            createdAt: Date()
        )
        try requestRef.setData(from: request, merge: true)
    }

    func acceptFriendRequest(_ request: FriendRequest, currentUserID: String) async throws {
        guard request.toID == currentUserID, request.status == .pending else { throw FirestoreServiceError.invalidFriendAction }
        let requestRef = db.collection("friendRequests").document(request.id)
        let friendshipRef = db.collection("friendships").document(friendshipID(request.fromID, request.toID))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                do {
                    let requestDoc = try transaction.getDocument(requestRef)
                    guard let status = requestDoc.data()?["status"] as? String,
                          status == FriendRequestStatus.pending.rawValue else {
                        return fail(FirestoreServiceError.invalidFriendAction)
                    }
                    let friendship = Friendship(
                        id: friendshipRef.documentID,
                        userIDs: [request.fromID, request.toID].sorted(),
                        usernames: [request.fromID: request.fromUsername, request.toID: request.toUsername],
                        createdAt: Date()
                    )
                    var updatedRequest = request
                    updatedRequest.status = .accepted
                    let requestData = try Firestore.Encoder().encode(updatedRequest)
                    let friendshipData = try Firestore.Encoder().encode(friendship)
                    transaction.setData(requestData, forDocument: requestRef, merge: true)
                    transaction.setData(friendshipData, forDocument: friendshipRef, merge: true)
                    return true
                } catch {
                    return fail(error)
                }
            }, completion: { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
    }

    func declineFriendRequest(_ request: FriendRequest, currentUserID: String) async throws {
        guard request.toID == currentUserID else { throw FirestoreServiceError.invalidFriendAction }
        var updated = request
        updated.status = .declined
        try db.collection("friendRequests").document(request.id).setData(from: updated, merge: true)
    }

    func cancelFriendRequest(_ request: FriendRequest, currentUserID: String) async throws {
        guard request.fromID == currentUserID else { throw FirestoreServiceError.invalidFriendAction }
        var updated = request
        updated.status = .canceled
        try db.collection("friendRequests").document(request.id).setData(from: updated, merge: true)
    }

    func createExhibitionInvite(from user: AppUser, to friend: FriendSummary, mode: GameMode, difficulty: Difficulty) async throws -> ExhibitionInvite {
        let friendshipDoc = try await db.collection("friendships").document(friendshipID(user.id, friend.userID)).getDocument()
        guard friendshipDoc.exists else { throw FirestoreServiceError.notFriends }
        let now = Date()
        let invite = ExhibitionInvite(
            id: UUID().uuidString,
            fromID: user.id,
            fromUsername: user.username,
            toID: friend.userID,
            toUsername: friend.username,
            mode: mode,
            difficulty: difficulty,
            status: .pending,
            createdAt: now,
            expiresAt: now.addingTimeInterval(120),
            sessionID: nil
        )
        try db.collection("exhibitionInvites").document(invite.id).setData(from: invite)
        return invite
    }

    func acceptExhibitionInvite(_ invite: ExhibitionInvite, currentUser: AppUser) async throws -> GameSession {
        guard invite.toID == currentUser.id else { throw FirestoreServiceError.invalidFriendAction }
        guard !invite.isExpired else {
            try? await expireExhibitionInvite(invite.id)
            throw FirestoreServiceError.exhibitionInviteExpired
        }

        let fromUser = try await fetchUser(id: invite.fromID)
        let sessionID = "exhibition_\(invite.id)_\(UUID().uuidString.prefix(8))"
        let seed = Int.random(in: 0..<Int.max)
        var session = GameSession(
            id: sessionID,
            mode: invite.mode,
            difficulty: invite.difficulty,
            status: .waiting,
            players: [
                MatchPlayer(userID: invite.fromID, username: fromUser.username, wager: 0, rankTier: fromUser.rank(for: invite.mode).displayTier, rankPoints: fromUser.rank(for: invite.mode).points),
                MatchPlayer(userID: currentUser.id, username: currentUser.username, wager: 0, rankTier: currentUser.rank(for: invite.mode).displayTier, rankPoints: currentUser.rank(for: invite.mode).points)
            ],
            seed: seed,
            puzzleData: MultiplayerPuzzleDataFactory.encoded(mode: invite.mode, difficulty: invite.difficulty, seed: seed),
            createdAt: Date(),
            matchKind: .exhibition
        )
        session.playerIDs = [invite.fromID, currentUser.id]

        let inviteRef = db.collection("exhibitionInvites").document(invite.id)
        let sessionRef = db.collection("sessions").document(sessionID)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                do {
                    let inviteDoc = try transaction.getDocument(inviteRef)
                    guard let status = inviteDoc.data()?["status"] as? String,
                          status == ExhibitionInviteStatus.pending.rawValue else {
                        return fail(FirestoreServiceError.invalidFriendAction)
                    }
                    var updatedInvite = invite
                    updatedInvite.status = .accepted
                    updatedInvite.sessionID = sessionID
                    let encoded = try Firestore.Encoder().encode(session)
                    let inviteData = try Firestore.Encoder().encode(updatedInvite)
                    transaction.setData(encoded, forDocument: sessionRef)
                    transaction.setData(inviteData, forDocument: inviteRef, merge: true)
                    return true
                } catch {
                    return fail(error)
                }
            }, completion: { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
        return session
    }

    func declineExhibitionInvite(_ invite: ExhibitionInvite, currentUserID: String) async throws {
        guard invite.toID == currentUserID else { throw FirestoreServiceError.invalidFriendAction }
        var updated = invite
        updated.status = .declined
        try db.collection("exhibitionInvites").document(invite.id).setData(from: updated, merge: true)
    }

    func completeExhibitionInvite(_ inviteID: String) async throws {
        try await db.collection("exhibitionInvites").document(inviteID).setData(["status": ExhibitionInviteStatus.completed.rawValue], merge: true)
    }

    private func expireExhibitionInvite(_ inviteID: String) async throws {
        try await db.collection("exhibitionInvites").document(inviteID).setData(["status": ExhibitionInviteStatus.expired.rawValue], merge: true)
    }

    func listenForFriends(userID: String, onChange: @escaping ([Friendship]) -> Void) -> ListenerRegistration {
        db.collection("friendships")
            .whereField("userIDs", arrayContains: userID)
            .addSnapshotListener { snapshot, error in
                if let error { print("Friends listener error: \(error.localizedDescription)") }
                onChange(snapshot?.documents.compactMap { try? $0.data(as: Friendship.self) } ?? [])
            }
    }

    func listenForIncomingFriendRequests(userID: String, onChange: @escaping ([FriendRequest]) -> Void) -> ListenerRegistration {
        db.collection("friendRequests")
            .whereField("toID", isEqualTo: userID)
            .addSnapshotListener { snapshot, error in
                if let error { print("Incoming friend requests listener error: \(error.localizedDescription)") }
                let requests = snapshot?.documents.compactMap { try? $0.data(as: FriendRequest.self) }
                    .filter { $0.status == .pending } ?? []
                onChange(requests)
            }
    }

    func listenForOutgoingFriendRequests(userID: String, onChange: @escaping ([FriendRequest]) -> Void) -> ListenerRegistration {
        db.collection("friendRequests")
            .whereField("fromID", isEqualTo: userID)
            .addSnapshotListener { snapshot, error in
                if let error { print("Outgoing friend requests listener error: \(error.localizedDescription)") }
                let requests = snapshot?.documents.compactMap { try? $0.data(as: FriendRequest.self) }
                    .filter { $0.status == .pending } ?? []
                onChange(requests)
            }
    }

    func listenForIncomingExhibitionInvites(userID: String, onChange: @escaping ([ExhibitionInvite]) -> Void) -> ListenerRegistration {
        db.collection("exhibitionInvites")
            .whereField("toID", isEqualTo: userID)
            .addSnapshotListener { snapshot, error in
                if let error { print("Incoming exhibition invite listener error: \(error.localizedDescription)") }
                let invites = snapshot?.documents.compactMap { try? $0.data(as: ExhibitionInvite.self) }
                    .filter { $0.status == .pending && !$0.isExpired } ?? []
                onChange(invites)
            }
    }

    func listenForOutgoingExhibitionInvites(userID: String, onChange: @escaping ([ExhibitionInvite]) -> Void) -> ListenerRegistration {
        db.collection("exhibitionInvites")
            .whereField("fromID", isEqualTo: userID)
            .addSnapshotListener { snapshot, error in
                if let error { print("Outgoing exhibition invite listener error: \(error.localizedDescription)") }
                let decodedInvites: [ExhibitionInvite] = snapshot?.documents.compactMap { document in
                    try? document.data(as: ExhibitionInvite.self)
                } ?? []
                let activeInvites = decodedInvites.filter { invite in
                    if invite.status == ExhibitionInviteStatus.pending {
                        return !invite.isExpired
                    }
                    if invite.status == ExhibitionInviteStatus.accepted {
                        return invite.sessionID != nil && !invite.isExpired
                    }
                    return false
                }
                onChange(activeInvites)
            }
    }

    private func friendshipID(_ a: String, _ b: String) -> String {
        [a, b].sorted().joined(separator: "_")
    }
}

private extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var values: [T] = []
        for element in self {
            let value = try await transform(element)
            values.append(value)
        }
        return values
    }
}
