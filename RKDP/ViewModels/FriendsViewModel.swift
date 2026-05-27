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
    @Published var friendProfiles: [String: AppUser] = [:]
    @Published var errorMessage: String?
    @Published var activeExhibitionSession: GameSession?
    private var activeExhibitionInviteID: String?
    private var activeExhibitionInviteType: ExhibitionInviteType = .playNow

    private let store = FirestoreService.shared
    private var listeners: [ListenerRegistration] = []
    private var handledSessionIDs: Set<String> = []

    func start(user: AppUser) {
        stop()
        listeners = [
            store.listenForFriends(userID: user.id) { [weak self] friendships in
                Task { @MainActor in
                    guard let self else { return }
                    let summaries: [FriendSummary] = friendships.compactMap { (friendship: Friendship) -> FriendSummary? in
                        guard let friendID = friendship.friendID(for: user.id) else { return nil }
                        return FriendSummary(userID: friendID, username: friendship.friendUsername(for: user.id))
                    }
                    .sorted { (lhs: FriendSummary, rhs: FriendSummary) -> Bool in
                        lhs.username.localizedCaseInsensitiveCompare(rhs.username) == .orderedAscending
                    }
                    self.friends = summaries
                    await self.hydrateFriendAvatars(summaries)
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
        friendProfiles = [:]
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

    func sendInvite(from user: AppUser, to friend: FriendSummary, mode: GameMode, difficulty: Difficulty, inviteType: ExhibitionInviteType) async {
        do {
            _ = try await store.createExhibitionInvite(from: user, to: friend, mode: mode, difficulty: difficulty, inviteType: inviteType)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(_ friend: FriendSummary, currentUserID: String) async {
        do {
            try await store.removeFriend(currentUserID: currentUserID, friendID: friend.userID)
            friends.removeAll { $0.userID == friend.userID }
            friendProfiles[friend.userID] = nil
            incomingInvites.removeAll { $0.fromID == friend.userID || $0.toID == friend.userID }
            outgoingInvites.removeAll { $0.fromID == friend.userID || $0.toID == friend.userID }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hydrateFriendAvatars(_ summaries: [FriendSummary]) async {
        var hydrated: [FriendSummary] = []
        var profiles: [String: AppUser] = [:]
        for summary in summaries {
            do {
                let friendUser = try await store.fetchUser(id: summary.userID)
                profiles[summary.userID] = friendUser
                hydrated.append(FriendSummary(
                    userID: summary.userID,
                    username: friendUser.username,
                    avatarStyle: friendUser.cosmetics.avatarStyle
                ))
            } catch {
                hydrated.append(summary)
            }
        }
        hydrated.sort { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }

        let currentIDs = Set(friends.map(\.userID))
        let hydratedIDs = Set(hydrated.map(\.userID))
        guard currentIDs == hydratedIDs else { return }
        friendProfiles = profiles
        friends = hydrated
    }

    func acceptInvite(_ invite: ExhibitionInvite, currentUser: AppUser) async {
        do {
            let session = try await store.acceptExhibitionInvite(invite, currentUser: currentUser)
            handledSessionIDs.insert(session.id)
            activeExhibitionInviteID = invite.id
            activeExhibitionInviteType = invite.kind
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

    func playInvite(_ invite: ExhibitionInvite, currentUser: AppUser) async {
        do {
            let session: GameSession
            if invite.isPlayLater, let sessionID = invite.sessionID {
                session = try await store.fetchSession(id: sessionID)
                if invite.toID == currentUser.id && invite.status == .pending {
                    _ = try await store.acceptExhibitionInvite(invite, currentUser: currentUser)
                }
            } else {
                session = try await store.acceptExhibitionInvite(invite, currentUser: currentUser)
            }
            handledSessionIDs.insert(session.id)
            activeExhibitionInviteID = invite.id
            activeExhibitionInviteType = invite.kind
            activeExhibitionSession = session
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeActiveExhibitionInvite() async {
        guard let inviteID = activeExhibitionInviteID else { return }
        let inviteType = activeExhibitionInviteType
        activeExhibitionInviteID = nil
        activeExhibitionInviteType = .playNow
        guard inviteType == .playNow else { return }
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
            activeExhibitionInviteType = invite.kind
            activeExhibitionSession = session
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
