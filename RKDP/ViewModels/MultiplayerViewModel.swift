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
    @Published var playerResults: [String: MatchPlayerResult] = [:]
    @Published var elapsedSeconds: Int = 0
    @Published var opponentUser: AppUser? = nil
    @Published var matchCountdown: Int = 5
    @Published var finishedSessionID: String?
    @Published var rewardErrorMessage: String?
    @Published var rewardSnapshot: PostMatchRewardSnapshot?
    @Published var casualRewardMessage: String?
    @Published var rematchRequests: Set<String> = []
    @Published var rematchErrorMessage: String?
    @Published var isStartingRematch = false
    @Published var dismissedRematchInviteSessionID: String?
    @Published var readySessionIDs: Set<String> = []
    private var countdownTask: Task<Void, Never>?
    private var sharedCountdownSessionID: String?
    private var sharedCountdownStartedAt: Date?
    private var botFallbackTask: Task<Void, Never>?
    private var botResultTask: Task<Void, Never>?

    private let store = FirestoreService.shared
    // Verified matches use Firestore/callables and need no legacy RTDB instance.
    private lazy var rtdb = RealtimeDBService.shared
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
    private var officialSearchTask: Task<Void, Never>?
    private var officialHeartbeatTask: Task<Void, Never>?
    private var officialProgressTask: Task<Void, Never>?
    private var usesOfficialSearch = false

    private static let officialProgressModes: Set<GameMode> = [
        .sudoku, .gridlock, .colorLink, .minesweeper, .wordle, .anagram, .wordHunt, .hangman
    ]

    var user: AppUser?
    var mode: GameMode = .sudoku
    var difficulty: Difficulty = .medium

    // MARK: - Matchmaking

    func startSearch(user: AppUser, mode: GameMode, difficulty: Difficulty) async {
        guard mode.rankedDifficulties.contains(difficulty) else {
            state = .error("\(mode.displayName) ranked is only available at \(mode.rankedDifficulties.map { mode.difficultyLabel($0) }.joined(separator: ", ")).")
            return
        }
        guard FirestoreService.serverWalletRolloutEnabled || user.rankedAccess.canStartRanked(mode: mode) else {
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
        casualRewardMessage = nil
        clearRematchState()
        readySessionIDs = []

        self.user = user
        self.mode = mode
        self.difficulty = difficulty
        playerResults = [:]
        elapsedSeconds = 0
        state = .searching

        do {
            // 0. Clear any stale state from a previous attempt before listening.
            if try await store.usesServerWallet(userID: user.id) {
                beginOfficialSearch(user: user, mode: mode, kind: .ranked, searchID: searchID)
                return
            }
            try? await store.clearPendingSession(userID: user.id)
            try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
            guard isCurrentSearch(searchID) else { return }

            // 1. Listen for sessions that include us. This avoids requiring one
            //    player to write pendingSessionID into the opponent's user doc.
            matchDiscoveryListener = store.listenForActiveSession(
                userID: user.id,
                mode: mode,
                difficulty: difficulty,
                matchKind: .ranked
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
                user: user, mode: mode, difficulty: difficulty, wager: 0, searchID: searchID.uuidString
            ) { [weak self] sessionID in
                Task { await self?.consumeMatch(sessionID: sessionID, pendingSearchID: searchID.uuidString, searchID: searchID) }
            }

            // 3. Write to queue and try to pair immediately
            try await store.joinAndPair(user: user, mode: mode, difficulty: difficulty, wager: 0, searchID: searchID.uuidString)
            scheduleBotFallback(user: user, mode: mode, difficulty: difficulty, searchID: searchID)

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

    func startCasualSearch(user: AppUser, mode: GameMode, difficulty: Difficulty) async {
        guard mode.casualDifficulties.contains(difficulty) else {
            state = .error("\(mode.displayName) casual is only available at \(mode.casualDifficulties.map { mode.difficultyLabel($0) }.joined(separator: ", ")).")
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
        casualRewardMessage = nil
        clearRematchState()
        readySessionIDs = []

        self.user = user
        self.mode = mode
        self.difficulty = difficulty
        state = .searching

        do {
            if try await store.usesServerWallet(userID: user.id) {
                beginOfficialSearch(user: user, mode: mode, kind: .casual, searchID: searchID)
                return
            }
            try? await store.clearPendingSession(userID: user.id)
            try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
            guard isCurrentSearch(searchID) else { return }

            matchDiscoveryListener = store.listenForActiveSession(
                userID: user.id,
                mode: mode,
                difficulty: difficulty,
                matchKind: .casual
            ) { [weak self] session in
                Task { await self?.consumeDiscoveredMatch(session: session, searchID: searchID) }
            }

            userDocListener = store.listenForMatch(userID: user.id) { [weak self] sessionID, pendingSearchID in
                Task { await self?.consumeMatch(sessionID: sessionID, pendingSearchID: pendingSearchID, searchID: searchID) }
            }

            queueListener = store.listenForCasualQueueMatch(
                user: user,
                mode: mode,
                difficulty: difficulty,
                searchID: searchID.uuidString
            ) { [weak self] sessionID in
                Task { await self?.consumeMatch(sessionID: sessionID, pendingSearchID: searchID.uuidString, searchID: searchID) }
            }

            try await store.joinAndPairCasual(user: user, mode: mode, difficulty: difficulty, searchID: searchID.uuidString)

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
        readySessionIDs = []

        self.user = user
        self.mode = session.mode
        self.difficulty = session.difficulty
        playerResults = session.playerResults ?? [:]
        opponentUser = nil
        elapsedSeconds = 0
        matchCountdown = 5
        finishedSessionID = nil
        rewardErrorMessage = nil
        rewardSnapshot = nil
        casualRewardMessage = nil
        currentSessionID = session.id

        if let opponentID = session.players.first(where: { $0.userID != user.id })?.userID {
            opponentUser = try? await store.fetchUser(id: opponentID)
        }
        if session.status == .finished {
            gameTimer?.invalidate()
            rewardSnapshot = nil
            rewardErrorMessage = nil
            casualRewardMessage = nil
            state = .finished(session: session)
            finishedSessionID = session.id
            return
        }
        if session.isAsyncExhibition {
            if session.usesVerifiedSocial {
                state = .matchFound(session: session)
                await confirmReady(session: session)
                return
            }
            state = .inMatch(session: session)
            listenForResults(session: session)
            listenForSessionStatus(sessionID: session.id)
        } else {
            state = .matchFound(session: session)
            if session.usesServerAuthority {
                await confirmReady(session: session)
            } else if !session.isLiveExhibition {
                startMatchCountdown(session: session)
            }
        }
    }

    func cancelSearch() async {
        guard let user else { return }
        let cancellingID = activeSearchID
        activeSearchID = nil
        tearDownListeners()
        countdownTask?.cancel()
        countdownTask = nil
        cancelBotTasks()
        if usesOfficialSearch, let cancellingID {
            if let reply = try? await store.officialCancel(userID: user.id, requestID: cancellingID.uuidString), let id = reply.sessionID {
                try? await store.officialAction("forfeit", userID: user.id, sessionID: id)
            }
            usesOfficialSearch = false
            state = .idle
            return
        }
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

        // Official discovery invokes this method from inside officialSearchTask.
        // Releasing that task is safe; canceling it here interrupts the ready call.
        tearDownDiscoveryListeners()
        officialSearchTask = nil
        officialHeartbeatTask?.cancel()
        officialHeartbeatTask = nil
        botFallbackTask?.cancel()
        botFallbackTask = nil
        try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
        try? await store.clearPendingSession(userID: user.id)

        let opponent = session.players.first { $0.userID != user.id }
        if let opponent, !opponent.isBot { opponentUser = try? await store.fetchUser(id: opponent.userID) }
        guard isCurrentSearch(searchID) else { return }
        activeSearchID = nil
        state = .matchFound(session: session)
        if session.usesServerAuthority {
            await confirmReady(session: session)
        } else {
            startMatchCountdown(session: session)
        }
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
                guard let self else { return }
                if session.usesVerifiedResults {
                    if session.status == .abandoned {
                        self.officialHeartbeatTask?.cancel()
                        self.state = .error("This match was cancelled or expired. No match coins were awarded.")
                        return
                    }
                    if session.status == .inProgress {
                        self.stopMatchCountdown()
                        if case .matchFound = self.state {
                            self.state = .inMatch(session: session)
                            self.startGameTimer()
                        }
                        return
                    }
                    if session.usesServerAuthority, session.status == .waiting {
                        self.state = .matchFound(session: session)
                        self.syncSharedMatchCountdown(session)
                        return
                    }
                }
                guard session.status == .finished else { return }
                var finishedSession = session
                if session.usesServerAuthority, Self.officialProgressModes.contains(session.mode), let userID = self.user?.id,
                   await self.retryOfficialProgress(sessionID: session.id, userID: userID),
                   let refreshed = try? await self.store.fetchSession(id: session.id) {
                    finishedSession = refreshed
                }
                self.officialHeartbeatTask?.cancel()
                self.gameTimer?.invalidate()
                if let results = finishedSession.playerResults {
                    self.playerResults = self.playerResults.merging(results) { _, sessionResult in sessionResult }
                }
                if finishedSession.isRanked {
                    await self.applyFinishedRewards(finishedSession)
                } else if finishedSession.isCasual {
                    await self.applyFinishedCasualRewards(finishedSession)
                } else {
                    self.rewardSnapshot = nil
                    self.rewardErrorMessage = nil
                    self.casualRewardMessage = nil
                    if finishedSession.isExhibition, let user = self.user {
                        if let updated = try? await self.store.recordOnlineBestIfNeeded(session: finishedSession, for: user.id) {
                            self.user = updated
                        }
                    }
                }
                self.state = .finished(session: finishedSession)
                self.finishedSessionID = finishedSession.id
            }
        }
    }

    func submitResult(_ result: MatchPlayerResult, session: GameSession) async {
        guard result.userID == user?.id else { return }
        if session.usesVerifiedResults {
            guard let evidence = result.rewardEvidenceJSON else { return }
            if !MatchResolver.isFinalResult(result) {
                guard session.usesServerAuthority, Self.officialProgressModes.contains(result.mode),
                      playerResults[result.userID].map({ MatchResolver.isFinalResult($0) }) != true else { return }
                if result.mode == .wordle {
                    guard MultiplayerPuzzleDataFactory.decodeWordle(session.puzzleData)?.matchRounds == 1 else { return }
                }
                UserDefaults.standard.set(evidence, forKey: officialProgressKey(session.id, result.userID))
                scheduleOfficialProgress(sessionID: session.id, userID: result.userID)
                return
            }
            officialProgressTask?.cancel()
            officialProgressTask = nil
            guard playerResults[result.userID].map({ MatchResolver.isFinalResult($0) }) != true else { return }
            playerResults[result.userID] = result
            let key = officialEvidenceKey(session.id, result.userID)
            UserDefaults.standard.set(evidence, forKey: key)
            if let data = try? JSONEncoder().encode(result) { UserDefaults.standard.set(data, forKey: key + "_result") }
            await retryOfficialSubmission(sessionID: session.id, userID: result.userID)
            return
        }
        if session.isAsyncExhibition {
            guard MatchResolver.isFinalResult(result) else { return }
            if let existing = playerResults[result.userID],
               MatchResolver.isFinalResult(existing) {
                return
            }
        } else if let existing = playerResults[result.userID] {
            switch session.mode {
            case .wordle:
                guard !existing.isFinalWordleResult,
                      result.wordleRoundCount >= existing.wordleRoundCount else { return }
            case .hangman:
                guard !MatchResolver.isFinalHangmanResult(existing),
                      result.wordleRoundCount >= existing.wordleRoundCount else { return }
                if result.wordleRoundCount == existing.wordleRoundCount,
                   result.hangmanGuessCount < existing.hangmanGuessCount { return }
            default:
                return
            }
        }
        do {
            try await rtdb.submitResult(sessionID: session.id, result: result)
            playerResults[result.userID] = result
            if session.isAsyncExhibition {
                try? await store.saveAsyncExhibitionResult(sessionID: session.id, result: result)
            }
            if MatchResolver.isFinalResult(result) {
                await recordDailyPlayIfNeeded(activityID: "match_\(session.id)_\(result.userID)")
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func recordDailyPlayIfNeeded(activityID: String) async {
        guard let currentUser = user else { return }
        do {
            // Migrated ranked/casual settlement includes daily play atomically.
            // No client-provided activity ID may independently mint a bonus.
            if try await store.usesServerWallet(userID: currentUser.id) { return }
            user = try await store.recordDailyPlay(userID: currentUser.id, activityID: activityID)
        } catch {
            #if DEBUG
            print("Daily play record failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func listenForResults(session: GameSession) {
        let handle = rtdb.listenForResults(sessionID: session.id) { [weak self] results in
            Task { @MainActor in
                self?.playerResults = results
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
            } else if updated.isCasual {
                await applyFinishedCasualRewards(updated)
            } else {
                rewardSnapshot = nil
                rewardErrorMessage = nil
                casualRewardMessage = nil
            }
            state = .finished(session: updated)
            finishedSessionID = updated.id
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func forfeitMatch(session: GameSession, resetAfterProcessing: Bool = false) async {
        if session.usesVerifiedResults, let userID = user?.id {
            do {
                try await store.officialAction("forfeit", userID: userID, sessionID: session.id)
                if resetAfterProcessing { reset() }
            } catch {
                rewardErrorMessage = "Could not confirm leaving the match. Reconnect and retry."
            }
            return
        }
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
            details: [session.isRanked ? "Quit the active ranked match." : (session.isCasual ? "Left the casual match." : "Left the exhibition match.")]
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
            details: [session.isRanked ? "Opponent forfeited before the match was completed." : (session.isCasual ? "Opponent left the casual match." : "Opponent left the exhibition match.")]
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
            } else if updated.isCasual {
                await applyFinishedCasualRewards(updated)
            } else {
                rewardSnapshot = nil
                rewardErrorMessage = nil
                casualRewardMessage = nil
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
        guard !session.usesVerifiedResults else { return }
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
        if session.usesVerifiedResults {
            rematchErrorMessage = "Use Play Again to find your next official match."
            return
        }
        guard !session.containsBot else {
            dismissedRematchInviteSessionID = session.id
            rematchErrorMessage = "Training bots do not rematch. Queue again for another match."
            try? await rtdb.publishRematchError(sessionID: session.id, message: "Training bot declined rematch.")
            return
        }
        guard (session.isRanked || session.isExhibition), let user else { return }
        if session.isRanked {
            guard session.players.contains(where: { $0.userID == user.id }) else { return }
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
        if let opponentID = session.players.first(where: { $0.userID != user.id })?.userID {
            opponentUser = try? await store.fetchUser(id: opponentID)
        }
        if session.isAsyncExhibition {
            state = .inMatch(session: session)
            listenForResults(session: session)
            listenForSessionStatus(sessionID: session.id)
        } else {
            state = .matchFound(session: session)
            if session.usesServerAuthority {
                await confirmReady(session: session)
            } else if !session.isLiveExhibition {
                startMatchCountdown(session: session)
            }
        }
    }

    private func consumeRankedEntryIfNeeded(for session: GameSession) async -> Bool {
        if session.usesVerifiedResults { return true }
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
                rewardSnapshot = PostMatchRewardSnapshot.staticSnapshot(session: session, user: outcome.user, recordedCoinReward: outcome.coinReward)
            }
            if let receipt = outcome.walletReceipt {
                let total = receipt.matchReward + receipt.dailyCoins
                // A fresh user snapshot can include another concurrent reward.
                // Animate only this receipt, never the difference between reads.
                rewardSnapshot?.coinDelta = total
                rewardSnapshot?.startingCoins = receipt.balance - total
                rewardSnapshot?.endingCoins = receipt.balance
                rewardSnapshot?.rankDelta = receipt.rankDelta
                rewardSnapshot?.rankPerformanceBonus = receipt.rankPerformanceBonus ?? 0
                if let start = receipt.startingRankPoints ?? session.players.first(where: { $0.userID == beforeUser.id })?.rankPoints {
                    let end = receipt.endingRankPoints ?? max(0, start + receipt.rankDelta)
                    rewardSnapshot?.startingRank.points = start
                    rewardSnapshot?.startingRank.tier = RankTier.tier(for: start)
                    rewardSnapshot?.endingRank.points = end
                    rewardSnapshot?.endingRank.tier = RankTier.tier(for: end)
                    if let snapshot = rewardSnapshot {
                        let oldPosition = snapshot.startingRank.displayTier.rawValue * 3 + snapshot.startingRank.division.rawValue
                        let newPosition = snapshot.endingRank.displayTier.rawValue * 3 + snapshot.endingRank.division.rawValue
                        rewardSnapshot?.didPromote = newPosition > oldPosition
                        rewardSnapshot?.didDemote = newPosition < oldPosition
                    }
                }
            }
            rewardErrorMessage = nil
        } catch {
            rewardErrorMessage = "Result saved. Tap to refresh rewards."
            rewardSnapshot = PostMatchRewardSnapshot.staticSnapshot(session: session, user: beforeUser)
        }
    }

    private func applyFinishedCasualRewards(_ session: GameSession) async {
        guard session.isCasual, let currentUser = user else {
            casualRewardMessage = nil
            return
        }
        do {
            let outcome = try await store.applyFinishedCasualSession(session, for: currentUser.id)
            user = outcome.user
            rewardSnapshot = nil
            rewardErrorMessage = nil
            if let receipt = outcome.walletReceipt {
                if receipt.matchReward > 0 {
                    casualRewardMessage = "+\(receipt.matchReward) casual coins"
                } else if receipt.reason == "casualLimit" {
                    casualRewardMessage = "Daily casual coin cap reached"
                } else {
                    casualRewardMessage = "No match coins awarded"
                }
                if receipt.dailyCoins > 0 {
                    casualRewardMessage = (casualRewardMessage ?? "") + " · +\(receipt.dailyCoins) daily bonus"
                }
            } else if outcome.coinDelta > 0 {
                casualRewardMessage = "+\(outcome.coinDelta) casual coins"
            } else if outcome.didApplyRewards {
                casualRewardMessage = "Daily casual coin cap reached"
            } else {
                casualRewardMessage = nil
            }
        } catch {
            casualRewardMessage = "Result saved. Casual coins will retry on refresh."
        }
    }

    // MARK: - Helpers

    private func startGameTimer() {
        elapsedSeconds = 0
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedSeconds += 1 }
        }
    }

    private func scheduleBotFallback(user: AppUser, mode: GameMode, difficulty: Difficulty, searchID: UUID) {
        guard BotMatchService.canOfferBot(to: user, mode: mode) else { return }
        botFallbackTask?.cancel()
        let delay = BotMatchService.fallbackDelaySeconds()
        botFallbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            await self?.createBotMatchIfStillSearching(user: user, mode: mode, difficulty: difficulty, searchID: searchID)
        }
    }

    private func createBotMatchIfStillSearching(user: AppUser, mode: GameMode, difficulty: Difficulty, searchID: UUID) async {
        guard isCurrentSearch(searchID), case .searching = state else { return }
        do {
            if let sessionID = try await store.createBronzeBotSession(
                user: user,
                mode: mode,
                difficulty: difficulty,
                wager: 0,
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
        officialSearchTask?.cancel()
        officialSearchTask = nil
        officialHeartbeatTask?.cancel()
        officialHeartbeatTask = nil
        officialProgressTask?.cancel()
        officialProgressTask = nil
        tearDownDiscoveryListeners()
        sessionListener?.remove()
        sessionListener = nil
    }

    private func tearDownDiscoveryListeners() {
        userDocListener?.remove()
        userDocListener = nil
        queueListener?.remove()
        queueListener = nil
        matchDiscoveryListener?.remove()
        matchDiscoveryListener = nil
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
        finishedSessionID = nil
        rewardErrorMessage = nil
        rewardSnapshot = nil
        casualRewardMessage = nil
        clearRematchState()
        readySessionIDs = []
        isForfeiting = false
    }

    func handleViewDisappeared() {
        if case .inMatch(let session) = state, session.isExhibition, hasSubmittedLocalTurn(in: session) {
            reset()
        } else if case .inMatch(let session) = state, session.isAsyncExhibition {
            reset()
        } else if case .inMatch(let session) = state, finishedSessionID == nil, !isForfeiting {
            Task { await forfeitMatch(session: session, resetAfterProcessing: true) }
        } else {
            reset()
        }
    }

    private func hasSubmittedLocalTurn(in session: GameSession) -> Bool {
        guard let user, let result = playerResults[user.id] else { return false }
        if session.isAsyncExhibition {
            return MatchResolver.isFinalResult(result)
        }
        switch session.mode {
        case .wordle:
            return result.isFinalWordleResult
        case .hangman:
            return MatchResolver.isFinalHangmanResult(result)
        default:
            return true
        }
    }

    private func isCurrentSearch(_ searchID: UUID) -> Bool {
        activeSearchID == searchID
    }

    func startMatchCountdown(session: GameSession) {
        matchCountdown = 5
        SoundManager.shared.playPreGameCountdown(sessionID: session.id)
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

    private func syncSharedMatchCountdown(_ session: GameSession) {
        guard let startedAt = session.preGameCountdownStartedAt else {
            stopMatchCountdown()
            matchCountdown = 5
            return
        }
        guard sharedCountdownSessionID != session.id || sharedCountdownStartedAt != startedAt else { return }

        stopMatchCountdown()
        sharedCountdownSessionID = session.id
        sharedCountdownStartedAt = startedAt
        SoundManager.shared.playPreGameCountdown(sessionID: session.id)
        countdownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let deadline = startedAt.addingTimeInterval(5)
            while !Task.isCancelled {
                let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
                self.matchCountdown = remaining
                guard remaining > 0 else { return }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func stopMatchCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        sharedCountdownSessionID = nil
        sharedCountdownStartedAt = nil
    }

    func confirmReady(session: GameSession) async {
        guard let userID = user?.id, !userID.isEmpty else { return }
        do {
            if session.usesVerifiedResults {
                currentSessionID = session.id
                let key = officialEvidenceKey(session.id, userID)
                if let data = UserDefaults.standard.data(forKey: key + "_result"),
                   let result = try? JSONDecoder().decode(MatchPlayerResult.self, from: data) {
                    playerResults[userID] = result
                }
                listenForSessionStatus(sessionID: session.id)
                let reply = try await store.officialAction("ready", userID: userID, sessionID: session.id)
                acceptOfficialReply(reply, sessionID: session.id, userID: userID)
                readySessionIDs.insert(session.id)
                officialHeartbeatTask?.cancel()
                officialHeartbeatTask = Task { [weak self] in
                    while !Task.isCancelled {
                        guard let self else { return }
                        await self.retryOfficialSubmission(sessionID: session.id, userID: userID)
                        if let reply = try? await self.store.officialAction("tick", userID: userID, sessionID: session.id) {
                            self.acceptOfficialReply(reply, sessionID: session.id, userID: userID)
                        }
                        do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
                    }
                }
                return
            }
            try await rtdb.markReady(sessionID: session.id, userID: userID)
            readySessionIDs.insert(session.id)
            if let bot = session.botPlayer {
                try await rtdb.markReady(sessionID: session.id, userID: bot.userID)
            }
            listenForBothReady(session: session)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func abortMatchFound(session: GameSession) async {
        if session.usesVerifiedResults, let userID = user?.id {
            try? await store.officialAction("forfeit", userID: userID, sessionID: session.id)
        }
        countdownTask?.cancel()
        countdownTask = nil
        reset()
    }

    private func beginOfficialSearch(user: AppUser, mode: GameMode, kind: SessionKind, searchID: UUID) {
        usesOfficialSearch = true
        officialSearchTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isCurrentSearch(searchID) else { return }
                do {
                    let reply = try await self.store.officialQueue(userID: user.id, mode: mode, kind: kind, requestID: searchID.uuidString)
                    guard self.isCurrentSearch(searchID) else {
                        let cancelled = try await self.store.officialCancel(userID: user.id, requestID: searchID.uuidString)
                        if let id = cancelled.sessionID { try await self.store.officialAction("forfeit", userID: user.id, sessionID: id) }
                        return
                    }
                    if let id = reply.sessionID {
                        let session = try await self.store.fetchSession(id: id)
                        // Resume an existing official match even when the player
                        // reopened matchmaking from a different mode's lobby.
                        self.mode = session.mode
                        self.difficulty = session.difficulty
                        if session.status == .finished {
                            self.state = .finished(session: session)
                            if session.isRanked { await self.applyFinishedRewards(session) }
                            else { await self.applyFinishedCasualRewards(session) }
                        } else {
                            await self.enterFoundMatch(session, searchID: searchID)
                        }
                        return
                    }
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                } catch {
                    if Task.isCancelled { return }
                    self.state = .error(error.localizedDescription)
                    return
                }
            }
        }
    }

    private func officialEvidenceKey(_ sessionID: String, _ userID: String) -> String {
        "officialMatchEvidence_\(userID)_\(sessionID)"
    }

    private func officialProgressKey(_ sessionID: String, _ userID: String) -> String {
        "officialMatchProgress_\(userID)_\(sessionID)"
    }

    private func scheduleOfficialProgress(sessionID: String, userID: String) {
        officialProgressTask?.cancel()
        officialProgressTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            guard !Task.isCancelled, let self else { return }
            _ = await self.retryOfficialProgress(sessionID: sessionID, userID: userID)
        }
    }

    @discardableResult
    private func retryOfficialProgress(sessionID: String, userID: String) async -> Bool {
        let key = officialProgressKey(sessionID, userID)
        guard let evidence = UserDefaults.standard.string(forKey: key) else { return false }
        do {
            _ = try await store.officialAction("progress", userID: userID, sessionID: sessionID, evidenceJSON: evidence)
            if UserDefaults.standard.string(forKey: key) == evidence {
                UserDefaults.standard.removeObject(forKey: key)
            }
            return true
        } catch {
            return false
        }
    }

    private func retryOfficialSubmission(sessionID: String, userID: String) async {
        let key = officialEvidenceKey(sessionID, userID)
        guard let evidence = UserDefaults.standard.string(forKey: key) else { return }
        do {
            let reply = try await store.officialAction("submit", userID: userID, sessionID: sessionID, evidenceJSON: evidence)
            acceptOfficialReply(reply, sessionID: sessionID, userID: userID)
            if reply.status == "finished" || reply.status == "abandoned" {
                UserDefaults.standard.removeObject(forKey: key)
                UserDefaults.standard.removeObject(forKey: key + "_result")
                UserDefaults.standard.removeObject(forKey: officialProgressKey(sessionID, userID))
            }
            rewardErrorMessage = nil
        } catch {
            rewardErrorMessage = "Submission saved on this device. Retrying when connected."
        }
    }

    private func acceptOfficialReply(_ reply: FirestoreService.OfficialMatchReply, sessionID: String, userID: String) {
        guard let result = reply.ownResult, result.userID == userID else { return }
        let key = officialEvidenceKey(sessionID, userID)
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: key + "_result")
        UserDefaults.standard.removeObject(forKey: officialProgressKey(sessionID, userID))
        guard currentSessionID == sessionID else { return }
        playerResults[userID] = result
    }
}

struct MatchResolution {
    let winnerID: String?
    let reason: String
}

enum MatchResolver {
    static func canResolve(session: GameSession, results: [String: MatchPlayerResult]) -> Bool {
        if session.isParty {
            return results.count >= session.players.count
        }
        if session.isAsyncExhibition {
            return session.players.allSatisfy { player in
                guard let result = results[player.userID] else { return false }
                return isFinalResult(result)
            }
        }
        if session.mode == .wordle {
            return session.players.allSatisfy { results[$0.userID]?.isFinalWordleResult == true }
        }
        if session.mode == .hangman {
            return session.players.allSatisfy { player in
                results[player.userID].map { isFinalHangmanResult($0) } ?? false
            }
        }
        if hasClinchedTargetResult(session: session, results: results) {
            return true
        }
        return results.count >= session.players.count
    }

    static func resolve(session: GameSession, results: [String: MatchPlayerResult]) -> MatchResolution {
        let ordered = session.players.compactMap { results[$0.userID] }
        if !session.isParty, !session.isAsyncExhibition, ordered.count == 1, let resolution = resolveClinchedTarget(session: session, result: ordered[0]) {
            return resolution
        }
        guard ordered.count == session.players.count, ordered.count == 2 else {
            return MatchResolution(winnerID: nil, reason: "Waiting for both players")
        }
        let a = ordered[0]
        let b = ordered[1]

        switch session.mode {
        case .wordle:
            guard a.isFinalWordleResult && b.isFinalWordleResult else {
                return MatchResolution(winnerID: nil, reason: "Waiting for both players")
            }
            return compareWordle(a, b)
        case .anagram:
            return compareWordScore(a, b, label: "Anagrams")
        case .wordHunt:
            return compareWordScore(a, b, label: "Word Hunt")
        case .hangman:
            guard isFinalHangmanResult(a) && isFinalHangmanResult(b) else {
                return MatchResolution(winnerID: nil, reason: "Waiting for both players")
            }
            return compareHangman(a, b)
        case .sudoku:
            return compareCompletion(a, b)
        case .gridlock:
            return compareSolitaire(a, b)
        case .colorLink:
            return compareColorLink(a, b)
        case .minesweeper:
            return compareMinesweeper(a, b)
        }
    }

    static func isFinalResult(_ result: MatchPlayerResult) -> Bool {
        if result.summary["isFinal"] == "false" { return false }
        switch result.mode {
        case .wordle:
            return result.isFinalWordleResult
        case .hangman:
            return isFinalHangmanResult(result)
        default:
            return true
        }
    }

    private static func compareWordle(_ a: MatchPlayerResult, _ b: MatchPlayerResult) -> MatchResolution {
        if a.solvedRounds != b.solvedRounds {
            let winner = a.solvedRounds > b.solvedRounds ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Solved more Word Guess words")
        }
        guard a.solvedRounds > 0 else { return MatchResolution(winnerID: nil, reason: "Neither player solved a word") }
        if a.totalGuesses != b.totalGuesses {
            let winner = a.totalGuesses < b.totalGuesses ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Solved in fewer guesses")
        }
        if a.elapsedSeconds != b.elapsedSeconds {
            return MatchResolution(winnerID: a.elapsedSeconds < b.elapsedSeconds ? a.userID : b.userID,
                                   reason: "Same guesses; faster finish")
        }
        return MatchResolution(winnerID: nil, reason: "Same solves, guesses, and time")
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

    private static func hasClinchedTargetResult(session: GameSession, results: [String: MatchPlayerResult]) -> Bool {
        results.values.contains { resolveClinchedTarget(session: session, result: $0) != nil }
    }

    private static func resolveClinchedTarget(session: GameSession, result: MatchPlayerResult) -> MatchResolution? {
        guard result.completed else { return nil }
        switch session.mode {
        case .sudoku:
            return MatchResolution(winnerID: result.userID, reason: "Completed the puzzle")
        case .gridlock:
            return MatchResolution(winnerID: result.userID, reason: "Cleared Solitaire")
        case .colorLink:
            return MatchResolution(winnerID: result.userID, reason: "Filled the Color Link board")
        case .minesweeper:
            return MatchResolution(winnerID: result.userID, reason: "Cleared the minefield")
        case .wordle, .hangman, .anagram, .wordHunt:
            return nil
        }
    }

    static func isFinalHangmanResult(_ result: MatchPlayerResult) -> Bool {
        if let final = result.summary["final"] { return final == "true" }
        if result.solvedRounds >= 2 { return true }
        if let totalRounds = Int(result.summary["totalRounds"] ?? ""), result.wordleRoundCount >= totalRounds { return true }
        return result.completed || result.status != "In progress"
    }

    private static func compareHangman(_ a: MatchPlayerResult, _ b: MatchPlayerResult) -> MatchResolution {
        if a.solvedRounds != b.solvedRounds {
            let winner = a.solvedRounds > b.solvedRounds ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Rescued more words")
        }
        if a.completed != b.completed {
            let winner = a.completed ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Rescued the puzzle")
        }
        if a.wrongGuessCount != b.wrongGuessCount {
            let winner = a.wrongGuessCount < b.wrongGuessCount ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Had fewer wrong letters")
        }
        if a.revealedLetterCount != b.revealedLetterCount {
            let winner = a.revealedLetterCount > b.revealedLetterCount ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Revealed more letters")
        }
        return compareElapsed(a, b, fallback: "Same Lava Rescue progress")
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

    private static func compareSolitaire(_ a: MatchPlayerResult, _ b: MatchPlayerResult) -> MatchResolution {
        if a.completed != b.completed {
            let winner = a.completed ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Cleared Solitaire")
        }
        if a.completed && b.completed {
            if a.moveCount != b.moveCount {
                let winner = a.moveCount < b.moveCount ? a : b
                return MatchResolution(winnerID: winner.userID, reason: "Solved in fewer moves")
            }
            return compareElapsed(a, b, fallback: "Same Solitaire clear")
        }
        if a.foundationCount != b.foundationCount {
            let winner = a.foundationCount > b.foundationCount ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Moved more cards to foundations")
        }
        if a.score != b.score {
            let winner = a.score > b.score ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Higher Solitaire score")
        }
        if a.progress != b.progress {
            let winner = a.progress > b.progress ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Higher foundation progress")
        }
        if a.moveCount != b.moveCount {
            let winner = a.moveCount < b.moveCount ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Used fewer moves")
        }
        return compareElapsed(a, b, fallback: "Same Solitaire progress")
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
