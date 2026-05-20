import Foundation
import FirebaseFirestore
import FirebaseDatabase

enum MultiplayerState {
    case idle
    case searching
    case matchFound(session: GameSession)
    case inMatch(session: GameSession)
    case finished(session: GameSession)
    case error(String)
}

@MainActor
final class MultiplayerViewModel: ObservableObject {
    @Published var state: MultiplayerState = .idle
    @Published var selectedWager: WagerTier?
    @Published var playerResults: [String: MatchPlayerResult] = [:]
    @Published var elapsedSeconds: Int = 0
    @Published var opponentUser: AppUser? = nil
    @Published var matchCountdown: Int = 5
    @Published var finishedSessionID: String?
    @Published var rewardErrorMessage: String?
    @Published var rewardSnapshot: PostMatchRewardSnapshot?
    @Published var rematchRequests: Set<String> = []
    @Published var rematchErrorMessage: String?
    @Published var isStartingRematch = false
    @Published var dismissedRematchInviteSessionID: String?
    private var countdownTask: Task<Void, Never>?
    private var botFallbackTask: Task<Void, Never>?
    private var botResultTask: Task<Void, Never>?

    private let store = FirestoreService.shared
    private let rtdb = RealtimeDBService.shared
    private let ranking = RankingService.shared

    // Firestore listeners
    private var userDocListener: ListenerRegistration?
    private var queueListener: ListenerRegistration?
    private var matchDiscoveryListener: ListenerRegistration?
    private var sessionListener: ListenerRegistration?

    // Realtime DB handles
    private var rtdbHandles: [(sessionID: String, handle: DatabaseHandle)] = []
    private var currentSessionID: String?
    private var rematchListeningSessionID: String?
    private var rematchPublishedSessionID: String?
    private var gameTimer: Timer?
    private var activeSearchID: UUID?
    private var isForfeiting = false

    var user: AppUser?
    var mode: GameMode = .sudoku
    var difficulty: Difficulty = .medium

    // MARK: - Matchmaking

    func startSearch(user: AppUser, mode: GameMode, difficulty: Difficulty, wager: WagerTier) async {
        guard mode.rankedDifficulties.contains(difficulty) else {
            state = .error("\(mode.displayName) ranked is only available at \(mode.rankedDifficulties.map { mode.difficultyLabel($0) }.joined(separator: ", ")).")
            return
        }
        guard user.coins >= wager.amount else {
            state = .error("Not enough coins for this tier wager.")
            return
        }
        guard user.rankedAccess.canStartRanked(mode: mode) else {
            state = .error("No ranked entry is available for this mode today.")
            return
        }

        let searchID = UUID()
        activeSearchID = searchID
        tearDownListeners()
        countdownTask?.cancel()
        countdownTask = nil
        cancelBotTasks()
        gameTimer?.invalidate()
        playerResults = [:]
        opponentUser = nil
        elapsedSeconds = 0
        matchCountdown = 5
        finishedSessionID = nil
        rewardErrorMessage = nil
        rewardSnapshot = nil
        clearRematchState()

        self.user = user
        self.mode = mode
        self.difficulty = difficulty
        self.selectedWager = wager
        playerResults = [:]
        elapsedSeconds = 0
        state = .searching

        do {
            // 0. Clear any stale state from a previous attempt before listening.
            try? await store.clearPendingSession(userID: user.id)
            try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
            guard isCurrentSearch(searchID) else { return }

            // 1. Listen for sessions that include us. This avoids requiring one
            //    player to write pendingSessionID into the opponent's user doc.
            matchDiscoveryListener = store.listenForActiveSession(
                userID: user.id,
                mode: mode,
                difficulty: difficulty
            ) { [weak self] session in
                Task { await self?.consumeDiscoveredMatch(session: session, searchID: searchID) }
            }

            // Keep the old own-user listener as a harmless fallback for existing sessions.
            userDocListener = store.listenForMatch(userID: user.id) { [weak self] sessionID, pendingSearchID in
                Task { await self?.consumeMatch(sessionID: sessionID, pendingSearchID: pendingSearchID, searchID: searchID) }
            }

            // 2. Also listen on the queue so that if we're the host we can pair
            //    any opponent who joins after us
            queueListener = store.listenForQueueMatch(
                user: user, mode: mode, difficulty: difficulty, wager: wager.amount, searchID: searchID.uuidString
            ) { [weak self] sessionID in
                Task { await self?.consumeMatch(sessionID: sessionID, pendingSearchID: searchID.uuidString, searchID: searchID) }
            }

            // 3. Write to queue and try to pair immediately
            try await store.joinAndPair(user: user, mode: mode, difficulty: difficulty, wager: wager.amount, searchID: searchID.uuidString)
            scheduleBotFallback(user: user, mode: mode, difficulty: difficulty, wager: wager, searchID: searchID)

            if !isCurrentSearch(searchID) {
                try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
                try? await store.clearPendingSession(userID: user.id)
            }
        } catch {
            guard isCurrentSearch(searchID) else { return }
            tearDownListeners()
            try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
            state = .error(error.localizedDescription)
        }
    }

