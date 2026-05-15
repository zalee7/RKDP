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
            user = try await store.fetchUser(id: firebaseUser.uid)
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
            user = newUser
        }
    }

    func refreshUser() async {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        await loadUser(firebaseUser: firebaseUser)
    }
}
