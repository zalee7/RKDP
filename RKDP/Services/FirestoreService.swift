import Foundation
import FirebaseFirestore

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
            rankTier: info.tier, rankPoints: info.points,
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

    func updateSession(_ session: GameSession) async throws {
        try db.collection("sessions").document(session.id).setData(from: session, merge: true)
    }

    func finishSession(id: String, winnerID: String?, finishedAt: Date) async throws {
        try await db.collection("sessions").document(id).updateData([
            "status": SessionStatus.finished.rawValue,
            "winnerID": winnerID as Any,
            "finishedAt": Timestamp(date: finishedAt)
        ])
    }

    // MARK: - Matchmaking

    /// Write this player into the queue, then attempt to pair with anyone already waiting.
    /// The player with the lexicographically larger userID always creates the session,
    /// guaranteeing exactly one session even if both arrive simultaneously.
    func joinAndPair(user: AppUser, mode: GameMode, difficulty: Difficulty, wager: Int) async throws {
        let tier = user.rank(for: mode).tier
        let queueRef = queueCollection(mode: mode, difficulty: difficulty)

        // 1. Write own entry (merge so a concurrent delete doesn't resurrect us)
        try await queueRef.document(user.id).setData([
            "userID":   user.id,
            "username": user.username,
            "wager":    wager,
            "rankTier": tier.rawValue
        ])

        // 2. Look for anyone else already in the queue
        let snapshot = try await queueRef.getDocuments()
        let others = snapshot.documents.filter { $0.documentID != user.id }
        guard let opponentDoc = others.first else { return }  // alone — wait for queue listener

        let opponentID = opponentDoc.documentID

        // 3. Only the player with the LARGER uid creates the session (deterministic tiebreak)
        guard user.id > opponentID else { return }

        try await createAndNotify(
            hostUser: user, wager: wager, tier: tier,
            opponentDoc: opponentDoc,
            mode: mode, difficulty: difficulty,
            queueRef: queueRef
        )
    }

    /// Watch the queue; if a second player appears AND this user has the larger uid,
    /// create the session and notify both players.
    func listenForQueueMatch(
        user: AppUser, mode: GameMode, difficulty: Difficulty, wager: Int,
        onPaired: @escaping (String) -> Void
    ) -> ListenerRegistration {
        let queueRef = queueCollection(mode: mode, difficulty: difficulty)

        return queueRef.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let snapshot else { return }
            let others = snapshot.documents.filter { $0.documentID != user.id }
            guard let opponentDoc = others.first else { return }

            // Only the larger-uid player creates
            guard user.id > opponentDoc.documentID else { return }
            let tier = user.rank(for: mode).tier

            Task {
                do {
                    try await self.createAndNotify(
                        hostUser: user, wager: wager, tier: tier,
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
        hostUser: AppUser, wager: Int, tier: RankTier,
        opponentDoc: QueryDocumentSnapshot,
        mode: GameMode, difficulty: Difficulty,
        queueRef: CollectionReference
    ) async throws {
        let opponentID       = opponentDoc.documentID
        let opponentUsername = opponentDoc.data()["username"] as? String ?? "Opponent"
        let opponentWager    = opponentDoc.data()["wager"]    as? Int    ?? wager
        let opponentTierRaw  = opponentDoc.data()["rankTier"] as? Int    ?? 0
        let opponentTier     = RankTier(rawValue: opponentTierRaw) ?? .bronze

        // Derive a deterministic session ID so simultaneous creates are idempotent
        let pair = [hostUser.id, opponentID].sorted().joined(separator: "_")
        let sessionID = "\(pair)_\(mode.rawValue)_\(difficulty.rawValue)"

        // Abort if we've already created this session
        let existing = try await db.collection("sessions").document(sessionID).getDocument()
        guard !existing.exists else { return }

        let seed = Int.random(in: 0..<Int.max)
        let session = GameSession(
            id: sessionID,
            mode: mode,
            difficulty: difficulty,
            status: .inProgress,
            players: [
                MatchPlayer(userID: hostUser.id, username: hostUser.username, wager: wager, rankTier: tier),
                MatchPlayer(userID: opponentID,  username: opponentUsername,  wager: opponentWager, rankTier: opponentTier)
            ],
            seed: seed,
            puzzleData: "",
            createdAt: Date()
        )

        // Create session
        try db.collection("sessions").document(sessionID).setData(from: session)

        // Notify both players by writing pendingSessionID to their user docs
        try await db.collection("users").document(hostUser.id).updateData(["pendingSessionID": sessionID])
        try await db.collection("users").document(opponentID).updateData(["pendingSessionID": sessionID])

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
            "pendingSessionID": FieldValue.delete()
        ])
    }

    /// Listen on the user's own doc for pendingSessionID written by the pairing host
    func listenForMatch(userID: String, onMatch: @escaping (String) -> Void) -> ListenerRegistration {
        db.collection("users").document(userID)
            .addSnapshotListener { snapshot, _ in
                guard let data = snapshot?.data(),
                      let sessionID = data["pendingSessionID"] as? String else { return }
                onMatch(sessionID)
            }
    }

    private func queueCollection(mode: GameMode, difficulty: Difficulty) -> CollectionReference {
        db.collection("matchmaking")
            .document("\(mode.rawValue)_\(difficulty.rawValue)")
            .collection("queue")
    }
}
