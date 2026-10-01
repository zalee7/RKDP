import SwiftUI

struct TournamentView: View {
    let user: AppUser
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var dailyVM: DailyChallengeViewModel
    @State private var confirmsDiscardDaily = false

    init(user: AppUser) {
        self.user = user
        _dailyVM = StateObject(wrappedValue: DailyChallengeViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if dailyVM.hasPendingSubmissions {
                            HStack {
                                Label("Submission pending", systemImage: "icloud.and.arrow.up")
                                Spacer()
                                Button("Retry") { Task { await dailyVM.refresh() } }
                                Button(role: .destructive) { confirmsDiscardDaily = true } label: {
                                    Image(systemName: "trash")
                                }
                                .accessibilityLabel("Discard pending daily submissions")
                            }
                            .font(.caption)
                            .disabled(dailyVM.isLoading)
                        }
                        DailyChallengeSection(vm: dailyVM) { challenge in
                            Task { await dailyVM.play(challenge) }
                        }
                    }
                    .padding()
                }
            }
            .foregroundStyle(AppTheme.textPrimary)
            .navigationTitle("Daily")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await dailyVM.refresh()
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    await dailyVM.refreshIfDayChanged()
                }
            }
            .refreshable {
                await dailyVM.refresh()
            }
            .confirmationDialog("Discard pending daily submissions?", isPresented: $confirmsDiscardDaily, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    Task { await dailyVM.discardPendingSubmissions() }
                }
            } message: {
                Text("Unsubmitted attempts will not earn rewards and cannot be restarted today. Rewards already credited will stay.")
            }
            .fullScreenCover(item: $dailyVM.selectedChallenge) { challenge in
                DailyChallengeGameView(challenge: challenge, user: dailyVM.user) { result in
                    let submitted = await dailyVM.submit(result, challenge: challenge)
                    await auth.refreshUser()
                    return submitted
                }
            }
            .alert(
                "Daily update failed",
                isPresented: Binding(get: { dailyVM.errorMessage != nil }, set: { if !$0 { dailyVM.errorMessage = nil } })
            ) {
                Button("OK") {
                    dailyVM.errorMessage = nil
                }
            } message: {
                Text(dailyVM.errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(AppTheme.hotPink)
                Text("Daily Challenges")
                    .font(.title2.bold())
                Spacer()
                CoinBadgeView(amount: dailyVM.user.coins)
            }
            Text("One fresh puzzle for every mode. Play, compare with friends, and keep your daily streak alive.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.tintedPanel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.25))
        .shadow(color: AppTheme.softShadow.opacity(0.45), radius: 12, x: 0, y: 6)
    }

}

private struct DailyChallengeSection: View {
    @ObservedObject var vm: DailyChallengeViewModel
    let onPlay: (DailyChallenge) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Today's Lineup", systemImage: "sparkles")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.hotPink)
                    Text("Finish any real attempt for streak credit. Clear every mode for the daily bonus.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(vm.completedCount) / \(vm.challengeSet.challenges.count)")
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(vm.didEarnCompletionBonus ? "Bonus earned" : "+\(DailyChallengeSet.completionBonus) all modes")
                        .font(.caption2.bold())
                        .foregroundStyle(vm.didEarnCompletionBonus ? AppTheme.success : AppTheme.crownGold)
                }
            }

            ForEach(vm.challengeSet.challenges) { challenge in
                DailyChallengeCard(
                    challenge: challenge,
                    myEntry: vm.myEntries[challenge.id],
                    standings: vm.standings(for: challenge),
                    friendStandings: vm.friendStandings(for: challenge),
                    currentUserID: vm.user.id,
                    onPlay: { onPlay(challenge) }
                )
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.hotPink.opacity(0.28), lineWidth: 1.25))
        .shadow(color: AppTheme.hotPink.opacity(0.14), radius: 14, x: 0, y: 7)
    }
}

private struct DailyChallengeCard: View {
    let challenge: DailyChallenge
    let myEntry: DailyChallengeEntry?
    let standings: [DailyChallengeEntry]
    let friendStandings: [DailyChallengeEntry]
    let currentUserID: String
    let onPlay: () -> Void

    @State private var showStandings = false

