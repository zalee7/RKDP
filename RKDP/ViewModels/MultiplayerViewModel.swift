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

    // Firestore listeners
    private var userDocListener: ListenerRegistration?
    private var queueListener: ListenerRegistration?

    // Realtime DB handles
    private var rtdbHandles: [DatabaseHandle] = []
    private var currentSessionID: String?
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

        do {
            // 0. Clear any stale pendingSessionID from a previous match
            try? await store.clearPendingSession(userID: user.id)

            // 1. Write to queue and try to pair immediately
            try await store.joinAndPair(user: user, mode: mode, difficulty: difficulty, wager: wager.amount)

            // 2. Listen on our user doc for pendingSessionID (written by the host player)
            userDocListener = store.listenForMatch(userID: user.id) { [weak self] sessionID in
                Task { await self?.consumeMatch(sessionID: sessionID) }
            }

            // 3. Also listen on the queue so that if we're the host we can pair
            //    any opponent who joins after us
            queueListener = store.listenForQueueMatch(
                user: user, mode: mode, difficulty: difficulty, wager: wager.amount
            ) { _ in /* session creation is handled inside listenForQueueMatch */ }

        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func cancelSearch() async {
        guard let user, selectedWager != nil else { return }
        tearDownListeners()
        try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
        state = .idle
    }

    /// Called when pendingSessionID appears on our user doc
    private func consumeMatch(sessionID: String) async {
        // Remove listeners — match is found
        tearDownListeners()

        // Clear the field so it doesn't re-fire on reconnect
        try? await store.clearPendingSession(userID: user?.id ?? "")

        do {
            let session = try await store.fetchSession(id: sessionID)
            state = .matchFound(sessionID: sessionID)
            try await rtdb.markReady(sessionID: sessionID, userID: user?.id ?? "")
            listenForBothReady(session: session)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Session

    private func listenForBothReady(session: GameSession) {
        currentSessionID = session.id
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
                var mp = p; mp.finishTime = times[p.userID]; return mp
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

    // MARK: - Helpers

    private func startGameTimer() {
        elapsedSeconds = 0
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedSeconds += 1 }
        }
    }

    private func tearDownListeners() {
        userDocListener?.remove()
        userDocListener = nil
        queueListener?.remove()
        queueListener = nil
    }

    func reset() {
        tearDownListeners()
        let sid = currentSessionID ?? ""
        rtdbHandles.forEach { rtdb.removeObserver(handle: $0, sessionID: sid) }
        rtdbHandles = []
        currentSessionID = nil
        gameTimer?.invalidate()
        state = .idle
        elapsedSeconds = 0
        finishTimes = [:]
    }
}
