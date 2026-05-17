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

    init() {
        // Use state-change listener so session is restored after cold launch
        Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                if let firebaseUser {
                    await self?.loadUser(firebaseUser: firebaseUser)
                } else {
                    self?.user = nil
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
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        do { try auth.signOut(); user = nil }
        catch { errorMessage = error.localizedDescription }
    }

    // Loads from Firestore; if doc is missing, creates it from Firebase Auth data
    private func loadUser(firebaseUser: FirebaseAuth.User) async {
        do {
            var loadedUser = try await store.fetchUser(id: firebaseUser.uid)
            loadedUser = await syncRankedPurchases(for: loadedUser)
            loadedUser = await applyPendingRankedOutcomes(for: loadedUser)
            user = loadedUser
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
        }
    }

    func refreshUser() async {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        await loadUser(firebaseUser: firebaseUser)
    }

    private func syncRankedPurchases(for loadedUser: AppUser) async -> AppUser {
        do {
            let productIDs = try await RankedStoreKitService.shared.currentEntitlementProductIDs()
            guard !productIDs.isEmpty else { return loadedUser }
            return try await store.syncRankedAccessEntitlements(userID: loadedUser.id, productIDs: productIDs)
        } catch {
            return loadedUser
        }
    }

    private func applyPendingRankedOutcomes(for loadedUser: AppUser) async -> AppUser {
        do {
            let sessions = try await store.fetchUnappliedFinishedSessions(for: loadedUser)
            guard !sessions.isEmpty else { return loadedUser }
            for session in sessions {
                try await ranking.applyFinishedSession(session, for: loadedUser.id)
            }
            return try await store.fetchUser(id: loadedUser.id)
        } catch {
            return loadedUser
        }
    }

    func recordSoloResult(_ result: SoloGameResult) async {
        guard var user else { return }
        if result.completed {
            user.recordSoloCompletion(mode: result.mode, difficulty: result.difficulty)
        }

        var rankInfo = user.ranks[result.mode] ?? .empty
        if result.completed {
            rankInfo.bestTime = min(rankInfo.bestTime ?? Int.max, result.elapsedSeconds)
        }
        if let score = result.score, result.mode.isScoreBased {
            rankInfo.bestScore = max(rankInfo.bestScore ?? 0, score)
        }
        if let moves = result.moves {
            rankInfo.bestMoves = min(rankInfo.bestMoves ?? Int.max, moves)
        }
        if let progress = result.progress {
            rankInfo.bestProgress = max(rankInfo.bestProgress ?? 0, progress)
        }
        if let guesses = result.guesses, result.completed {
            rankInfo.bestGuesses = min(rankInfo.bestGuesses ?? Int.max, guesses)
        }
        user.ranks[result.mode] = rankInfo
        self.user = user
        try? await store.updateUser(user)
    }
}
