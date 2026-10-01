import SwiftUI

// Routes to the correct game view. In multiplayer, pass seed so both players get identical puzzles.
struct SoloGameView: View {
    let mode: GameMode
    let difficulty: Difficulty
    let user: AppUser?
    var sessionID: String? = nil
    var seed: Int? = nil
    var puzzleData: String? = nil
    var onMatchResult: (MatchPlayerResult) -> Void = { _ in }
    var onSoloResult: (SoloGameResult) -> Void = { _ in }
    var onPlayAgain: () -> Void = {}
    var onChangeDifficulty: () -> Void = {}
    var onTryRanked: () -> Void = {}
    var onHome: () -> Void = {}
    var onNextDifficulty: ((Difficulty) -> Void)? = nil

    @State private var runID = UUID()
    @State private var runProgress: SoloRunProgress?
    @StateObject private var rewardRun = SoloRewardRun()
    @State private var confirmsDiscard = false
    @EnvironmentObject private var auth: AuthViewModel

    private var usesSoloRewards: Bool {
        auth.soloRewardsEnabled && sessionID == nil && seed == nil && user != nil
    }

    private var gameSeed: Int? { rewardRun.attempt?.seed ?? seed }

    private func reportSoloResult(_ result: SoloGameResult) {
        onSoloResult(result)
        guard usesSoloRewards, let userID = user?.id else { return }
        Task {
            await rewardRun.submit(result, userID: userID)
            await auth.refreshUser()
        }
    }

    private var currentProgress: SoloRunProgress {
        SoloRunProgress(previousBest: user?.rank(for: mode).soloBest(for: difficulty),
                        completedDifficulties: user?.completedSoloDifficulties(for: mode) ?? [])
    }

    private var replay: () -> Void {
        {
            guard !usesSoloRewards || rewardRun.isSettled else { return }
            runProgress = currentProgress
            rewardRun.reset()
            runID = UUID()
            onPlayAgain()
        }
    }

