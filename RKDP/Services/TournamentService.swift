import Foundation
import FirebaseFirestore

final class TournamentService {
    static let shared = TournamentService()
    private let db = Firestore.firestore()
    private init() {}

    func todaysTournaments(for tier: RankTier) -> [DailyTournament] {
        GameMode.allCases.map { DailyTournament.make(mode: $0, tier: tier) }
    }

    func fetchEntries(tournamentID: String) async throws -> [TournamentEntry] {
        let snapshot = try await db.collection("tournaments")
            .document(tournamentID)
            .collection("entries")
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: TournamentEntry.self) }
    }

    func enterTournament(_ tournament: DailyTournament, user: AppUser) async throws -> (AppUser, TournamentEntry) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(AppUser, TournamentEntry), Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let tournamentRef = self.db.collection("tournaments").document(tournament.id)
                let entryRef = tournamentRef.collection("entries").document(user.id)
                let userRef = self.db.collection("users").document(user.id)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var currentUser = try transaction.getDocument(userRef).data(as: AppUser.self)
                    if let existing = try? transaction.getDocument(entryRef).data(as: TournamentEntry.self) {
                        return ["user": currentUser, "entry": existing]
                    }
                    guard currentUser.coins >= tournament.entryFee else { return fail(FirestoreServiceError.insufficientCoins) }
                    currentUser.coins -= tournament.entryFee
                    let entry = TournamentEntry(
                        id: user.id,
                        tournamentID: tournament.id,
                        userID: user.id,
                        username: currentUser.username,
                        rankTier: tournament.rankTier,
                        enteredAt: Date()
                    )
                    let encodedTournament = try Firestore.Encoder().encode(tournament)
                    let encodedEntry = try Firestore.Encoder().encode(entry)
                    transaction.setData(encodedTournament, forDocument: tournamentRef, merge: true)
                    transaction.setData(encodedEntry, forDocument: entryRef, merge: true)
                    let encodedUser = try Firestore.Encoder().encode(currentUser)
                    transaction.setData(encodedUser, forDocument: userRef, merge: true)
                    return ["user": currentUser, "entry": entry]
                } catch {
                    return fail(error)
                }
            }, completion: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let dict = result as? [String: Any],
                          let user = dict["user"] as? AppUser,
                          let entry = dict["entry"] as? TournamentEntry {
                    continuation.resume(returning: (user, entry))
                } else {
                    continuation.resume(throwing: FirestoreServiceError.missingUpdatedUser)
                }
            })
        }
    }

    func submitResult(_ result: TournamentResult, tournament: DailyTournament, userID: String) async throws {
        try await db.collection("tournaments")
            .document(tournament.id)
            .collection("entries")
            .document(userID)
            .setData(["result": try Firestore.Encoder().encode(result)], merge: true)
    }

    func claimPrize(tournament: DailyTournament, userID: String) async throws -> AppUser {
        let entries = try await fetchEntries(tournamentID: tournament.id)
        let sorted = TournamentScoring.sortedEntries(entries, mode: tournament.mode)
        guard let index = sorted.firstIndex(where: { $0.userID == userID }) else { throw FirestoreServiceError.invalidFriendAction }
        let prize = TournamentScoring.prize(for: index + 1, entryCount: entries.count, entryFee: tournament.entryFee)
        guard prize > 0 else { throw FirestoreServiceError.invalidFriendAction }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let entryRef = self.db.collection("tournaments").document(tournament.id).collection("entries").document(userID)
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var entry = try transaction.getDocument(entryRef).data(as: TournamentEntry.self)
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    if entry.prizeClaimed { return user }
                    entry.prizeClaimed = true
                    entry.prizeAmount = prize
                    user.coins += prize
                    let encodedEntry = try Firestore.Encoder().encode(entry)
                    transaction.setData(encodedEntry, forDocument: entryRef, merge: true)
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
}
