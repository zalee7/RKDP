import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore

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
    case dailyCoinsAlreadyClaimed
    case rewardedCoinLimitReached
    case unknownCoinPack
    case cosmeticPackComplete
    case partyRoomNotFound
    case partyRoomFull
    case partyRoomExpired
    case partyRoomAlreadyStarted
    case notPartyHost
    case earnedRewardLocked
    case walletMigrationPending

    var errorDescription: String? {
        switch self {
        case .insufficientCoins:
            return "You do not have enough coins for that."
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
        case .dailyCoinsAlreadyClaimed:
            return "Daily coins are already claimed today."
        case .rewardedCoinLimitReached:
            return "You have reached today's rewarded coin ad limit."
        case .unknownCoinPack:
            return "That coin pack is not available yet."
        case .cosmeticPackComplete:
            return "You already own every item in that pack."
        case .partyRoomNotFound:
            return "That party code was not found."
        case .partyRoomFull:
            return "That party room is full."
        case .partyRoomExpired:
            return "That party room expired."
        case .partyRoomAlreadyStarted:
            return "That party already started."
        case .notPartyHost:
            return "Only the host can do that."
        case .earnedRewardLocked:
            return "That reward is not unlocked yet. Refresh your progress and try again."
        case .walletMigrationPending:
            return "This action is not available for migrated wallets yet. Your coins have not been changed."
        }
    }
}

struct SoloRewardAttempt: Codable {
    let id: String
    let mode: GameMode
    let difficulty: Difficulty
    let seed: Int
    let reward: Int
    let expiresAtMs: Double
}

struct SoloRewardReceipt: Codable {
    let attemptID: String
    let puzzleCoins: Int
    let dailyCoins: Int
    let balance: Int
}

@MainActor
enum SoloRewardClient {
    // Keep off until every existing wallet writer is migrated and the rollout
    // checklist is satisfied. Server flags independently enforce the same gate.
    static let rolloutEnabled = false
    private struct Start: Codable {
        let attemptID: String
        let mode: GameMode
        let difficulty: Difficulty
    }
    private struct Pending: Codable {
        let attemptID: String
        let evidenceJSON: String
    }
    private struct Availability: Decodable { let enabled: Bool }
    private struct Abandoned: Decodable { let abandoned: Bool }

    static func isEnabled(userID: String) async -> Bool {
        guard rolloutEnabled else { return false }
        let status: Availability? = try? await call("soloRewardStatus", userID: userID, data: [:])
        return status?.enabled == true
    }

    static func begin(userID: String, mode: GameMode, difficulty: Difficulty) async throws -> SoloRewardAttempt {
        // A pending payout must resolve before another puzzle can replace its receipt.
        _ = try await recover(userID: userID)
        let key = "soloRewardStart_\(userID)"
        var start = UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(Start.self, from: $0) }
        if let old = start, old.mode != mode || old.difficulty != difficulty {
            try await abandon(userID: userID, attemptID: old.attemptID)
            start = nil
        }
        let request = start ?? Start(attemptID: UUID().uuidString, mode: mode, difficulty: difficulty)
        UserDefaults.standard.set(try JSONEncoder().encode(request), forKey: key)
        let attempt: SoloRewardAttempt = try await call("beginSoloReward", userID: userID, data: [
            "attemptID": request.attemptID, "mode": mode.rawValue,
            "difficulty": difficulty.rawValue, "protocolVersion": "solo-v1"
        ])
        UserDefaults.standard.set(try JSONEncoder().encode(Start(attemptID: attempt.id, mode: mode, difficulty: difficulty)), forKey: key)
        return attempt
    }

    static func submit(userID: String, attemptID: String, evidenceJSON: String) async throws -> SoloRewardReceipt {
        let key = "soloRewardPending_\(userID)"
        if let data = UserDefaults.standard.data(forKey: key),
           let existing = try? JSONDecoder().decode(Pending.self, from: data), existing.attemptID != attemptID {
            _ = try await recover(userID: userID)
        }
        let pending = Pending(attemptID: attemptID, evidenceJSON: evidenceJSON)
        UserDefaults.standard.set(try JSONEncoder().encode(pending), forKey: key)
        guard let receipt = try await recover(userID: userID) else { throw URLError(.cannotParseResponse) }
        return receipt
    }

    static func recover(userID: String) async throws -> SoloRewardReceipt? {
        let key = "soloRewardPending_\(userID)"
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let pending = try JSONDecoder().decode(Pending.self, from: data)
        let evidence = try JSONSerialization.jsonObject(with: Data(pending.evidenceJSON.utf8))
        let receipt: SoloRewardReceipt = try await call("completeSoloReward", userID: userID,
            data: ["attemptID": pending.attemptID, "evidence": evidence])
        guard receipt.attemptID == pending.attemptID else { throw URLError(.cannotParseResponse) }
        // A delayed duplicate response must not erase a newer run's saved claim.
        if let current = UserDefaults.standard.data(forKey: key),
           (try? JSONDecoder().decode(Pending.self, from: current))?.attemptID == pending.attemptID {
            UserDefaults.standard.removeObject(forKey: key)
        }
        clearStart(userID: userID, attemptID: pending.attemptID)
        return receipt
    }

    static func abandon(userID: String, attemptID: String) async throws {
        let _: Abandoned = try await call("abandonSoloReward", userID: userID, data: ["attemptID": attemptID])
        clearStart(userID: userID, attemptID: attemptID)
    }

    private static func clearStart(userID: String, attemptID: String) {
        let key = "soloRewardStart_\(userID)"
        guard let data = UserDefaults.standard.data(forKey: key),
              (try? JSONDecoder().decode(Start.self, from: data))?.attemptID == attemptID else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func discardPendingAttempt(userID: String) async throws {
        let pendingKey = "soloRewardPending_\(userID)"
        let startKey = "soloRewardStart_\(userID)"
        // Explicit confirmation also closes an attempt from a previous install/device.
        // If settlement won the transaction race, its coins remain credited.
        let _: Abandoned = try await call("abandonSoloReward", userID: userID, data: ["allPending": true])
        UserDefaults.standard.removeObject(forKey: pendingKey)
        UserDefaults.standard.removeObject(forKey: startKey)
    }

    // Uses Firebase's callable protocol without adding another package product.
    private static func call<T: Decodable>(_ name: String, userID: String, data: [String: Any]) async throws -> T {
        try await EconomyCallable.call(name, userID: userID, data: data)
    }
}