    private var myPlace: Int? {
        standings.firstIndex { $0.userID == currentUserID }.map { $0 + 1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.modeGradient(challenge.mode))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: challenge.mode.icon).font(.title3.bold()).foregroundStyle(.white))

                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.mode.displayName)
                        .font(.headline.bold())
                    Text("\(challenge.category.displayName) · \(challenge.mode.difficultyLabel(challenge.difficulty))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                if let myPlace {
                    Text("#\(myPlace)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.crownGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.crownGold.opacity(0.14))
                        .clipShape(Capsule())
                } else {
                    Text("Open")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.hotPink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.hotPink.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if let myEntry {
                Text("You submitted · \(dailyResultSummary(myEntry.result, mode: challenge.mode))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            } else {
                Text("One attempt. Your result appears with friends after you finish.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            friendPreview

            HStack(spacing: 10) {
                Button {
                    showStandings = true
                } label: {
                    Label("Results", systemImage: "list.number")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.controlBackground)
                        .foregroundStyle(AppTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1.1))
                }

                Button(action: onPlay) {
                    Label(myEntry == nil ? "Play" : "Done", systemImage: myEntry == nil ? "play.fill" : "checkmark.seal.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(myEntry == nil ? AppTheme.hotPink : AppTheme.cardBorder)
                        .foregroundStyle(myEntry == nil ? AppTheme.textOnColor : AppTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(myEntry != nil)
            }
        }
        .padding(12)
        .background(AppTheme.tintedPanel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.05))
        .sheet(isPresented: $showStandings) {
            DailyChallengeStandingsSheet(
                challenge: challenge,
                myEntry: myEntry,
                standings: standings,
                friendStandings: friendStandings,
                currentUserID: currentUserID
            )
        }
    }

    @ViewBuilder
    private var friendPreview: some View {
        let friends = friendStandings.filter { $0.userID != currentUserID }.prefix(2)
        if friends.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppTheme.teal)
                Text("Friends will show here after they play.")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            }
            .padding(10)
            .background(AppTheme.controlBackground.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            VStack(spacing: 6) {
                ForEach(Array(friends.enumerated()), id: \.element.id) { item in
                    DailyChallengeMiniRow(
                        place: friendStandings.firstIndex(where: { $0.id == item.element.id }).map { $0 + 1 },
                        entry: item.element,
                        mode: challenge.mode,
                        isCurrentUser: false
                    )
                }
            }
        }
    }
}

private struct DailyChallengeStandingsSheet: View {
    let challenge: DailyChallenge
    let myEntry: DailyChallengeEntry?
    let standings: [DailyChallengeEntry]
    let friendStandings: [DailyChallengeEntry]
    let currentUserID: String

    @Environment(\.dismiss) private var dismiss
    @State private var tab: DailyChallengeStandingsTab = .friends

    private var displayedEntries: [DailyChallengeEntry] {
        switch tab {
        case .friends: return friendStandings
        case .global: return standings
        case .me: return myEntry.map { [$0] } ?? []
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        Picker("Results", selection: $tab) {
                            ForEach(DailyChallengeStandingsTab.allCases, id: \.self) { tab in
                                Text(tab.title).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 8) {
                            if displayedEntries.isEmpty {
                                Text(emptyText)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(Array(displayedEntries.prefix(25).enumerated()), id: \.element.id) { item in
                                    DailyChallengeLeaderboardRow(
                                        place: placement(for: item.element),
                                        entry: item.element,
                                        mode: challenge.mode,
                                        isCurrentUser: item.element.userID == currentUserID
                                    )
                                }
                            }
                        }
                        .padding(12)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.1))
                    }
                    .padding()
                }
            }
            .navigationTitle("Daily Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accentBright)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.modeGradient(challenge.mode))
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: challenge.mode.icon).font(.title3.bold()).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(challenge.mode.displayName) Daily")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(challenge.category.displayName) · \(challenge.mode.difficultyLabel(challenge.difficulty))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.25))
    }

    private var emptyText: String {
        switch tab {
        case .friends: return "No friend scores yet."
        case .global: return "No scores yet."
        case .me: return "Finish this challenge to see your result."
        }
    }

    private func placement(for entry: DailyChallengeEntry) -> Int? {
        standings.firstIndex { $0.id == entry.id }.map { $0 + 1 }
    }
}

private enum DailyChallengeStandingsTab: Hashable, CaseIterable {
    case friends
    case global
    case me

    var title: String {
        switch self {
        case .friends: return "Friends"
        case .global: return "Global"
        case .me: return "Me"
        }
    }
}