    func startExhibition(user: AppUser, session: GameSession) async {
        activeSearchID = nil
        tearDownListeners()
        countdownTask?.cancel()
        countdownTask = nil
        cancelBotTasks()
        gameTimer?.invalidate()
        removeRealtimeObservers()
        clearRematchState()

        self.user = user
        self.mode = session.mode
        self.difficulty = session.difficulty
        self.selectedWager = nil
        playerResults = [:]
        opponentUser = nil
        elapsedSeconds = 0
        matchCountdown = 5
        finishedSessionID = nil
        rewardErrorMessage = nil
        rewardSnapshot = nil
        currentSessionID = session.id

        if let opponentID = session.players.first(where: { $0.userID != user.id })?.userID {
            opponentUser = try? await store.fetchUser(id: opponentID)
        }
        state = .matchFound(session: session)
        startMatchCountdown(session: session)
    }

    func cancelSearch() async {
        guard let user else { return }
        activeSearchID = nil
        tearDownListeners()
        countdownTask?.cancel()
        countdownTask = nil
        cancelBotTasks()
        try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
        try? await store.clearPendingSession(userID: user.id)
        opponentUser = nil
        playerResults = [:]
        elapsedSeconds = 0
        state = .idle
    }

    /// Called when pendingSessionID appears on our own user doc.
    private func consumeMatch(sessionID: String, pendingSearchID: String?, searchID: UUID) async {
        guard isCurrentSearch(searchID), let user else { return }
        guard pendingSearchID == searchID.uuidString else {
            try? await store.clearPendingSession(userID: user.id)
            return
        }
        do {
            let session = try await store.fetchSession(id: sessionID)
            await enterFoundMatch(session, searchID: searchID)
        } catch {
            guard isCurrentSearch(searchID) else { return }
            state = .error(error.localizedDescription)
        }
    }

    private func consumeDiscoveredMatch(session: GameSession, searchID: UUID) async {
        await enterFoundMatch(session, searchID: searchID)
    }

    private func enterFoundMatch(_ session: GameSession, searchID: UUID) async {
        guard isCurrentSearch(searchID), let user else { return }
        guard session.mode == mode,
              session.difficulty == difficulty,
              session.players.contains(where: { $0.userID == user.id }) else {
            return
        }
        guard await consumeRankedEntryIfNeeded(for: session) else {
            try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
            try? await store.clearPendingSession(userID: user.id)
            activeSearchID = nil
            return
        }

        tearDownListeners()
        botFallbackTask?.cancel()
        botFallbackTask = nil
        try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
        try? await store.clearPendingSession(userID: user.id)

        let opponent = session.players.first { $0.userID != user.id }
        if let opponent, !opponent.isBot { opponentUser = try? await store.fetchUser(id: opponent.userID) }
        guard isCurrentSearch(searchID) else { return }
        activeSearchID = nil
        state = .matchFound(session: session)
        startMatchCountdown(session: session)
    }

    // MARK: - Session

    private func listenForBothReady(session: GameSession) {
        currentSessionID = session.id
        let handle = rtdb.listenForBothReady(sessionID: session.id) { [weak self] in
            Task { @MainActor in
                self?.state = .inMatch(session: session)
                self?.startGameTimer()
                self?.listenForResults(session: session)
                self?.listenForSessionStatus(sessionID: session.id)
                self?.scheduleBotResultIfNeeded(session: session)
            }
        }
        rtdbHandles.append((session.id, handle))
    }

