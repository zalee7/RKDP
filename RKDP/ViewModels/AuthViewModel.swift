import Foundation
import SwiftUI
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: AppUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let auth = FirebaseAuthService.shared
    private let store = FirestoreService.shared
    private let ranking = RankingService.shared
    private var rewardStatusUserID: String?

    init() {
        // Use state-change listener so session is restored after cold launch
        Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                if let firebaseUser {
                    await self?.loadUser(firebaseUser: firebaseUser)
                } else {
                    CoinPackStoreKitService.shared.stopObservingPurchases()
                    self?.user = nil
                    self?.soloRewardsEnabled = false
                    self?.rewardStatusUserID = nil
                }
            }
        }
    }

    var isSignedIn: Bool { user != nil }

    func signIn(email: String, password: String) async {
        isLoading = true; errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await loadUser(firebaseUser: result.user)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp(email: String, password: String, username: String) async {
        isLoading = true; errorMessage = nil
        do {
            let firebaseUser = try await auth.signUp(email: email, password: password)
            let newUser = AppUser.makeNew(id: firebaseUser.uid, username: username, email: email)
            try await store.createUser(newUser)
            user = newUser
            await NotificationTokenService.shared.syncCurrentToken()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        do {
            try auth.signOut()
            CoinPackStoreKitService.shared.stopObservingPurchases()
            user = nil
            soloRewardsEnabled = false
            rewardStatusUserID = nil
        }
        catch { errorMessage = error.localizedDescription }
    }

    func updateNotificationSettings(_ settings: NotificationSettings) async -> Bool {
        guard let currentUser = user else { return false }
        do {
            user = try await store.updateNotificationSettings(userID: currentUser.id, settings: settings)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async -> Bool {
        guard let currentUser = user else { return false }
        do {
            user = try await RankedStoreKitService.shared.syncPurchases(userID: currentUser.id, restoring: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteAccount() async -> Bool {
        guard let currentUser = user else { return false }
        if let lastSignIn = Auth.auth().currentUser?.metadata.lastSignInDate,
           Date().timeIntervalSince(lastSignIn) > 300 {
            errorMessage = "For security, sign out and sign back in before deleting your account."
            return false
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await store.anonymizeAccountData(userID: currentUser.id)
            try await auth.deleteCurrentUser()
            user = nil
            return true
        } catch {
            errorMessage = "Could not delete account. If you signed in a while ago, sign out and sign back in before trying again."
            return false
        }
    }

    // Loads from Firestore; if doc is missing, creates it from Firebase Auth data
    private func loadUser(firebaseUser: FirebaseAuth.User) async {
        #if PP_SOCIAL_SANDBOX
        do {
            _ = try await store.usesServerWallet(userID: firebaseUser.uid)
            let loaded = try await store.fetchUser(id: firebaseUser.uid)
            guard Auth.auth().currentUser?.uid == firebaseUser.uid else { return }
            user = loaded
            errorMessage = nil
        } catch {
            guard Auth.auth().currentUser?.uid == firebaseUser.uid else { return }
            user = nil
            errorMessage = "This test account is not ready yet. Ask to have it prepared for friend and party testing."
        }
        #else
        do {
            var loadedUser = try await store.fetchUser(id: firebaseUser.uid)
            loadedUser = await syncRankedPurchases(for: loadedUser)
            loadedUser = await applyPendingRankedOutcomes(for: loadedUser)
            loadedUser = (try? await store.reconcileCompetitiveBadgeWins(for: loadedUser)) ?? loadedUser
            if !Set(loadedUser.earnedRewards.map(\.id)).isSubset(of: loadedUser.earnedShowcase.unlockedIDs) {
                // Failure to sync a showcase must never fall through to account creation.
                loadedUser = (try? await store.updateEarnedShowcase(userID: loadedUser.id)) ?? loadedUser
            }
            guard Auth.auth().currentUser?.uid == firebaseUser.uid else { return }
            if rewardStatusUserID != firebaseUser.uid {
                let enabled = await SoloRewardClient.isEnabled(userID: firebaseUser.uid)
                guard Auth.auth().currentUser?.uid == firebaseUser.uid else { return }
                soloRewardsEnabled = enabled
                rewardStatusUserID = firebaseUser.uid
            }
            user = loadedUser
            if soloRewardsEnabled, (try? await SoloRewardClient.recover(userID: firebaseUser.uid)) != nil {
                user = (try? await store.fetchUser(id: firebaseUser.uid)) ?? loadedUser
            }
            CoinPackStoreKitService.shared.observePurchases(userID: firebaseUser.uid) { [weak self] updated in
                guard Auth.auth().currentUser?.uid == updated.id else { return }
                self?.user = updated
            }
            if let recovered = await CoinPackStoreKitService.shared.recoverPurchases(userID: firebaseUser.uid),
               Auth.auth().currentUser?.uid == firebaseUser.uid {
                user = recovered
            }
            await NotificationTokenService.shared.syncCurrentToken()
        } catch {
            // Doc missing — create a minimal profile so login never hard-fails
            let fallbackUsername = firebaseUser.displayName
                ?? firebaseUser.email?.components(separatedBy: "@").first
                ?? "Player"
            let newUser = AppUser.makeNew(
                id: firebaseUser.uid,
                username: fallbackUsername,
                email: firebaseUser.email ?? ""
            )
            try? await store.createUser(newUser)
            user = await syncRankedPurchases(for: newUser)
            await NotificationTokenService.shared.syncCurrentToken()
        }
        #endif
    }

    func refreshUser() async {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        await loadUser(firebaseUser: firebaseUser)
    }

    private func syncRankedPurchases(for loadedUser: AppUser) async -> AppUser {
        do {
            return try await RankedStoreKitService.shared.syncPurchases(userID: loadedUser.id)
        } catch {
            return loadedUser
        }
    }

    private func applyPendingRankedOutcomes(for loadedUser: AppUser) async -> AppUser {
        do {
            let sessions = try await store.fetchUnappliedFinishedSessions(for: loadedUser)
            guard !sessions.isEmpty else { return loadedUser }
            for session in sessions {
                if session.usesServerAuthority && session.isCasual {
                    _ = try await store.applyFinishedCasualSession(session, for: loadedUser.id)
                } else {
                    try await ranking.applyFinishedSession(session, for: loadedUser.id)
                }
            }
            return try await store.fetchUser(id: loadedUser.id)
        } catch {
            return loadedUser
        }
    }


    func setTesterRankedAccess(enabled: Bool) async {
        guard let currentUser = user else { return }
        do {
            user = try await store.setTesterRankedAccess(userID: currentUser.id, enabled: enabled)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func grantTesterRankedAccess() async {
        await setTesterRankedAccess(enabled: true)
    }

    func equipEarnedReward(_ id: String?, in slot: EarnedRewardSlot) async throws {
        guard let userID = user?.id else { return }
        let updated = try await store.updateEarnedShowcase(userID: userID, slot: slot, rewardID: id)
        guard user?.id == userID else { return }
        user = updated
    }

    @Published private(set) var soloRewardsEnabled = false

    func recordSoloResult(_ result: SoloGameResult) async {
        guard var user else { return }
        let serverOwned = (try? await store.usesServerWallet(userID: user.id)) ?? true
        if result.completed {
            user.recordSoloCompletion(mode: result.mode, difficulty: result.difficulty)
        }
        let streakReward = (soloRewardsEnabled || serverOwned) ? 0 : user.playProgress.recordGamePlayed(
            activityID: "solo_\(result.mode.rawValue)_\(result.difficulty.rawValue)_\(result.id.uuidString)"
        )
        if streakReward > 0 {
            user.coins += streakReward
        }

        var rankInfo = user.ranks[result.mode] ?? .empty
        rankInfo.soloBest = BestStat.updated(rankInfo.soloBest, with: .from(solo: result))
        rankInfo.recordSoloBest(result)
        user.ranks[result.mode] = rankInfo
        user.reconcileEarnedRewards()
        self.user = user
        if soloRewardsEnabled || serverOwned {
            // Server owns coins and daily progression. Save only local solo statistics.
            try? await store.updateSoloStatistics(user, mode: result.mode)
        } else {
            try? await store.updateUser(user)
        }
    }
}
