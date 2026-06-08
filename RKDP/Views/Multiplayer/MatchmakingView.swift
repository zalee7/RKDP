import SwiftUI

enum MatchmakingEntryKind {
    case ranked
    case casual
}

struct MatchmakingView: View {
    let user: AppUser
    let mode: GameMode
    let difficulty: Difficulty
    let initialSession: GameSession?
    let entryKind: MatchmakingEntryKind
    var onMatchFinished: () -> Void

    @StateObject private var vm = MultiplayerViewModel()
    @State private var selectedWager: WagerTier?
    @State private var showBreakdown = false
    @State private var didNotifyFinished = false
    @State private var inMatchMusicEnabled = true
    @State private var showForfeitWarning = false
    @State private var rewardAnimationFinished = false
    @State private var showCompatibilityHint = false
    @State private var didStartInitialSession = false
    @State private var playedResultSoundSessionID: String?
    @Environment(\.dismiss) var dismiss

    init(user: AppUser, mode: GameMode, difficulty: Difficulty, entryKind: MatchmakingEntryKind = .ranked, onMatchFinished: @escaping () -> Void = {}) {
        self.user = user
        self.mode = mode
        self.difficulty = difficulty
        self.initialSession = nil
        self.entryKind = entryKind
        self.onMatchFinished = onMatchFinished
    }

    init(exhibitionSession: GameSession, user: AppUser, onMatchFinished: @escaping () -> Void = {}) {
        self.user = user
        self.mode = exhibitionSession.mode
        self.difficulty = exhibitionSession.difficulty
        self.initialSession = exhibitionSession
        self.entryKind = exhibitionSession.isCasual ? .casual : .ranked
        self.onMatchFinished = onMatchFinished
    }

    private var automaticWager: WagerTier {
        Wager.fixed(for: user.rank(for: mode))
    }

    private var canAffordAutomaticWager: Bool {
        user.coins >= automaticWager.amount
    }

    private var queueSettingTitle: String {
        if mode == .wordle { return "Guesses" }
        if mode == .anagram || mode == .hangman { return "Word length" }
        return "Difficulty"
    }

    private var queueCriteriaHint: String {
        if isCasualFlow {
            return "Casual pairs random players with the same mode and \(queueSettingTitle.lowercased()). Rank, division, wagers, and ranked entries do not matter."
        }
        switch mode {
        case .wordle:
            return "Wordle pairs players with the same guess count and rank tier."
        case .anagram:
            return "Anagrams pairs players with the same word length and rank tier."
        case .hangman:
            return "Lava Rescue pairs players with the same word length, category puzzle rules, and rank tier."
        default:
            return "Ranked pairs players with the same mode, difficulty, rank tier, and wager."
        }
    }

    private var rankTierForQueue: RankTier {
        user.rank(for: mode).tier
    }

    private var shouldBlockDismiss: Bool {
        switch vm.state {
        case .matchFound:
            return true
        case .inMatch(let session):
            return !session.isAsyncExhibition
        default:
            return false
        }
    }

    private var isCasualFlow: Bool {
        entryKind == .casual || initialSession?.isCasual == true
    }

    private var navigationTitle: String {
        if initialSession?.isAsyncExhibition == true { return "Play Later" }
        if initialSession?.isExhibition == true { return "Exhibition Match" }
        return isCasualFlow ? "Casual Match" : "Ranked Match"
    }

    private var activeInMatchSession: GameSession? {
        if case .inMatch(let session) = vm.state { return session }
        return nil
    }

    private var leaveAlertTitle: String {
        if activeInMatchSession?.isAsyncExhibition == true { return "Leave challenge?" }
        if activeInMatchSession?.isCasual == true { return "Leave casual match?" }
        return activeInMatchSession?.isExhibition == true ? "Leave exhibition match?" : "Forfeit ranked match?"
    }

    private var leaveAlertActionTitle: String {
        if activeInMatchSession?.isAsyncExhibition == true { return "Leave" }
        if activeInMatchSession?.isCasual == true { return "Leave" }
        return activeInMatchSession?.isExhibition == true ? "Leave" : "Forfeit"
    }

