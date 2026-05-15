import Foundation
import FirebaseDatabase

// Manages live session state (move sync, ready signals, finish times)
final class RealtimeDBService {
    static let shared = RealtimeDBService()
    private let ref = Database.database().reference()

    private init() {}

    private func sessionRef(_ sessionID: String) -> DatabaseReference {
        ref.child("sessions").child(sessionID)
    }

    // MARK: - Session lifecycle

    func markReady(sessionID: String, userID: String) async throws {
        try await sessionRef(sessionID).child("ready").child(userID).setValue(true)
    }

    func listenForBothReady(sessionID: String, completion: @escaping () -> Void) -> DatabaseHandle {
        sessionRef(sessionID).child("ready").observe(.value) { snapshot in
            guard let dict = snapshot.value as? [String: Bool],
                  dict.values.allSatisfy({ $0 }) && dict.count == 2 else { return }
            completion()
        }
    }

    // MARK: - Match results

    func submitResult(sessionID: String, result: MatchPlayerResult) async throws {
        try await sessionRef(sessionID)
            .child("results")
            .child(result.userID)
            .setValue(result.realtimeValue)
    }

    func listenForResults(sessionID: String, onUpdate: @escaping ([String: MatchPlayerResult]) -> Void) -> DatabaseHandle {
        sessionRef(sessionID).child("results").observe(.value) { snapshot in
            guard let dict = snapshot.value as? [String: Any] else {
                onUpdate([:])
                return
            }

            var results: [String: MatchPlayerResult] = [:]
            for (userID, raw) in dict {
                if let result = MatchPlayerResult.fromRealtimeValue(raw) {
                    results[userID] = result
                }
            }
            onUpdate(results)
        }
    }

    // MARK: - Move sync (for future turn-based modes)

    func broadcastMove(sessionID: String, userID: String, move: [String: Any]) async throws {
        let key = sessionRef(sessionID).child("moves").childByAutoId().key ?? UUID().uuidString
        try await sessionRef(sessionID).child("moves").child(key).setValue(move)
    }

    func listenForMoves(sessionID: String, onMove: @escaping ([String: Any]) -> Void) -> DatabaseHandle {
        sessionRef(sessionID).child("moves").observe(.childAdded) { snapshot in
            guard let dict = snapshot.value as? [String: Any] else { return }
            onMove(dict)
        }
    }

    func removeObserver(handle: DatabaseHandle, sessionID: String) {
        sessionRef(sessionID).removeObserver(withHandle: handle)
    }

    func removeSession(id: String) async throws {
        try await sessionRef(id).removeValue()
    }
}
