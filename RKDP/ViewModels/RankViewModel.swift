import Foundation

@MainActor
final class RankViewModel: ObservableObject {
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var selectedMode: GameMode = .sudoku
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let store = FirestoreService.shared

    func loadLeaderboard(mode: GameMode) async {
        isLoading = true; errorMessage = nil; selectedMode = mode
        do { leaderboard = try await store.fetchLeaderboard(mode: mode) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}
