import SwiftUI

struct TournamentView: View {
    let user: AppUser
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm: TournamentViewModel

    init(user: AppUser) {
        self.user = user
        _vm = StateObject(wrappedValue: TournamentViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        ForEach(vm.tournaments) { tournament in
                            TournamentCard(
                                tournament: tournament,
                                entry: vm.myEntries[tournament.id],
                                standings: vm.standings(for: tournament),
                                preview: vm.prizePreview(for: tournament),
                                userCoins: vm.user.coins
                            ) { action in
                                Task {
                                    switch action {
                                    case .enter: await vm.enter(tournament); await auth.refreshUser()
                                    case .play: vm.play(tournament)
                                    case .claim: await vm.claimPrize(tournament); await auth.refreshUser()
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .foregroundStyle(AppTheme.textPrimary)
            .navigationTitle("Tournaments")
            .navigationBarTitleDisplayMode(.inline)
            .task { await vm.refresh() }
            .refreshable { await vm.refresh() }
            .fullScreenCover(item: $vm.selectedTournament) { tournament in
                TournamentGameView(tournament: tournament, user: vm.user) { result in
                    await vm.submit(result, tournament: tournament)
                    await auth.refreshUser()
                }
            }
            .alert(
                "Tournament update failed",
                isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
            ) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(AppTheme.crownGold)
                Text("Daily Coin Tournaments")
                    .font(.title2.bold())
                Spacer()
                CoinBadgeView(amount: vm.user.coins)
            }
            Text("Tournaments are separated by rank tier for each mode. Enter with coins, play one shared-seed attempt, and claim a virtual coin prize if you place after the event closes. No rank or W/L changes.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

private enum TournamentCardAction {
    case enter
    case play
    case claim
}

private struct TournamentCard: View {
    let tournament: DailyTournament
    let entry: TournamentEntry?
    let standings: [TournamentEntry]
    let preview: TournamentPrizePreview
    let userCoins: Int
    let onAction: (TournamentCardAction) -> Void

    private var canAfford: Bool { userCoins >= tournament.entryFee }
    private var hasResult: Bool { entry?.result != nil }
    private var canClaim: Bool { tournament.isClosed && (entry?.prizeClaimed == false) && preview.prize > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.modeGradient(tournament.mode))
                    .frame(width: 54, height: 54)
                    .overlay(Image(systemName: tournament.mode.icon).font(.title3.bold()).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 3) {
                    Text(tournament.mode.displayName)
                        .font(.headline.bold())
                    Text("\(tournament.rankTier.displayName)-only board · \(tournament.mode.difficultyLabel(tournament.difficulty))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Entry")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                    CoinBadgeView(amount: tournament.entryFee)
                }
            }

            HStack(spacing: 10) {
                statTile("Entries", "\(standings.count)")
                statTile("Paid", "Top \(preview.paidPlaces)")
                statTile("Prize", preview.prize > 0 ? "\(preview.prize)" : "--")
            }

            TimelineView(.periodic(from: Date(), by: 1)) { context in
                closesRow(now: context.date)
            }

            if let place = preview.place {
                Text("Your place: #\(place)")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.crownGold)
            } else {
                Text("One attempt. Shared puzzle. Best result wins the daily board.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if let result = entry?.result {
                Text("Submitted: \(result.completed ? "Complete" : "Incomplete") · Score \(result.score) · Time \(formattedTime(result.elapsedSeconds))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Button(action: { onAction(buttonAction) }) {
                Label(buttonTitle, systemImage: buttonIcon)
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(buttonEnabled ? AppTheme.crownGold : AppTheme.cardBorder)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!buttonEnabled)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var buttonAction: TournamentCardAction {
        if entry == nil { return .enter }
        if !hasResult { return .play }
        return .claim
    }

    private var buttonTitle: String {
        if entry == nil { return canAfford ? "Enter Tournament" : "Need More Coins" }
        if !hasResult { return "Play Attempt" }
        if entry?.prizeClaimed == true { return "Prize Claimed" }
        if !tournament.isClosed { return "Prize Unlocks at Close" }
        return preview.prize > 0 ? "Claim \(preview.prize) Coins" : "No Prize This Time"
    }

    private var buttonIcon: String {
        if entry == nil { return "ticket.fill" }
        if !hasResult { return "play.fill" }
        return "gift.fill"
    }

    private var buttonEnabled: Bool {
        if entry == nil { return canAfford }
        if !hasResult { return true }
        return canClaim
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func closesRow(now: Date) -> some View {
        let seconds = max(0, Int(tournament.closesAt.timeIntervalSince(now)))
        let isClosed = seconds == 0
        return HStack(spacing: 8) {
            Image(systemName: isClosed ? "lock.open.fill" : "timer")
                .foregroundStyle(isClosed ? AppTheme.success : AppTheme.crownGold)
            Text(isClosed ? "Tournament closed" : "Closes in \(countdownText(seconds))")
                .font(.caption.bold())
                .foregroundStyle(isClosed ? AppTheme.success : AppTheme.textPrimary)
            Spacer()
            Text("\(tournament.rankTier.displayName) rank only")
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.crownGold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func countdownText(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

private struct TournamentGameView: View {
    let tournament: DailyTournament
    let user: AppUser
    let onResult: (SoloGameResult) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var submittedResult: SoloGameResult?
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            SoloGameView(
                mode: tournament.mode,
                difficulty: tournament.difficulty,
                user: user,
                seed: tournament.seed,
                puzzleData: tournament.puzzleData,
                onSoloResult: { result in
                    guard submittedResult == nil else { return }
                    submittedResult = result
                    isSubmitting = true
                    Task {
                        await onResult(result)
                        isSubmitting = false
                    }
                },
                onPlayAgain: {},
                onChangeDifficulty: {},
                onTryRanked: {},
                onHome: { dismiss() }
            )

            if let submittedResult {
                VStack(spacing: 12) {
                    Image(systemName: isSubmitting ? "hourglass" : "checkmark.seal.fill")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.crownGold)
                    Text(isSubmitting ? "Submitting Result" : "Tournament Result Submitted")
                        .font(.title3.bold())
                    Text("\(submittedResult.title) · Score \(submittedResult.score ?? 0)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Button("Back to Tournaments") { dismiss() }
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.crownGold)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(22)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(24)
            }
        }
    }
}
