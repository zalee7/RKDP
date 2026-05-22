import Foundation

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case declined
    case canceled
}

struct FriendRequest: Codable, Identifiable, Equatable {
    var id: String
    var fromID: String
    var fromUsername: String
    var toID: String
    var toUsername: String
    var status: FriendRequestStatus
    var createdAt: Date

    func otherUserID(currentUserID: String) -> String {
        fromID == currentUserID ? toID : fromID
    }

    func otherUsername(currentUserID: String) -> String {
        fromID == currentUserID ? toUsername : fromUsername
    }
}

struct Friendship: Codable, Identifiable, Equatable {
    var id: String
    var userIDs: [String]
    var usernames: [String: String]
    var createdAt: Date

    func friendID(for currentUserID: String) -> String? {
        userIDs.first { $0 != currentUserID }
    }

    func friendUsername(for currentUserID: String) -> String {
        guard let id = friendID(for: currentUserID) else { return "Friend" }
        return usernames[id] ?? "Friend"
    }
}

struct FriendSummary: Identifiable, Equatable {
    var id: String { userID }
    var userID: String
    var username: String
}

enum ExhibitionInviteStatus: String, Codable {
    case pending
    case accepted
    case declined
    case expired
    case canceled
    case completed
}

enum ExhibitionInviteType: String, Codable {
    case playNow
    case playLater
}

struct ExhibitionInvite: Codable, Identifiable, Equatable {
    var id: String
    var fromID: String
    var fromUsername: String
    var toID: String
    var toUsername: String
    var mode: GameMode
    var difficulty: Difficulty
    var status: ExhibitionInviteStatus
    var createdAt: Date
    var expiresAt: Date
    var sessionID: String?
    var inviteType: ExhibitionInviteType?

    var kind: ExhibitionInviteType { inviteType ?? .playNow }
    var isExpired: Bool { Date() >= expiresAt }
    var isPlayLater: Bool { kind == .playLater }

    func otherUsername(currentUserID: String) -> String {
        fromID == currentUserID ? toUsername : fromUsername
    }
}