    private var leaveAlertMessage: String {
        if activeInMatchSession?.isAsyncExhibition == true {
            return "Your Play Later challenge will stay in Friends so you can come back before it expires."
        }
        if activeInMatchSession?.isCasual == true {
            return "Leaving gives the other player the casual win. No rank, W/L, or wager coins are affected."
        }
        return activeInMatchSession?.isExhibition == true ? "Leaving ends the exhibition for both players. No rank or coins are affected." : "Quitting now counts as a ranked loss and forfeits your wager."
    }

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()
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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(shouldBlockDismiss)
        .interactiveDismissDisabled(shouldBlockDismiss)
        .onAppear { startInitialSessionIfNeeded() }
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
        .alert(leaveAlertTitle, isPresented: $showForfeitWarning) {
            Button("Keep Playing", role: .cancel) {}
            Button(leaveAlertActionTitle, role: .destructive) {
                guard let session = activeInMatchSession else { return }
                if session.isAsyncExhibition {
                    dismiss()
                } else {
                    Task { await vm.forfeitMatch(session: session) }
                }
            }
        } message: {
            Text(leaveAlertMessage)
        }
    }

    private func startInitialSessionIfNeeded() {
        guard let initialSession, !didStartInitialSession else { return }
        didStartInitialSession = true
        Task { await vm.startExhibition(user: user, session: initialSession) }
    }

    // MARK: - Wager picker

    private var wagerPicker: some View {
        if isCasualFlow {
            return AnyView(casualPicker)
        }

        let wager = automaticWager
        let rank = user.rank(for: mode)

        return AnyView(ScrollView {
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

                queueCriteriaCard(wager: wager, includeHint: true)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        CoinIconView(size: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tier Wager")
                                .font(.headline.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("\(rank.displayTier.displayName) sets this match at \(wager.amount) coins.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        CoinBadgeView(amount: wager.amount)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))

                    HStack(spacing: 10) {
                        wagerOutcomeTile(title: "Win", value: "+\(wager.amount)", color: AppTheme.success)
                        wagerOutcomeTile(title: "Loss", value: "-\(wager.amount)", color: AppTheme.danger)
                    }
                }
                .padding(.horizontal)

                if !canAffordAutomaticWager {
                    VStack(spacing: 6) {
                        Text("Not enough coins for this tier wager.")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.warning)
                        Text("Earn free coins or grab a coin pack from the Shop.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.warning.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.warning.opacity(0.4), lineWidth: 1))
                    .padding(.horizontal)
                }

                Button {
                    didNotifyFinished = false
                    rewardAnimationFinished = false
                    inMatchMusicEnabled = true
                    Task { await vm.startSearch(user: user, mode: mode, difficulty: difficulty, wager: wager) }
                } label: {
                    Text(canAffordAutomaticWager ? "Find Match" : "Need More Coins")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canAffordAutomaticWager ? mode.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(!canAffordAutomaticWager)
            }
            .padding(.vertical)
        })
    }

    private var casualPicker: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(mode.accentColor)
                    Text("\(mode.displayName) · \(mode.difficultyLabel(difficulty))")
                        .font(.headline)
                    Text("Random casual online")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.crownGold)
                }

                queueCriteriaCard(wager: nil, includeHint: true)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    casualInfoRow(icon: "shield.slash.fill", title: "No rank at stake", detail: "Rank points, divisions, and ranked W/L stay untouched.")
                    casualInfoRow(icon: "circle.slash", title: "No wager", detail: "You never risk coins in casual matches.")
                    casualInfoRow(icon: "shuffle.circle.fill", title: "Same puzzle", detail: "Both players get the same seed and puzzle data.")
                    casualInfoRow(icon: "centsign.circle.fill", title: "Small daily coins", detail: "Win +10, loss/draw +3, capped at 100 casual coins per day.")
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
                .padding(.horizontal)

                Button {
                    didNotifyFinished = false
                    rewardAnimationFinished = true
                    inMatchMusicEnabled = true
                    Task { await vm.startCasualSearch(user: user, mode: mode, difficulty: difficulty) }
                } label: {
                    Text("Find Casual Match")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.hotPink)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func casualInfoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accentBright)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
    }

    private func wagerOutcomeTile(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func queueCriteriaCard(wager: WagerTier?, includeHint: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(AppTheme.accentBright)
                Text("Queue Criteria")
                    .font(.subheadline.bold())
                Spacer()
            }
            queueCriterionRow(title: "Mode", value: mode.displayName)
            queueCriterionRow(title: queueSettingTitle, value: mode.difficultyLabel(difficulty))
            if isCasualFlow {
                queueCriterionRow(title: "Queue type", value: "Random casual")
                queueCriterionRow(title: "Stakes", value: "No rank · No wager")
            } else {
                queueCriterionRow(title: "Tier wager", value: wager.map { "\($0.amount) coins" } ?? "Automatic")
                queueCriterionRow(title: "Rank tier", value: rankTierForQueue.displayName)
            }
            if includeHint {
                Text(queueCriteriaHint)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func queueCriterionRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textPrimary)
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
            Text("Searching for same settings")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.accentBright)
            queueCriteriaCard(wager: vm.selectedWager, includeHint: false)
                .padding(.horizontal)
            if showCompatibilityHint {
                Text(isCasualFlow ? "Still searching? Casual only needs another player on the same \(mode.displayName) and \(queueSettingTitle.lowercased())." : "Still searching? Make sure both players chose the same \(mode.displayName), \(queueSettingTitle.lowercased()), rank tier, and wager.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button("Cancel") { Task { await vm.cancelSearch() } }
                .foregroundStyle(.red)
            Spacer()
        }
        .onAppear {
            SoundManager.shared.playMatchmakingLoop()
            showCompatibilityHint = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                if case .searching = vm.state {
                    showCompatibilityHint = true
                }
            }
        }
        .onDisappear { SoundManager.shared.stopMatchmakingLoop() }
    }

    // MARK: - Match found

    private func matchFoundView(session: GameSession) -> some View {
        let opponent = session.players.first { $0.userID != user.id }
        let oppUser  = vm.opponentUser
        let isBotOpponent = opponent?.isBot == true
        let needsManualReady = session.isLiveExhibition && !isBotOpponent
        let didReady = vm.readySessionIDs.contains(session.id)

        return VStack(spacing: 24) {
            Spacer()

            Text(isBotOpponent ? "Training Bot Found!" : (session.isCasual ? "Casual Match Found!" : (session.isExhibition ? "Exhibition Ready!" : "Match Found!")))
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.textPrimary)

            // Opponent card
            VStack(spacing: 12) {
                StickDuelerAvatarView(
                    style: oppUser?.cosmetics.avatarStyle ?? opponent?.avatarStyle ?? .default,
                    size: 76,
                    initials: opponent.map { String($0.username.prefix(1)) }
                )

                VStack(spacing: 4) {
                    Text(opponent?.username ?? "Opponent")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)

                    if isBotOpponent {
                        Text("Bronze Training Bot")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.crownGold)
                        Text("Limited ranked rewards")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
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
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.cardBorder, lineWidth: 1))
            .padding(.horizontal)

            if needsManualReady {
                VStack(spacing: 12) {
                    Image(systemName: didReady ? "checkmark.circle.fill" : "hand.tap.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(didReady ? AppTheme.teal : AppTheme.hotPink)
                    Text(didReady ? "Ready · waiting for friend" : "Ready Up")
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Both players need to tap Ready before the live match starts.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        Task { await vm.confirmReady(session: session) }
                    } label: {
                        Label(didReady ? "Waiting" : "Ready", systemImage: didReady ? "hourglass" : "checkmark.circle.fill")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(didReady ? AnyShapeStyle(AppTheme.controlBackground) : AnyShapeStyle(AppTheme.brandGradient))
                            .foregroundStyle(didReady ? AppTheme.textSecondary : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(didReady ? AppTheme.controlBorder : Color.clear, lineWidth: 1))
                    }
                    .disabled(didReady)
                    .buttonStyle(.plain)
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
                .padding(.horizontal)
            } else {
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

                Text(isBotOpponent ? "Bronze bot match · limited ranked rewards…" : (session.isCasual ? "No rank, no wager · starts automatically…" : (session.isExhibition ? "No rank or coins at stake · starts automatically…" : "Game starts automatically…")))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Button {
                Task { await vm.abortMatchFound(session: session) }
            } label: {
                Label((session.isExhibition || session.isCasual) ? "Leave Match" : "Abort (-1 coin)", systemImage: "xmark.circle")
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
                Label(session.containsBot ? "Training Bot" : "Opponent", systemImage: session.containsBot ? "cpu.fill" : "person.fill")
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
                    Label(session.isAsyncExhibition ? "Leave" : ((session.isExhibition || session.isCasual) ? "Leave" : "Quit"), systemImage: session.isAsyncExhibition ? "xmark.circle.fill" : "flag.slash.fill")
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
                    seed: session.seed,
                    puzzleData: session.puzzleData
                ) { result in
                    Task { await vm.submitResult(result, session: session) }
                }

                if let myResult = vm.playerResults[user.id], session.mode != .wordle || myResult.isFinalWordleResult {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(myResult.status)
                            .font(.headline.bold())
                        Text(session.isAsyncExhibition ? "Saved. Waiting for your friend…" : "Waiting for opponent…")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        if session.isAsyncExhibition {
                            Button {
                                dismiss()
                            } label: {
                                Label("Back to Friends", systemImage: "chevron.left")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.controlBackground)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(AppTheme.controlBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
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
        let results      = vm.playerResults.merging(session.playerResults ?? [:]) { _, sessionResult in sessionResult }
        let myResult     = results[user.id]
        let opponentID   = session.players.first(where: { $0.userID != user.id })?.userID ?? ""
        let opponentResult = results[opponentID]
        let snapshot = session.isRanked ? (vm.rewardSnapshot ?? PostMatchRewardSnapshot.staticSnapshot(session: session, user: user)) : nil
        let controlsReady = snapshot.map { rewardAnimationFinished || !$0.shouldAnimate } ?? true

        return VStack(spacing: 20) {
            Spacer()
            Text(isDraw ? "Draw 🤝" : (isWinner ? "Victory! 🏆" : "Defeat 😔"))
                .font(.largeTitle.bold())
                .foregroundStyle(isDraw || isWinner ? AppTheme.crownGold : AppTheme.textSecondary)

            VStack(spacing: 4) {
                Text(userFacingResultReason(session: session, results: results))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                if session.containsBot {
                    Text("Bronze Training Bot · limited ranked rewards")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.crownGold)
                }
            }
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

                if let snapshot {
                    PostMatchRewardPanel(
                        snapshot: snapshot,
                        adjustmentLabel: rankAdjustmentLabel(session: session)
                    ) {
                        rewardAnimationFinished = true
                    }
                    .padding(.vertical, 10)
                } else if session.isCasual {
                    VStack(spacing: 6) {
                        Text("Casual Match")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.crownGold)
                        Text("No rank, wager, leaderboard, ranked ticket, or W/L changed.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        if let casualReward = vm.casualRewardMessage {
                            Label(casualReward, systemImage: "centsign.circle.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.success)
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                } else {
                    VStack(spacing: 4) {
                        Text("Exhibition Match")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.accentBright)
                        Text("No rank, coins, tickets, or W/L changed.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
            .padding(.horizontal)

            if session.isRanked, let rewardError = vm.rewardErrorMessage {
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
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.hotPink)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: AppTheme.crownGold.opacity(0.28), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal)
            .opacity(controlsReady ? 1 : 0.36)
            .disabled(!controlsReady)

            if (session.isRanked || session.isExhibition) && !session.containsBot {
                rematchControl(session: session, controlsReady: controlsReady)
            }

            if session.isCasual {
                Button {
                    didNotifyFinished = false
                    rewardAnimationFinished = true
                    Task { await vm.startCasualSearch(user: user, mode: session.mode, difficulty: session.difficulty) }
                } label: {
                    Label("Find New Casual", systemImage: "shuffle.circle.fill")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.hotPink)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .opacity(controlsReady ? 1 : 0.36)
                .disabled(!controlsReady)
            }

            Button { dismiss() } label: {
                Label(session.isExhibition ? "Leave to Friends" : "Back to Home", systemImage: session.isExhibition ? "person.2.fill" : "house.fill")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .foregroundStyle(AppTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
            }
            .padding(.horizontal)
            .opacity(controlsReady ? 1 : 0.36)
            .disabled(!controlsReady)
            Spacer()
        }
        .onAppear {
            SoundManager.shared.stopAllLoops()
            playResultSoundIfNeeded(session: session)
            if (session.isRanked || session.isExhibition) && !session.containsBot { vm.beginRematchListening(session: session) }
        }
        .sheet(isPresented: $showBreakdown) {
            MatchBreakdownView(session: session, currentUserID: user.id, results: results)
        }
    }

    private func playResultSoundIfNeeded(session: GameSession) {
        guard playedResultSoundSessionID != session.id else { return }
        guard let winnerID = session.winnerID else { return }
        playedResultSoundSessionID = session.id
        if winnerID == user.id {
            SoundManager.shared.playMatchVictory()
        } else {
            SoundManager.shared.playMatchLoss()
        }
    }

    @ViewBuilder
    private func rematchControl(session: GameSession, controlsReady: Bool) -> some View {
        let myID = user.id
        let opponentID = session.players.first(where: { $0.userID != myID })?.userID
        let requested = vm.rematchRequests.contains(myID)
        let opponentRequested = opponentID.map { vm.rematchRequests.contains($0) } ?? false
        let inviteDismissed = vm.dismissedRematchInviteSessionID == session.id
        let bothRequested = requested && opponentRequested

        VStack(spacing: 8) {
            if let error = vm.rematchErrorMessage {
                Text(error)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.warning)
                    .multilineTextAlignment(.center)
            }

            if vm.isStartingRematch || bothRequested {
                Label("Starting rematch...", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .foregroundStyle(AppTheme.accentBright)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
            } else if requested {
                Button {
                    Task { await vm.cancelRematch(session: session) }
                } label: {
                    Label("Waiting for opponent... Tap to cancel", systemImage: "hourglass")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .foregroundStyle(AppTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
                }
                .disabled(!controlsReady)
            } else if opponentRequested && !inviteDismissed {
                VStack(spacing: 8) {
                    Text("Opponent wants a rematch")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accentBright)
                    HStack(spacing: 10) {
                        Button {
                            Task { await vm.declineRematch(session: session) }
                        } label: {
                            Text("Decline")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.cardBackground)
                                .foregroundStyle(AppTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
                        }
                        Button {
                            didNotifyFinished = false
                            Task { await vm.requestRematch(session: session) }
                        } label: {
                            Text("Accept")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.hotPink)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .disabled(!controlsReady)
            } else {
                Button {
                    didNotifyFinished = false
                    Task { await vm.requestRematch(session: session) }
                } label: {
                    Label("Request Rematch", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.hotPink)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!controlsReady)
            }
        }
        .padding(.horizontal)
        .opacity(controlsReady ? 1 : 0.36)
    }

    private func performanceColumn(label: String, result: MatchPlayerResult?, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption.bold()).foregroundStyle(AppTheme.textSecondary)
            if let result {
                Text(result.status)
                    .font(.headline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(highlight ? AppTheme.success : AppTheme.textPrimary)
                Text("\(result.elapsedSeconds / 60):\(String(format: "%02d", result.elapsedSeconds % 60))")
                    .font(.system(size: 10)).foregroundStyle(AppTheme.textSecondary)
            } else {
                Text("—").font(.title2.bold()).foregroundStyle(.secondary)
                Text(sessionModeMissingResultText).font(.system(size: 10)).foregroundStyle(AppTheme.textSecondary)
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
        guard !session.containsBot,
              let winnerID = session.winnerID,
              let me = session.players.first(where: { $0.userID == user.id }),
              let opponent = session.players.first(where: { $0.userID != user.id }) else { return nil }
        let myScore = rankPosition(me)
        let oppScore = rankPosition(opponent)
        guard myScore != oppScore else { return nil }

        let isWinner = winnerID == user.id
        let baselineBase = isWinner ? 30 : -15
        let baselineDelta = Int(Double(baselineBase) * mode.pointMultiplier(for: session.difficulty))
        let actualDelta = RankingService.rankDelta(
            for: user.id,
            mode: session.mode,
            difficulty: session.difficulty,
            winnerID: winnerID,
            players: session.players
        )
        let adjustment = actualDelta - baselineDelta
        let signedAdjustment = "\(adjustment >= 0 ? "+" : "")\(adjustment)"
        let adjustmentText = adjustment == 0 ? "" : " \(signedAdjustment) pts"

        if isWinner {
            return oppScore > myScore ? "Higher division bonus\(adjustmentText)" : "Lower division adjustment\(adjustmentText)"
        }
        return oppScore > myScore ? "Reduced loss vs higher division\(adjustmentText)" : "Lower division penalty\(adjustmentText)"
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
                AppTheme.arenaBackground.ignoresSafeArea()
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
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.2))
    }

    private func playerBreakdownCard(_ player: MatchPlayer) -> some View {
        let result = results[player.userID]
        let isCurrent = player.userID == currentUserID
        let isWinner = session.winnerID == player.userID

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                StickDuelerAvatarView(style: player.avatarStyle, size: 46, initials: String(player.username.prefix(1)))
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
                } else if session.mode == .anagram || session.mode == .wordHunt {
                    wordScoreBreakdown(result)
                } else if session.mode == .hangman {
                    hangmanBreakdown(result)
                } else {
                    statGrid(modeStats(for: result))
                    boardSnapshot(for: result)
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
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.2))
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
                .background(Color.black.opacity(0.24))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
        }
    }


    @ViewBuilder
    private func wordScoreBreakdown(_ result: MatchPlayerResult) -> some View {
        statGrid(modeStats(for: result))
        let words = parsedFoundWords(from: result)
        if words.isEmpty {
            detailLines(result.details.isEmpty ? ["No word list was stored for this match."] : result.details)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Words Found")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    if let byLength = result.summary["wordsByLength"], !byLength.isEmpty {
                        Text(byLength.replacingOccurrences(of: ",", with: " · "))
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                ForEach(groupedWords(words).prefix(6), id: \.0) { length, group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(length) letters")
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.textSecondary)
                        FlexibleWordWrap(spacing: 6) {
                            ForEach(group.prefix(24), id: \.self) { word in
                                Text(word.capitalized)
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(session.mode.accentColor.opacity(0.16))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(session.mode.accentColor.opacity(0.28), lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.24))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
    }

    private func parsedFoundWords(from result: MatchPlayerResult) -> [String] {
        if let raw = result.summary["foundWords"], !raw.isEmpty {
            return raw.split(separator: "|").map { String($0) }
        }
        return result.details.compactMap { detail in
            detail.split(separator: " ").first.map { String($0).uppercased() }
        }
    }

    private func groupedWords(_ words: [String]) -> [(Int, [String])] {
        Dictionary(grouping: words, by: { $0.count })
            .map { ($0.key, $0.value.sorted()) }
            .sorted { $0.0 > $1.0 }
    }

    @ViewBuilder
    private func hangmanBreakdown(_ result: MatchPlayerResult) -> some View {
        statGrid(modeStats(for: result))
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Category")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(result.summary["category"] ?? "Mystery")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.crownGold)
            }
            HStack {
                Text("Target")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text((result.summary["targetWord"] ?? "-").capitalized)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.crownGold)
            }
            HStack {
                Text("Starter")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(result.summary["starterLetter"] ?? "-")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            HStack {
                Text("Final Pattern")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(displayHangmanPattern(result.summary["revealedPattern"] ?? ""))
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            HStack {
                Text("Lava Level")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(result.wrongGuessCount)/\(result.maxWrongGuesses)")
                    .font(.caption.bold())
                    .foregroundStyle(result.wrongGuessCount >= result.maxWrongGuesses ? AppTheme.danger : AppTheme.textPrimary)
            }
            letterChipRow(title: "Correct Letters", letters: result.summary["correctLetters"] ?? "", color: AppTheme.success)
            letterChipRow(title: "Wrong Letters", letters: result.summary["wrongLetters"] ?? "", color: AppTheme.danger)
        }
        .padding(10)
        .background(Color.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
        detailLines(result.details)
    }

    private func letterChipRow(title: String, letters: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.textSecondary)
            FlexibleWordWrap(spacing: 6) {
                ForEach(Array(letters).map(String.init), id: \.self) { letter in
                    Text(letter)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.22))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(color.opacity(0.36), lineWidth: 1))
                }
                if letters.isEmpty {
                    Text("None")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func displayHangmanPattern(_ pattern: String) -> String {
        pattern.map { $0 == "_" ? "_" : String($0) }.joined(separator: " ")
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

        if result.summary["isFinal"] != "true" {
            Text("Not finished before clinch.")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.warning)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

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
                            Text(round.isPartial ? "Not finished" : (round.solved ? "Solved" : "Failed"))
                                .font(.caption.bold())
                                .foregroundStyle(round.isPartial ? AppTheme.warning : (round.solved ? AppTheme.success : AppTheme.danger))
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
                    .background(Color.black.opacity(0.24))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
                }
            }
        }
    }

    private func wordleGuessRow(_ guess: WordleBreakdownGuess) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(guess.word.enumerated()), id: \.offset) { idx, char in
                Text(String(char))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func boardSnapshot(for result: MatchPlayerResult) -> some View {
        switch session.mode {
        case .sudoku:
            let rows = snapshotRows(result.summary["boardRows"])
            if !rows.isEmpty {
                snapshotCard(title: "Board") {
                    sudokuSnapshot(rows)
                }
            }
        case .minesweeper:
            let rows = snapshotRows(result.summary["boardRows"])
            if !rows.isEmpty {
                snapshotCard(title: "Board") {
                    minesweeperSnapshot(rows)
                }
            }
        case .gridlock:
            let targetRows = snapshotRows(result.summary["targetRows"])
            let rows = snapshotRows(result.summary["tileRows"])
            if !targetRows.isEmpty {
                snapshotCard(title: "Target") {
                    colorGridSnapshot(rows: targetRows, cellSize: 18, showText: false)
                }
            }
            if !rows.isEmpty {
                snapshotCard(title: "Final Grid") {
                    colorGridSnapshot(rows: rows, cellSize: 22, showText: false)
                }
            }
        case .colorLink:
            let rows = snapshotRows(result.summary["boardRows"])
            if !rows.isEmpty {
                snapshotCard(title: "Board") {
                    colorGridSnapshot(rows: rows, cellSize: 24, showText: true)
                }
            }
        default:
            EmptyView()
        }
    }

    private func snapshotRows(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw.split(separator: "/").map(String.init)
    }

    private func snapshotCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                content()
                    .padding(.trailing, 2)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }

    private func sudokuSnapshot(_ rows: [String]) -> some View {
        VStack(spacing: 1) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 1) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, char in
                        Text(char == "." ? "" : String(char))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(char == "." ? 0.06 : 0.16))
                            .overlay(sudokuBorder(row: rowIndex, col: colIndex))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func sudokuBorder(row: Int, col: Int) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .stroke((row % 3 == 0 || col % 3 == 0) ? Color.white.opacity(0.34) : Color.white.opacity(0.12), lineWidth: 0.8)
    }

    private func minesweeperSnapshot(_ rows: [String]) -> some View {
        VStack(spacing: 1) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 1) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, char in
                        Text(minesweeperLabel(char))
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(minesweeperTextColor(char))
                            .frame(width: 10, height: 10)
                            .background(minesweeperCellColor(char))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func colorGridSnapshot(rows: [String], cellSize: CGFloat, showText: Bool) -> some View {
        VStack(spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 2) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, char in
                        Text(showText && char != "." ? String(char) : "")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: cellSize, height: cellSize)
                            .background(char == "." ? Color.white.opacity(0.07) : snapshotPaletteColor(char))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }
        }
    }

    private func minesweeperLabel(_ char: Character) -> String {
        switch char {
        case "H": return ""
        case "F": return "⚑"
        case "X", "M": return "✕"
        case "0": return ""
        default: return String(char)
        }
    }

    private func minesweeperCellColor(_ char: Character) -> Color {
        switch char {
        case "H": return Color.white.opacity(0.12)
        case "F": return AppTheme.crownGold.opacity(0.85)
        case "X": return AppTheme.danger
        case "M": return AppTheme.danger.opacity(0.7)
        default: return Color.white.opacity(0.26)
        }
    }

    private func minesweeperTextColor(_ char: Character) -> Color {
        switch char {
        case "1": return Color(hex: "63B3FF")
        case "2": return AppTheme.success
        case "3": return AppTheme.danger
        case "4": return AppTheme.hotPink
        default: return AppTheme.textPrimary
        }
    }

    private func snapshotPaletteColor(_ char: Character) -> Color {
        let palette = [
            AppTheme.hotPink,
            AppTheme.teal,
            AppTheme.royalBlue,
            AppTheme.crownGold,
            Color(hex: "8B5CF6"),
            Color(hex: "22C55E"),
            Color(hex: "F97316"),
            Color(hex: "06B6D4")
        ]
        let value = Int(String(char), radix: 36) ?? 0
        return palette[value % palette.count]
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
            stats.append(contentsOf: [
                ("Score", "\(result.score)"),
                ("Words", "\(result.wordCount)"),
                ("Longest", "\(result.longestWordLength) letters"),
                ("Average", result.summary["averageWordLength"] ?? "-"),
                ("Top Word", (result.summary["topWord"] ?? "-").capitalized)
            ])
        case .hangman:
            stats.append(contentsOf: [
                ("Result", result.completed ? "Rescued" : "Failed"),
                ("Wrong", "\(result.wrongGuessCount)/\(result.maxWrongGuesses)"),
                ("Revealed", "\(result.revealedLetterCount)"),
                ("Category", result.summary["category"] ?? "Mystery")
            ])
        case .minesweeper:
            stats.append(contentsOf: [("Safe cells", result.summary["safeCells"] ?? "\(result.score)"), ("Mine hit", result.hitMine ? "Yes" : "No")])
        case .sudoku:
            stats.append(contentsOf: [("Completed", result.completed ? "Yes" : "No"), ("Progress", percent(result.progress))])
        case .gridlock:
            stats.append(contentsOf: [("Completed", result.completed ? "Yes" : "No"), ("Moves", "\(result.moveCount)"), ("Pattern", percent(result.progress))])
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
                    guesses: parseEncodedGuesses(result.summary["round\(idx)Guesses"] ?? ""),
                    isPartial: result.summary["round\(idx)Partial"] == "true"
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
                return WordleBreakdownRound(index: idx + 1, target: String(body[..<range.lowerBound]), solved: true, guessCount: Int(body[range.upperBound...]) ?? 0, guesses: [], isPartial: false)
            }
            if let range = body.range(of: " failed") {
                return WordleBreakdownRound(index: idx + 1, target: String(body[..<range.lowerBound]), solved: false, guessCount: 0, guesses: [], isPartial: false)
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
    let isPartial: Bool
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


private struct FlexibleWordWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? UIScreen.main.bounds.width
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var x: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        var x = bounds.minX
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
