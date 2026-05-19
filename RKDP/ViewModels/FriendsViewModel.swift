import Foundation
import FirebaseFirestore

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [FriendSummary] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var incomingInvites: [ExhibitionInvite] = []
    @Published var outgoingInvites: [ExhibitionInvite] = []
    @Published var searchText = ""
    @Published var searchResults: [AppUser] = []
    @Published var errorMessage: String?
    @Published var activeExhibitionSession: GameSession?
    private var activeExhibitionInviteID: String?

    private let store = FirestoreService.shared
    private var listeners: [ListenerRegistration] = []
    private var handledSessionIDs: Set<String> = []

    func start(user: AppUser) {
        stop()
        listeners = [
            store.listenForFriends(userID: user.id) { [weak self] friendships in
                Task { @MainActor in
                    self?.friends = friendships.compactMap { friendship in
                        guard let friendID = friendship.friendID(for: user.id) else { return nil }
                        return FriendSummary(userID: friendID, username: friendship.friendUsername(for: user.id))
                    }
                    .sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
                }
            },
            store.listenForIncomingFriendRequests(userID: user.id) { [weak self] requests in
                Task { @MainActor in self?.incomingRequests = requests.sorted { $0.createdAt > $1.createdAt } }
            },
            store.listenForOutgoingFriendRequests(userID: user.id) { [weak self] requests in
                Task { @MainActor in self?.outgoingRequests = requests.sorted { $0.createdAt > $1.createdAt } }
            },
            store.listenForIncomingExhibitionInvites(userID: user.id) { [weak self] invites in
                Task { @MainActor in self?.incomingInvites = invites.sorted { $0.createdAt > $1.createdAt } }
            },
            store.listenForOutgoingExhibitionInvites(userID: user.id) { [weak self] invites in
                Task { @MainActor in
                    self?.outgoingInvites = invites.sorted { $0.createdAt > $1.createdAt }
                    await self?.openAcceptedInviteIfNeeded(invites)
                }
            }
        ]
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners = []
    }

    func search(currentUserID: String) async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        do {
            searchResults = try await store.searchUsers(username: query, excluding: currentUserID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendRequest(from user: AppUser, to target: AppUser) async {
        do {
            try await store.sendFriendRequest(from: user, to: target)
            searchResults.removeAll { $0.id == target.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptRequest(_ request: FriendRequest, currentUserID: String) async {
        do {
            try await store.acceptFriendRequest(request, currentUserID: currentUserID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineRequest(_ request: FriendRequest, currentUserID: String) async {
        do {
            try await store.declineFriendRequest(request, currentUserID: currentUserID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelRequest(_ request: FriendRequest, currentUserID: String) async {
        do {
            try await store.cancelFriendRequest(request, currentUserID: currentUserID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendInvite(from user: AppUser, to friend: FriendSummary, mode: GameMode, difficulty: Difficulty) async {
        do {
            _ = try await store.createExhibitionInvite(from: user, to: friend, mode: mode, difficulty: difficulty)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptInvite(_ invite: ExhibitionInvite, currentUser: AppUser) async {
        do {
            let session = try await store.acceptExhibitionInvite(invite, currentUser: currentUser)
            handledSessionIDs.insert(session.id)
            activeExhibitionInviteID = invite.id
            activeExhibitionSession = session
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineInvite(_ invite: ExhibitionInvite, currentUserID: String) async {
        do {
            try await store.declineExhibitionInvite(invite, currentUserID: currentUserID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    func closeActiveExhibitionInvite() async {
        guard let inviteID = activeExhibitionInviteID else { return }
        activeExhibitionInviteID = nil
        do {
            try await store.completeExhibitionInvite(inviteID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openAcceptedInviteIfNeeded(_ invites: [ExhibitionInvite]) async {
        guard let invite = invites.first(where: { $0.status == .accepted && $0.sessionID != nil && !$0.isExpired }),
              let sessionID = invite.sessionID,
              !handledSessionIDs.contains(sessionID) else { return }
        do {
            let session = try await store.fetchSession(id: sessionID)
            if session.status == .finished {
                try? await store.completeExhibitionInvite(invite.id)
                handledSessionIDs.insert(sessionID)
                return
            }
            handledSessionIDs.insert(sessionID)
            activeExhibitionInviteID = invite.id
            activeExhibitionSession = session
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
