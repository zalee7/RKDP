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
            guard sessionID != nil, !didNotifyFinished else { return }
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
                        let oppRank = RankInfo(points: opp.rankPoints, tier: opp.rankTier,
                                              wins: 0, losses: 0, bestTime: nil, bestScore: nil)
                        Text(oppRank.fullDisplayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(opp.rankTier.color)
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
        let rankDelta = RankingService.rankDelta(
            for: user.id,
            mode: session.mode,
            difficulty: session.difficulty,
            winnerID: session.winnerID,
            players: session.players
        )

        let results      = session.playerResults ?? vm.playerResults
        let myResult     = results[user.id]
        let opponentID   = session.players.first(where: { $0.userID != user.id })?.userID ?? ""
        let opponentResult = results[opponentID]

        return VStack(spacing: 20) {
            Spacer()
            Text(isDraw ? "Draw 🤝" : (isWinner ? "Victory! 🏆" : "Defeat 😔"))
                .font(.largeTitle.bold())
                .foregroundStyle(isDraw || isWinner ? AppTheme.crownGold : AppTheme.textSecondary)

            Text(session.winnerReason ?? mode.winConditionText)
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

                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("Rank Points").font(.caption).foregroundStyle(AppTheme.textSecondary)
                        Text("\(rankDelta >= 0 ? "+" : "")\(rankDelta)")
                            .font(.title3.bold())
                            .foregroundStyle(rankDelta >= 0 ? AppTheme.success : AppTheme.danger)
                        if let adjustmentLabel = rankAdjustmentLabel(session: session) {
                            Text(adjustmentLabel)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.crownGold)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if let wager = vm.selectedWager {
                        Divider().frame(height: 40)
                        let coinDelta = isDraw ? 0 : (isWinner ? wager.amount : -wager.amount)
                        VStack(spacing: 2) {
                            Text("Coins").font(.caption).foregroundStyle(AppTheme.textSecondary)
                            Text("\(coinDelta >= 0 ? "+" : "")\(coinDelta)")
                                .font(.title3.bold())
                                .foregroundStyle(coinDelta >= 0 ? AppTheme.success : AppTheme.danger)
                        }
                        .frame(maxWidth: .infinity)
                    }
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

            Button {
                didNotifyFinished = false
                vm.reset()
            } label: {
                Text("Play Again")
                    .frame(maxWidth: .infinity).padding()
                    .background(mode.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            Button("Back to Home") { dismiss() }.foregroundStyle(.secondary)
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
            tier: player.rankTier,
            wins: 0,
            losses: 0,
            bestTime: nil,
            bestScore: nil
        )
        return player.rankTier.rawValue * 3 + info.division.rawValue
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

struct MatchBreakdownView: View {
    let session: GameSession
    let currentUserID: String
    let results: [String: MatchPlayerResult]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let reason = session.winnerReason {
                        Label(reason, systemImage: session.winnerID == nil ? "equal.circle.fill" : "crown.fill")
                            .foregroundStyle(session.mode.accentColor)
                    }
                }

                ForEach(session.players, id: \.userID) { player in
                    Section(player.userID == currentUserID ? "You" : player.username) {
                        if let result = results[player.userID] {
                            breakdownRows(for: result)
                        } else {
                            Text(session.mode == .wordle ? "Not finished before clinch." : "No result submitted yet.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Match Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func breakdownRows(for result: MatchPlayerResult) -> some View {
        LabeledContent("Status", value: result.status)
        LabeledContent("Time", value: "\(result.elapsedSeconds / 60):\(String(format: "%02d", result.elapsedSeconds % 60))")

        switch session.mode {
        case .wordle:
            LabeledContent("Rounds solved", value: "\(result.solvedRounds)")
            LabeledContent("Solved-round guesses", value: "\(result.totalGuesses)")
        case .anagram, .wordHunt:
            LabeledContent("Score", value: "\(result.score)")
            LabeledContent("Words", value: "\(result.wordCount)")
            LabeledContent("Longest word", value: "\(result.longestWordLength) letters")
        case .minesweeper:
            LabeledContent("Safe cells", value: result.summary["safeCells"] ?? "\(result.score)")
            LabeledContent("Mine hit", value: result.hitMine ? "Yes" : "No")
        case .sudoku:
            LabeledContent("Completed", value: result.completed ? "Yes" : "No")
            LabeledContent("Progress", value: "\(Int((result.progress * 100).rounded()))%")
        case .gridlock:
            LabeledContent("Completed", value: result.completed ? "Yes" : "No")
            LabeledContent("Moves", value: "\(result.moveCount)")
            LabeledContent("Symmetry", value: "\(Int((result.progress * 100).rounded()))%")
            LabeledContent("Grid", value: result.summary["boardSize"].map { "\($0)x\($0)" } ?? "Unknown")
            LabeledContent("Colors", value: result.summary["colorCount"] ?? "Unknown")
        case .colorLink:
            LabeledContent("Completed", value: result.completed ? "Yes" : "No")
            LabeledContent("Board fill", value: "\(Int((result.progress * 100).rounded()))%")
            LabeledContent("Color pairs", value: "\(result.solvedPairs)")
        }

        if !result.details.isEmpty {
            ForEach(result.details, id: \.self) { detail in
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
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
