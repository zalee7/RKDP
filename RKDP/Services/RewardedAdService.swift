import Foundation

@MainActor
final class RewardedAdService {
    static let shared = RewardedAdService()

    private init() {}

    func watchRankedEntryAd() async throws {
        #if DEBUG
        try await Task.sleep(nanoseconds: 900_000_000)
        #else
        throw RewardedAdServiceError.adNetworkNotConfigured
        #endif
    }
}

enum RewardedAdServiceError: LocalizedError {
    case adNetworkNotConfigured

    var errorDescription: String? {
        switch self {
        case .adNetworkNotConfigured:
            return "Rewarded ads are not configured in this build yet."
        }
    }
}
