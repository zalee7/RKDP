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

    init(user: AppUser) {
        self.user = user
        self.tournaments = GameMode.allCases.map { DailyTournament.make(mode: $0, tier: user.rank(for: $0).displayTier) }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        tournaments = GameMode.allCases.map { DailyTournament.make(mode: $0, tier: user.rank(for: $0).displayTier) }
        do {
            var entriesMap: [String: [TournamentEntry]] = [:]
            var mine: [String: TournamentEntry] = [:]
            for tournament in tournaments {
                let entries = try await service.fetchEntries(tournamentID: tournament.id)
                entriesMap[tournament.id] = entries
                if let entry = entries.first(where: { $0.userID == user.id }) {
                    mine[tournament.id] = entry
                }
            }
            entriesByTournamentID = entriesMap
            myEntries = mine
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
}