private struct DailyChallengeLeaderboardRow: View {
    let place: Int?
    let entry: DailyChallengeEntry
    let mode: GameMode
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(place.map { "#\($0)" } ?? "--")
                .font(.caption.bold())
                .foregroundStyle(isCurrentUser ? AppTheme.crownGold : AppTheme.textSecondary)
                .frame(width: 36, alignment: .leading)

            StickDuelerAvatarView(style: entry.avatarStyle, size: 34, initials: String(entry.username.prefix(1)).uppercased())

            VStack(alignment: .leading, spacing: 2) {
                Text(isCurrentUser ? "You" : entry.username)
                    .font(.caption.bold())
                    .foregroundStyle(isCurrentUser ? AppTheme.crownGold : AppTheme.textPrimary)
                    .lineLimit(1)
                Text(dailyResultSummary(entry.result, mode: mode))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer()
        }
        .padding(.vertical, 5)
    }
}

private struct DailyChallengeMiniRow: View {
    let place: Int?
    let entry: DailyChallengeEntry
    let mode: GameMode
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(place.map { "#\($0)" } ?? "--")
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.crownGold)
                .frame(width: 30, alignment: .leading)
            Text(isCurrentUser ? "You" : entry.username)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(dailyResultSummary(entry.result, mode: mode))
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(8)
        .background(AppTheme.controlBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private func dailyResultSummary(_ result: DailyChallengeResult, mode: GameMode) -> String {
    switch mode {
    case .anagram, .wordHunt:
        return "\(result.score) pts · \(result.wordCount ?? 0)w · L\(result.longestWord ?? 0)"
    case .wordle:
        return "\(result.completed ? "Solved" : "Failed") · \(result.guesses ?? 0) guesses · \(formattedTime(result.elapsedSeconds))"
    case .hangman:
        return "\(result.completed ? "Rescued" : "Failed") · \(result.score) letters · \(formattedTime(result.elapsedSeconds))"
    case .gridlock:
        let foundations = Int((result.progress * 52).rounded())
        let moves = result.moves.map { " · \($0)m" } ?? ""
        return "\(result.completed ? "Cleared" : "\(foundations)/52")\(moves) · \(formattedTime(result.elapsedSeconds))"
    default:
        let progress = Int((result.progress * 100).rounded())
        return "\(result.completed ? "Done" : "\(progress)%") · \(formattedTime(result.elapsedSeconds))"
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
    @State private var showStandings = false

    private var canAfford: Bool { userCoins >= tournament.entryFee }
    private var hasResult: Bool { entry?.result != nil }
    private var canClaim: Bool { tournament.isClosed && (entry?.prizeClaimed == false) && preview.prize > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.modeGradient(tournament.mode))
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: tournament.mode.icon).font(.title3.bold()).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament.mode.displayName)
                        .font(.headline.bold())
                    Text("\(tournament.rankTier.displayName) rank only · \(tournament.mode.difficultyLabel(tournament.difficulty))")
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

            VStack(spacing: 10) {
                TimelineView(.periodic(from: Date(), by: 1)) { context in
                    closesRow(now: context.date)
                }

                HStack(spacing: 10) {
                    compactPill(icon: "person.2.fill", label: "Entries", value: "\(standings.count)")
                    compactPill(icon: statusIcon, label: "Status", value: statusText)
                }
            }
            .padding(10)
            .background(AppTheme.tintedPanel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.1))

            if let result = entry?.result {
                Text("Submitted · \(resultSummary(for: result))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else if entry == nil {
                Text("Enter once, play when ready, then check standings after the hour closes.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            HStack(spacing: 10) {
                Button {
                    showStandings = true
                } label: {
                    Label("Standings", systemImage: "list.number")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.controlBackground)
                        .foregroundStyle(AppTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1.15))
                }

                Button(action: { onAction(buttonAction) }) {
                    Label(buttonTitle, systemImage: buttonIcon)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(buttonEnabled ? AppTheme.hotPink : AppTheme.cardBorder)
                        .foregroundStyle(buttonEnabled ? AppTheme.textOnColor : AppTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(!buttonEnabled)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.25))
        .shadow(color: AppTheme.softShadow.opacity(0.38), radius: 10, x: 0, y: 5)
        .sheet(isPresented: $showStandings) {
            TournamentStandingsSheet(
                tournament: tournament,
                entry: entry,
                standings: standings,
                preview: preview
            )
        }
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

    private var statusText: String {
        if entry == nil { return canAfford ? "Open" : "Need coins" }
        if !hasResult { return "Ready" }
        if entry?.prizeClaimed == true { return "Claimed" }
        if !tournament.isClosed { return "Submitted" }
        return preview.prize > 0 ? "Prize ready" : "Complete"
    }

    private var statusIcon: String {
        if entry == nil { return canAfford ? "ticket.fill" : "exclamationmark.circle.fill" }
        if !hasResult { return "play.fill" }
        if entry?.prizeClaimed == true { return "checkmark.seal.fill" }
        if !tournament.isClosed { return "hourglass" }
        return preview.prize > 0 ? "gift.fill" : "checkmark.circle.fill"
    }

    private func compactPill(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.crownGold)
                .frame(width: 22, height: 22)
                .background(AppTheme.crownGold.opacity(0.14))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Text(value)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(AppTheme.controlBackground.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
    }

    private func resultSummary(for result: TournamentResult?) -> String {
        guard let result else { return "No attempt" }
        switch tournament.mode {
        case .anagram, .wordHunt:
            return "\(result.score) pts · \(result.wordCount ?? 0) words · L\(result.longestWord ?? 0)"
        case .wordle:
            return "\(result.completed ? "Solved" : "Failed") · \(result.guesses ?? 0) guesses · \(formattedTime(result.elapsedSeconds))"
        case .hangman:
            return "\(result.completed ? "Rescued" : "Failed") · \(result.score) letters · \(formattedTime(result.elapsedSeconds))"
        case .gridlock:
            let foundations = Int((result.progress * 52).rounded())
            let moves = result.moves.map { " · \($0)m" } ?? ""
            return "\(result.completed ? "Cleared" : "\(foundations)/52")\(moves) · \(formattedTime(result.elapsedSeconds))"
        default:
            let progress = Int((result.progress * 100).rounded())
            return "\(result.completed ? "Done" : "\(progress)%") · \(formattedTime(result.elapsedSeconds))"
        }
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
            Text("\(tournament.rankTier.displayName) only")
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.crownGold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AppTheme.controlBackground.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
    }

    private func countdownText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

private struct TournamentStandingsSheet: View {
    let tournament: DailyTournament
    let entry: TournamentEntry?
    let standings: [TournamentEntry]
    let preview: TournamentPrizePreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        prizeSummary
                        leaderboardSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Standings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accentBright)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.modeGradient(tournament.mode))
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: tournament.mode.icon).font(.title3.bold()).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text(tournament.mode.displayName)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(tournament.rankTier.displayName) rank only · \(tournament.mode.difficultyLabel(tournament.difficulty))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.25))
        .shadow(color: AppTheme.softShadow.opacity(0.35), radius: 9, x: 0, y: 4)
    }

    private var prizeSummary: some View {
        HStack(spacing: 10) {
            statTile("Entries", "\(standings.count)")
            statTile("Paid", "Top \(preview.paidPlaces)")
            statTile("Prize", preview.prize > 0 ? "\(preview.prize)" : "--")
        }
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
        .background(AppTheme.controlBackground.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Leaderboard", systemImage: "list.number")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("Top 5")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.crownGold)
            }

            if standings.isEmpty {
                Text("No scores yet.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(topFiveEntries) { item in
                    leaderboardRow(place: item.place, item: item.entry, isCurrentUser: item.entry.userID == currentUserID)
                }

                if let outside = currentUserOutsideTopFive {
                    Divider().overlay(AppTheme.cardBorder)
                    leaderboardRow(place: outside.place, item: outside.entry, isCurrentUser: true, label: "Your Score")
                }
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.15))
        .shadow(color: AppTheme.softShadow.opacity(0.25), radius: 7, x: 0, y: 3)
    }

    private var currentUserID: String? { entry?.userID }

    private var currentPlacement: Int? {
        guard let currentUserID else { return nil }
        return standings.firstIndex { $0.userID == currentUserID }.map { $0 + 1 }
    }

    private var topFiveEntries: [StandingDisplayEntry] {
        standings.prefix(5).enumerated().map { item in
            StandingDisplayEntry(place: item.offset + 1, entry: item.element)
        }
    }

    private var currentUserOutsideTopFive: (place: Int, entry: TournamentEntry)? {
        guard
            let place = currentPlacement,
            place > 5,
            let currentUserID,
            let entry = standings.first(where: { $0.userID == currentUserID })
        else { return nil }
        return (place, entry)
    }

    private func leaderboardRow(place: Int, item: TournamentEntry, isCurrentUser: Bool, label: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text("#\(place)")
                .font(.caption.bold())
                .foregroundStyle(isCurrentUser ? AppTheme.crownGold : AppTheme.textSecondary)
                .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(label ?? item.username)
                    .font(.caption.bold())
                    .foregroundStyle(isCurrentUser ? AppTheme.crownGold : AppTheme.textPrimary)
                    .lineLimit(1)
                if label != nil {
                    Text(item.username)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(resultSummary(for: item.result))
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 5)
    }

    private func resultSummary(for result: TournamentResult?) -> String {
        guard let result else { return "No attempt" }
        switch tournament.mode {
        case .anagram, .wordHunt:
            return "\(result.score) pts · \(result.wordCount ?? 0)w · L\(result.longestWord ?? 0)"
        case .wordle:
            return "\(result.completed ? "Solved" : "Failed") · \(result.guesses ?? 0) guesses · \(formattedTime(result.elapsedSeconds))"
        case .hangman:
            return "\(result.completed ? "Rescued" : "Failed") · \(result.score) letters · \(formattedTime(result.elapsedSeconds))"
        case .gridlock:
            let foundations = Int((result.progress * 52).rounded())
            let moves = result.moves.map { " · \($0)m" } ?? ""
            return "\(result.completed ? "Cleared" : "\(foundations)/52")\(moves) · \(formattedTime(result.elapsedSeconds))"
        default:
            let progress = Int((result.progress * 100).rounded())
            return "\(result.completed ? "Done" : "\(progress)%") · \(formattedTime(result.elapsedSeconds))"
        }
    }

}

