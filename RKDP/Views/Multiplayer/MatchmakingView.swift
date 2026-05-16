import SwiftUI

struct MatchmakingView: View {
    let user: AppUser
    let mode: GameMode
    let difficulty: Difficulty
    var onMatchFinished: () -> Void = {}

    @StateObject private var vm = MultiplayerViewModel()
    @State private var selectedWager: WagerTier?
    @State private var showBreakdown = false
    @State private var didNotifyFinished = false
    @State private var inMatchMusicEnabled = true
    @State private var showForfeitWarning = false
    @State private var rewardAnimationFinished = false
    @Environment(\.dismiss) var dismiss

    private var wagerOptions: [WagerTier] {
        Wager.options(for: user.rank(for: mode).tier)
    }

    private var shouldBlockDismiss: Bool {
        switch vm.state {
        case .matchFound, .inMatch:
            return true
        default:
            return false
        }
    }

    private var activeInMatchSession: GameSession? {
        if case .inMatch(let session) = vm.state { return session }
        return nil
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                switch vm.state {
                case .idle:
                    wagerPicker
                case .searching:
                    searchingView
                case .matchFound(let session):
                    matchFoundView(session: session)
                case .inMatch(let session):
                    inMatchView(session: session)
                case .finished(let session):
                    resultView(session: session)
                case .error(let msg):
                    errorView(msg)
                }
            }
        }
        .foregroundStyle(AppTheme.textPrimary)
        .navigationTitle("Ranked Match")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(shouldBlockDismiss)
        .interactiveDismissDisabled(shouldBlockDismiss)
        .onDisappear {
            SoundManager.shared.stopAllLoops()
            vm.handleViewDisappeared()
        }
        .onChange(of: vm.finishedSessionID) { _, sessionID in
            guard sessionID != nil else { return }
            rewardAnimationFinished = false
            guard !didNotifyFinished else { return }
            didNotifyFinished = true
            onMatchFinished()
        }
        .alert("Forfeit ranked match?", isPresented: $showForfeitWarning) {
            Button("Keep Playing", role: .cancel) {}
            Button("Forfeit", role: .destructive) {
                guard let session = activeInMatchSession else { return }
                Task { await vm.forfeitMatch(session: session) }
            }
        } message: {
            Text("Quitting now counts as a ranked loss and forfeits your wager.")
        }
    }

    // MARK: - Wager picker

    private var wagerPicker: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(mode.accentColor)
                    Text("\(mode.displayName) · \(mode.difficultyLabel(difficulty))")
                        .font(.headline)
                    HStack {
                        Text("Your balance:")
                        CoinBadgeView(amount: user.coins)
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                }

                Text("Choose Your Wager").font(.title3.bold())

                VStack(spacing: 12) {
                    ForEach(wagerOptions) { option in
                        WagerOptionRow(
                            option: option,
                            isSelected: selectedWager?.id == option.id,
                            canAfford: user.coins >= option.amount
                        ) {
                            selectedWager = option
                        }
                    }
                }
                .padding(.horizontal)

                if let wager = selectedWager {
                    VStack(spacing: 6) {
                        Text("Winner takes: \(wager.amount * 2) coins").font(.subheadline.bold()).foregroundStyle(AppTheme.success)
                        Text("Both players wager \(wager.amount) coins each").font(.caption).foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
                    .padding(.horizontal)
                }

                Button {
                    guard let wager = selectedWager else { return }
                    didNotifyFinished = false
                    rewardAnimationFinished = false
                    inMatchMusicEnabled = true
                    Task { await vm.startSearch(user: user, mode: mode, difficulty: difficulty, wager: wager) }
                } label: {
                    Text("Find Match")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedWager != nil ? mode.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(selectedWager == nil)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Searching

    private var searchingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text("Finding a match…")
                .font(.title3.bold())
            if let wager = vm.selectedWager {
                Text("Wager: \(wager.amount) coins").foregroundStyle(.secondary)
            }
            Button("Cancel") { Task { await vm.cancelSearch() } }
                .foregroundStyle(.red)
            Spacer()
        }
        .onAppear { SoundManager.shared.playMatchmakingLoop() }
        .onDisappear { SoundManager.shared.stopMatchmakingLoop() }
    }

    // MARK: - Match found

    private func matchFoundView(session: GameSession) -> some View {
        let opponent = session.players.first { $0.userID != user.id }
        let oppUser  = vm.opponentUser

        return VStack(spacing: 24) {
            Spacer()

            Text("Match Found!")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.textPrimary)

            // Opponent card
            VStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.brandGradient)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text(String((opponent?.username ?? "?").prefix(1)))
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    )
                    .shadow(color: AppTheme.accent.opacity(0.5), radius: 10)

                VStack(spacing: 4) {
                    Text(opponent?.username ?? "Opponent")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)

                    if let title = oppUser?.cosmetics.equippedTitle,
                       let item = CosmeticCatalog.allTitles.first(where: { $0.id == title }) {
                        Text(item.name)
                            .font(.caption.italic())
                            .foregroundStyle(AppTheme.accentBright)
                    }

                    if let opp = opponent {
                        let liveRank = oppUser?.rank(for: mode)
                        let oppRank = liveRank ?? RankInfo(points: opp.rankPoints, tier: RankTier.tier(for: opp.rankPoints),
                                                           wins: 0, losses: 0, bestTime: nil, bestScore: nil)
                        Text(oppRank.fullDisplayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(oppRank.displayTier.color)
                        RecordTextView(
                            wins: liveRank?.wins,
                            losses: liveRank?.losses,
                            prefix: "W/L ",
                            font: .caption.bold()
                        )
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.cardBorder, lineWidth: 1))
            .padding(.horizontal)

            // Countdown ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: CGFloat(vm.matchCountdown) / 5.0)
                    .stroke(mode.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: vm.matchCountdown)
                Text("\(vm.matchCountdown)")
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Text("Game starts automatically…")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                Task { await vm.abortMatchFound(session: session) }
            } label: {
                Label("Abort (−1 coin)", systemImage: "xmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .onAppear {
            SoundManager.shared.stopMatchmakingLoop()
            SoundManager.shared.playGameFound()
        }
    }

    // MARK: - In match

    private func inMatchView(session: GameSession) -> some View {
        VStack(spacing: 0) {
            // Opponent status bar
            HStack(spacing: 10) {
                Label("Opponent", systemImage: "person.fill")
                Spacer()
                if let oppResult = vm.playerResults.first(where: { $0.key != user.id })?.value {
                    Label(oppResult.status, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                } else {
                    Text("In progress…").foregroundStyle(AppTheme.textSecondary)
                }
                Button {
                    toggleInMatchMusic()
                } label: {
                    Image(systemName: inMatchMusicEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(inMatchMusicEnabled ? AppTheme.accentBright : AppTheme.textSecondary)

                Button {
                    showForfeitWarning = true
                } label: {
                    Label("Quit", systemImage: "flag.slash.fill")
                        .labelStyle(.iconOnly)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(AppTheme.danger)
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(AppTheme.cardBackground)

            ZStack {
                // Game board — seed ensures both players get identical puzzle
                SoloGameView(
                    mode: session.mode,
                    difficulty: session.difficulty,
                    user: vm.user,
                    sessionID: session.id,
                    seed: session.seed
                ) { result in
                    Task { await vm.submitResult(result, session: session) }
                }

                if let myResult = vm.playerResults[user.id] {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(myResult.status)
                            .font(.headline.bold())
                        Text("Waiting for opponent…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 12)
                }
            }
        }
        .onAppear {
            SoundManager.shared.stopMatchmakingLoop()
            if inMatchMusicEnabled {
                SoundManager.shared.playOnlineGameLoop()
            }
        }
        .onDisappear { SoundManager.shared.stopOnlineGameLoop() }
    }

    private func toggleInMatchMusic() {
        inMatchMusicEnabled.toggle()
        if inMatchMusicEnabled {
            SoundManager.shared.playOnlineGameLoop()
        } else {
            SoundManager.shared.stopOnlineGameLoop()
        }
    }

    // MARK: - Result

    private func resultView(session: GameSession) -> some View {
        let isWinner = session.winnerID == user.id
        let isDraw   = session.winnerID == nil
        let results      = session.playerResults ?? vm.playerResults
        let myResult     = results[user.id]
        let opponentID   = session.players.first(where: { $0.userID != user.id })?.userID ?? ""
        let opponentResult = results[opponentID]
        let snapshot = vm.rewardSnapshot ?? PostMatchRewardSnapshot.staticSnapshot(session: session, user: user)
        let controlsReady = rewardAnimationFinished || !snapshot.shouldAnimate

        return VStack(spacing: 20) {
            Spacer()
            Text(isDraw ? "Draw 🤝" : (isWinner ? "Victory! 🏆" : "Defeat 😔"))
                .font(.largeTitle.bold())
                .foregroundStyle(isDraw || isWinner ? AppTheme.crownGold : AppTheme.textSecondary)

            Text(userFacingResultReason(session: session, results: results))
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Performance breakdown
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    performanceColumn(label: "You", result: myResult, highlight: isWinner)
                    Divider().frame(height: 60)
                    performanceColumn(label: "Opponent", result: opponentResult, highlight: !isWinner && !isDraw)
                }
                .padding(.vertical, 10)

                Divider()

                PostMatchRewardPanel(
                    snapshot: snapshot,
                    adjustmentLabel: rankAdjustmentLabel(session: session)
                ) {
                    rewardAnimationFinished = true
                }
                .padding(.vertical, 10)
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
            .padding(.horizontal)

            if let rewardError = vm.rewardErrorMessage {
                Button {
                    Task { await vm.retryFinishedRewards(session: session) }
                } label: {
                    Label(rewardError, systemImage: "arrow.clockwise.circle.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.warning.opacity(0.18))
                        .foregroundStyle(AppTheme.warning)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.warning.opacity(0.45), lineWidth: 1))
                }
                .padding(.horizontal)
            }

            Button { showBreakdown = true } label: {
                Label("Match Breakdown", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .foregroundStyle(mode.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
            }
            .padding(.horizontal)
            .opacity(controlsReady ? 1 : 0.36)
            .disabled(!controlsReady)

            Button {
                didNotifyFinished = false
                rewardAnimationFinished = false
                vm.reset()
            } label: {
                Text("Play Again")
                    .frame(maxWidth: .infinity).padding()
                    .background(mode.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .opacity(controlsReady ? 1 : 0.36)
            .disabled(!controlsReady)

            Button("Back to Home") { dismiss() }
                .foregroundStyle(.secondary)
                .opacity(controlsReady ? 1 : 0.36)
                .disabled(!controlsReady)
            Spacer()
        }
        .onAppear { SoundManager.shared.stopAllLoops() }
        .sheet(isPresented: $showBreakdown) {
            MatchBreakdownView(session: session, currentUserID: user.id, results: results)
        }
    }

    private func performanceColumn(label: String, result: MatchPlayerResult?, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            if let result {
                Text(result.status)
                    .font(.headline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(highlight ? .green : .primary)
                Text("\(result.elapsedSeconds / 60):\(String(format: "%02d", result.elapsedSeconds % 60))")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                Text("—").font(.title2.bold()).foregroundStyle(.secondary)
                Text(sessionModeMissingResultText).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func userFacingResultReason(session: GameSession, results: [String: MatchPlayerResult]) -> String {
        if let forfeiterID = results.first(where: { $0.value.summary["forfeit"] == "true" })?.key,
           let forfeiter = session.players.first(where: { $0.userID == forfeiterID }) {
            return forfeiter.userID == user.id ? "You forfeited" : "\(forfeiter.username) forfeited"
        }

        if session.winnerReason == "Opponent forfeited",
           let winnerID = session.winnerID,
           let forfeiter = session.players.first(where: { $0.userID != winnerID }) {
            return forfeiter.userID == user.id ? "You forfeited" : "\(forfeiter.username) forfeited"
        }

        return session.winnerReason ?? mode.winConditionText
    }

    private var sessionModeMissingResultText: String {
        mode == .wordle ? "not finished" : "waiting"
    }

    private func rankAdjustmentLabel(session: GameSession) -> String? {
        guard session.winnerID != nil,
              let me = session.players.first(where: { $0.userID == user.id }),
              let opponent = session.players.first(where: { $0.userID != user.id }) else { return nil }
        let myScore = rankPosition(me)
        let oppScore = rankPosition(opponent)
        guard myScore != oppScore else { return nil }
        if session.winnerID == user.id {
            return oppScore > myScore ? "Higher division bonus" : "Lower division adjustment"
        }
        return oppScore > myScore ? "Reduced loss vs higher division" : "Lower division penalty"
    }

    private func rankPosition(_ player: MatchPlayer) -> Int {
        let info = RankInfo(
            points: player.rankPoints,
            tier: RankTier.tier(for: player.rankPoints),
            wins: 0,
            losses: 0,
            bestTime: nil,
            bestScore: nil
        )
        return info.displayTier.rawValue * 3 + info.division.rawValue
    }

    // MARK: - Error

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(.red)
            Text("Something went wrong").font(.title3.bold())
            Text(msg).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry") { vm.reset() }
        }
        .padding()
    }
}


struct PostMatchRewardPanel: View {
    let snapshot: PostMatchRewardSnapshot
    let adjustmentLabel: String?
    let onAnimationFinished: () -> Void

    @State private var displayedCoins = 0
    @State private var displayedRankProgress = 0.0
    @State private var coinsArrived = false
    @State private var showEndingRank = false
    @State private var rankPulse = false
    @State private var hasStarted = false

    private var displayedRank: RankInfo { showEndingRank ? snapshot.endingRank : snapshot.startingRank }
    private var coinSpriteCount: Int { min(16, max(8, abs(snapshot.coinDelta) / 5)) }
    private var rankGain: Bool { snapshot.rankDelta >= 0 }
    private var rankColor: Color { rankGain ? AppTheme.success : AppTheme.danger }
    private var transitionLabel: String? {
        if snapshot.didPromote { return "Promoted" }
        if snapshot.didDemote { return "Demoted" }
        return nil
    }
    private var animationIdentity: String {
        "\(snapshot.sessionID)-\(snapshot.shouldAnimate)-\(snapshot.startingCoins)-\(snapshot.endingCoins)-\(snapshot.rankDelta)"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    balanceChip
                    Spacer()
                    coinDeltaBlock
                }

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        RankIconView(
                            tier: displayedRank.displayTier,
                            division: displayedRank.division,
                            size: rankPulse ? 42 : 34
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayedRank.fullDisplayName)
                                .font(.headline.bold())
                                .foregroundStyle(displayedRank.displayTier.color)
                            Text(displayedRank.nextRankStepText)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Rank Points")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(deltaText(snapshot.rankDelta))
                                .font(.title3.bold())
                                .foregroundStyle(rankColor)
                        }
                    }

                    RankDivisionProgressView(
                        info: displayedRank,
                        height: 8,
                        spacing: 4,
                        showLabels: true,
                        progressOverride: displayedRankProgress
                    )
                    .shadow(color: rankColor.opacity(rankPulse ? 0.65 : 0.18), radius: rankPulse ? 9 : 3)

                    HStack {
                        if let adjustmentLabel {
                            Text(adjustmentLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.crownGold)
                        }
                        Spacer()
                        if let transitionLabel {
                            Text(transitionLabel.uppercased())
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(snapshot.didPromote ? AppTheme.crownGold : AppTheme.danger)
                                .opacity(showEndingRank ? 1 : 0)
                        }
                    }
                }
            }
            .padding(14)

            coinSprites
        }
        .task(id: animationIdentity) {
            hasStarted = false
            await runAnimation()
        }
    }

    private var balanceChip: some View {
        HStack(spacing: 6) {
            CoinIconView(size: 22)
                .scaleEffect(coinsArrived && snapshot.coinDelta >= 0 ? 1.18 : 1)
            Text("\(displayedCoins)")
                .font(.headline.bold())
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.cardBackground)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var coinDeltaBlock: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Coins")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(deltaText(snapshot.coinDelta))
                .font(.title3.bold())
                .foregroundStyle(snapshot.coinDelta >= 0 ? AppTheme.success : AppTheme.danger)
        }
    }

    @ViewBuilder
    private var coinSprites: some View {
        if snapshot.coinDelta != 0 && snapshot.shouldAnimate {
            ForEach(0..<coinSpriteCount, id: \.self) { index in
                CoinIconView(size: 15)
                    .scaleEffect(coinsArrived ? 0.34 : 1)
                    .opacity(coinsArrived ? 0 : 1)
                    .offset(coinOffset(index: index, arrived: coinsArrived))
                    .animation(
                        .interpolatingSpring(stiffness: 90, damping: 13)
                            .delay(Double(index) * 0.035),
                        value: coinsArrived
                    )
            }
        }
    }

    private func coinOffset(index: Int, arrived: Bool) -> CGSize {
        if snapshot.coinDelta > 0 {
            let startX = CGFloat(210 + (index % 4) * 18)
            let startY = CGFloat(36 + (index / 4) * 16)
            return arrived ? CGSize(width: 22, height: 9) : CGSize(width: startX, height: startY)
        } else {
            let endX = CGFloat(130 + (index % 5) * 30)
            let endY = CGFloat(96 + (index / 5) * 22)
            return arrived ? CGSize(width: endX, height: endY) : CGSize(width: 22, height: 9)
        }
    }

    private func runAnimation() async {
        guard !hasStarted else { return }
        hasStarted = true
        displayedCoins = snapshot.startingCoins
        displayedRankProgress = startingBarProgress
        showEndingRank = false
        coinsArrived = false
        rankPulse = false

        guard snapshot.shouldAnimate else {
            displayedCoins = snapshot.endingCoins
            displayedRankProgress = rankProgress(snapshot.endingRank)
            showEndingRank = true
            onAnimationFinished()
            return
        }

        try? await Task.sleep(nanoseconds: 250_000_000)
        withAnimation(.easeOut(duration: 0.85)) { coinsArrived = true }
        await countCoins()

        try? await Task.sleep(nanoseconds: 180_000_000)
        withAnimation(.easeInOut(duration: 0.95)) {
            displayedRankProgress = endingBarProgress
        }
        try? await Task.sleep(nanoseconds: 950_000_000)

        showEndingRank = true
        displayedRankProgress = rankProgress(snapshot.endingRank)
        if snapshot.didPromote || snapshot.didDemote {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.48)) {
                rankPulse = true
            }
            try? await Task.sleep(nanoseconds: 550_000_000)
            withAnimation(.easeOut(duration: 0.25)) { rankPulse = false }
        }
        onAnimationFinished()
    }

    private func countCoins() async {
        let steps = max(1, min(18, abs(snapshot.coinDelta)))
        for step in 1...steps {
            displayedCoins = snapshot.startingCoins + Int(Double(snapshot.coinDelta) * Double(step) / Double(steps))
            try? await Task.sleep(nanoseconds: 42_000_000)
        }
        displayedCoins = snapshot.endingCoins
    }

    private var startingBarProgress: Double { rankProgress(snapshot.startingRank) }

    private var endingBarProgress: Double {
        if snapshot.didPromote { return 1 }
        if snapshot.didDemote { return 0 }
        return rankProgress(snapshot.endingRank)
    }

    private func rankProgress(_ rank: RankInfo) -> Double {
        rank.divisionProgress
    }

    private func deltaText(_ value: Int) -> String {
        "\(value >= 0 ? "+" : "")\(value)"
    }
}


