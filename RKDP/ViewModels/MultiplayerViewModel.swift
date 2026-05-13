import Foundation
import FirebaseFirestore
import FirebaseDatabase

enum MultiplayerState {
    case idle
    case searching
    case matchFound(sessionID: String)
    case inMatch(session: GameSession)
    case finished(session: GameSession)
    case error(String)
}

@MainActor
final class MultiplayerViewModel: ObservableObject {
    @Published var state: MultiplayerState = .idle
    @Published var selectedWager: WagerTier?
    @Published var finishTimes: [String: Int] = [:]
    @Published var elapsedSeconds: Int = 0

    private let store = FirestoreService.shared
    private let rtdb = RealtimeDBService.shared
    private let ranking = RankingService.shared
    private var matchListener: ListenerRegistration?
    private var rtdbHandles: [DatabaseHandle] = []
    private var searchTimer: Timer?
    private var gameTimer: Timer?

    var user: AppUser?
    var mode: GameMode = .sudoku
    var difficulty: Difficulty = .medium

    // MARK: - Matchmaking

    func startSearch(user: AppUser, mode: GameMode, difficulty: Difficulty, wager: WagerTier) async {
        guard user.coins >= wager.amount else {
            state = .error("Not enough coins for this wager.")
            return
        }
        self.user = user
        self.mode = mode
        self.difficulty = difficulty
        self.selectedWager = wager
        state = .searching

        let tier = user.rank(for: mode).tier
        do {
            try await store.joinMatchmakingQueue(
                userID: user.id, mode: mode, difficulty: difficulty,
                wager: wager.amount, rankTier: tier
            )
            listenForMatch(userID: user.id)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func cancelSearch() async {
        guard let user, let wager = selectedWager else { return }
        matchListener?.remove()
        try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
        state = .idle
    }

    private func listenForMatch(userID: String) {
        matchListener = store.listenForMatch(userID: userID, mode: mode, difficulty: difficulty) { [weak self] sessionID in
            Task { await self?.joinSession(id: sessionID) }
        }
    }

    // MARK: - Session

    private func joinSession(id: String) async {
        do {
            let session = try await store.fetchSession(id: id)
            state = .matchFound(sessionID: id)
            try await rtdb.markReady(sessionID: id, userID: user?.id ?? "")
            listenForBothReady(session: session)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func listenForBothReady(session: GameSession) {
        let handle = rtdb.listenForBothReady(sessionID: session.id) { [weak self] in
            Task { @MainActor in
                self?.state = .inMatch(session: session)
                self?.startGameTimer()
                self?.listenForFinishTimes(sessionID: session.id)
            }
        }
        rtdbHandles.append(handle)
    }

    func submitFinish(sessionID: String) async {
        guard let userID = user?.id else { return }
        gameTimer?.invalidate()
        do {
            try await rtdb.submitFinishTime(sessionID: sessionID, userID: userID, seconds: elapsedSeconds)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func listenForFinishTimes(sessionID: String) {
        let handle = rtdb.listenForFinishTimes(sessionID: sessionID) { [weak self] times in
            Task { @MainActor in
                self?.finishTimes = times
                if times.count == 2 { await self?.resolveMatch(sessionID: sessionID, times: times) }
            }
        }
        rtdbHandles.append(handle)
    }

    private func resolveMatch(sessionID: String, times: [String: Int]) async {
        guard case .inMatch(let session) = state else { return }
        gameTimer?.invalidate()

        let winnerID = times.min(by: { $0.value < $1.value })?.key
        let outcome = RankingService.MatchOutcome(
            sessionID: sessionID,
            mode: session.mode,
            difficulty: session.difficulty,
            winnerID: winnerID,
            players: session.players.map { p in
                var mp = p
                mp.finishTime = times[p.userID]
                return mp
            }
        )
        do {
            try await ranking.processOutcome(outcome)
            let updated = try await store.fetchSession(id: sessionID)
            state = .finished(session: updated)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func startGameTimer() {
        elapsedSeconds = 0
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedSeconds += 1 }
        }
    }

    func reset() {
        matchListener?.remove()
        rtdbHandles.forEach { rtdb.removeObserver(handle: $0, sessionID: "") }
        rtdbHandles = []
        gameTimer?.invalidate()
        state = .idle
        elapsedSeconds = 0
        finishTimes = [:]
    }
}
