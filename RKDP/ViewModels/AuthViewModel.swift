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
        if let firebaseUser = auth.currentUser {
            Task { await loadUser(id: firebaseUser.uid) }
        }
    }

    var isSignedIn: Bool { user != nil }

    func signIn(email: String, password: String) async {
        isLoading = true; errorMessage = nil
        do {
            try await auth.signIn(email: email, password: password)
            if let uid = auth.currentUser?.uid { await loadUser(id: uid) }
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    func signUp(email: String, password: String, username: String) async {
        isLoading = true; errorMessage = nil
        do {
            let firebaseUser = try await auth.signUp(email: email, password: password)
            let newUser = AppUser.makeNew(id: firebaseUser.uid, username: username, email: email)
            try await store.createUser(newUser)
            user = newUser
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    func signOut() {
        do { try auth.signOut(); user = nil }
        catch { errorMessage = error.localizedDescription }
    }

    private func loadUser(id: String) async {
        do { user = try await store.fetchUser(id: id) }
        catch { errorMessage = "Failed to load profile." }
    }

    func refreshUser() async {
        guard let id = user?.id else { return }
        await loadUser(id: id)
    }
}
