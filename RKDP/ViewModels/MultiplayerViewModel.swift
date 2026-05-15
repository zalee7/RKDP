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
    private var countdownTask: Task<Void, Never>?

    private let store = FirestoreService.shared
    private let rtdb = RealtimeDBService.shared
    private let ranking = RankingService.shared

    // Firestore listeners
    private var userDocListener: ListenerRegistration?
    private var queueListener: ListenerRegistration?
    private var sessionListener: ListenerRegistration?

    // Realtime DB handles
    private var rtdbHandles: [DatabaseHandle] = []
    private var currentSessionID: String?
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
            state = .error("Not enough coins for this wager.")
            return
        }

        let searchID = UUID()
        activeSearchID = searchID
        tearDownListeners()
        countdownTask?.cancel()
        countdownTask = nil
        gameTimer?.invalidate()
        playerResults = [:]
        opponentUser = nil
        elapsedSeconds = 0
        matchCountdown = 5
        finishedSessionID = nil

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

            // 1. Listen on our user doc before entering the queue so a fast pair
            //    cannot write pendingSessionID before we are watching for it.
            userDocListener = store.listenForMatch(userID: user.id) { [weak self] sessionID, pendingSearchID in
                Task { await self?.consumeMatch(sessionID: sessionID, pendingSearchID: pendingSearchID, searchID: searchID) }
            }

            // 2. Also listen on the queue so that if we're the host we can pair
            //    any opponent who joins after us
            queueListener = store.listenForQueueMatch(
                user: user, mode: mode, difficulty: difficulty, wager: wager.amount, searchID: searchID.uuidString
            ) { _ in /* session creation is handled inside listenForQueueMatch */ }

            // 3. Write to queue and try to pair immediately
            try await store.joinAndPair(user: user, mode: mode, difficulty: difficulty, wager: wager.amount, searchID: searchID.uuidString)

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

    func cancelSearch() async {
        guard let user else { return }
        activeSearchID = nil
        tearDownListeners()
        countdownTask?.cancel()
        countdownTask = nil
        try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
        try? await store.clearPendingSession(userID: user.id)
        opponentUser = nil
        playerResults = [:]
        elapsedSeconds = 0
        state = .idle
    }

    /// Called when pendingSessionID appears on our user doc
    private func consumeMatch(sessionID: String, pendingSearchID: String?, searchID: UUID) async {
        guard isCurrentSearch(searchID), let user else { return }
        guard pendingSearchID == searchID.uuidString else {
            try? await store.clearPendingSession(userID: user.id)
            return
        }
        tearDownListeners()
        try? await store.clearPendingSession(userID: user.id)
        do {
            let session = try await store.fetchSession(id: sessionID)
            guard isCurrentSearch(searchID) else { return }
            guard session.mode == mode,
                  session.difficulty == difficulty,
                  session.players.contains(where: { $0.userID == user.id }) else {
                return
            }
            // Fetch opponent for display on the match-found screen
            let oppID = session.players.first { $0.userID != user.id }?.userID
            if let oppID { opponentUser = try? await store.fetchUser(id: oppID) }
            guard isCurrentSearch(searchID) else { return }
            activeSearchID = nil
            state = .matchFound(session: session)
            startMatchCountdown(session: session)
        } catch {
            guard isCurrentSearch(searchID) else { return }
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
                self?.listenForResults(session: session)
                self?.listenForSessionStatus(sessionID: session.id)
            }
        }
        rtdbHandles.append(handle)
    }

    private func listenForSessionStatus(sessionID: String) {
        sessionListener?.remove()
        sessionListener = store.listenForSession(id: sessionID) { [weak self] session in
            Task { @MainActor in
                guard let self, session.status == .finished else { return }
                self.gameTimer?.invalidate()
                if let results = session.playerResults {
                    self.playerResults = results
                }
                self.state = .finished(session: session)
                self.finishedSessionID = session.id
            }
        }
    }

    func submitResult(_ result: MatchPlayerResult, session: GameSession) async {
        guard result.userID == user?.id, playerResults[result.userID] == nil else { return }
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
                if MatchResolver.canResolve(session: session, results: results) {
                    await self?.resolveMatch(session: session, results: results)
                }
            }
        }
        rtdbHandles.append(handle)
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
            details: ["Quit the active ranked match."]
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
            details: ["Opponent forfeited before the match was completed."]
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
        sessionListener?.remove()
        sessionListener = nil
    }

    func reset() {
        activeSearchID = nil
        tearDownListeners()
        countdownTask?.cancel()
        countdownTask = nil
        if let user {
            let mode = self.mode
            let difficulty = self.difficulty
            Task {
                try? await store.leaveMatchmakingQueue(userID: user.id, mode: mode, difficulty: difficulty)
                try? await store.clearPendingSession(userID: user.id)
            }
        }
        let sid = currentSessionID ?? ""
        rtdbHandles.forEach { rtdb.removeObserver(handle: $0, sessionID: sid) }
        rtdbHandles = []
        currentSessionID = nil
        gameTimer?.invalidate()
        state = .idle
        elapsedSeconds = 0
        playerResults = [:]
        opponentUser = nil
        selectedWager = nil
        finishedSessionID = nil
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
            listenForBothReady(session: session)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func abortMatchFound(session: GameSession) async {
        countdownTask?.cancel()
        countdownTask = nil
        if let userID = user?.id {
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
        if session.mode == .wordle, hasClinchedWordleResult(results) {
            return true
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
            return MatchResolution(winnerID: winner.userID, reason: "Completed Grid Duel symmetry")
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
            return MatchResolution(winnerID: winner.userID, reason: "Higher symmetry progress")
        }
        if a.moveCount != b.moveCount {
            let winner = a.moveCount < b.moveCount ? a : b
            return MatchResolution(winnerID: winner.userID, reason: "Used fewer moves")
        }
        return compareElapsed(a, b, fallback: "Same Grid Duel progress")
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
