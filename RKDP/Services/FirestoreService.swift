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

    // MARK: - Matchmaking queue

    func joinMatchmakingQueue(userID: String, mode: GameMode, difficulty: Difficulty, wager: Int, rankTier: RankTier) async throws {
        try await db.collection("matchmaking")
            .document("\(mode.rawValue)_\(difficulty.rawValue)")
            .collection("queue")
            .document(userID)
            .setData([
                "userID": userID,
                "wager": wager,
                "rankTier": rankTier.rawValue,
                "joinedAt": FieldValue.serverTimestamp()
            ])
    }

    func leaveMatchmakingQueue(userID: String, mode: GameMode, difficulty: Difficulty) async throws {
        try await db.collection("matchmaking")
            .document("\(mode.rawValue)_\(difficulty.rawValue)")
            .collection("queue")
            .document(userID)
            .delete()
    }

    func listenForMatch(userID: String, mode: GameMode, difficulty: Difficulty, onMatch: @escaping (String) -> Void) -> ListenerRegistration {
        db.collection("users").document(userID)
            .addSnapshotListener { snapshot, _ in
                guard let data = snapshot?.data(),
                      let sessionID = data["pendingSessionID"] as? String else { return }
                onMatch(sessionID)
            }
    }
}
