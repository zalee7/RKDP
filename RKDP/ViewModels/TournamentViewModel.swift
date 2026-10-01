import Foundation

@MainActor
final class DailyChallengeViewModel: ObservableObject {
    @Published private(set) var user: AppUser
    @Published var challengeSet: DailyChallengeSet = .today(includePuzzleData: false)
    @Published var entriesByChallengeID: [String: [DailyChallengeEntry]] = [:]
    @Published var myEntries: [String: DailyChallengeEntry] = [:]
    @Published var friendIDs: Set<String> = []
    @Published var errorMessage: String?
    @Published var selectedChallenge: DailyChallenge?
    @Published var isLoading = false
    @Published private(set) var hasPendingSubmissions = false

    private let service = DailyChallengeService.shared
    private var currentDayKey = RankedAccess.todayKey()

    init(user: AppUser) {
        self.user = user
    }

    var completedCount: Int {
        challengeSet.challenges.filter { myEntries[$0.id] != nil }.count
    }

    var didEarnCompletionBonus: Bool {
        user.dailyChallengeBonusDays[challengeSet.dayKey] == true
    }

    func refresh() async {
        isLoading = true
        defer {
            isLoading = false
            hasPendingSubmissions = VerifiedDailyClient.hasPending(userID: user.id)
        }
        currentDayKey = RankedAccess.todayKey()
        do {
            var recoveryError: String?
            if try await FirestoreService.shared.usesServerWallet(userID: user.id) {
                do { try await VerifiedDailyClient.recover(userID: user.id) }
                catch { recoveryError = error.localizedDescription }
                user = try await FirestoreService.shared.fetchUser(id: user.id)
            }
            let set = try await service.todayChallengeSet(userID: user.id, includePuzzleData: false)
            let entries = try await service.fetchEntries(dayKey: set.dayKey, userID: user.id)
            let friendIDs = try await service.fetchFriendIDs(for: user.id)
            challengeSet = set
            entriesByChallengeID = Dictionary(grouping: entries, by: \.challengeID)
            myEntries = entries.reduce(into: [:]) { partial, entry in
                guard entry.userID == user.id else { return }
                partial[entry.challengeID] = entry
            }
            self.friendIDs = Set(friendIDs)
            errorMessage = recoveryError
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshIfDayChanged() async {
        guard RankedAccess.todayKey() != currentDayKey else { return }
        await refresh()
    }

    func play(_ challenge: DailyChallenge) async {
        do {
            if try await FirestoreService.shared.usesServerWallet(userID: user.id) {
                selectedChallenge = try await VerifiedDailyClient.begin(userID: user.id, challengeID: challenge.id)
                return
            }
            let set = try await service.todayChallengeSet(userID: user.id, includePuzzleData: true)
            if let prepared = set.challenges.first(where: { $0.id == challenge.id }) {
                selectedChallenge = prepared
            } else {
                selectedChallenge = challenge.preparedForPlay()
            }
        } catch {
            // Never silently replace a verified daily with a locally generated puzzle.
            errorMessage = error.localizedDescription
        }
    }

    func submit(_ soloResult: SoloGameResult, challenge: DailyChallenge) async -> Bool {
        defer { hasPendingSubmissions = VerifiedDailyClient.hasPending(userID: user.id) }
        do {
            if try await FirestoreService.shared.usesServerWallet(userID: user.id) {
                guard let evidence = soloResult.rewardEvidenceJSON else {
                    throw NSError(domain: "DailyChallenge", code: 1, userInfo: [NSLocalizedDescriptionKey:
                        "This result is missing its verification data. No coins were granted."])
                }
                try await VerifiedDailyClient.submit(userID: user.id, challengeID: challenge.id, evidenceJSON: evidence)
            } else {
                let result = DailyChallengeResult.fromSoloResult(soloResult)
                let submitted = try await service.submitResult(result, challenge: challenge, userID: user.id)
                user = submitted.0
                myEntries[challenge.id] = submitted.1
            }
            await refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func discardPendingSubmissions() async {
        do {
            try await VerifiedDailyClient.discardPending(userID: user.id)
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func standings(for challenge: DailyChallenge) -> [DailyChallengeEntry] {
        DailyChallengeScoring.sortedEntries(entriesByChallengeID[challenge.id] ?? [], mode: challenge.mode)
    }

    func friendStandings(for challenge: DailyChallenge) -> [DailyChallengeEntry] {
        standings(for: challenge).filter { friendIDs.contains($0.userID) || $0.userID == user.id }
    }
}

@MainActor
final class TournamentViewModel: ObservableObject {
    @Published private(set) var user: AppUser
    @Published var tournaments: [DailyTournament] = []
    @Published var entriesByTournamentID: [String: [TournamentEntry]] = [:]
    @Published var myEntries: [String: TournamentEntry] = [:]
    @Published var errorMessage: String?
    @Published var selectedTournament: DailyTournament?
    @Published var isLoading = false

    private let service = TournamentService.shared
    private var currentHourKey = DailyTournament.utcHourKey()

    init(user: AppUser) {
        self.user = user
        self.tournaments = Self.currentTournaments(for: user)
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        currentHourKey = DailyTournament.utcHourKey()
        do {
            var displayTournaments = Self.currentTournaments(for: user)
            tournaments = displayTournaments
            var entriesMap: [String: [TournamentEntry]] = [:]
            var mine: [String: TournamentEntry] = [:]
            let previousTournaments = Self.previousTournaments(for: user)

            for try await (tournament, entries) in entryFetchStream(for: displayTournaments + previousTournaments) {
                entriesMap[tournament.id] = entries
                if let entry = entries.first(where: { $0.userID == user.id }) {
                    mine[tournament.id] = entry
                    if previousTournaments.contains(where: { $0.id == tournament.id }),
                       entry.prizeClaimed == false,
                       !displayTournaments.contains(where: { $0.id == tournament.id }) {
                        displayTournaments.append(tournament)
                    }
                }
            }

            tournaments = displayTournaments
            entriesByTournamentID = entriesMap
            myEntries = mine
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshIfHourChanged() async {
        guard DailyTournament.utcHourKey() != currentHourKey else { return }
        await refresh()
    }

    func enter(_ tournament: DailyTournament) async {
        do {
            let playableTournament = tournament.preparedForPlay()
            let result = try await service.enterTournament(playableTournament, user: user)
            user = result.0
            myEntries[playableTournament.id] = result.1
            await refresh()
            selectedTournament = playableTournament
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func play(_ tournament: DailyTournament) {
        selectedTournament = tournament.preparedForPlay()
    }

    func submit(_ soloResult: SoloGameResult, tournament: DailyTournament) async {
        do {
            let result = TournamentResult.fromSoloResult(soloResult)
            try await service.submitResult(result, tournament: tournament, userID: user.id)
            user = try await FirestoreService.shared.recordDailyPlay(userID: user.id, activityID: "tournament_\(tournament.id)_\(user.id)")
            await refresh()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func claimPrize(_ tournament: DailyTournament) async {
        do {
            user = try await service.claimPrize(tournament: tournament, userID: user.id)
            await refresh()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func standings(for tournament: DailyTournament) -> [TournamentEntry] {
        TournamentScoring.sortedEntries(entriesByTournamentID[tournament.id] ?? [], mode: tournament.mode)
    }

    func prizePreview(for tournament: DailyTournament) -> TournamentPrizePreview {
        let standings = standings(for: tournament)
        guard let place = standings.firstIndex(where: { $0.userID == user.id }).map({ $0 + 1 }) else {
            return TournamentPrizePreview(place: nil, prize: 0, paidPlaces: TournamentScoring.paidPlaces(entryCount: standings.count))
        }
        return TournamentPrizePreview(
            place: place,
            prize: TournamentScoring.prize(for: place, entryCount: standings.count, entryFee: tournament.entryFee),
            paidPlaces: TournamentScoring.paidPlaces(entryCount: standings.count)
        )
    }

    private static func currentTournaments(for user: AppUser) -> [DailyTournament] {
        GameMode.allCases.map { DailyTournament.make(mode: $0, tier: user.rank(for: $0).displayTier, includePuzzleData: false) }
    }

    private static func previousTournaments(for user: AppUser) -> [DailyTournament] {
        GameMode.allCases.map { DailyTournament.previous(mode: $0, tier: user.rank(for: $0).displayTier, includePuzzleData: false) }
    }

    private func entryFetchStream(for tournaments: [DailyTournament]) -> AsyncThrowingStream<(DailyTournament, [TournamentEntry]), Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await withThrowingTaskGroup(of: (DailyTournament, [TournamentEntry]).self) { group in
                        for tournament in tournaments {
                            group.addTask {
                                let entries = try await TournamentService.shared.fetchEntries(tournamentID: tournament.id)
                                return (tournament, entries)
                            }
                        }

                        for try await result in group {
                            continuation.yield(result)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
