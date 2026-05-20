import Foundation

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
            var entriesMap: [String: [TournamentEntry]] = [:]
            var mine: [String: TournamentEntry] = [:]

            for tournament in displayTournaments {
                let entries = try await service.fetchEntries(tournamentID: tournament.id)
                entriesMap[tournament.id] = entries
                if let entry = entries.first(where: { $0.userID == user.id }) {
                    mine[tournament.id] = entry
                }
            }

            for previous in Self.previousTournaments(for: user) {
                let entries = try await service.fetchEntries(tournamentID: previous.id)
                guard let entry = entries.first(where: { $0.userID == user.id }), entry.prizeClaimed == false else { continue }
                entriesMap[previous.id] = entries
                mine[previous.id] = entry
                if !displayTournaments.contains(where: { $0.id == previous.id }) {
                    displayTournaments.append(previous)
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
            let result = try await service.enterTournament(tournament, user: user)
            user = result.0
            myEntries[tournament.id] = result.1
            await refresh()
            selectedTournament = tournament
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func play(_ tournament: DailyTournament) {
        selectedTournament = tournament
    }

    func submit(_ soloResult: SoloGameResult, tournament: DailyTournament) async {
        do {
            let result = TournamentResult.fromSoloResult(soloResult)
            try await service.submitResult(result, tournament: tournament, userID: user.id)
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
        GameMode.allCases.map { DailyTournament.make(mode: $0, tier: user.rank(for: $0).displayTier) }
    }

    private static func previousTournaments(for user: AppUser) -> [DailyTournament] {
        GameMode.allCases.map { DailyTournament.previous(mode: $0, tier: user.rank(for: $0).displayTier) }
    }
}