    private func listenForSessionStatus(sessionID: String) {
        sessionListener?.remove()
        sessionListener = store.listenForSession(id: sessionID) { [weak self] session in
            Task { @MainActor in
                guard let self, session.status == .finished else { return }
                self.gameTimer?.invalidate()
                if let results = session.playerResults {
                    self.playerResults = self.playerResults.merging(results) { _, sessionResult in sessionResult }
                }
                if session.isRanked {
                    await self.applyFinishedRewards(session)
                } else {
                    self.rewardSnapshot = nil
                    self.rewardErrorMessage = nil
                }
                self.state = .finished(session: session)
                self.finishedSessionID = session.id
            }
        }
    }

    func submitResult(_ result: MatchPlayerResult, session: GameSession) async {
        guard result.userID == user?.id else { return }
        if let existing = playerResults[result.userID] {
            guard session.mode == .wordle,
                  !existing.isFinalWordleResult,
                  result.wordleRoundCount >= existing.wordleRoundCount else { return }
        }
        do {
            try await rtdb.submitResult(sessionID: session.id, result: result)
            playerResults[result.userID] = result
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func listenForResults(session: GameSession) {
        let handle = rtdb.listenForResults(sessionID: session.id) { [weak self] results in
            Task { @MainActor in
                self?.playerResults = results
                if let self,
                   session.mode == .wordle,
                   let bot = session.botPlayer,
                   results[bot.userID] == nil,
                   results.values.contains(where: { !$0.userID.hasPrefix(BotMatchService.botIDPrefix) && $0.solvedRounds >= 2 }) {
                    await self.submitBotResultIfNeeded(session: session, bot: bot, minimumElapsed: self.elapsedSeconds)
                    return
                }
                if MatchResolver.canResolve(session: session, results: results) {
                    await self?.resolveMatch(session: session, results: results)
                }
            }
        }
        rtdbHandles.append((session.id, handle))
    }

    private func resolveMatch(session: GameSession, results: [String: MatchPlayerResult]) async {
        guard case .inMatch = state else { return }
        gameTimer?.invalidate()

        let resolution = MatchResolver.resolve(session: session, results: results)
        let outcome = RankingService.MatchOutcome(
            sessionID: session.id,
            mode: session.mode,
            difficulty: session.difficulty,
            winnerID: resolution.winnerID,
            players: session.players.map { p in
                var mp = p
                mp.finishTime = results[p.userID]?.elapsedSeconds
                return mp
            },
            playerResults: results,
            winnerReason: resolution.reason
        )
        do {
            try await ranking.processOutcome(outcome)
            let updated = try await store.fetchSession(id: session.id)
            if updated.isRanked {
                await applyFinishedRewards(updated)
            } else {
                rewardSnapshot = nil
                rewardErrorMessage = nil
            }
            state = .finished(session: updated)
            finishedSessionID = updated.id
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func forfeitMatch(session: GameSession, resetAfterProcessing: Bool = false) async {
        guard !isForfeiting,
              case .inMatch = state,
              let forfeiter = user,
              let opponent = session.players.first(where: { $0.userID != forfeiter.id }) else { return }

        isForfeiting = true
        gameTimer?.invalidate()

        let forfeiterResult = MatchPlayerResult(
            userID: forfeiter.id,
            mode: session.mode,
            completed: false,
            elapsedSeconds: elapsedSeconds,
            score: 0,
            progress: 0,
            status: "Forfeited",
            summary: ["forfeit": "true"],
            details: [session.isRanked ? "Quit the active ranked match." : "Left the exhibition match."]
        )

        let opponentResult = playerResults[opponent.userID] ?? MatchPlayerResult(
            userID: opponent.userID,
            mode: session.mode,
            completed: true,
            elapsedSeconds: elapsedSeconds,
            score: 0,
            progress: 0,
            status: "Won by forfeit",
            summary: ["forfeitWin": "true"],
            details: [session.isRanked ? "Opponent forfeited before the match was completed." : "Opponent left the exhibition match."]
        )

        var results = playerResults
        results[forfeiter.id] = forfeiterResult
        results[opponent.userID] = opponentResult
        playerResults = results

        let outcome = RankingService.MatchOutcome(
            sessionID: session.id,
            mode: session.mode,
            difficulty: session.difficulty,
            winnerID: opponent.userID,
            players: session.players.map { p in
                var mp = p
                mp.finishTime = results[p.userID]?.elapsedSeconds
                return mp
            },
            playerResults: results,
            winnerReason: "Opponent forfeited"
        )

        do {
            try await ranking.processOutcome(outcome)
            let updated = try await store.fetchSession(id: session.id)
            if updated.isRanked {
                await applyFinishedRewards(updated)
            } else {
                rewardSnapshot = nil
                rewardErrorMessage = nil
            }
            state = .finished(session: updated)
            finishedSessionID = updated.id
            if resetAfterProcessing {
                reset()
            }
        } catch {
            state = .error(error.localizedDescription)
        }
        isForfeiting = false
    }

    func retryFinishedRewards(session: GameSession) async {
        await applyFinishedRewards(session)
        if rewardErrorMessage == nil {
            finishedSessionID = session.id
        }
    }


    func beginRematchListening(session: GameSession) {
        guard !session.containsBot else { return }
        guard (session.isRanked || session.isExhibition), session.status == .finished else { return }
        if rematchListeningSessionID == session.id { return }
        rematchListeningSessionID = session.id
        rematchRequests = []
        rematchErrorMessage = nil
        dismissedRematchInviteSessionID = nil
        rematchPublishedSessionID = nil

        let handle = rtdb.listenForRematch(sessionID: session.id) { [weak self] update in
            Task { @MainActor in
                await self?.handleRematchUpdate(update, session: session)
            }
        }
        rtdbHandles.append((session.id, handle))
    }

    func requestRematch(session: GameSession) async {
        guard !session.containsBot else {
            dismissedRematchInviteSessionID = session.id
            rematchErrorMessage = "Training bots do not rematch. Queue again for another match."
            try? await rtdb.publishRematchError(sessionID: session.id, message: "Training bot declined rematch.")
            return
        }
        guard (session.isRanked || session.isExhibition), let user else { return }
        if session.isRanked {
            guard let player = session.players.first(where: { $0.userID == user.id }) else { return }
            guard user.coins >= player.wager else {
                rematchErrorMessage = "Not enough coins for rematch."
                return
            }
            guard user.rankedAccess.canStartRanked(mode: session.mode) else {
                rematchErrorMessage = "No ranked entry is available for this mode today."
                return
            }
        }
        beginRematchListening(session: session)
        dismissedRematchInviteSessionID = nil
        rematchErrorMessage = nil
        do {
            try? await rtdb.clearRematchError(sessionID: session.id)
            try await rtdb.requestRematch(sessionID: session.id, userID: user.id)
            rematchRequests.insert(user.id)
        } catch {
            rematchErrorMessage = error.localizedDescription
        }
    }

    func cancelRematch(session: GameSession) async {
        guard let userID = user?.id else { return }
        do {
            try await rtdb.cancelRematch(sessionID: session.id, userID: userID)
            rematchRequests.remove(userID)
        } catch {
            rematchErrorMessage = error.localizedDescription
        }
    }

    func declineRematch(session: GameSession) async {
        if session.containsBot {
            dismissedRematchInviteSessionID = session.id
            rematchErrorMessage = "Training bot declined rematch."
            try? await rtdb.publishRematchError(sessionID: session.id, message: "Training bot declined rematch.")
            return
        }
        dismissedRematchInviteSessionID = session.id
        rematchErrorMessage = nil
        try? await rtdb.publishRematchError(sessionID: session.id, message: "Rematch declined.")
    }

    private func handleRematchUpdate(_ update: RematchUpdate, session: GameSession) async {
        guard !session.containsBot else {
            rematchRequests = []
            rematchErrorMessage = "Training bot declined rematch."
            return
        }
        rematchRequests = update.requests
        if let error = update.error {
            rematchErrorMessage = error
            isStartingRematch = false
            return
        }
        if let newSessionID = update.newSessionID {
            await enterRematchSession(id: newSessionID)
            return
        }
        guard shouldCreateRematch(from: session, requests: update.requests), !isStartingRematch else { return }
        await createAndPublishRematch(from: session)
    }

    private func shouldCreateRematch(from session: GameSession, requests: Set<String>) -> Bool {
        guard let userID = user?.id else { return false }
        let playerIDs = session.players.map(\.userID)
        guard playerIDs.count == 2, playerIDs.allSatisfy({ requests.contains($0) }) else { return false }
        return userID == playerIDs.sorted().first
    }

    private func createAndPublishRematch(from session: GameSession) async {
        guard rematchPublishedSessionID == nil else { return }
        isStartingRematch = true
        do {
            let rematch = try await store.createRematchSession(from: session)
            rematchPublishedSessionID = rematch.id
            try await rtdb.publishRematchSessionID(oldSessionID: session.id, newSessionID: rematch.id)
            await enterRematchSession(rematch)
        } catch FirestoreServiceError.insufficientCoins {
            let message = "Not enough coins for rematch."
            rematchErrorMessage = message
            try? await rtdb.publishRematchError(sessionID: session.id, message: message)
            isStartingRematch = false
        } catch {
            rematchErrorMessage = error.localizedDescription
            isStartingRematch = false
        }
    }

    private func enterRematchSession(id sessionID: String) async {
        guard rematchPublishedSessionID != sessionID else { return }
        rematchPublishedSessionID = sessionID
        do {
            let session = try await store.fetchSession(id: sessionID)
            await enterRematchSession(session)
        } catch {
            rematchErrorMessage = error.localizedDescription
            isStartingRematch = false
        }
    }

    private func enterRematchSession(_ session: GameSession) async {
        guard let user, session.players.contains(where: { $0.userID == user.id }) else { return }
        guard await consumeRankedEntryIfNeeded(for: session) else {
            isStartingRematch = false
            return
        }
        removeRealtimeObservers()
        sessionListener?.remove()
        sessionListener = nil
        countdownTask?.cancel()
        countdownTask = nil
        gameTimer?.invalidate()
        currentSessionID = session.id
        rematchListeningSessionID = nil
        rematchRequests = []
        dismissedRematchInviteSessionID = nil
        rematchErrorMessage = nil
        isStartingRematch = false
        playerResults = [:]
        elapsedSeconds = 0
        matchCountdown = 5
        finishedSessionID = nil
        rewardErrorMessage = nil
        rewardSnapshot = nil
        mode = session.mode
        difficulty = session.difficulty
        if let me = session.players.first(where: { $0.userID == user.id }) {
            selectedWager = WagerTier(rank: user.rank(for: session.mode).displayTier, label: "Rematch", amount: me.wager)
        }
        if let opponentID = session.players.first(where: { $0.userID != user.id })?.userID {
            opponentUser = try? await store.fetchUser(id: opponentID)
        }
        state = .matchFound(session: session)
        startMatchCountdown(session: session)
    }

    private func consumeRankedEntryIfNeeded(for session: GameSession) async -> Bool {
        guard session.isRanked else { return true }
        guard let currentUser = user else { return false }
        do {
            user = try await store.consumeRankedEntry(userID: currentUser.id, mode: session.mode, sessionID: session.id)
            return true
        } catch {
            state = .error(error.localizedDescription)
            return false
        }
    }

    private func applyFinishedRewards(_ session: GameSession) async {
        guard session.isRanked else {
            rewardSnapshot = nil
            rewardErrorMessage = nil
            return
        }
        guard let beforeUser = user else { return }
        do {
            let outcome = try await ranking.applyFinishedSession(session, for: beforeUser.id)
            user = outcome.user
            if outcome.didApplyRewards {
                rewardSnapshot = PostMatchRewardSnapshot.make(
                    session: session,
                    userID: beforeUser.id,
                    before: beforeUser,
                    after: outcome.user,
                    didApplyRewards: true
                )
            } else {
                rewardSnapshot = PostMatchRewardSnapshot.staticSnapshot(session: session, user: outcome.user)
            }
            rewardErrorMessage = nil
        } catch {
            rewardErrorMessage = "Result saved. Tap to refresh rewards."
            rewardSnapshot = PostMatchRewardSnapshot.staticSnapshot(session: session, user: beforeUser)
        }
    }

    // MARK: - Helpers

    private func startGameTimer() {
        elapsedSeconds = 0
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedSeconds += 1 }
        }
    }

    private func scheduleBotFallback(user: AppUser, mode: GameMode, difficulty: Difficulty, wager: WagerTier, searchID: UUID) {
        guard BotMatchService.canOfferBot(to: user, mode: mode) else { return }
        botFallbackTask?.cancel()
        let delay = BotMatchService.fallbackDelaySeconds()
        botFallbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            await self?.createBotMatchIfStillSearching(user: user, mode: mode, difficulty: difficulty, wager: wager, searchID: searchID)
        }
    }

    private func createBotMatchIfStillSearching(user: AppUser, mode: GameMode, difficulty: Difficulty, wager: WagerTier, searchID: UUID) async {
        guard isCurrentSearch(searchID), case .searching = state else { return }
        do {
            if let sessionID = try await store.createBronzeBotSession(
                user: user,
                mode: mode,
                difficulty: difficulty,
                wager: wager.amount,
                searchID: searchID.uuidString
            ) {
                await consumeMatch(sessionID: sessionID, pendingSearchID: searchID.uuidString, searchID: searchID)
            }
        } catch {
            // Bot fallback should never interrupt normal matchmaking.
        }
    }

    private func scheduleBotResultIfNeeded(session: GameSession) {
        guard let bot = session.botPlayer else { return }
        botResultTask?.cancel()
        let delay = BotMatchService.resultDelaySeconds(for: session)
        botResultTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            await self?.submitBotResultIfNeeded(session: session, bot: bot, minimumElapsed: delay)
        }
    }