    var body: some View {
        Group {
            if usesSoloRewards && rewardRun.attempt == nil {
                VStack(spacing: 16) {
                    if let error = rewardRun.error {
                        Text(error).font(.callout).multilineTextAlignment(.center)
                        Button("Retry") { runID = UUID() }
                        Button("Discard Attempt", role: .destructive) { confirmsDiscard = true }
                    } else {
                        ProgressView("Preparing puzzle")
                    }
                    Button("Back", action: onChangeDifficulty)
                }.padding()
            } else {
                game
            }
        }
        .environment(\.soloRewardRun, usesSoloRewards ? rewardRun : nil)
        .confirmationDialog("Discard this attempt and its pending reward?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Discard Attempt", role: .destructive) {
                Task {
                    if await rewardRun.discard() {
                        rewardRun.reset()
                        runID = UUID()
                    }
                }
            }
        }
        .task(id: runID) {
            guard usesSoloRewards, let userID = user?.id else { return }
            await rewardRun.prepare(userID: userID, mode: mode, difficulty: difficulty)
        }
    }

    private var game: some View {
        Group {
            switch mode {
            case .sudoku:
                SudokuView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: gameSeed, onMatchResult: onMatchResult, onSoloResult: reportSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .minesweeper:
                MinesweeperView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: gameSeed, onMatchResult: onMatchResult, onSoloResult: reportSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .colorLink:
                ColorLinkView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: gameSeed, onMatchResult: onMatchResult, onSoloResult: reportSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .gridlock:
                GridlockView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: gameSeed, onMatchResult: onMatchResult, onSoloResult: reportSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .anagram:
                AnagramView(difficulty: difficulty, user: user, sessionID: sessionID, seed: gameSeed, puzzleData: puzzleData, onMatchResult: onMatchResult, onSoloResult: reportSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .wordHunt:
                WordHuntView(difficulty: difficulty, user: user, sessionID: sessionID, seed: gameSeed, puzzleData: puzzleData, onMatchResult: onMatchResult, onSoloResult: reportSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .wordle:
                WordleView(difficulty: difficulty, user: user, sessionID: sessionID, seed: gameSeed, puzzleData: puzzleData, onMatchResult: onMatchResult, onSoloResult: reportSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .hangman:
                HangmanView(difficulty: difficulty, user: user, sessionID: sessionID, seed: gameSeed, puzzleData: puzzleData, onMatchResult: onMatchResult, onSoloResult: reportSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            }
        }
        .id(runID)
        .environment(\.boardCosmetics, user?.cosmetics ?? .default)
        .environment(\.soloRunContext, onNextDifficulty.map {
            SoloRunContext(progress: runProgress ?? currentProgress, advance: $0)
        })
        .onAppear {
            if runProgress == nil { runProgress = currentProgress }
        }
    }
}

@MainActor
private final class SoloRewardRun: ObservableObject {
    @Published var attempt: SoloRewardAttempt?
    @Published var receipt: SoloRewardReceipt?
    @Published var error: String?
    @Published var isBusy = false
    @Published var isDiscarded = false
    var isSettled: Bool { receipt != nil || isDiscarded }
    private var pendingResult: SoloGameResult?
    private var userID: String?

    func reset() {
        guard !isBusy else { return }
        attempt = nil
        receipt = nil
        error = nil
        pendingResult = nil
        isDiscarded = false
    }

    func prepare(userID: String, mode: GameMode, difficulty: Difficulty) async {
        guard !isBusy else { return }
        self.userID = userID
        isBusy = true
        error = nil
        defer { isBusy = false }
        do { attempt = try await SoloRewardClient.begin(userID: userID, mode: mode, difficulty: difficulty) }
        catch { self.error = error.localizedDescription }
    }

    func submit(_ result: SoloGameResult, userID: String) async {
        guard let attempt, receipt == nil, !isBusy else { return }
        pendingResult = result
        isBusy = true
        error = nil
        defer { isBusy = false }
        guard let evidence = result.rewardEvidenceJSON else {
            error = "This attempt is missing its verification data. No coins were granted."
            return
        }
        do { receipt = try await SoloRewardClient.submit(userID: userID, attemptID: attempt.id, evidenceJSON: evidence) }
        catch { self.error = error.localizedDescription }
    }

    func retry() async {
        guard let pendingResult, let userID else { return }
        await submit(pendingResult, userID: userID)
    }

    func discard() async -> Bool {
        guard !isBusy, let userID else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            try await SoloRewardClient.discardPendingAttempt(userID: userID)
            isDiscarded = true
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

private struct SoloRewardRunKey: EnvironmentKey {
    static let defaultValue: SoloRewardRun? = nil
}

private extension EnvironmentValues {
    var soloRewardRun: SoloRewardRun? {
        get { self[SoloRewardRunKey.self] }
        set { self[SoloRewardRunKey.self] = newValue }
    }
}

private struct SoloRewardSummary: View {
    @ObservedObject var run: SoloRewardRun
    @EnvironmentObject private var auth: AuthViewModel
    @State private var confirmsDiscard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let receipt = run.receipt {
                Label("Coins Earned", systemImage: "checkmark.circle.fill").font(.headline)
                HStack {
                    Text("Puzzle +\(receipt.puzzleCoins)")
                    Spacer()
                    Text("Daily bonus +\(receipt.dailyCoins)")
                }.font(.subheadline)
            } else if run.isDiscarded {
                Text("Attempt closed").font(.subheadline)
            } else if let error = run.error {
                Text(error).font(.caption)
                Button("Retry Reward") {
                    Task { await run.retry(); await auth.refreshUser() }
                }.disabled(run.isBusy)
                Button("Discard Attempt", role: .destructive) { confirmsDiscard = true }
                    .disabled(run.isBusy)
            } else {
                ProgressView("Verifying reward")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .foregroundStyle(AppTheme.textPrimary)
        .confirmationDialog("Discard this attempt and its pending reward?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Discard Attempt", role: .destructive) {
                Task { _ = await run.discard(); await auth.refreshUser() }
            }
        }
    }
}

private struct SoloRunContext {
    let progress: SoloRunProgress
    let advance: (Difficulty) -> Void
}

private struct SoloRunContextKey: EnvironmentKey {
    static let defaultValue: SoloRunContext? = nil
}

private extension EnvironmentValues {
    var soloRunContext: SoloRunContext? {
        get { self[SoloRunContextKey.self] }
        set { self[SoloRunContextKey.self] = newValue }
    }
}

struct SoloResultOverlay: View {
    let result: SoloGameResult
    let onPlayAgain: () -> Void
    let onChangeDifficulty: () -> Void
    let onTryRanked: () -> Void
    let onHome: () -> Void
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.soloRunContext) private var runContext
    @Environment(\.soloRewardRun) private var rewardRun

    var body: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    resultHeader
                    statGrid
                    personalBestSummary
                    unlockSummary
                    if let rewardRun { SoloRewardSummary(run: rewardRun) }
                    actionButtons
                    progressSummary
                    detailSummary
                    sectionBreakdowns
                    PostGameCoinBoostButton(user: auth.user) { _ in
                        Task { await auth.refreshUser() }
                    }
                }
                .padding(22)
            }
            .background(AppTheme.backgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(AppTheme.cardBorder, lineWidth: 1))
            .padding(18)
        }
        .transition(.opacity)
    }

    private var resultHeader: some View {
        VStack(spacing: 12) {
            Label("\(result.mode.displayName) · \(result.mode.difficultyLabel(result.difficulty))", systemImage: result.mode.icon)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.accentBright)
                .multilineTextAlignment(.center)

            VStack(spacing: 5) {
                Text(result.title)
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text(result.message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var statGrid: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(result.stats.prefix(4))) { stat in
                    VStack(spacing: 3) {
                        Text(stat.value)
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.accentBright)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(stat.label)
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 74)
                    .padding(.horizontal, 8)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                }
            }
            ForEach(Array(result.stats.dropFirst(4))) { stat in
                HStack(alignment: .firstTextBaseline) {
                    Text(stat.label).foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(stat.value).bold().foregroundStyle(AppTheme.textPrimary)
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var progressSummary: some View {
        if let progress = normalizedProgress {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(progressLabel)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accentBright)
                }
                ProgressView(value: progress)
                    .tint(AppTheme.accentBright)
            }
            .resultPanel()
        }
    }

    @ViewBuilder
    private var detailSummary: some View {
        if !result.details.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Breakdown")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(result.details, id: \.self) { detail in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(AppTheme.accentBright.opacity(0.85))
                            .frame(width: 5, height: 5)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .resultPanel()
        }
    }

    @ViewBuilder
    private var sectionBreakdowns: some View {
        if !result.sections.isEmpty {
            ForEach(result.sections) { section in
                DisclosureGroup {
                    sectionItems(section)
                } label: {
                    HStack {
                        Text(section.title)
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text("\(section.items.count)")
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.accentBright)
                    }
                }
                .tint(AppTheme.accentBright)
                .resultPanel()
            }
        }
    }

    @ViewBuilder
    private func sectionItems(_ section: SoloResultSection) -> some View {
        if section.items.isEmpty {
            Text("None")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        } else {
            LazyVGrid(columns: result.mode == .wordle ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 112), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(section.items, id: \.self) { item in
                    Text(item)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.controlBorder.opacity(0.7), lineWidth: 1))
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if let next = nextDifficulty, let context = runContext {
                resultButton("Play \(result.mode.difficultyLabel(next))", icon: "arrow.right", action: { context.advance(next) }, filled: true)
            }
            resultButton("Play Again", icon: "arrow.clockwise", action: onPlayAgain, filled: nextDifficulty == nil)
                .disabled(rewardRun.map { !$0.isSettled } ?? false)
            HStack {
                Button(action: onChangeDifficulty) {
                    Label("Difficulty", systemImage: "slider.horizontal.3")
                }
                Spacer()
                Menu {
                    ShareLink(item: result.shareText) { Label("Share Result", systemImage: "square.and.arrow.up") }
                    Button("Challenge Friends", systemImage: "person.2.fill") {
                        NotificationCenter.default.post(name: .openFriendsTabRequested, object: nil)
                        onHome()
                    }
                    Button("Daily Challenges", systemImage: "calendar.badge.checkmark") {
                        NotificationCenter.default.post(name: .openDailyTabRequested, object: nil)
                        onHome()
                    }
                    Button("Try Ranked", systemImage: "flag.checkered.2.crossed", action: onTryRanked)
                    Button("Home", systemImage: "house.fill", action: onHome)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(minHeight: 44)
        }
    }

    private var nextDifficulty: Difficulty? {
        runContext?.progress.newlyUnlockedDifficulty(for: result)
    }

    @ViewBuilder
    private var personalBestSummary: some View {
        if let comparison = runContext?.progress.bestComparison(for: result) {
            VStack(alignment: .leading, spacing: 4) {
                Label(comparison.title, systemImage: comparison.isNewBest ? "trophy.fill" : "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accentBright)
                if let previous = comparison.previous {
                    Text("This run: \(comparison.current.displayText(for: result.mode))")
                    Text("Previous best: \(previous.displayText(for: result.mode))")
                } else {
                    Text(comparison.current.displayText(for: result.mode))
                }
                Text(result.mode.difficultyLabel(result.difficulty))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder
    private var unlockSummary: some View {
        if let context = runContext {
            if let next = nextDifficulty {
                Label("\(result.mode.difficultyLabel(next)) unlocked", systemImage: "lock.open.fill")
                    .foregroundStyle(AppTheme.teal)
                    .font(.headline)
            } else if !result.completed && !context.progress.completedDifficulties.contains(result.difficulty) {
                Text(result.mode.soloCompletionRequirement)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            } else if result.completed && result.difficulty == .expert {
                Label("Final difficulty completed", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.teal)
            }
        }
    }

    private var progressLabel: String {
        switch result.mode {
        case .anagram, .wordHunt: return "Possible words found"
        case .minesweeper: return "Safe cells revealed"
        case .colorLink: return "Board filled"
        case .gridlock: return "Cards in foundations"
        case .sudoku: return "Puzzle filled"
        case .hangman: return "Unique letters revealed"
        case .wordle: return "Word solved"
        }
    }

    private var normalizedProgress: Double? {
        guard result.mode != .wordle, let progress = result.progress, progress.isFinite else { return nil }
        if progress < 0 { return 0 }
        if progress > 1 { return nil }
        return progress
    }

    private func resultButton(_ title: String, icon: String, action: @escaping () -> Void, filled: Bool = false) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 14)
                .background(filled ? AnyShapeStyle(AppTheme.modeGradient(result.mode)) : AnyShapeStyle(AppTheme.controlBackground))
                .foregroundStyle(filled ? AppTheme.textOnColor : AppTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(filled ? Color.clear : AppTheme.controlBorder, lineWidth: filled ? 0 : 1.5))
        }
    }

}

struct PostGameCoinBoostButton: View {
    let user: AppUser?
    var onRewardGranted: (AppUser) -> Void = { _ in }

    @State private var localRemaining: Int?
    @State private var isWatching = false
    @State private var didClaimOnThisResult = false
    @State private var errorMessage: String?

    private var remainingAds: Int {
        localRemaining ?? user?.coinWallet.rewardedAdsRemaining() ?? 0
    }

    private var canShow: Bool {
        user != nil && remainingAds > 0 && !didClaimOnThisResult
    }

    var body: some View {
        if canShow {
            VStack(spacing: 7) {
                Button {
                    Task { await watchBoostAd() }
                } label: {
                    HStack(spacing: 10) {
                        if isWatching {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "play.rectangle.fill")
                        }
                        Text(isWatching ? "Loading reward..." : "Watch Ad: +\(CoinWallet.rewardedAdAmount) coins")
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(AppTheme.crownGold)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: AppTheme.crownGold.opacity(0.28), radius: 8, x: 0, y: 4)
                }
                .disabled(isWatching)

                Text("Optional coin boost. \(remainingAds)/\(CoinWallet.rewardedAdsPerDay) left today.")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.textSecondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.warning)
                        .multilineTextAlignment(.center)
                }
            }
            .resultPanel()
        }
    }

    @MainActor
    private func watchBoostAd() async {
        guard let user, remainingAds > 0, !isWatching else { return }
        isWatching = true
        errorMessage = nil
        defer { isWatching = false }

        do {
            try await RewardedAdService.shared.watchCoinRewardAd()
            let updatedUser = try await FirestoreService.shared.grantRewardedCoins(userID: user.id)
            localRemaining = updatedUser.coinWallet.rewardedAdsRemaining()
            didClaimOnThisResult = true
            onRewardGranted(updatedUser)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension SoloGameResult {
    var shareText: String {
        var lines = [
            "I just played \(mode.displayName) on Puzzle Party.",
            completed ? "Result: \(title)" : "Result: \(title)",
            "Difficulty: \(mode.difficultyLabel(difficulty))",
            "Time: \(formattedTime(elapsedSeconds))"
        ]

        if let score {
            lines.append("Score: \(score)")
        }
        if let progress, progress >= 0, progress <= 1 {
            lines.append("Progress: \(Int((progress * 100).rounded()))%")
        }
        if let guesses {
            lines.append("Guesses: \(guesses)")
        }
        if let moves {
            lines.append("Moves: \(moves)")
        }

        lines.append("Can you beat it?")
        return lines.joined(separator: "\n")
    }
}

private extension View {
    func resultPanel() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

func formattedTime(_ seconds: Int) -> String {
    "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}