@MainActor
enum EconomyCallable {
    static func call<T: Decodable>(_ name: String, userID: String, data: [String: Any]) async throws -> T {
        guard let user = Auth.auth().currentUser, user.uid == userID,
              let project = FirebaseApp.app()?.options.projectID,
              let url = URL(string: "https://us-central1-\(project).cloudfunctions.net/\(name)") else {
            throw URLError(.userAuthenticationRequired)
        }
        let token = try await user.getIDToken()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": data])
        let (body, response) = try await URLSession.shared.data(for: request)
        guard Auth.auth().currentUser?.uid == userID else { throw URLError(.userAuthenticationRequired) }
        let envelope = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        if let error = envelope?["error"] as? [String: Any], let message = error["message"] as? String {
            throw NSError(domain: "Economy", code: 1, userInfo: [NSLocalizedDescriptionKey: String(message.prefix(300))])
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let envelope,
              envelope["error"] == nil, let result = envelope["result"] ?? envelope["data"] else {
            throw NSError(domain: "Economy", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Could not complete this request. Refresh and retry when connected."])
        }
        return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: result))
    }
}

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // Enable only with the coordinated backend/rules rollout. An account that has
    // migrated must never fall back to legacy writes after a network error.
    static let serverWalletRolloutEnabled = false

    func usesServerWallet(userID: String) async throws -> Bool {
        #if PP_PURCHASE_SANDBOX || PP_SOCIAL_SANDBOX
        guard FirebaseApp.app()?.options.projectID == "puzzlepartytest",
              try await db.collection("coinWallets").document(userID).getDocument(source: .server).exists else {
            throw FirestoreServiceError.walletMigrationPending
        }
        return true
        #else
        guard Self.serverWalletRolloutEnabled else { return false }
        return try await db.collection("coinWallets").document(userID).getDocument().exists
        #endif
    }

    func requireLegacyWallet(userID: String) async throws {
        if try await usesServerWallet(userID: userID) { throw FirestoreServiceError.walletMigrationPending }
    }

    private struct WalletReply: Decodable { let balance: Int }

    struct PurchasePreparation: Decodable {
        let appAccountToken: UUID
        let environment: String
        let refundDebt: Int
    }

    func prepareWalletPurchase(userID: String) async throws -> PurchasePreparation {
        let reply: PurchasePreparation = try await EconomyCallable.call("prepareWalletPurchase", userID: userID, data: [:])
        #if PP_PURCHASE_SANDBOX || PP_SOCIAL_SANDBOX
        guard reply.environment == "Sandbox" else { throw CoinPackStoreKitError.unverified }
        #endif
        return reply
    }

    func walletRefundDebt(userID: String) async throws -> Int {
        guard Self.serverWalletRolloutEnabled else { return 0 }
        let snapshot = try await db.collection("coinWallets").document(userID).getDocument()
        return max(0, (snapshot.data()?["purchaseRefundDebt"] as? NSNumber)?.intValue ?? 0)
    }

    func claimWalletPurchase(userID: String, signedTransaction: String) async throws -> AppUser {
        struct PurchaseReply: Decodable { let accepted: Bool; let revoked: Bool }
        let reply: PurchaseReply = try await EconomyCallable.call("claimWalletPurchase", userID: userID,
                                                                 data: ["signedTransaction": signedTransaction])
        guard reply.accepted else { throw CoinPackStoreKitError.unverified }
        return try await fetchUser(id: userID)
    }
    private struct SavedReply: Decodable { let saved: Bool }

    struct MatchWalletReply: Decodable {
        let sessionID: String
        let matchReward: Int
        let dailyCoins: Int
        let rankDelta: Int
        let balance: Int
        let didApplyRewards: Bool
        let reason: String
    }

    func settleMatchWallet(sessionID: String, userID: String) async throws -> MatchWalletReply {
        // Only the identity is sent. The server selects the verified outcome,
        // starting rank, caps and reward, and settles both human participants.
        try await EconomyCallable.call("settleWalletMatch", userID: userID, data: ["sessionID": sessionID])
    }

    struct OfficialMatchReply: Decodable {
        var sessionID: String?
        var accepted: Bool?
        var status: String?
        var ownResult: MatchPlayerResult?
    }

    func officialQueue(userID: String, mode: GameMode, kind: SessionKind, requestID: String) async throws -> OfficialMatchReply {
        try await EconomyCallable.call("officialMatch_queue", userID: userID,
                                       data: ["mode": mode.rawValue, "matchKind": kind.rawValue, "requestID": requestID])
    }

    func officialCancel(userID: String, requestID: String) async throws -> OfficialMatchReply {
        try await EconomyCallable.call("officialMatch_cancel", userID: userID, data: ["requestID": requestID])
    }

    @discardableResult
    func officialAction(_ action: String, userID: String, sessionID: String, evidenceJSON: String? = nil) async throws -> OfficialMatchReply {
        var data: [String: Any] = ["sessionID": sessionID]
        if let evidenceJSON {
            data["evidence"] = try JSONSerialization.jsonObject(with: Data(evidenceJSON.utf8))
        }
        if sessionID.hasPrefix("sv1_") {
            data["roundIndex"] = 0
            return try await EconomyCallable.call("socialGame_\(action)", userID: userID, data: data)
        }
        return try await EconomyCallable.call("officialMatch_\(action)", userID: userID, data: data)
    }

    private func createVerifiedSocial(userID: String, kind: String, rounds: [PartyStageRoundConfiguration], friendID: String? = nil) async throws -> String {
        // Retain a request identity through a lost response instead of making a second room.
        let key = "socialCreate_\(userID)_\(kind)_\(friendID ?? "party")_" + rounds.map { "\($0.mode.rawValue)_\($0.difficulty.rawValue)" }.joined(separator: "_")
        let requestID = UserDefaults.standard.string(forKey: key) ?? UUID().uuidString
        UserDefaults.standard.set(requestID, forKey: key)
        var data: [String: Any] = ["kind": kind, "requestID": requestID,
            "rounds": rounds.map { ["mode": $0.mode.rawValue, "difficulty": $0.difficulty.rawValue] }]
        if let friendID { data["friendID"] = friendID }
        let reply: OfficialMatchReply = try await EconomyCallable.call("socialGame_create", userID: userID, data: data)
        guard let id = reply.sessionID else { throw FirestoreServiceError.invalidFriendAction }
        UserDefaults.standard.removeObject(forKey: key)
        return id
    }

    @discardableResult
    func verifiedPartyAction(_ action: String, code: String, userID: String, roundIndex: Int? = nil,
                             evidenceJSON: String? = nil, isReady: Bool? = nil) async throws -> PartyRoom {
        // A guest loses read access after leaving the lobby. Keep that final local view for dismissal.
        let leavingRoom: PartyRoom? = action == "forfeit" ? try await db.collection("partyRooms").document(normalizedPartyCode(code)).getDocument(as: PartyRoom.self) : nil
        var data: [String: Any] = ["sessionID": normalizedPartyCode(code)]
        if let roundIndex { data["roundIndex"] = roundIndex }
        if let isReady { data["isReady"] = isReady }
        if let evidenceJSON { data["evidence"] = try JSONSerialization.jsonObject(with: Data(evidenceJSON.utf8)) }
        let _: OfficialMatchReply = try await EconomyCallable.call("socialGame_\(action)", userID: userID, data: data)
        if let leavingRoom, leavingRoom.status == .lobby, leavingRoom.hostID != userID { return leavingRoom }
        return try await db.collection("partyRooms").document(normalizedPartyCode(code)).getDocument(as: PartyRoom.self)
    }

    // MARK: - Users

    func createUser(_ user: AppUser) async throws {
        try await requireLegacyWallet(userID: user.id)
        try db.collection("users").document(user.id).setData(from: user)
    }

    func fetchUser(id: String) async throws -> AppUser {
        #if PP_SOCIAL_SANDBOX
        if id != Auth.auth().currentUser?.uid {
            return try await db.collection("socialTestProfiles").document(id).getDocument(as: AppUser.self)
        }
        #endif
        return try await db.collection("users").document(id).getDocument(as: AppUser.self)
    }

    func updateUser(_ user: AppUser) async throws {
        try await requireLegacyWallet(userID: user.id)
        try db.collection("users").document(user.id).setData(from: user, merge: true)
    }

    func updateSoloStatistics(_ user: AppUser, mode: GameMode) async throws {
        let rank = user.rank(for: mode)
        var updates: [String: Any] = [
            "soloCompletions.\(mode.rawValue)": FieldValue.arrayUnion((user.soloCompletions[mode] ?? []).map(\.rawValue))
        ]
        if let best = rank.soloBest {
            updates["ranks.\(mode.rawValue).soloBest"] = try Firestore.Encoder().encode(best)
        }
        if let bests = rank.soloBestsByDifficulty {
            for (difficulty, best) in bests {
                updates["ranks.\(mode.rawValue).soloBestsByDifficulty.\(difficulty)"] = try Firestore.Encoder().encode(best)
            }
        }
        try await db.collection("users").document(user.id).updateData(updates)
    }

    func updateNotificationSettings(userID: String, settings: NotificationSettings) async throws -> AppUser {
        let encoded = try Firestore.Encoder().encode(settings)
        try await db.collection("users").document(userID).updateData([
            "notificationSettings": encoded
        ])
        return try await fetchUser(id: userID)
    }

    func updateEarnedShowcase(userID: String, slot: EarnedRewardSlot? = nil, rewardID: String? = nil) async throws -> AppUser {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            let ref = db.collection("users").document(userID)
            db.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    var user = try transaction.getDocument(ref).data(as: AppUser.self)
                    let previous = user.earnedShowcase
                    if let slot {
                        guard user.equipEarnedReward(rewardID, in: slot) else { throw FirestoreServiceError.earnedRewardLocked }
                    } else {
                        user.reconcileEarnedRewards()
                    }
                    var updates: [String: Any] = [:]
                    if previous != user.earnedShowcase {
                        updates["earnedShowcase"] = try Firestore.Encoder().encode(user.earnedShowcase)
                    }
                    if slot == .title { updates["cosmetics.equippedTitle"] = user.cosmetics.equippedTitle }
                    if !updates.isEmpty { transaction.updateData(updates, forDocument: ref) }
                    return user
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { result, error in
                if let error { continuation.resume(throwing: error) }
                else if let user = result as? AppUser { continuation.resume(returning: user) }
                else { continuation.resume(throwing: FirestoreServiceError.missingUpdatedUser) }
            })
        }
    }

    func recordDailyPlay(userID: String, activityID: String) async throws -> AppUser {
        try await requireLegacyWallet(userID: userID)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    let reward = user.playProgress.recordGamePlayed(activityID: activityID)
                    if reward > 0 {
                        user.coins += reward
                    }
                    user.reconcileEarnedRewards()

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

    func anonymizeAccountData(userID: String) async throws {
        try? await clearPendingSession(userID: userID)
        for mode in GameMode.allCases {
            for difficulty in Difficulty.allCases {
                try? await leaveMatchmakingQueue(userID: userID, mode: mode, difficulty: difficulty)
            }
        }

        try? await cancelFriendRequestDocs(inField: "fromID", userID: userID)
        try? await cancelFriendRequestDocs(inField: "toID", userID: userID)
        try? await cancelExhibitionInviteDocs(inField: "fromID", userID: userID)
        try? await cancelExhibitionInviteDocs(inField: "toID", userID: userID)
        try? await expirePartyInviteDocs(inField: "fromID", userID: userID)
        try? await expirePartyInviteDocs(inField: "toID", userID: userID)
        try? await deleteFriendshipDocs(userID: userID)

        let disabledNotifications = try Firestore.Encoder().encode(NotificationSettings(
            friendRequests: false,
            playNowInvites: false,
            playLaterInvites: false,
            partyInvites: false,
            rematches: false
        ))
        try await db.collection("users").document(userID).setData([
            "username": "Deleted Player",
            "email": "",
            "avatarURL": FieldValue.delete(),
            "fcmTokens": [],
            "fcmTokenUpdatedAt": FieldValue.delete(),
            "notificationSettings": disabledNotifications,
            "deletedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func updateCoins(userID: String, delta: Int) async throws {
        try await requireLegacyWallet(userID: userID)
        try await db.collection("users").document(userID).updateData([
            "coins": FieldValue.increment(Int64(delta))
        ])
    }

    func updateCosmetics(userID: String, cosmetics: OwnedCosmetics) async throws {
        let encoded = try Firestore.Encoder().encode(cosmetics)
        if try await usesServerWallet(userID: userID) {
            let selection = encoded.filter { $0.key != "purchasedIDs" }
            let _: SavedReply = try await EconomyCallable.call("equipWalletCosmetics", userID: userID, data: ["selection": selection])
            return
        }
        try await db.collection("users").document(userID).updateData(["cosmetics": encoded])
    }

    func purchaseCosmetic(userID: String, item: CosmeticItem) async throws -> AppUser {
        if try await usesServerWallet(userID: userID) {
            let _: WalletReply = try await EconomyCallable.call("purchaseWalletCosmetic", userID: userID,
                data: ["itemID": item.id, "expectedPrice": item.price])
            return try await fetchUser(id: userID)
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
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

    func openCosmeticPack(userID: String, kind: CosmeticPackKind) async throws -> CosmeticPackOpenResponse {
        try await requireLegacyWallet(userID: userID)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CosmeticPackOpenResponse, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    guard user.coins >= kind.price else { return fail(FirestoreServiceError.insufficientCoins) }

                    let packDrop = try self.pickCosmeticPackDrop(kind: kind)
                    let isDuplicate = user.cosmetics.purchasedIDs.contains(packDrop.item.id)
                    let duplicateRefund = isDuplicate ? packDrop.item.rarity.duplicateRefund : 0
                    user.coins -= kind.price
                    if isDuplicate {
                        user.coins += duplicateRefund
                    } else {
                        user.cosmetics.purchasedIDs.insert(packDrop.item.id)
                    }

                    let encodedUser = try Firestore.Encoder().encode(user)
                    transaction.setData(encodedUser, forDocument: userRef, merge: true)

                    return CosmeticPackOpenResponse(
                        user: user,
                        result: CosmeticPackOpenResult(
                            kind: kind,
                            item: packDrop.item,
                            coinsSpent: kind.price,
                            rolledRarity: packDrop.rolledRarity,
                            isDuplicate: isDuplicate,
                            duplicateRefund: duplicateRefund
                        )
                    )
                } catch {
                    return fail(error)
                }
            }, completion: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let response = result as? CosmeticPackOpenResponse {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: FirestoreServiceError.missingUpdatedUser)
                }
            })
        }
    }

    private func pickCosmeticPackDrop(kind: CosmeticPackKind) throws -> (item: CosmeticItem, rolledRarity: CosmeticRarity) {
        let eligibleItems = CosmeticCatalog.all.filter { item in
            kind.eligibleCategories.contains(item.category) && item.price > 0 && item.isLaunchCatalogVisible
        }
        guard !eligibleItems.isEmpty else { throw FirestoreServiceError.cosmeticPackComplete }

        let rolledRarity = rollPackRarity(kind)
        for rarity in packRarityFallbackOrder(from: rolledRarity) {
            let candidates = eligibleItems.filter { $0.rarity == rarity }
            if let item = candidates.randomElement() {
                return (item, rolledRarity)
            }
        }

        return (eligibleItems.randomElement()!, rolledRarity)
    }

    private func rollPackRarity(_ kind: CosmeticPackKind) -> CosmeticRarity {
        let roll = Int.random(in: 0..<100)
        var threshold = 0
        for odds in kind.odds {
            threshold += odds.percent
            if roll < threshold { return odds.rarity }
        }
        return .common
    }

    private func packRarityFallbackOrder(from rarity: CosmeticRarity) -> [CosmeticRarity] {
        switch rarity {
        case .free:
            return [.common, .rare, .epic, .legendary]
        case .common:
            return [.common, .rare, .epic, .legendary]
        case .rare:
            return [.rare, .epic, .legendary, .common]
        case .epic:
            return [.epic, .legendary, .rare, .common]
        case .legendary:
            return [.legendary, .epic, .rare, .common]
        }
    }


    // MARK: - Coin Economy

    func applyCoinPackPurchase(userID: String, productID: String, transactionID: String) async throws -> AppUser {
        guard let pack = CoinPackProduct.pack(for: productID) else { throw FirestoreServiceError.unknownCoinPack }
        return try await updateCoinWallet(userID: userID) { user in
            if user.coinWallet.processedTransactions[transactionID] == true { return }
            user.coinWallet.processedTransactions[transactionID] = true
            user.coins += pack.coins
        }
    }

    func claimDailyCoins(userID: String, dayKey: String = CoinWallet.todayKey()) async throws -> AppUser {
        if try await usesServerWallet(userID: userID) {
            let _: WalletReply = try await EconomyCallable.call("claimWalletDaily", userID: userID, data: [:])
            return try await fetchUser(id: userID)
        }
        return try await updateCoinWallet(userID: userID) { user in
            guard user.coinWallet.recordDailyClaim(dayKey: dayKey) else { throw FirestoreServiceError.dailyCoinsAlreadyClaimed }
            user.coins += CoinWallet.dailyClaimAmount
        }
    }

    func grantRewardedCoins(userID: String, dayKey: String = CoinWallet.todayKey()) async throws -> AppUser {
        try await updateCoinWallet(userID: userID) { user in
            guard user.coinWallet.recordRewardedAd(dayKey: dayKey) else { throw FirestoreServiceError.rewardedCoinLimitReached }
            user.coins += CoinWallet.rewardedAdAmount
        }
    }

    private func updateCoinWallet(userID: String, mutate: @escaping (inout AppUser) throws -> Void) async throws -> AppUser {
        try await requireLegacyWallet(userID: userID)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    try mutate(&user)
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
        try await requireLegacyWallet(userID: userID)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
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
        let user = try? await fetchUser(id: userID)
        let entry = LeaderboardEntry(
            id: userID, username: username, avatarURL: user?.avatarURL,
            rankTier: info.displayTier, rankPoints: info.points,
            wins: info.wins, bestTime: info.bestTime, mode: mode,
            equippedTitle: user?.displayedTitle,
            avatarStyle: user?.cosmetics.avatarStyle ?? .default
        )
        try db.collection("leaderboards")
            .document(mode.rawValue)
            .collection("entries")
            .document(userID)
            .setData(from: entry)
    }

    struct AppliedCasualOutcome {
        let user: AppUser
        let coinDelta: Int
        let didApplyRewards: Bool
        var walletReceipt: MatchWalletReply? = nil
    }

    func applyFinishedCasualSession(_ session: GameSession, for userID: String) async throws -> AppliedCasualOutcome {
        guard session.isCasual,
              session.status == .finished,
              session.players.contains(where: { $0.userID == userID }) else {
            let user = try await fetchUser(id: userID)
            return AppliedCasualOutcome(user: user, coinDelta: 0, didApplyRewards: false)
        }

        if try await usesServerWallet(userID: userID) {
            let receipt = try await settleMatchWallet(sessionID: session.id, userID: userID)
            let user = try await fetchUser(id: userID)
            return AppliedCasualOutcome(user: user, coinDelta: receipt.matchReward,
                                        didApplyRewards: receipt.didApplyRewards, walletReceipt: receipt)
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppliedCasualOutcome, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    if user.appliedCasualOutcomes[session.id] == true {
                        return AppliedCasualOutcome(user: user, coinDelta: 0, didApplyRewards: false)
                    }

                    let result = session.result(for: userID) ?? .draw
                    let requestedReward: Int
                    switch result {
                    case .win:
                        requestedReward = CoinWallet.casualWinReward
                    case .loss, .draw, .abandoned:
                        requestedReward = CoinWallet.casualOtherReward
                    }
                    let granted = user.coinWallet.recordCasualReward(requestedReward)
                    user.coins += granted
                    if let result = session.playerResults?[userID] {
                        var rankInfo = user.ranks[session.mode] ?? .empty
                        rankInfo.onlineBest = BestStat.updated(rankInfo.onlineBest, with: .from(match: result, mode: session.mode))
                        user.ranks[session.mode] = rankInfo
                    }
                    user.appliedCasualOutcomes[session.id] = true

                    let encodedUser = try Firestore.Encoder().encode(user)
                    transaction.setData(encodedUser, forDocument: userRef, merge: true)
                    return AppliedCasualOutcome(user: user, coinDelta: granted, didApplyRewards: true)
                } catch {
                    return fail(error)
                }
            }, completion: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let outcome = result as? AppliedCasualOutcome {
                    continuation.resume(returning: outcome)
                } else {
                    continuation.resume(throwing: FirestoreServiceError.missingUpdatedUser)
                }
            })
        }
    }

    func recordOnlineBestIfNeeded(session: GameSession, for userID: String) async throws -> AppUser {
        if try await usesServerWallet(userID: userID) {
            // Verified match settlement owns online records for migrated users.
            // Never write a stale whole user after a server reward has arrived.
            return try await fetchUser(id: userID)
        }
        guard session.status == .finished,
              let result = session.playerResults?[userID],
              session.players.contains(where: { $0.userID == userID }) else {
            return try await fetchUser(id: userID)
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let userRef = self.db.collection("users").document(userID)

                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var user = try transaction.getDocument(userRef).data(as: AppUser.self)
                    let savedSession = try transaction.getDocument(self.db.collection("sessions").document(session.id)).data(as: GameSession.self)
                    user.recordCompetitiveBadgeWin(from: savedSession)
                    var rankInfo = user.ranks[session.mode] ?? .empty
                    rankInfo.onlineBest = BestStat.updated(rankInfo.onlineBest, with: .from(match: result, mode: session.mode))
                    user.ranks[session.mode] = rankInfo

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

    // MARK: - Game Sessions

    /// Also catches Play Later wins resolved while this player was away. Never replays coin/rank payouts.
    func reconcileCompetitiveBadgeWins(for user: AppUser) async throws -> AppUser {
        guard user.earnedShowcase.friendlyWins < 100 || user.earnedShowcase.underdogWins < 100 else { return user }
        let snapshot = try await db.collection("sessions").whereField("winnerID", isEqualTo: user.id).getDocuments()
        var candidate = user
        let ids = snapshot.documents.compactMap { document -> String? in
            guard let session = try? document.data(as: GameSession.self),
                  candidate.recordCompetitiveBadgeWin(from: session) else { return nil }
            return document.documentID
        }
        guard !ids.isEmpty else { return user }
        var updated = user
        // Keep each transaction small; every outcome and latest user are re-read before writing.
        for offset in stride(from: 0, to: ids.count, by: 20) {
            let batch = Array(ids[offset..<min(offset + 20, ids.count)])
            updated = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppUser, Error>) in
                db.runTransaction({ transaction, errorPointer -> Any? in
                    do {
                        let ref = self.db.collection("users").document(user.id)
                        var latest = try transaction.getDocument(ref).data(as: AppUser.self)
                        for sessionID in batch {
                            let session = try transaction.getDocument(self.db.collection("sessions").document(sessionID)).data(as: GameSession.self)
                            latest.recordCompetitiveBadgeWin(from: session)
                        }
                        transaction.updateData(["earnedShowcase": try Firestore.Encoder().encode(latest.earnedShowcase)], forDocument: ref)
                        return latest
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }
                }, completion: { result, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let latest = result as? AppUser { continuation.resume(returning: latest) }
                    else { continuation.resume(throwing: FirestoreServiceError.missingUpdatedUser) }
                })
            }
        }
        return updated
    }

    func createSession(_ session: GameSession) async throws -> String {
        let ref = db.collection("sessions").document(session.id)
        try ref.setData(from: session)
        return session.id
    }

    func fetchSession(id: String) async throws -> GameSession {
        try await db.collection(id.hasPrefix("v1_") ? "serverMatches" : "sessions").document(id).getDocument(as: GameSession.self)
    }

    func fetchUnappliedFinishedSessions(for user: AppUser, limit: Int = 10) async throws -> [GameSession] {
        if try await usesServerWallet(userID: user.id) {
            return Array(try await fetchFinishedOnlineSessions(for: user.id)
                .filter { session in
                    session.usesServerAuthority && (session.isRanked
                        ? user.appliedRankedOutcomes[session.id] != true
                        : user.appliedCasualOutcomes[session.id] != true)
                }
                .prefix(limit))
        }
        let snapshot = try await db.collection("sessions")
            .whereField("playerIDs", arrayContains: user.id)
            .whereField("status", isEqualTo: SessionStatus.finished.rawValue)
            .limit(to: limit)
            .getDocuments()

        return try snapshot.documents
            .map { try $0.data(as: GameSession.self) }
            .filter { user.appliedRankedOutcomes[$0.id] != true }
    }

    func fetchRecentFinishedSessions(for userID: String, limit: Int = 20) async throws -> [GameSession] {
        return try await fetchFinishedOnlineSessions(for: userID, fetchLimit: nil)
            .prefix(limit)
            .map { $0 }
    }

    func fetchFinishedOnlineSessions(for userID: String) async throws -> [GameSession] {
        try await fetchFinishedOnlineSessions(for: userID, fetchLimit: nil)
    }

    private func fetchFinishedOnlineSessions(for userID: String, fetchLimit: Int?) async throws -> [GameSession] {
        var query: Query = db.collection("sessions")
            .whereField("playerIDs", arrayContains: userID)
        if let fetchLimit {
            query = query.limit(to: fetchLimit)
        }
        let snapshot = try await query.getDocuments()
        var documents = snapshot.documents
        if try await usesServerWallet(userID: userID) {
            let official = try await db.collection("serverMatches").whereField("playerIDs", arrayContains: userID).getDocuments()
            documents += official.documents
        }

        return documents
            .compactMap { document -> GameSession? in
                do {
                    return try document.data(as: GameSession.self)
                } catch {
                    #if DEBUG
                    print("Skipping malformed online session \(document.documentID): \(error)")
                    #endif
                    return nil
                }
            }
            .filter { session in
                session.status == .finished &&
                (session.matchKind == .ranked || session.matchKind == .casual || session.isExhibition)
            }
            .sorted { lhs, rhs in
                recentSortDate(lhs) > recentSortDate(rhs)
            }
    }

    private func recentSortDate(_ session: GameSession) -> Date {
        session.finishedAt ?? session.startedAt ?? session.createdAt
    }

    func listenForSession(id: String, onChange: @escaping (GameSession) -> Void) -> ListenerRegistration {
        db.collection(id.hasPrefix("v1_") ? "serverMatches" : "sessions").document(id)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot, let session = try? snapshot.data(as: GameSession.self) else { return }
                onChange(session)
            }
    }

    func listenForActiveSession(
        userID: String,
        mode: GameMode,
        difficulty: Difficulty,
        matchKind: SessionKind = .ranked,
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
                    $0.matchKind == matchKind &&
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
            if oldSession.isRanked {
                guard latestUser.rankedAccess.canStartRanked(mode: oldSession.mode) else { throw FirestoreServiceError.rankedAccessUnavailable }
            }
            let rank = latestUser.rank(for: oldSession.mode)
            return MatchPlayer(
                userID: latestUser.id,
                username: latestUser.username,
                wager: 0,
                finishTime: nil,
                rankTier: rank.displayTier,
                rankPoints: rank.points,
                avatarStyle: latestUser.cosmetics.avatarStyle
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
            puzzleData: MultiplayerPuzzleDataFactory.onlinePayload(mode: oldSession.mode, difficulty: oldSession.difficulty, seed: seed, context: "rematch"),
            createdAt: Date(),
            matchKind: oldSession.matchKind
        )
        session.playerIDs = refreshedPlayers.map(\.userID)
        try db.collection("sessions").document(sessionID).setData(from: session)
        return session
    }

    // MARK: - Matchmaking


    func createBronzeBotSession(user: AppUser, mode: GameMode, difficulty: Difficulty, wager: Int, searchID: String) async throws -> String? {
        guard BotMatchService.canOfferBot(to: user, mode: mode) else { return nil }
        let tier = user.rank(for: mode).displayTier
        guard tier == .bronze else { return nil }

        let queueRef = queueCollection(mode: mode, difficulty: difficulty)
        let queueDoc = try await queueRef.document(user.id).getDocument()
        guard let queue = queueDoc.data(),
              (queue["searchID"] as? String) == searchID,
              (queue["wager"] as? Int) == wager,
              (queue["rankTier"] as? Int) == tier.rawValue else {
            return nil
        }

        let snapshot = try await queueRef.getDocuments()
        let realOpponents = snapshot.documents.filter {
            $0.documentID != user.id &&
            !($0.documentID.hasPrefix(BotMatchService.botIDPrefix)) &&
            ($0.data()["rankTier"] as? Int ?? -1) == tier.rawValue
        }
        guard realOpponents.isEmpty else { return nil }

        let seed = Int.random(in: 0..<Int.max)
        let bot = BotMatchService.makeBotPlayer(mode: mode, wager: 0, searchID: searchID, seed: seed)
        let sessionID = makeSessionID(
            userID: user.id,
            opponentID: bot.userID,
            mode: mode,
            difficulty: difficulty,
            creatorSearchID: searchID
        )

        let existing = try await db.collection("sessions").document(sessionID).getDocument()
        if existing.exists {
            let status = existing.data()?["status"] as? String ?? ""
            if status == SessionStatus.inProgress.rawValue || status == SessionStatus.waiting.rawValue {
                return sessionID
            }
            return nil
        }

        var session = GameSession(
            id: sessionID,
            mode: mode,
            difficulty: difficulty,
            status: .inProgress,
            players: [
                MatchPlayer(userID: user.id, username: user.username, wager: 0, rankTier: tier, rankPoints: user.rank(for: mode).points, avatarStyle: user.cosmetics.avatarStyle),
                bot
            ],
            seed: seed,
            puzzleData: MultiplayerPuzzleDataFactory.onlinePayload(mode: mode, difficulty: difficulty, seed: seed, context: "online session"),
            createdAt: Date()
        )
        session.playerIDs = [user.id, bot.userID]

        try db.collection("sessions").document(sessionID).setData(from: session)
        try? await db.collection("users").document(user.id).updateData([
            "pendingSessionID": sessionID,
            "pendingSearchID": searchID
        ])
        try? await queueRef.document(user.id).delete()
        return sessionID
    }

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
            "avatarStyle": [
                "head": user.cosmetics.equippedAvatarHead,
                "face": user.cosmetics.equippedAvatarFace,
                "outfit": user.cosmetics.equippedAvatarOutfit,
                "aura": user.cosmetics.equippedAvatarAura,
                "pose": user.cosmetics.equippedAvatarPose,
                "bodyHex": user.cosmetics.customAvatarBodyHex
            ],
            "searchID":   searchID
        ])

        // 2. Look for anyone else in the queue with the same rank tier
        let snapshot = try await queueRef.getDocuments()
        let myTier = tier.rawValue
        let others = snapshot.documents.filter {
            $0.documentID != user.id &&
            ($0.data()["rankTier"] as? Int ?? -1) == myTier
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

    func joinAndPairCasual(user: AppUser, mode: GameMode, difficulty: Difficulty, searchID: String) async throws {
        let queueRef = queueCollection(mode: mode, difficulty: difficulty)

        try await queueRef.document(user.id).setData([
            "userID": user.id,
            "username": user.username,
            "queueKind": SessionKind.casual.rawValue,
            "rankPoints": user.rank(for: mode).points,
            "avatarStyle": [
                "head": user.cosmetics.equippedAvatarHead,
                "face": user.cosmetics.equippedAvatarFace,
                "outfit": user.cosmetics.equippedAvatarOutfit,
                "aura": user.cosmetics.equippedAvatarAura,
                "pose": user.cosmetics.equippedAvatarPose,
                "bodyHex": user.cosmetics.customAvatarBodyHex
            ],
            "searchID": searchID
        ])

        let snapshot = try await queueRef.getDocuments()
        let others = snapshot.documents.filter {
            $0.documentID != user.id &&
            ($0.data()["queueKind"] as? String) == SessionKind.casual.rawValue
        }
        guard let opponentDoc = others.first else { return }
        guard user.id > opponentDoc.documentID else { return }

        _ = try await createAndNotifyCasual(
            hostUser: user,
            searchID: searchID,
            opponentDoc: opponentDoc,
            mode: mode,
            difficulty: difficulty,
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
                ($0.data()["rankTier"] as? Int ?? -1) == myTier
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

    func listenForCasualQueueMatch(
        user: AppUser, mode: GameMode, difficulty: Difficulty, searchID: String,
        onPaired: @escaping (String) -> Void
    ) -> ListenerRegistration {
        let queueRef = queueCollection(mode: mode, difficulty: difficulty)

        return queueRef.addSnapshotListener { [weak self] snapshot, error in
            if let error { print("Casual queue listener error: \(error.localizedDescription)") }
            guard let self, let snapshot else { return }
            let others = snapshot.documents.filter {
                $0.documentID != user.id &&
                ($0.data()["queueKind"] as? String) == SessionKind.casual.rawValue
            }
            guard let opponentDoc = others.first else { return }

            let opponentID = opponentDoc.documentID
            Task {
                do {
                    if user.id > opponentID {
                        if let sessionID = try await self.createAndNotifyCasual(
                            hostUser: user,
                            searchID: searchID,
                            opponentDoc: opponentDoc,
                            mode: mode,
                            difficulty: difficulty,
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


    private func avatarStyle(from value: Any?) -> AvatarStyle {
        guard let dict = value as? [String: Any] else { return .default }
        return AvatarStyle(
            head: dict["head"] as? String ?? AvatarStyle.default.head,
            face: dict["face"] as? String ?? AvatarStyle.default.face,
            outfit: dict["outfit"] as? String ?? AvatarStyle.default.outfit,
            aura: dict["aura"] as? String ?? AvatarStyle.default.aura,
            pose: dict["pose"] as? String ?? AvatarStyle.default.pose,
            bodyHex: dict["bodyHex"] as? String ?? AvatarStyle.default.bodyHex
        )
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
              (opponentQueue["rankTier"] as? Int) == tier.rawValue,
              opponentQueue["searchID"] is String else {
            return nil
        }

        let opponentUsername = opponentQueue["username"] as? String ?? "Opponent"
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
        let opponentAvatarStyle = avatarStyle(from: opponentQueue["avatarStyle"])

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
                MatchPlayer(userID: hostUser.id, username: hostUser.username, wager: 0, rankTier: tier, rankPoints: hostUser.rank(for: mode).points, avatarStyle: hostUser.cosmetics.avatarStyle),
                MatchPlayer(userID: opponentID,  username: opponentUsername,  wager: 0, rankTier: opponentTier, rankPoints: opponentRankPoints, avatarStyle: opponentAvatarStyle)
            ],
            seed: seed,
            puzzleData: MultiplayerPuzzleDataFactory.onlinePayload(mode: mode, difficulty: difficulty, seed: seed, context: "online session"),
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

    private func createAndNotifyCasual(
        hostUser: AppUser,
        searchID: String,
        opponentDoc: QueryDocumentSnapshot,
        mode: GameMode,
        difficulty: Difficulty,
        queueRef: CollectionReference
    ) async throws -> String? {
        let opponentID = opponentDoc.documentID

        let hostQueueDoc = try await queueRef.document(hostUser.id).getDocument()
        let opponentQueueDoc = try await queueRef.document(opponentID).getDocument()
        guard let hostQueue = hostQueueDoc.data(),
              let opponentQueue = opponentQueueDoc.data(),
              (hostQueue["searchID"] as? String) == searchID,
              (hostQueue["queueKind"] as? String) == SessionKind.casual.rawValue,
              (opponentQueue["queueKind"] as? String) == SessionKind.casual.rawValue,
              opponentQueue["searchID"] is String else {
            return nil
        }

        let sessionID = makeSessionID(
            userID: hostUser.id,
            opponentID: opponentID,
            mode: mode,
            difficulty: difficulty,
            creatorSearchID: searchID
        )

        let existing = try await db.collection("sessions").document(sessionID).getDocument()
        if existing.exists {
            let status = existing.data()?["status"] as? String ?? ""
            if status == SessionStatus.inProgress.rawValue || status == SessionStatus.waiting.rawValue {
                return sessionID
            }
            return nil
        }

        let opponentUsername = opponentQueue["username"] as? String ?? "Opponent"
        let opponentRankPoints = opponentQueue["rankPoints"] as? Int ?? 0
        let opponentAvatarStyle = avatarStyle(from: opponentQueue["avatarStyle"])
        let seed = Int.random(in: 0..<Int.max)
        var session = GameSession(
            id: sessionID,
            mode: mode,
            difficulty: difficulty,
            status: .inProgress,
            players: [
                MatchPlayer(userID: hostUser.id, username: hostUser.username, wager: 0, rankTier: hostUser.rank(for: mode).displayTier, rankPoints: hostUser.rank(for: mode).points, avatarStyle: hostUser.cosmetics.avatarStyle),
                MatchPlayer(userID: opponentID, username: opponentUsername, wager: 0, rankTier: RankTier.tier(for: opponentRankPoints), rankPoints: opponentRankPoints, avatarStyle: opponentAvatarStyle)
            ],
            seed: seed,
            puzzleData: MultiplayerPuzzleDataFactory.onlinePayload(mode: mode, difficulty: difficulty, seed: seed, context: "online session"),
            createdAt: Date(),
            matchKind: .casual
        )
        session.playerIDs = [hostUser.id, opponentID]

        try db.collection("sessions").document(sessionID).setData(from: session)
        try? await db.collection("users").document(hostUser.id).updateData([
            "pendingSessionID": sessionID,
            "pendingSearchID": searchID
        ])
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
        let friendshipRef = db.collection("friendships").document(requestID)

        let friendshipSnapshot = try await friendshipRef.getDocument()
        if friendshipSnapshot.exists {
            throw FirestoreServiceError.friendshipAlreadyExists
        }

        if let existing = try? await requestRef.getDocument(as: FriendRequest.self) {
            switch existing.status {
            case .pending:
                throw FirestoreServiceError.friendRequestAlreadyPending
            case .accepted:
                // Accepted request records can outlive the friendship after unfriend.
                // If the friendship document is gone, reuse this request slot.
                break
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

    func removeFriend(currentUserID: String, friendID: String) async throws {
        guard currentUserID != friendID else { throw FirestoreServiceError.invalidFriendAction }
        let friendshipRef = db.collection("friendships").document(friendshipID(currentUserID, friendID))
        let friendship = try await friendshipRef.getDocument(as: Friendship.self)
        guard friendship.userIDs.contains(currentUserID),
              friendship.userIDs.contains(friendID) else {
            throw FirestoreServiceError.notFriends
        }

        try await friendshipRef.delete()
        try await cancelFriendRequestRecord(between: currentUserID, and: friendID)
        try await cancelPendingExhibitionInvites(between: currentUserID, and: friendID)
    }

    private func cancelFriendRequestRecord(between firstUserID: String, and secondUserID: String) async throws {
        let requestRef = db.collection("friendRequests").document(friendshipID(firstUserID, secondUserID))
        let snapshot = try await requestRef.getDocument()
        guard snapshot.exists else { return }
        try await requestRef.setData([
            "status": FriendRequestStatus.canceled.rawValue
        ], merge: true)
    }

    private func cancelPendingExhibitionInvites(between firstUserID: String, and secondUserID: String) async throws {
        let forward = try await db.collection("exhibitionInvites")
            .whereField("fromID", isEqualTo: firstUserID)
            .whereField("toID", isEqualTo: secondUserID)
            .getDocuments()
        let reverse = try await db.collection("exhibitionInvites")
            .whereField("fromID", isEqualTo: secondUserID)
            .whereField("toID", isEqualTo: firstUserID)
            .getDocuments()

        let activeStatuses = [
            ExhibitionInviteStatus.pending.rawValue,
            ExhibitionInviteStatus.accepted.rawValue
        ]
        for document in forward.documents + reverse.documents {
            guard let status = document.data()["status"] as? String,
                  activeStatuses.contains(status) else { continue }
            if document.documentID.hasPrefix("sv1_") {
                try await officialAction("forfeit", userID: firstUserID, sessionID: document.documentID)
                continue
            }
            try await document.reference.setData([
                "status": ExhibitionInviteStatus.canceled.rawValue
            ], merge: true)
        }
    }

    private func cancelFriendRequestDocs(inField field: String, userID: String) async throws {
        let snapshot = try await db.collection("friendRequests")
            .whereField(field, isEqualTo: userID)
            .getDocuments()
        for document in snapshot.documents {
            try? await document.reference.setData([
                "status": FriendRequestStatus.canceled.rawValue
            ], merge: true)
        }
    }

    private func cancelExhibitionInviteDocs(inField field: String, userID: String) async throws {
        let snapshot = try await db.collection("exhibitionInvites")
            .whereField(field, isEqualTo: userID)
            .getDocuments()
        for document in snapshot.documents {
            try? await document.reference.setData([
                "status": ExhibitionInviteStatus.canceled.rawValue
            ], merge: true)
        }
    }

    private func expirePartyInviteDocs(inField field: String, userID: String) async throws {
        let snapshot = try await db.collection("partyInvites")
            .whereField(field, isEqualTo: userID)
            .getDocuments()
        for document in snapshot.documents {
            try? await document.reference.setData([
                "expiresAt": Date()
            ], merge: true)
        }
    }

    private func deleteFriendshipDocs(userID: String) async throws {
        let snapshot = try await db.collection("friendships")
            .whereField("userIDs", arrayContains: userID)
            .getDocuments()
        for document in snapshot.documents {
            try? await document.reference.delete()
        }
    }

    func createExhibitionInvite(from user: AppUser, to friend: FriendSummary, mode: GameMode, difficulty: Difficulty, inviteType: ExhibitionInviteType = .playNow) async throws -> ExhibitionInvite {
        if try await usesServerWallet(userID: user.id) {
            let id = try await createVerifiedSocial(userID: user.id, kind: inviteType == .playLater ? "asyncExhibition" : "exhibition",
                rounds: [PartyStageRoundConfiguration(index: 0, mode: mode, difficulty: difficulty)], friendID: friend.userID)
            return try await db.collection("exhibitionInvites").document(id).getDocument(as: ExhibitionInvite.self)
        }
        let friendshipDoc = try await db.collection("friendships").document(friendshipID(user.id, friend.userID)).getDocument()
        guard friendshipDoc.exists else { throw FirestoreServiceError.notFriends }
        let now = Date()
        let seed = Int.random(in: 0..<Int.max)
        let inviteID = UUID().uuidString
        let sessionID = inviteType == .playLater ? "async_exhibition_\(inviteID)_\(UUID().uuidString.prefix(8))" : nil
        let invite = ExhibitionInvite(
            id: inviteID,
            fromID: user.id,
            fromUsername: user.username,
            toID: friend.userID,
            toUsername: friend.username,
            mode: mode,
            difficulty: difficulty,
            status: .pending,
            createdAt: now,
            expiresAt: now.addingTimeInterval(inviteType == .playLater ? 172_800 : 120),
            sessionID: sessionID,
            inviteType: inviteType
        )

        if inviteType == .playLater, let sessionID {
            let friendUser = try await fetchUser(id: friend.userID)
            var session = GameSession(
                id: sessionID,
                mode: mode,
                difficulty: difficulty,
                status: .inProgress,
                players: [
                    MatchPlayer(userID: user.id, username: user.username, wager: 0, rankTier: user.rank(for: mode).displayTier, rankPoints: user.rank(for: mode).points, avatarStyle: user.cosmetics.avatarStyle),
                    MatchPlayer(userID: friendUser.id, username: friendUser.username, wager: 0, rankTier: friendUser.rank(for: mode).displayTier, rankPoints: friendUser.rank(for: mode).points, avatarStyle: friendUser.cosmetics.avatarStyle)
                ],
                seed: seed,
                puzzleData: MultiplayerPuzzleDataFactory.onlinePayload(mode: mode, difficulty: difficulty, seed: seed, context: "online session"),
                createdAt: now,
                matchKind: .asyncExhibition
            )
            session.playerIDs = [user.id, friendUser.id]
            try db.collection("sessions").document(sessionID).setData(from: session)
        }

        try db.collection("exhibitionInvites").document(invite.id).setData(from: invite)
        return invite
    }

    func acceptExhibitionInvite(_ invite: ExhibitionInvite, currentUser: AppUser) async throws -> GameSession {
        if invite.id.hasPrefix("sv1_") {
            try await officialAction("accept", userID: currentUser.id, sessionID: invite.id)
            return try await fetchSession(id: invite.id)
        }
        try await requireLegacyWallet(userID: currentUser.id)
        guard invite.toID == currentUser.id else { throw FirestoreServiceError.invalidFriendAction }
        guard !invite.isExpired else {
            try? await expireExhibitionInvite(invite.id)
            throw FirestoreServiceError.exhibitionInviteExpired
        }

        if invite.isPlayLater, let existingSessionID = invite.sessionID {
            let session = try await fetchSession(id: existingSessionID)
            var updatedInvite = invite
            updatedInvite.status = .accepted
            try db.collection("exhibitionInvites").document(invite.id).setData(from: updatedInvite, merge: true)
            return session
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
                MatchPlayer(userID: invite.fromID, username: fromUser.username, wager: 0, rankTier: fromUser.rank(for: invite.mode).displayTier, rankPoints: fromUser.rank(for: invite.mode).points, avatarStyle: fromUser.cosmetics.avatarStyle),
                MatchPlayer(userID: currentUser.id, username: currentUser.username, wager: 0, rankTier: currentUser.rank(for: invite.mode).displayTier, rankPoints: currentUser.rank(for: invite.mode).points, avatarStyle: currentUser.cosmetics.avatarStyle)
            ],
            seed: seed,
            puzzleData: MultiplayerPuzzleDataFactory.onlinePayload(mode: invite.mode, difficulty: invite.difficulty, seed: seed, context: "exhibition invite"),
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
        if invite.id.hasPrefix("sv1_") {
            try await officialAction("decline", userID: currentUserID, sessionID: invite.id)
            return
        }
        guard invite.toID == currentUserID else { throw FirestoreServiceError.invalidFriendAction }
        var updated = invite
        updated.status = .declined
        try db.collection("exhibitionInvites").document(invite.id).setData(from: updated, merge: true)
    }

    func completeExhibitionInvite(_ inviteID: String) async throws {
        // Verified room settlement owns the invite's final status.
        guard !inviteID.hasPrefix("sv1_") else { return }
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
                    .filter { invite in
                        guard !invite.isExpired else { return false }
                        if invite.isPlayLater {
                            return invite.status == .pending || invite.status == .accepted
                        }
                        return invite.status == .pending
                    } ?? []
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
                    guard !invite.isExpired else { return false }
                    if invite.isPlayLater {
                        return (invite.status == .pending || invite.status == .accepted) && invite.sessionID != nil
                    }
                    if invite.status == ExhibitionInviteStatus.pending {
                        return true
                    }
                    if invite.status == ExhibitionInviteStatus.accepted {
                        return invite.sessionID != nil
                    }
                    return false
                }
                onChange(activeInvites)
            }
    }

    func saveAsyncExhibitionResult(sessionID: String, result: MatchPlayerResult) async throws {
        let encoded = try Firestore.Encoder().encode(result)
        try await db.collection("sessions")
            .document(sessionID)
            .setData(["playerResults.\(result.userID)": encoded], merge: true)
    }

    // MARK: - Party Rooms

    func createPartyRoom(host: AppUser, mode: GameMode, difficulty: Difficulty) async throws -> PartyRoom {
        if try await usesServerWallet(userID: host.id) {
            let code = try await createVerifiedSocial(userID: host.id, kind: "party",
                rounds: [PartyStageRoundConfiguration(index: 0, mode: mode, difficulty: difficulty)])
            return try await db.collection("partyRooms").document(code).getDocument(as: PartyRoom.self)
        }
        let now = Date()
        let seed = Int.random(in: 0..<Int.max)
        let player = PartyPlayer(
            userID: host.id,
            username: host.username,
            avatarStyle: host.cosmetics.avatarStyle,
            joinedAt: now,
            isHost: true,
            result: nil,
            abandoned: false
        )

        for _ in 0..<12 {
            let code = makePartyCode()
            let ref = db.collection("partyRooms").document(code)
            let existing = try await ref.getDocument()
            guard !existing.exists else { continue }

            let room = PartyRoom(
                code: code,
                hostID: host.id,
                mode: mode,
                difficulty: difficulty,
                status: .lobby,
                players: [player],
                playerIDs: [host.id],
                seed: seed,
                puzzleData: MultiplayerPuzzleDataFactory.onlinePayload(mode: mode, difficulty: difficulty, seed: seed, context: "online session"),
                createdAt: now,
                expiresAt: now.addingTimeInterval(1_800),
                startedAt: nil,
                finishedAt: nil,
                winnerID: nil,
                winnerReason: nil,
                readyPlayerIDs: [],
                finishWindowStartedAt: nil,
                finishWindowDeadline: nil,
                finishWindowStarterID: nil,
                stageRounds: nil,
                currentStageRoundIndex: nil,
                stageScores: nil,
                isStageRoom: nil,
                maxPlayers: 8
            )
            try ref.setData(from: room)
            return room
        }

        throw FirestoreServiceError.invalidFriendAction
    }

    func createPartyStageRoom(host: AppUser, rounds configurations: [PartyStageRoundConfiguration]) async throws -> PartyRoom {
        if try await usesServerWallet(userID: host.id) {
            let code = try await createVerifiedSocial(userID: host.id, kind: "party", rounds: configurations)
            return try await db.collection("partyRooms").document(code).getDocument(as: PartyRoom.self)
        }
        let now = Date()
        let sanitized = Array(configurations.prefix(3))
        guard sanitized.count == 3, Set(sanitized.map(\.mode)).count == 3 else {
            throw FirestoreServiceError.invalidFriendAction
        }

        let stageRounds = sanitized.enumerated().map { offset, configuration in
            let seed = Int.random(in: 0..<Int.max)
            return PartyStageRound(
                index: offset,
                mode: configuration.mode,
                difficulty: configuration.difficulty,
                seed: seed,
                puzzleData: MultiplayerPuzzleDataFactory.onlinePayload(
                    mode: configuration.mode,
                    difficulty: configuration.difficulty,
                    seed: seed,
                    context: "party playlist round \(offset + 1)"
                ),
                status: .waiting,
                startedAt: nil,
                finishedAt: nil,
                finishWindowStartedAt: nil,
                finishWindowDeadline: nil,
                finishWindowStarterID: nil,
                results: [:],
                scoreRows: nil
            )
        }

        let player = PartyPlayer(
            userID: host.id,
            username: host.username,
            avatarStyle: host.cosmetics.avatarStyle,
            joinedAt: now,
            isHost: true,
            result: nil,
            abandoned: false
        )

        for _ in 0..<12 {
            let code = makePartyCode()
            let ref = db.collection("partyRooms").document(code)
            let existing = try await ref.getDocument()
            guard !existing.exists else { continue }

            let firstRound = stageRounds[0]
            let room = PartyRoom(
                code: code,
                hostID: host.id,
                mode: firstRound.mode,
                difficulty: firstRound.difficulty,
                status: .lobby,
                players: [player],
                playerIDs: [host.id],
                seed: firstRound.seed,
                puzzleData: firstRound.puzzleData,
                createdAt: now,
                expiresAt: now.addingTimeInterval(1_800),
                startedAt: nil,
                finishedAt: nil,
                winnerID: nil,
                winnerReason: nil,
                readyPlayerIDs: [],
                finishWindowStartedAt: nil,
                finishWindowDeadline: nil,
                finishWindowStarterID: nil,
                stageRounds: stageRounds,
                currentStageRoundIndex: nil,
                stageScores: [host.id: 0],
                isStageRoom: true,
                maxPlayers: 8
            )
            try ref.setData(from: room)
            return room
        }

        throw FirestoreServiceError.invalidFriendAction
    }

    func createPartyInvite(room: PartyRoom, from user: AppUser, to friend: FriendSummary) async throws {
        guard room.status == .lobby,
              room.containsPlayer(user.id),
              Date() < room.expiresAt else {
            throw FirestoreServiceError.partyRoomAlreadyStarted
        }
        guard friend.userID != user.id else { throw FirestoreServiceError.invalidFriendAction }

        let friendshipDoc = try await db.collection("friendships")
            .document(friendshipID(user.id, friend.userID))
            .getDocument()
        guard friendshipDoc.exists else { throw FirestoreServiceError.notFriends }

        let now = Date()
        let invite = PartyInvite(
            id: UUID().uuidString,
            roomCode: room.code,
            fromID: user.id,
            fromUsername: user.username,
            toID: friend.userID,
            toUsername: friend.username,
            mode: room.mode,
            difficulty: room.difficulty,
            createdAt: now,
            expiresAt: room.expiresAt
        )
        try db.collection("partyInvites").document(invite.id).setData(from: invite)
    }

    func joinPartyRoom(code rawCode: String, user: AppUser) async throws -> PartyRoom {
        if normalizedPartyCode(rawCode).hasPrefix("S1") {
            return try await verifiedPartyAction("join", code: rawCode, userID: user.id)
        }
        try await requireLegacyWallet(userID: user.id)
        let code = normalizedPartyCode(rawCode)
        guard !code.isEmpty else { throw FirestoreServiceError.partyRoomNotFound }
        let roomRef = db.collection("partyRooms").document(code)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PartyRoom, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var room = try transaction.getDocument(roomRef).data(as: PartyRoom.self)
                    guard room.status == .lobby else { return fail(FirestoreServiceError.partyRoomAlreadyStarted) }
                    guard Date() < room.expiresAt else {
                        room.status = .expired
                        let expiredData = try Firestore.Encoder().encode(room)
                        transaction.setData(expiredData, forDocument: roomRef, merge: true)
                        return fail(FirestoreServiceError.partyRoomExpired)
                    }

                    if room.containsPlayer(user.id) {
                        return room
                    }

                    guard room.players.count < room.maxPlayers else { return fail(FirestoreServiceError.partyRoomFull) }

                    let player = PartyPlayer(
                        userID: user.id,
                        username: user.username,
                        avatarStyle: user.cosmetics.avatarStyle,
                        joinedAt: Date(),
                        isHost: false,
                        result: nil,
                        abandoned: false
                    )
                    room.players.append(player)
                    room.playerIDs = room.players.map(\.userID)
                    room.readyPlayerIDs = (room.readyPlayerIDs ?? []).filter { $0 != user.id }
                    if room.isStageRoom == true {
                        var scores = room.stageScores ?? [:]
                        scores[user.id] = scores[user.id] ?? 0
                        room.stageScores = scores
                    }
                    let encoded = try Firestore.Encoder().encode(room)
                    transaction.setData(encoded, forDocument: roomRef, merge: true)
                    return room
                } catch {
                    return fail(error is DecodingError ? FirestoreServiceError.partyRoomNotFound : error)
                }
            }, completion: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let room = result as? PartyRoom {
                    continuation.resume(returning: room)
                } else {
                    continuation.resume(throwing: FirestoreServiceError.partyRoomNotFound)
                }
            })
        }
    }

    func startPartyRoom(code: String, hostID: String) async throws -> PartyRoom {
        if code.hasPrefix("S1") { return try await verifiedPartyAction("start", code: code, userID: hostID) }
        let roomRef = db.collection("partyRooms").document(normalizedPartyCode(code))
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PartyRoom, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var room = try transaction.getDocument(roomRef).data(as: PartyRoom.self)
                    guard room.hostID == hostID else { return fail(FirestoreServiceError.notPartyHost) }
                    guard room.status == .lobby else { return fail(FirestoreServiceError.partyRoomAlreadyStarted) }
                    guard Date() < room.expiresAt else { return fail(FirestoreServiceError.partyRoomExpired) }
                    guard room.players.count >= 2 else { return fail(FirestoreServiceError.invalidFriendAction) }
                    guard room.allPlayersReady else { return fail(FirestoreServiceError.invalidFriendAction) }
                    room.status = .inProgress
                    room.startedAt = Date()
                    if room.isStageRoom == true {
                        room = self.startFirstPartyStageRound(room, at: room.startedAt ?? Date())
                    }
                    let encoded = try Firestore.Encoder().encode(room)
                    transaction.setData(encoded, forDocument: roomRef, merge: true)
                    return room
                } catch {
                    return fail(error)
                }
            }, completion: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let room = result as? PartyRoom {
                    continuation.resume(returning: room)
                } else {
                    continuation.resume(throwing: FirestoreServiceError.partyRoomNotFound)
                }
            })
        }
    }

    func setPartyReady(code: String, userID: String, isReady: Bool) async throws -> PartyRoom {
        if code.hasPrefix("S1") { return try await verifiedPartyAction("ready", code: code, userID: userID, isReady: isReady) }
        return try await mutatePartyRoom(code: code) { room in
            guard room.status == .lobby, room.containsPlayer(userID) else {
                throw FirestoreServiceError.invalidFriendAction
            }
            var readyIDs = Set(room.readyPlayerIDs ?? [])
            if isReady {
                readyIDs.insert(userID)
            } else {
                readyIDs.remove(userID)
            }
            room.readyPlayerIDs = Array(readyIDs)
        }
    }

    func submitPartyResult(code: String, userID: String, result: MatchPlayerResult) async throws -> PartyRoom {
        if code.hasPrefix("S1") {
            guard let evidence = result.rewardEvidenceJSON else { throw FirestoreServiceError.invalidFriendAction }
            return try await verifiedPartyAction("submit", code: code, userID: userID, roundIndex: 0, evidenceJSON: evidence)
        }
        return try await mutatePartyRoom(code: code) { room in
            guard let index = room.players.firstIndex(where: { $0.userID == userID }) else {
                throw FirestoreServiceError.invalidFriendAction
            }
            room.players[index].result = result
            room.players[index].abandoned = false
            room = self.startPartyFinishWindowIfNeeded(room, starterID: userID, result: result)
            room = self.finishPartyRoomIfReady(room)
        }
    }

    func submitPartyStageResult(code: String, userID: String, result: MatchPlayerResult) async throws -> PartyRoom {
        // Verified playlists submit with an explicit captured round index in the view model.
        guard !code.hasPrefix("S1") else { throw FirestoreServiceError.invalidFriendAction }
        return try await mutatePartyRoom(code: code) { room in
            guard room.isStageRoom == true,
                  room.status == .inProgress,
                  room.containsPlayer(userID),
                  let roundIndex = room.currentStageRoundIndex,
                  var rounds = room.stageRounds,
                  rounds.indices.contains(roundIndex),
                  rounds[roundIndex].status == .inProgress else {
                throw FirestoreServiceError.invalidFriendAction
            }

            rounds[roundIndex].results[userID] = result
            rounds[roundIndex] = self.startPartyStageFinishWindowIfNeeded(rounds[roundIndex], starterID: userID, result: result)
            room.stageRounds = rounds
            room = self.finishPartyStageRoundIfReady(room)
        }
    }

    func advancePartyStageRound(code: String, hostID: String) async throws -> PartyRoom {
        if code.hasPrefix("S1") {
            let room = try await db.collection("partyRooms").document(code).getDocument(as: PartyRoom.self)
            return try await verifiedPartyAction("advance", code: code, userID: hostID, roundIndex: room.currentStageRoundIndex ?? 0)
        }
        return try await mutatePartyRoom(code: code) { room in
            guard room.isStageRoom == true,
                  room.status == .inProgress,
                  room.hostID == hostID,
                  let currentIndex = room.currentStageRoundIndex,
                  var rounds = room.stageRounds,
                  rounds.indices.contains(currentIndex),
                  rounds[currentIndex].status == .finished else {
                throw FirestoreServiceError.invalidFriendAction
            }

            let nextIndex = currentIndex + 1
            guard rounds.indices.contains(nextIndex) else {
                room = self.finishPartyStageRoom(room)
                return
            }

            rounds[nextIndex].status = .inProgress
            rounds[nextIndex].startedAt = Date()
            room.stageRounds = rounds
            room.currentStageRoundIndex = nextIndex
            room.mode = rounds[nextIndex].mode
            room.difficulty = rounds[nextIndex].difficulty
            room.seed = rounds[nextIndex].seed
            room.puzzleData = rounds[nextIndex].puzzleData
        }
    }

    func finalizeExpiredPartyFinishWindow(code: String) async throws -> PartyRoom {
        guard !code.hasPrefix("S1") else { throw FirestoreServiceError.invalidFriendAction }
        return try await mutatePartyRoom(code: code) { room in
            if room.isStageRoom == true {
                room = self.finalizeExpiredPartyStageFinishWindow(room)
                return
            }

            guard room.status == .inProgress,
                  let deadline = room.finishWindowDeadline,
                  Date() >= deadline else {
                return
            }

            for index in room.players.indices where !self.isFinalPartyResult(room.players[index].result) {
                room.players[index].result = self.partyTimeoutResult(for: room, userID: room.players[index].userID)
                room.players[index].abandoned = false
            }
            room = self.finishPartyRoomIfReady(room)
        }
    }

    func leavePartyRoom(code: String, userID: String) async throws -> PartyRoom {
        if code.hasPrefix("S1") { return try await verifiedPartyAction("forfeit", code: code, userID: userID) }
        return try await mutatePartyRoom(code: code) { room in
            room.readyPlayerIDs = (room.readyPlayerIDs ?? []).filter { $0 != userID }
            switch room.status {
            case .lobby:
                if room.hostID == userID {
                    room.status = .canceled
                    room.finishedAt = Date()
                } else {
                    room.players.removeAll { $0.userID == userID }
                    room.playerIDs = room.players.map(\.userID)
                }
            case .inProgress:
                guard let index = room.players.firstIndex(where: { $0.userID == userID }) else { return }
                if room.isStageRoom == true {
                    if let roundIndex = room.currentStageRoundIndex,
                       var rounds = room.stageRounds,
                       rounds.indices.contains(roundIndex),
                       rounds[roundIndex].results[userID] == nil {
                        rounds[roundIndex].results[userID] = MatchPlayerResult(
                            userID: userID,
                            mode: rounds[roundIndex].mode,
                            completed: false,
                            elapsedSeconds: 0,
                            score: 0,
                            progress: 0,
                            status: "Abandoned",
                            summary: ["abandoned": "true"],
                            details: ["Left the party round."]
                        )
                        room.stageRounds = rounds
                        room = self.finishPartyStageRoundIfReady(room)
                    }
                    return
                }
                if room.players[index].result == nil {
                    room.players[index].result = MatchPlayerResult(
                        userID: userID,
                        mode: room.mode,
                        completed: false,
                        elapsedSeconds: 0,
                        score: 0,
                        progress: 0,
                        status: "Abandoned",
                        summary: ["abandoned": "true"],
                        details: ["Left the party match."]
                    )
                    room.players[index].abandoned = true
                }
                room = self.finishPartyRoomIfReady(room)
            case .finished, .canceled, .expired:
                break
            }
        }
    }

    func listenForPartyRoom(code rawCode: String, onChange: @escaping (PartyRoom?) -> Void) -> ListenerRegistration {
        db.collection("partyRooms")
            .document(normalizedPartyCode(rawCode))
            .addSnapshotListener { snapshot, error in
                if let error { print("Party room listener error: \(error.localizedDescription)") }
                onChange(try? snapshot?.data(as: PartyRoom.self))
            }
    }

    private func mutatePartyRoom(code rawCode: String, mutate: @escaping (inout PartyRoom) throws -> Void) async throws -> PartyRoom {
        let roomRef = db.collection("partyRooms").document(normalizedPartyCode(rawCode))
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PartyRoom, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                func fail(_ error: Error) -> Any? {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                do {
                    var room = try transaction.getDocument(roomRef).data(as: PartyRoom.self)
                    try mutate(&room)
                    let encoded = try Firestore.Encoder().encode(room)
                    transaction.setData(encoded, forDocument: roomRef, merge: true)
                    return room
                } catch {
                    return fail(error)
                }
            }, completion: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let room = result as? PartyRoom {
                    continuation.resume(returning: room)
                } else {
                    continuation.resume(throwing: FirestoreServiceError.partyRoomNotFound)
                }
            })
        }
    }

    private func startFirstPartyStageRound(_ room: PartyRoom, at date: Date) -> PartyRoom {
        guard room.isStageRoom == true,
              var rounds = room.stageRounds,
              rounds.indices.contains(0) else {
            return room
        }
        var updated = room
        rounds[0].status = .inProgress
        rounds[0].startedAt = date
        updated.stageRounds = rounds
        updated.currentStageRoundIndex = 0
        updated.mode = rounds[0].mode
        updated.difficulty = rounds[0].difficulty
        updated.seed = rounds[0].seed
        updated.puzzleData = rounds[0].puzzleData
        updated.stageScores = updated.players.reduce(into: updated.stageScores ?? [:]) { scores, player in
            scores[player.userID] = scores[player.userID] ?? 0
        }
        return updated
    }

    private func finishPartyStageRoundIfReady(_ room: PartyRoom) -> PartyRoom {
        guard room.isStageRoom == true,
              room.status == .inProgress,
              let roundIndex = room.currentStageRoundIndex,
              var rounds = room.stageRounds,
              rounds.indices.contains(roundIndex),
              rounds[roundIndex].status == .inProgress,
              !room.players.isEmpty,
              room.players.allSatisfy({ player in
                  isFinalPartyResult(rounds[roundIndex].results[player.userID])
              }) else {
            return room
        }

        var updated = room
        rounds[roundIndex] = scoreFinishedPartyStageRound(rounds[roundIndex], players: room.players, cumulativeBefore: room.stageScores ?? [:])
        updated.stageScores = rounds[roundIndex].scoreRows?.reduce(into: room.stageScores ?? [:]) { scores, row in
            scores[row.userID] = row.cumulativePoints
        }
        rounds[roundIndex].status = .finished
        rounds[roundIndex].finishedAt = Date()
        updated.stageRounds = rounds

        if roundIndex >= rounds.count - 1 {
            updated = finishPartyStageRoom(updated)
        }
        return updated
    }

    private func scoreFinishedPartyStageRound(
        _ round: PartyStageRound,
        players: [PartyPlayer],
        cumulativeBefore: [String: Int]
    ) -> PartyStageRound {
        let sortedPlayers = players.sorted {
            PartyScoring.compare(round.results[$0.userID], round.results[$1.userID], mode: round.mode) < 0
        }
        var scored = round
        var rows: [PartyStageRoundScore] = []
        var previousResult: MatchPlayerResult?
        var currentPlacement = 1

        for (offset, player) in sortedPlayers.enumerated() {
            let result = round.results[player.userID]
            if offset > 0,
               PartyScoring.compare(result, previousResult, mode: round.mode) != 0 {
                currentPlacement = offset + 1
            }
            let points = stagePoints(for: currentPlacement)
            let cumulative = (cumulativeBefore[player.userID] ?? 0) + points
            rows.append(PartyStageRoundScore(
                userID: player.userID,
                username: player.username,
                placement: currentPlacement,
                roundPoints: points,
                cumulativePoints: cumulative,
                resultSummary: PartyScoring.summary(for: result, mode: round.mode)
            ))
            previousResult = result
        }

        scored.scoreRows = rows
        return scored
    }

    private func finishPartyStageRoom(_ room: PartyRoom) -> PartyRoom {
        var updated = room
        updated.status = .finished
        updated.finishedAt = Date()
        let resolution = partyStageWinnerResolution(for: updated)
        updated.winnerID = resolution.winnerID
        updated.winnerReason = resolution.reason
        return updated
    }

    private func partyStageWinnerResolution(for room: PartyRoom) -> (winnerID: String?, reason: String) {
        let scores = room.stageScores ?? [:]
        guard let topScore = scores.values.max() else {
            return (nil, "No submitted results")
        }

        var candidates = scores.filter { $0.value == topScore }.map(\.key)
        if candidates.count == 1 {
            return (candidates[0], "Party champion with \(topScore) points")
        }

        let roundWins = partyStageRoundWins(in: room)
        if let bestWins = candidates.map({ roundWins[$0] ?? 0 }).max() {
            let winLeaders = candidates.filter { (roundWins[$0] ?? 0) == bestWins }
            if winLeaders.count == 1 {
                return (winLeaders[0], "Party champion with \(topScore) points")
            }
            candidates = winLeaders
        }

        if let latestRows = room.stageRounds?.last(where: { $0.status == .finished })?.scoreRows {
            let placements = Dictionary(uniqueKeysWithValues: latestRows.map { ($0.userID, $0.placement) })
            if let bestPlacement = candidates.compactMap({ placements[$0] }).min() {
                let latestLeaders = candidates.filter { placements[$0] == bestPlacement }
                if latestLeaders.count == 1 {
                    return (latestLeaders[0], "Party champion with \(topScore) points")
                }
            }
        }

        return (nil, "Party ended in a tie")
    }

    private func partyStageRoundWins(in room: PartyRoom) -> [String: Int] {
        (room.stageRounds ?? []).reduce(into: [String: Int]()) { wins, round in
            for row in round.scoreRows ?? [] where row.placement == 1 {
                wins[row.userID, default: 0] += 1
            }
        }
    }

    private func finalizeExpiredPartyStageFinishWindow(_ room: PartyRoom) -> PartyRoom {
        guard room.isStageRoom == true,
              room.status == .inProgress,
              let roundIndex = room.currentStageRoundIndex,
              var rounds = room.stageRounds,
              rounds.indices.contains(roundIndex),
              rounds[roundIndex].status == .inProgress,
              let deadline = rounds[roundIndex].finishWindowDeadline,
              Date() >= deadline else {
            return room
        }

        var updated = room
        for player in room.players where !isFinalPartyResult(rounds[roundIndex].results[player.userID]) {
            rounds[roundIndex].results[player.userID] = partyStageTimeoutResult(for: rounds[roundIndex], room: room, userID: player.userID)
        }
        updated.stageRounds = rounds
        return finishPartyStageRoundIfReady(updated)
    }

    private func startPartyStageFinishWindowIfNeeded(_ round: PartyStageRound, starterID: String, result: MatchPlayerResult) -> PartyStageRound {
        guard round.finishWindowDeadline == nil,
              isSuccessfulPartyCompletion(result) else {
            return round
        }

        var updated = round
        let now = Date()
        updated.finishWindowStartedAt = now
        updated.finishWindowDeadline = now.addingTimeInterval(180)
        updated.finishWindowStarterID = starterID
        return updated
    }

    private func stagePoints(for placement: Int) -> Int {
        switch placement {
        case 1: return 10
        case 2: return 7
        case 3: return 5
        case 4: return 3
        default: return 1
        }
    }

    private func finishPartyRoomIfReady(_ room: PartyRoom) -> PartyRoom {
        guard room.status == .inProgress,
              !room.players.isEmpty,
              room.players.allSatisfy({ player in
                  isFinalPartyResult(player.result)
              }) else {
            return room
        }

        var resolved = PartyScoring.resolvedRoom(room)
        resolved.status = .finished
        resolved.finishedAt = Date()
        return resolved
    }

    private func startPartyFinishWindowIfNeeded(_ room: PartyRoom, starterID: String, result: MatchPlayerResult) -> PartyRoom {
        guard room.status == .inProgress,
              room.finishWindowDeadline == nil,
              isSuccessfulPartyCompletion(result) else {
            return room
        }

        var updated = room
        let now = Date()
        updated.finishWindowStartedAt = now
        updated.finishWindowDeadline = now.addingTimeInterval(180)
        updated.finishWindowStarterID = starterID
        return updated
    }

    private func isSuccessfulPartyCompletion(_ result: MatchPlayerResult) -> Bool {
        guard result.completed else { return false }
        switch result.mode {
        case .sudoku, .gridlock, .colorLink, .minesweeper:
            return true
        case .wordle:
            return result.isFinalWordleResult
        case .hangman:
            return result.summary["final"] == "true" || result.solvedRounds >= 2
        case .anagram, .wordHunt:
            return false
        }
    }

    private func partyTimeoutResult(for room: PartyRoom, userID: String) -> MatchPlayerResult {
        MatchPlayerResult(
            userID: userID,
            mode: room.mode,
            completed: false,
            elapsedSeconds: max(0, Int(Date().timeIntervalSince(room.startedAt ?? Date()))),
            score: 0,
            progress: 0,
            status: "Time expired",
            summary: ["partyTimeout": "true"],
            details: ["Party finish window expired."]
        )
    }

    private func partyStageTimeoutResult(for round: PartyStageRound, room: PartyRoom, userID: String) -> MatchPlayerResult {
        MatchPlayerResult(
            userID: userID,
            mode: round.mode,
            completed: false,
            elapsedSeconds: max(0, Int(Date().timeIntervalSince(round.startedAt ?? room.startedAt ?? Date()))),
            score: 0,
            progress: 0,
            status: "Time expired",
            summary: ["partyTimeout": "true"],
            details: ["Party finish window expired."]
        )
    }

    private func isFinalPartyResult(_ result: MatchPlayerResult?) -> Bool {
        guard let result else { return false }
        if result.status == "Abandoned" { return true }
        if result.summary["partyTimeout"] == "true" { return true }
        switch result.mode {
        case .wordle:
            return result.isFinalWordleResult
        case .hangman:
            return result.summary["final"] == "true" || result.completed || result.wrongGuessCount >= result.maxWrongGuesses
        default:
            return true
        }
    }

    private func makePartyCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in alphabet.randomElement() })
    }

    private func normalizedPartyCode(_ code: String) -> String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
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