    private func submitBotResultIfNeeded(session: GameSession, bot: MatchPlayer, minimumElapsed: Int) async {
        guard case .inMatch(let currentSession) = state,
              currentSession.id == session.id,
              playerResults[bot.userID] == nil else { return }
        let result = BotMatchService.makeResult(
            for: session,
            bot: bot,
            elapsedSeconds: max(elapsedSeconds, minimumElapsed)
        )
        do {
            try await rtdb.submitResult(sessionID: session.id, result: result)
            playerResults[bot.userID] = result
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func cancelBotTasks() {
        botFallbackTask?.cancel()
        botFallbackTask = nil
        botResultTask?.cancel()
        botResultTask = nil
    }

    private func tearDownListeners() {
        userDocListener?.remove()
        userDocListener = nil
        queueListener?.remove()
        queueListener = nil
        matchDiscoveryListener?.remove()
        matchDiscoveryListener = nil
        sessionListener?.remove()
        sessionListener = nil
    }


    private func removeRealtimeObservers() {
        rtdbHandles.forEach { item in
            rtdb.removeObserver(handle: item.handle, sessionID: item.sessionID)
        }
        rtdbHandles = []
    }

    private func cancelLocalRematchRequestIfNeeded() {
        guard let sessionID = rematchListeningSessionID,
              let userID = user?.id,
              rematchRequests.contains(userID) else { return }
        Task { try? await rtdb.cancelRematch(sessionID: sessionID, userID: userID) }
    }

    private func clearRematchState() {
        rematchRequests = []
        rematchErrorMessage = nil
        isStartingRematch = false
        dismissedRematchInviteSessionID = nil
        rematchPublishedSessionID = nil
    }

    func reset() {
        activeSearchID = nil
        tearDownListeners()
        countdownTask?.cancel()
        countdownTask = nil
        cancelBotTasks()
        if let user {
            let mode = self.mode
            let difficulty = self.difficulty
            Task {
                try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
                try? await store.clearPendingSession(userID: user.id)
            }
        }
        cancelLocalRematchRequestIfNeeded()
        removeRealtimeObservers()
        currentSessionID = nil
        rematchListeningSessionID = nil
        gameTimer?.invalidate()
        state = .idle
        elapsedSeconds = 0
        playerResults = [:]
        opponentUser = nil
        selectedWager = nil
        finishedSessionID = nil
        rewardErrorMessage = nil
        rewardSnapshot = nil
        clearRematchState()
        isForfeiting = false
    }

    func handleViewDisappeared() {
        if case .inMatch(let session) = state, finishedSessionID == nil, !isForfeiting {
            Task { await forfeitMatch(session: session, resetAfterProcessing: true) }
        } else {
            reset()
        }
    }

    private func isCurrentSearch(_ searchID: UUID) -> Bool {
        activeSearchID == searchID
    }

    func startMatchCountdown(session: GameSession) {
        matchCountdown = 5
        countdownTask?.cancel()
        countdownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for tick in stride(from: 5, through: 1, by: -1) {
                if Task.isCancelled { return }
                self.matchCountdown = tick
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            if !Task.isCancelled {
                await self.confirmReady(session: session)
            }
        }
    }

    func confirmReady(session: GameSession) async {
        do {
            try await rtdb.markReady(sessionID: session.id, userID: user?.id ?? "")
            if let bot = session.botPlayer {
                try await rtdb.markReady(sessionID: session.id, userID: bot.userID)
            }
            listenForBothReady(session: session)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func abortMatchFound(session: GameSession) async {
        countdownTask?.cancel()
        countdownTask = nil
        if session.isRanked, let userID = user?.id {
            try? await store.updateCoins(userID: userID, delta: -1)
        }
        reset()
    }
}

struct MatchResolution {
    let winnerID: String?
    let reason: String
}

enum MatchResolver {
    static func canResolve(session: GameSession, results: [String: MatchPlayerResult]) -> Bool {
        if session.mode == .wordle {
            if hasClinchedWordleResult(results) { return true }
            return results.count >= session.players.count && results.values.allSatisfy(\.isFinalWordleResult)
        }
        return results.count >= session.players.count
    }

    static func resolve(session: GameSession, results: [String: MatchPlayerResult]) -> MatchResolution {
        let ordered = session.players.compactMap { results[$0.userID] }
        if session.mode == .wordle, ordered.count == 1, let resolution = resolveClinchedWordle(ordered[0]) {
            return resolution
        }
        guard ordered.count == session.players.count, ordered.count == 2 else {
            return MatchResolution(winnerID: nil, reason: "Waiting for both players")
        }
        let a = ordered[0]
        let b = ordered[1]

        switch session.mode {
        case .wordle:
            return compareWordle(a, b)
        case .anagram:
            return compareWordScore(a, b, label: "Anagrams")
        case .wordHunt:
            return compareWordScore(a, b, label: "Word Hunt")
        case .hangman:
            return compareHangman(a, b)
        case .sudoku:
            return compareCompletion(a, b)
        case .gridlock:
            return compareGridlock(a, b)
        case .colorLink:
            return compareColorLink(a, b)
        case .minesweeper:
            return compareMinesweeper(a, b)
        }
    }

    private static func hasClinchedWordleResult(_ results: [String: MatchPlayerResult]) -> Bool {
        results.values.contains { $0.mode == .wordle && $0.solvedRounds >= 2 }
    }

    private static func resolveClinchedWordle(_ result: MatchPlayerResult) -> MatchResolution? {
        guard result.solvedRounds >= 2 else { return nil }
        return MatchResolution(winnerID: result.userID, reason: "Won \(result.solvedRounds) Wordles")
    }

    private static func compareWordle(_ a: MatchPlayerResult, _ b: MatchPlayerResult) -> MatchResolution {
        if a.solvedRounds != b.solvedRounds {
            let winner = a.solvedRounds > b.solvedRounds ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Won \(winner.solvedRounds) Wordles")
        }
        if a.totalGuesses != b.totalGuesses {
            let winner = a.totalGuesses < b.totalGuesses ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Solved in fewer guesses")
        }
        return compareElapsed(a, b, fallback: "Same Wordle result")
    }

    private static func compareWordScore(_ a: MatchPlayerResult, _ b: MatchPlayerResult, label: String) -> MatchResolution {
        if a.score != b.score {
            let winner = a.score > b.score ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Higher \(label) score")
        }
        if a.wordCount != b.wordCount {
            let winner = a.wordCount > b.wordCount ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Found more words")
        }
        if a.longestWordLength != b.longestWordLength {
            let winner = a.longestWordLength > b.longestWordLength ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Found the longest word")
        }
        return MatchResolution(winnerID: nil, reason: "Same score and word count")
    }

    private static func compareHangman(_ a: MatchPlayerResult, _ b: MatchPlayerResult) -> MatchResolution {
        if a.completed != b.completed {
            let winner = a.completed ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Solved the Hangman word")
        }
        if a.completed && b.completed {
            if a.wrongGuessCount != b.wrongGuessCount {
                let winner = a.wrongGuessCount < b.wrongGuessCount ? a : b
                return MatchResolution(winnerID: winner.userID, reason: "Solved with fewer misses")
            }
            return compareElapsed(a, b, fallback: "Same Hangman result")
        }
        if a.revealedLetterCount != b.revealedLetterCount {
            let winner = a.revealedLetterCount > b.revealedLetterCount ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Revealed more letters")
        }
        if a.wrongGuessCount != b.wrongGuessCount {
            let winner = a.wrongGuessCount < b.wrongGuessCount ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Had fewer misses")
        }
        return compareElapsed(a, b, fallback: "Same Hangman progress")
    }

    private static func compareCompletion(_ a: MatchPlayerResult, _ b: MatchPlayerResult) -> MatchResolution {
        if a.completed != b.completed {
            let winner = a.completed ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Completed the puzzle")
        }
        if a.completed && b.completed {
            return compareElapsed(a, b, fallback: "Both completed in the same time")
        }
        if a.progress != b.progress {
            let winner = a.progress > b.progress ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Better puzzle progress")
        }
        return compareElapsed(a, b, fallback: "Same puzzle progress")
    }

    private static func compareGridlock(_ a: MatchPlayerResult, _ b: MatchPlayerResult) -> MatchResolution {
        if a.completed != b.completed {
            let winner = a.completed ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Matched the Grid Duel target")
        }
        if a.completed && b.completed {
            if a.moveCount != b.moveCount {
                let winner = a.moveCount < b.moveCount ? a : b
                return MatchResolution(winnerID: winner.userID, reason: "Solved in fewer moves")
            }
            return compareElapsed(a, b, fallback: "Same Grid Duel result")
        }
        if a.progress != b.progress {
            let winner = a.progress > b.progress ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Higher pattern-match progress")
        }
        if a.moveCount != b.moveCount {
            let winner = a.moveCount < b.moveCount ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Used fewer moves")
        }
        return compareElapsed(a, b, fallback: "Same Grid Duel pattern progress")
    }

    private static func compareColorLink(_ a: MatchPlayerResult, _ b: MatchPlayerResult) -> MatchResolution {
        if a.completed != b.completed {
            let winner = a.completed ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Filled the Color Link board")
        }
        if a.completed && b.completed {
            return compareElapsed(a, b, fallback: "Both filled the board")
        }
        if a.progress != b.progress {
            let winner = a.progress > b.progress ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Higher board fill")
        }
        if a.solvedPairs != b.solvedPairs {
            let winner = a.solvedPairs > b.solvedPairs ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Connected more color pairs")
        }
        return compareElapsed(a, b, fallback: "Same Color Link fill")
    }

    private static func compareMinesweeper(_ a: MatchPlayerResult, _ b: MatchPlayerResult) -> MatchResolution {
        if a.hitMine != b.hitMine {
            let winner = a.hitMine ? b : a
            return MatchResolution(winnerID: winner.userID, reason: "Avoided the mine")
        }
        if a.completed != b.completed {
            let winner = a.completed ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Cleared the board")
        }
        if a.score != b.score {
            let winner = a.score > b.score ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Revealed more safe cells")
        }
        return compareElapsed(a, b, fallback: "Same Minesweeper result")
    }

    private static func compareElapsed(_ a: MatchPlayerResult, _ b: MatchPlayerResult, fallback: String) -> MatchResolution {
        if a.elapsedSeconds != b.elapsedSeconds {
            let winner = a.elapsedSeconds < b.elapsedSeconds ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Faster finish")
        }
        return MatchResolution(winnerID: nil, reason: fallback)
    }
}