struct MatchBreakdownView: View {
    let session: GameSession
    let currentUserID: String
    let results: [String: MatchPlayerResult]
    @Environment(\.dismiss) private var dismiss

    private var currentOutcome: SessionResult { session.result(for: currentUserID) ?? .draw }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                        ForEach(session.players, id: \.userID) { player in
                            playerBreakdownCard(player)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Match Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accentBright)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: headerIcon)
                    .font(.title2.bold())
                    .foregroundStyle(session.mode.accentColor)
                    .frame(width: 36, height: 36)
                    .background(session.mode.accentColor.opacity(0.16))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(session.mode.displayName) · \(session.mode.difficultyLabel(session.difficulty))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }

            Text(userFacingReason)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func playerBreakdownCard(_ player: MatchPlayer) -> some View {
        let result = results[player.userID]
        let isCurrent = player.userID == currentUserID
        let isWinner = session.winnerID == player.userID

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isWinner ? AppTheme.brandGradient : LinearGradient(colors: [AppTheme.cardBackground], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .overlay(Text(String(player.username.prefix(1))).font(.headline.bold()).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text(isCurrent ? "You" : player.username)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(result.map { displayStatus($0, for: player) } ?? missingResultText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor(result, isWinner: isWinner))
                }
                Spacer()
                if isWinner {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(AppTheme.crownGold)
                }
            }

            if let result {
                if session.mode == .wordle {
                    wordleBreakdown(result)
                } else {
                    statGrid(modeStats(for: result))
                    detailLines(result.details)
                }
            } else {
                Text(missingResultText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func statGrid(_ stats: [(String, String)]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                VStack(alignment: .leading, spacing: 3) {
                    Text(stat.0)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(stat.1)
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func wordleBreakdown(_ result: MatchPlayerResult) -> some View {
        let rounds = parsedWordleRounds(from: result)
        statGrid([
            ("Rounds", "\(result.solvedRounds)/3 solved"),
            ("Solved guesses", "\(result.totalGuesses)"),
            ("Time", formattedTime(result.elapsedSeconds)),
            ("Status", result.completed ? "Complete" : "Incomplete")
        ])

        if rounds.isEmpty {
            detailLines(result.details.isEmpty ? ["No Wordle round details were stored for this match."] : result.details)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rounds) { round in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Round \(round.index)")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text(round.solved ? "Solved" : "Failed")
                                .font(.caption.bold())
                                .foregroundStyle(round.solved ? AppTheme.success : AppTheme.danger)
                        }
                        Text("Word: \(round.target)")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.textPrimary)

                        if round.guesses.isEmpty {
                            Text("Guess grid unavailable for this round.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        } else {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(round.guesses) { guess in
                                    wordleGuessRow(guess)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func wordleGuessRow(_ guess: WordleBreakdownGuess) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(guess.word.enumerated()), id: \.offset) { idx, char in
                Text(String(char))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(wordleColor(guess.results.indices.contains(idx) ? guess.results[idx] : "A"))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
        }
    }

    private func detailLines(_ details: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(details.prefix(8), id: \.self) { detail in
                Text(displayDetail(detail))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func modeStats(for result: MatchPlayerResult) -> [(String, String)] {
        var stats: [(String, String)] = [
            ("Status", displayStatus(result, for: player(for: result.userID))),
            ("Time", formattedTime(result.elapsedSeconds))
        ]
        switch session.mode {
        case .wordle:
            stats.append(contentsOf: [("Rounds", "\(result.solvedRounds)"), ("Guesses", "\(result.totalGuesses)")])
        case .anagram, .wordHunt:
            stats.append(contentsOf: [("Score", "\(result.score)"), ("Words", "\(result.wordCount)"), ("Longest", "\(result.longestWordLength) letters")])
        case .minesweeper:
            stats.append(contentsOf: [("Safe cells", result.summary["safeCells"] ?? "\(result.score)"), ("Mine hit", result.hitMine ? "Yes" : "No")])
        case .sudoku:
            stats.append(contentsOf: [("Completed", result.completed ? "Yes" : "No"), ("Progress", percent(result.progress))])
        case .gridlock:
            stats.append(contentsOf: [("Completed", result.completed ? "Yes" : "No"), ("Moves", "\(result.moveCount)"), ("Symmetry", percent(result.progress))])
        case .colorLink:
            stats.append(contentsOf: [("Completed", result.completed ? "Yes" : "No"), ("Board fill", percent(result.progress)), ("Pairs", "\(result.solvedPairs)")])
        }
        return stats
    }

    private var userFacingReason: String {
        if let forfeiter = forfeitPlayer {
            return forfeiter.userID == currentUserID ? "You forfeited" : "\(forfeiter.username) forfeited"
        }
        return session.winnerReason ?? session.mode.winConditionText
    }

    private var headerTitle: String {
        switch currentOutcome {
        case .win: return "Victory"
        case .loss: return "Defeat"
        case .draw: return "Draw"
        case .abandoned: return "Abandoned"
        }
    }

    private var headerIcon: String {
        switch currentOutcome {
        case .win: return "crown.fill"
        case .loss: return "xmark.circle.fill"
        case .draw: return "equal.circle.fill"
        case .abandoned: return "flag.slash.fill"
        }
    }

    private var forfeitPlayer: MatchPlayer? {
        if let forfeiterID = results.first(where: { $0.value.summary["forfeit"] == "true" })?.key {
            return player(for: forfeiterID)
        }
        guard session.winnerReason == "Opponent forfeited" else { return nil }
        if let winnerID = session.winnerID {
            return session.players.first { $0.userID != winnerID }
        }
        return nil
    }

    private var missingResultText: String {
        session.mode == .wordle ? "Not finished before clinch." : "No result submitted yet."
    }

    private func displayStatus(_ result: MatchPlayerResult, for player: MatchPlayer?) -> String {
        if result.summary["forfeit"] == "true" {
            return player?.userID == currentUserID ? "You forfeited" : "\(player?.username ?? "Opponent") forfeited"
        }
        if result.summary["forfeitWin"] == "true" {
            return "Won by forfeit"
        }
        return result.status
    }

    private func displayDetail(_ detail: String) -> String {
        if detail.localizedCaseInsensitiveContains("Opponent forfeited"), let forfeiter = forfeitPlayer {
            return forfeiter.userID == currentUserID ? "You forfeited." : "\(forfeiter.username) forfeited."
        }
        return detail
    }

    private func statusColor(_ result: MatchPlayerResult?, isWinner: Bool) -> Color {
        guard let result else { return AppTheme.textSecondary }
        if result.summary["forfeit"] == "true" { return AppTheme.danger }
        if isWinner || result.completed { return AppTheme.success }
        return AppTheme.textSecondary
    }

    private func parsedWordleRounds(from result: MatchPlayerResult) -> [WordleBreakdownRound] {
        let count = Int(result.summary["roundCount"] ?? "0") ?? 0
        if count > 0 {
            return (1...count).map { idx in
                WordleBreakdownRound(
                    index: idx,
                    target: result.summary["round\(idx)Target"] ?? "-----",
                    solved: result.summary["round\(idx)Solved"] == "true",
                    guessCount: Int(result.summary["round\(idx)GuessCount"] ?? "0") ?? 0,
                    guesses: parseEncodedGuesses(result.summary["round\(idx)Guesses"] ?? "")
                )
            }
        }
        return parseLegacyWordleDetails(result.details)
    }

    private func parseEncodedGuesses(_ encoded: String) -> [WordleBreakdownGuess] {
        encoded.split(separator: ";").enumerated().compactMap { idx, item in
            let parts = item.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return WordleBreakdownGuess(id: idx, word: Array(parts[0]), results: Array(parts[1]))
        }
    }

    private func parseLegacyWordleDetails(_ details: [String]) -> [WordleBreakdownRound] {
        details.enumerated().compactMap { idx, detail in
            guard let colon = detail.firstIndex(of: ":") else { return nil }
            let body = detail[detail.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if let range = body.range(of: " in ") {
                return WordleBreakdownRound(index: idx + 1, target: String(body[..<range.lowerBound]), solved: true, guessCount: Int(body[range.upperBound...]) ?? 0, guesses: [])
            }
            if let range = body.range(of: " failed") {
                return WordleBreakdownRound(index: idx + 1, target: String(body[..<range.lowerBound]), solved: false, guessCount: 0, guesses: [])
            }
            return nil
        }
    }

    private func player(for userID: String) -> MatchPlayer? {
        session.players.first { $0.userID == userID }
    }

    private func formattedTime(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    private func percent(_ progress: Double) -> String {
        "\(Int((progress * 100).rounded()))%"
    }

    private func wordleColor(_ result: Character) -> Color {
        switch result {
        case "C": return Color(hex: "538D4E")
        case "P": return Color(hex: "B59F3B")
        default: return Color(hex: "3A3A3C")
        }
    }
}

private struct WordleBreakdownRound: Identifiable {
    let index: Int
    let target: String
    let solved: Bool
    let guessCount: Int
    let guesses: [WordleBreakdownGuess]
    var id: Int { index }
}

private struct WordleBreakdownGuess: Identifiable {
    let id: Int
    let word: [Character]
    let results: [Character]
}

// MARK: - Wager option row

struct WagerOptionRow: View {
    let option: WagerTier
    let isSelected: Bool
    let canAfford: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                HStack(spacing: 10) {
                    CoinIconView(size: 28)
                    Text("\(option.amount)")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
                if !canAfford {
                    Text("Insufficient coins").font(.caption).foregroundStyle(AppTheme.danger)
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.teal)
                }
            }
            .padding()
            .background(isSelected ? AppTheme.teal.opacity(0.16) : AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? AppTheme.teal : AppTheme.cardBorder, lineWidth: isSelected ? 2 : 1))
        }
        .disabled(!canAfford)
        .opacity(canAfford ? 1 : 0.4)
        .buttonStyle(.plain)
    }
}
