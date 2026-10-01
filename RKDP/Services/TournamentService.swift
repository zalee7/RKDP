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
        try await FirestoreService.shared.requireLegacyWallet(userID: user.id)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(AppUser, TournamentEntry), Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let tournamentRef = self.db.collection("tournaments").document(tournament.id)
                let entryRef = tournamentRef.collection("entries").document(user.id)
                let userRef = self.db.collection("users").document(user.id)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    let userSnapshot = try transaction.getDocument(userRef)
                    guard (userSnapshot.data()?["serverWalletVersion"] as? Int ?? 0) == 0 else {
                        return fail(FirestoreServiceError.walletMigrationPending)
                    }
                    var currentUser = try userSnapshot.data(as: AppUser.self)
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
        try await FirestoreService.shared.requireLegacyWallet(userID: userID)
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
                    let userSnapshot = try transaction.getDocument(userRef)
                    guard (userSnapshot.data()?["serverWalletVersion"] as? Int ?? 0) == 0 else {
                        return fail(FirestoreServiceError.walletMigrationPending)
                    }
                    var user = try userSnapshot.data(as: AppUser.self)
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

@MainActor
enum VerifiedDailyClient {
    private struct Pending: Codable {
        let challengeID: String
        let evidenceJSON: String
    }
    private struct Receipt: Decodable { let challengeID: String }
    private struct DiscardReply: Decodable { let discarded: Bool }

    static func hasPending(userID: String) -> Bool {
        (try? pending(userID: userID).isEmpty == false) ?? true
    }

    static func discardPending(userID: String) async throws {
        for item in try pending(userID: userID) {
            let reply: DiscardReply = try await EconomyCallable.call("dailyChallenge_discard", userID: userID,
                data: ["challengeID": item.challengeID])
            guard reply.discarded else { throw URLError(.cannotParseResponse) }
            let remaining = try pending(userID: userID).filter { $0.challengeID != item.challengeID }
            UserDefaults.standard.set(try JSONEncoder().encode(remaining), forKey: key(userID))
        }
    }

    static func today(userID: String) async throws -> DailyChallengeSet {
        try await EconomyCallable.call("dailyChallenge_today", userID: userID, data: [:])
    }

    static func begin(userID: String, challengeID: String) async throws -> DailyChallenge {
        return try await EconomyCallable.call("dailyChallenge_begin", userID: userID,
            data: ["challengeID": challengeID])
    }

    static func submit(userID: String, challengeID: String, evidenceJSON: String) async throws {
        var saved = try pending(userID: userID)
        // Preserve the first final proof across retries and overlapping callbacks.
        if !saved.contains(where: { $0.challengeID == challengeID }) {
            saved.append(Pending(challengeID: challengeID, evidenceJSON: evidenceJSON))
            UserDefaults.standard.set(try JSONEncoder().encode(saved), forKey: key(userID))
        }
        guard let item = try pending(userID: userID).first(where: { $0.challengeID == challengeID }) else {
            throw URLError(.cannotParseResponse)
        }
        try await settle(item, userID: userID)
    }

    @discardableResult
    static func recover(userID: String) async throws -> Bool {
        let saved = try pending(userID: userID)
        var firstError: Error?
        for item in saved {
            do { try await settle(item, userID: userID) }
            catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
        return !saved.isEmpty
    }

    private static func settle(_ item: Pending, userID: String) async throws {
        let evidence = try JSONSerialization.jsonObject(with: Data(item.evidenceJSON.utf8))
        let receipt: Receipt = try await EconomyCallable.call("dailyChallenge_complete", userID: userID,
            data: ["challengeID": item.challengeID, "evidence": evidence])
        guard receipt.challengeID == item.challengeID else { throw URLError(.cannotParseResponse) }
        let remaining = try pending(userID: userID).filter { $0.challengeID != item.challengeID }
        UserDefaults.standard.set(try JSONEncoder().encode(remaining), forKey: key(userID))
    }

    private static func key(_ userID: String) -> String { "verifiedDailyPending_\(userID)" }
    private static func pending(userID: String) throws -> [Pending] {
        guard let data = UserDefaults.standard.data(forKey: key(userID)) else { return [] }
        return try JSONDecoder().decode([Pending].self, from: data)
    }
}

final class DailyChallengeService {
    static let shared = DailyChallengeService()
    private let db = Firestore.firestore()
    private init() {}

    func todayChallengeSet(userID: String, includePuzzleData: Bool = false) async throws -> DailyChallengeSet {
        if try await FirestoreService.shared.usesServerWallet(userID: userID) {
            return try await VerifiedDailyClient.today(userID: userID)
        }
        let localSet = DailyChallengeSet.today(includePuzzleData: includePuzzleData)
        let ref = db.collection("dailyChallenges").document(localSet.dayKey)
        let snapshot = try await ref.getDocument()
        if snapshot.exists, let remote = try? snapshot.data(as: DailyChallengeSet.self) {
            let localIDs = Set(localSet.challenges.map(\.id))
            let remoteIDs = Set(remote.challenges.map(\.id))
            guard localIDs != remoteIDs else {
                return includePuzzleData ? remoteWithPreparedPuzzleData(remote) : remote
            }
        }

        try ref.setData(from: localSet, merge: true)
        return localSet
    }