private struct StandingDisplayEntry: Identifiable {
    let place: Int
    let entry: TournamentEntry

    var id: String { entry.id }
}

private struct TournamentGameView: View {
    let tournament: DailyTournament
    let user: AppUser
    let onResult: (SoloGameResult) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var submittedResult: SoloGameResult?
    @State private var isSubmitting = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            if submittedResult == nil {
                Button { dismiss() } label: {
                    Label("Exit", systemImage: "xmark.circle.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.controlBackground)
                        .foregroundStyle(AppTheme.textPrimary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.controlBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding()
            }

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
                    if !isSubmitting {
                        PostGameCoinBoostButton(user: user)
                    }
                    Button("Back to Tournaments") { dismiss() }
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.hotPink)
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

private struct DailyChallengeGameView: View {
    let challenge: DailyChallenge
    let user: AppUser
    let onResult: (SoloGameResult) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var submittedResult: SoloGameResult?
    @State private var isSubmitting = false
    @State private var didSubmit = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SoloGameView(
                mode: challenge.mode,
                difficulty: challenge.difficulty,
                user: user,
                seed: challenge.seed,
                puzzleData: challenge.puzzleData,
                onSoloResult: { result in
                    guard submittedResult == nil else { return }
                    submittedResult = result
                    isSubmitting = true
                    Task {
                        didSubmit = await onResult(result)
                        isSubmitting = false
                    }
                },
                onPlayAgain: {},
                onChangeDifficulty: {},
                onTryRanked: {},
                onHome: { dismiss() }
            )
            .disabled(submittedResult != nil)
            .allowsHitTesting(submittedResult == nil)

            if submittedResult == nil {
                Button { dismiss() } label: {
                    Label("Exit", systemImage: "xmark.circle.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.controlBackground)
                        .foregroundStyle(AppTheme.textPrimary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.controlBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding()
            }

            if let submittedResult {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                VStack(spacing: 12) {
                    Image(systemName: isSubmitting ? "hourglass" : (didSubmit ? "checkmark.seal.fill" : "exclamationmark.circle"))
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.hotPink)
                    Text(isSubmitting ? "Submitting Result" : (didSubmit ? "Daily Result Submitted" : "Result Not Submitted"))
                        .font(.title3.bold())
                    Text("\(submittedResult.title) · \(dailyResultSummary(DailyChallengeResult.fromSoloResult(submittedResult), mode: challenge.mode))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    if !isSubmitting && didSubmit {
                        PostGameCoinBoostButton(user: user)
                    }
                    if !isSubmitting && !didSubmit {
                        Button("Retry Submission") {
                            isSubmitting = true
                            Task {
                                didSubmit = await onResult(submittedResult)
                                isSubmitting = false
                            }
                        }
                    }
                    Button("Back to Daily") { dismiss() }
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.hotPink)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(22)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(24)
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }
}