    func fetchEntries(dayKey: String, userID: String) async throws -> [DailyChallengeEntry] {
        let verified = try await FirestoreService.shared.usesServerWallet(userID: userID)
        let snapshot = try await db.collection(verified ? "serverDailyChallenges" : "dailyChallenges")
            .document(dayKey)
            .collection("entries")
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: DailyChallengeEntry.self) }
    }

    func fetchFriendIDs(for userID: String) async throws -> [String] {
        let snapshot = try await db.collection("friendships")
            .whereField("userIDs", arrayContains: userID)
            .getDocuments()
        return try snapshot.documents.compactMap { document in
            let friendship = try document.data(as: Friendship.self)
            return friendship.friendID(for: userID)
        }
    }

    func submitResult(_ result: DailyChallengeResult, challenge: DailyChallenge, userID: String) async throws -> (AppUser, DailyChallengeEntry) {
        try await FirestoreService.shared.requireLegacyWallet(userID: userID)
        let challengeSet = DailyChallengeSet.make(dayKey: challenge.dayKey, includePuzzleData: false)
        let challengeIDs = challengeSet.challenges.map(\.id)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(AppUser, DailyChallengeEntry), Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let dayRef = self.db.collection("dailyChallenges").document(challenge.dayKey)
                let entriesRef = dayRef.collection("entries")
                let entryRefs = challengeIDs.map { entriesRef.document(self.entryID(userID: userID, challengeID: $0)) }
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    let userSnapshot = try transaction.getDocument(userRef)
                    guard (userSnapshot.data()?["serverWalletVersion"] as? Int ?? 0) == 0 else {
                        return fail(FirestoreServiceError.walletMigrationPending)
                    }
                    var user = try userSnapshot.data(as: AppUser.self)
                    let entrySnapshots = try entryRefs.map { try transaction.getDocument($0) }
                    let selectedEntryID = self.entryID(userID: userID, challengeID: challenge.id)

                    if let existingIndex = challengeIDs.firstIndex(of: challenge.id),
                       let existing = try? entrySnapshots[existingIndex].data(as: DailyChallengeEntry.self) {
                        return ["user": user, "entry": existing]
                    }

                    var completedChallengeIDs = Set<String>()
                    for snapshot in entrySnapshots {
                        if let entry = try? snapshot.data(as: DailyChallengeEntry.self) {
                            completedChallengeIDs.insert(entry.challengeID)
                        }
                    }
                    completedChallengeIDs.insert(challenge.id)

                    let streakReward = user.playProgress.recordGamePlayed(activityID: "daily_\(challenge.id)_\(userID)")
                    if streakReward > 0 {
                        user.coins += streakReward
                    }
                    if completedChallengeIDs.count >= challengeIDs.count,
                       user.dailyChallengeBonusDays[challenge.dayKey] != true {
                        user.dailyChallengeBonusDays[challenge.dayKey] = true
                        user.coins += DailyChallengeSet.completionBonus
                    }

                    let entry = DailyChallengeEntry(
                        id: selectedEntryID,
                        dayKey: challenge.dayKey,
                        challengeID: challenge.id,
                        category: challenge.category,
                        mode: challenge.mode,
                        difficulty: challenge.difficulty,
                        userID: user.id,
                        username: user.username,
                        avatarStyle: user.cosmetics.avatarStyle,
                        submittedAt: Date(),
                        result: result
                    )

                    let encodedSet = try Firestore.Encoder().encode(challengeSet)
                    let encodedEntry = try Firestore.Encoder().encode(entry)
                    let encodedUser = try Firestore.Encoder().encode(user)
                    transaction.setData(encodedSet, forDocument: dayRef, merge: true)
                    transaction.setData(encodedEntry, forDocument: entriesRef.document(selectedEntryID), merge: true)
                    transaction.setData(encodedUser, forDocument: userRef, merge: true)
                    return ["user": user, "entry": entry]
                } catch {
                    return fail(error)
                }
            }, completion: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let dict = result as? [String: Any],
                          let user = dict["user"] as? AppUser,
                          let entry = dict["entry"] as? DailyChallengeEntry {
                    continuation.resume(returning: (user, entry))
                } else {
                    continuation.resume(throwing: FirestoreServiceError.missingUpdatedUser)
                }
            })
        }
    }

    private func remoteWithPreparedPuzzleData(_ set: DailyChallengeSet) -> DailyChallengeSet {
        var prepared = set
        prepared.challenges = set.challenges.map { $0.preparedForPlay() }
        return prepared
    }

    private func entryID(userID: String, challengeID: String) -> String {
        "\(userID)_\(challengeID)"
    }
}
