import SwiftUI
import FirebaseFirestore

struct HomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var selectedMode: GameMode?
    @State private var showProfile = false
    @State private var showShop = false
    @State private var showHowToPlay = false
    @State private var showLeaderboard = false
    @State private var showNotificationHub = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        HomeBrandHeader()
                        if let user = auth.user { userHeader(user: user) }

                        HomeChooseGameIntro {
                            showHowToPlay = true
                        }
                        .padding(.top, 2)

                        HomeModeList(user: auth.user) { mode in
                            selectedMode = mode
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 28)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showShop = true } label: {
                        Image(systemName: "bag.fill").foregroundStyle(AppTheme.accentBright)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showLeaderboard = true } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.hotPink)
                    }
                    .accessibilityLabel("Leaderboard")

                    if auth.user != nil {
                        Button { showNotificationHub = true } label: {
                            Image(systemName: "bell.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.accentBright)
                        }
                        .accessibilityLabel("Notifications")
                    }

                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.accentBright)
                    }
                    .accessibilityLabel("Profile")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $selectedMode) { mode in
                GameModeDetailView(mode: mode).environmentObject(auth)
            }
            .sheet(isPresented: $showProfile) {
                if let user = auth.user { ProfileView(user: user, onDone: { showProfile = false }).environmentObject(auth) }
            }
            .sheet(isPresented: $showShop) {
                if let user = auth.user {
                    ShopView(user: user) {
                        Task { await auth.refreshUser() }
                    }
                }
            }
            .sheet(isPresented: $showHowToPlay) { HowToPlayView() }
            .sheet(isPresented: $showLeaderboard) { LeaderboardView() }
            .sheet(isPresented: $showNotificationHub) {
                if let user = auth.user {
                    NotificationHubView(user: user)
                        .environmentObject(auth)
                }
            }
        }
    }

    @ViewBuilder
    private func userHeader(user: AppUser) -> some View {
        Button {
            showProfile = true
        } label: {
            HStack(spacing: 12) {
                HomeHeaderAvatarView(style: user.cosmetics.avatarStyle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.username)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    CoinBadgeView(amount: user.coins)
                }
                Spacer(minLength: 0)
                DailyPlayStreakChip(user: user)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 340, alignment: .center)
            .background(AppTheme.cardBackground.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(AppTheme.cardBorder.opacity(0.9), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open profile for \(user.username)")
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

private struct HomeHeaderAvatarView: View {
    let style: AvatarStyle

    var body: some View {
        ZStack {
            StickDuelerAvatarView(style: style, size: 58, allowsMotion: false)
        }
        .frame(width: 68, height: 68)
        .clipShape(Circle())
        .contentShape(Circle())
    }
}

private struct DailyPlayStreakChip: View {
    let user: AppUser

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: user.playProgress.hasPlayedToday ? "checkmark.circle.fill" : "calendar.badge.plus")
                .font(.caption.bold())
                .foregroundStyle(user.playProgress.hasPlayedToday ? AppTheme.teal : AppTheme.crownGold)
            VStack(alignment: .leading, spacing: 1) {
                Text(titleText)
                    .font(.caption.bold())
                    .foregroundStyle(user.playProgress.hasPlayedToday ? AppTheme.teal : AppTheme.crownGold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(rewardText)
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(width: 108, height: 48, alignment: .center)
        .background(AppTheme.controlBackground.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
    }

    private var titleText: String {
        user.playProgress.hasPlayedToday ? "Played today" : "Play today"
    }

    private var rewardText: String {
        user.playProgress.canEarnDailyBonusToday ? "+\(CoinWallet.dailyPlayReward) daily" : "Bonus claimed"
    }
}

private struct HomeBrandHeader: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("Puzzle Party")
                .font(.system(size: 33, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.brandGradient)
                .shadow(color: AppTheme.crownGold.opacity(0.32), radius: 12, x: 0, y: 4)
            Text("Solo, Ranked, Casual")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.horizontal)
    }
}

private struct HomeChooseGameIntro: View {
    let onHelp: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("Choose Your Game")
                    .font(.callout.bold())
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.hotPink)
                Button(action: onHelp) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accentBright)
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("How to play")
            }
            Text("Solo, ranked, casual, and daily")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

private struct NotificationHubView: View {
    let user: AppUser
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var friendsVM = FriendsViewModel()
    @State private var notificationSettings: NotificationSettings
    @State private var isSaving = false
    @State private var statusMessage: String?

    init(user: AppUser) {
        self.user = user
        _notificationSettings = State(initialValue: user.notificationSettings)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        notificationSummary
                        actionSection
                        settingsSection
                        if let statusMessage {
                            Text(statusMessage)
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accentBright)
                }
            }
            .onAppear {
                notificationSettings = auth.user?.notificationSettings ?? user.notificationSettings
                friendsVM.start(user: auth.user ?? user)
            }
            .onDisappear {
                friendsVM.stop()
            }
        }
    }

    private var notificationSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .font(.title2.bold())
                    .foregroundStyle(actionableCount > 0 ? AppTheme.hotPink : AppTheme.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(actionableCount > 0 ? "\(actionableCount) item\(actionableCount == 1 ? "" : "s") waiting" : "All caught up")
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Friend requests, game invites, and alert preferences.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }

    private var actionSection: some View {
        notificationCard("Action Items", icon: "tray.full.fill", color: AppTheme.crownGold) {
            notificationActionRow(
                title: "Friend Requests",
                detail: friendRequestDetail,
                icon: "person.crop.circle.badge.plus",
                color: AppTheme.teal
            ) {
                openFriendsTab()
            }

            Divider().overlay(AppTheme.cardBorder)

            notificationActionRow(
                title: "Game Invites",
                detail: inviteDetail,
                icon: "gamecontroller.fill",
                color: AppTheme.hotPink
            ) {
                openFriendsTab()
            }
        }
    }

    private var settingsSection: some View {
        notificationCard("Alert Settings", icon: "bell.fill", color: AppTheme.teal) {
            ForEach(NotificationPreferenceType.allCases) { type in
                Toggle(isOn: notificationBinding(for: type)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(type.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(type.detail)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .tint(AppTheme.hotPink)
                .disabled(isSaving)

                if type != NotificationPreferenceType.allCases.last {
                    Divider().overlay(AppTheme.cardBorder)
                }
            }
        }
    }

    private var actionableCount: Int {
        friendsVM.incomingRequests.count + friendsVM.incomingInvites.count
    }

    private var friendRequestDetail: String {
        let incoming = friendsVM.incomingRequests.count
        let outgoing = friendsVM.outgoingRequests.count
        if incoming == 0 && outgoing == 0 { return "No pending requests" }
        if incoming == 0 { return "\(outgoing) sent" }
        if outgoing == 0 { return "\(incoming) waiting for you" }
        return "\(incoming) waiting · \(outgoing) sent"
    }

    private var inviteDetail: String {
        let incoming = friendsVM.incomingInvites.count
        let outgoing = friendsVM.outgoingInvites.count
        if incoming == 0 && outgoing == 0 { return "No active invites" }
        if incoming == 0 { return "\(outgoing) sent" }
        if outgoing == 0 { return "\(incoming) waiting for you" }
        return "\(incoming) waiting · \(outgoing) sent"
    }

    private func notificationCard<Content: View>(
        _ title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline.bold())
                .foregroundStyle(color)
            content()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }

    private func notificationActionRow(
        title: String,
        detail: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.bold())
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func notificationBinding(for type: NotificationPreferenceType) -> Binding<Bool> {
        Binding {
            notificationSettings.enabled(for: type)
        } set: { isEnabled in
            var updated = notificationSettings
            updated.set(isEnabled, for: type)
            notificationSettings = updated
            Task { await saveNotificationSettings(updated) }
        }
    }

    private func saveNotificationSettings(_ settings: NotificationSettings) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        if await auth.updateNotificationSettings(settings) {
            statusMessage = "Notification settings saved."
        } else {
            statusMessage = auth.errorMessage ?? "Could not save notification settings."
        }
    }

    private func openFriendsTab() {
        dismiss()
        NotificationCenter.default.post(name: .openFriendsTabRequested, object: nil)
    }
}

private struct HomeGameCategorySection: View {
    let title: String
    let subtitle: String
    let modes: [GameMode]
    let user: AppUser?
    let accent: Color
    let icon: String
    let onSelect: (GameMode) -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 13) {
            VStack(alignment: .center, spacing: 5) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.caption.bold())
                        .foregroundStyle(accent)
                        .frame(width: 25, height: 25)
                        .background(accent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(accent)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(modes) { mode in
                        GameModeCardView(mode: mode, user: user) {
                            onSelect(mode)
                        }
                        .frame(width: 196, height: 232)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
}

private struct HomeModeList: View {
    let user: AppUser?
    let onSelect: (GameMode) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppPreferenceKeys.reduceExtraAnimations) private var reduceExtraAnimations = false

    var body: some View {
        let reduceMotionEnabled = reduceMotion || reduceExtraAnimations
        VStack(spacing: 10) {
            ForEach(GameMode.allCases) { mode in
                GameModeCardView(mode: mode, user: user) {
                    onSelect(mode)
                }
                .frame(height: 124)
                .scrollTransition(.animated(.easeInOut(duration: 0.24)), axis: .vertical) { content, phase in
                    content
                        .opacity(reduceMotionEnabled || phase.isIdentity ? 1 : 0.76)
                        .scaleEffect(reduceMotionEnabled || phase.isIdentity ? 1 : 0.965)
                        .offset(y: reduceMotionEnabled || phase.isIdentity ? 0 : 10)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Mode Detail sheet

private enum GameLobbyTab: String, CaseIterable {
    case solo = "Solo"
    case online = "Online"
}

struct GameModeDetailView: View {
    let mode: GameMode
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedDifficulty: Difficulty
    @State private var selectedTab: GameLobbyTab = .solo
    @State private var destination: NavigationPath = .init()
    @State private var showRankedAccessStore = false

    init(mode: GameMode) {
        self.mode = mode
        _selectedDifficulty = State(initialValue: mode.defaultDifficulty)
    }

    private var user: AppUser? { auth.user }
    private var rankInfo: RankInfo { user?.rank(for: mode) ?? .empty }
    private var soloLockedReason: String? {
        user?.soloUnlockReason(mode: mode, difficulty: selectedDifficulty)
    }
    private var onlineDifficulty: Difficulty { mode.onlinePresetDifficulty }
    private var hasRankedEntry: Bool {
        user?.rankedAccess.canStartRanked(mode: mode) ?? false
    }
    private var rankedButtonTitle: String {
        return hasRankedEntry ? "Ranked" : "Ranked Access"
    }
    private var rankedButtonSubtitle: String {
        if hasRankedEntry {
            let status = user?.rankedAccess.statusText(for: mode) ?? "Free entry available"
            return "\(status) · \(rankedRewardText)"
        }
        return "Watch ad or unlock ranked"
    }
    private var rankedButtonIcon: String {
        return hasRankedEntry ? "flag.checkered.2.crossed" : "lock.open.fill"
    }
    private var rankedRewardText: String {
        guard let user else { return "Earn coins per win" }
        return "+\(RankedCoinRewards.win(for: user.rank(for: mode).displayTier)) coins per win"
    }
    private var onlineFormatSummary: String {
        "Standard"
    }
    private var timerOrFormatValue: String {
        selectedTab == .solo ? selectedDifficulty.rankedTimeLabel(for: mode) : onlineFormatSummary
    }
    private var soloBestSummary: String {
        rankInfo.soloBest(for: selectedDifficulty)?.displayText(for: mode) ?? "--"
    }
    private var onlineBestSummary: String {
        rankInfo.onlineBest?.displayText(for: mode) ?? "--"
    }
    private var completedSoloSummary: String {
        "\(user?.completedSoloDifficulties(for: mode).count ?? 0)/\(Difficulty.allCases.count)"
    }
    private var completedSolo: Set<Difficulty> {
        user?.completedSoloDifficulties(for: mode) ?? []
    }
    private var recommendedSoloDifficulty: Difficulty {
        Difficulty.allCases.first { !completedSolo.contains($0) && (user?.isSoloDifficultyUnlocked(mode: mode, difficulty: $0) ?? ($0 == .easy)) } ?? .expert
    }
    private var onlinePresetSummary: String {
        "Ranked and casual use a preset format for fast matchmaking and fair standard play."
    }

    var body: some View {
        NavigationStack(path: $destination) {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        ModeLobbyHeader(mode: mode)
                        LobbyTabSelector(selectedTab: $selectedTab)
                            .padding(.horizontal)

                        if selectedTab == .solo {
                            soloProgressSummary
                        } else {
                            LobbySummaryStrip(
                            rankText: rankInfo.fullDisplayName,
                            secondTitle: selectedTab == .solo ? "Solo Best" : "Ranked W/L",
                            secondValue: selectedTab == .solo ? soloBestSummary : rankInfo.recordDisplay,
                            formatTitle: selectedTab == .solo ? "Timer" : "Format",
                            formatValue: timerOrFormatValue,
                            fourthTitle: selectedTab == .solo ? "Completed" : "Online Best",
                            fourthValue: selectedTab == .solo ? completedSoloSummary : onlineBestSummary,
                            rankColor: rankInfo.displayTier.color
                        )
                        .padding(.horizontal)
                        }

                        if selectedTab == .solo {
                            soloDifficultySection
                        } else {
                            onlinePresetSection
                        }

                        VStack(spacing: 12) {
                            if selectedTab == .solo {
                                LobbyActionButton(
                                    title: soloLockedReason == nil ? "Play Solo" : "Solo Locked",
                                    subtitle: soloLockedReason ?? mode.difficultyLabel(selectedDifficulty),
                                    icon: soloLockedReason == nil ? "person.fill" : "lock.fill",
                                    style: .primary,
                                    disabled: soloLockedReason != nil
                                ) {
                                    destination.append("solo")
                                }
                            } else {
                                OnlineActionCard(
                                    title: rankedButtonTitle,
                                    subtitle: rankedButtonSubtitle,
                                    icon: rankedButtonIcon,
                                    chips: rankedChips,
                                    style: hasRankedEntry ? .primary : .secondary,
                                    disabled: user == nil
                                ) {
                                    if hasRankedEntry {
                                        destination.append("ranked")
                                    } else {
                                        showRankedAccessStore = true
                                    }
                                }

                                OnlineActionCard(
                                    title: "Casual",
                                    subtitle: "Same puzzle, random opponent",
                                    icon: "shuffle.circle.fill",
                                    chips: casualChips,
                                    style: .secondary,
                                    disabled: user == nil
                                ) {
                                    destination.append("casual")
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle(mode.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(AppTheme.accentBright)
                }
            }
            .onChange(of: selectedTab) { _, tab in
                if tab == .solo {
                    selectedDifficulty = recommendedSoloDifficulty
                    return
                }
                selectedDifficulty = onlineDifficulty
            }
            .onAppear {
                if selectedTab == .solo { selectedDifficulty = recommendedSoloDifficulty }
            }
            .sheet(isPresented: $showRankedAccessStore) {
                if let user {
                    RankedAccessStoreView(user: user, focusedMode: mode) {
                        Task { await auth.refreshUser() }
                    }
                }
            }
            .navigationDestination(for: String.self) { dest in
                if dest == "solo" {
                    SoloGameView(
                        mode: mode,
                        difficulty: selectedDifficulty,
                        user: auth.user,
                        onSoloResult: { result in
                            Task { await auth.recordSoloResult(result) }
                        },
                        onPlayAgain: {},
                        onChangeDifficulty: { destination.removeLast() },
                        onTryRanked: {
                            selectedDifficulty = onlineDifficulty
                            destination.removeLast()
                            if auth.user != nil {
                                destination.append("ranked")
                            }
                        },
                        onHome: { dismiss() },
                        onNextDifficulty: { next in selectedDifficulty = next }
                    )
                    .id(selectedDifficulty)
                } else if dest == "ranked", let user = auth.user {
                    MatchmakingView(user: user, mode: mode, difficulty: onlineDifficulty) {
                        Task { await auth.refreshUser() }
                    }
                } else if dest == "casual", let user = auth.user {
                    MatchmakingView(user: user, mode: mode, difficulty: onlineDifficulty, entryKind: .casual) {
                        Task { await auth.refreshUser() }
                    }
                }
            }
        }
    }

    private var rankedChips: [LobbyActionChip] {
        var chips = [
            LobbyActionChip(text: "Standard puzzle", icon: "checkmark.seal.fill"),
            LobbyActionChip(text: rankedRewardText, icon: "circle.fill", usesCoinIcon: true),
            LobbyActionChip(text: "Points count", icon: "arrow.up.forward.circle.fill")
        ]
        if let user {
            chips.insert(LobbyActionChip(text: user.rankedAccess.statusText(for: mode), icon: "ticket.fill"), at: 1)
        } else {
            chips.insert(LobbyActionChip(text: "Sign in", icon: "person.crop.circle.badge.exclamationmark"), at: 1)
        }
        return chips
    }

    private var casualChips: [LobbyActionChip] {
        [
            LobbyActionChip(text: "Standard puzzle", icon: "checkmark.seal.fill"),
            LobbyActionChip(text: "No rank", icon: "minus.circle.fill"),
            LobbyActionChip(text: "No wager", icon: "slash.circle"),
            LobbyActionChip(text: "+10 win", icon: "sparkles", usesCoinIcon: true)
        ]
    }

    private var soloDifficultySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose Difficulty")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(mode.soloTimingDescription)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                    let soloLockedReason = user?.soloUnlockReason(mode: mode, difficulty: difficulty)
                    let soloDisabled = soloLockedReason != nil
                    DifficultyCardView(
                        mode: mode,
                        difficulty: difficulty,
                        isSelected: selectedDifficulty == difficulty,
                        isDisabled: soloDisabled,
                        soloLockedReason: soloLockedReason,
                        isCompleted: completedSolo.contains(difficulty),
                        bestText: rankInfo.soloBest(for: difficulty)?.displayText(for: mode)
                    ) {
                        if !soloDisabled {
                            selectedDifficulty = difficulty
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var soloProgressSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your Solo Progress")
                    .font(.headline)
                Spacer(minLength: 8)
                Text("\(completedSoloSummary) complete")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.accentBright)
            }
            ProgressView(value: Double(completedSolo.count), total: Double(Difficulty.allCases.count))
                .tint(AppTheme.accentBright)
                .accessibilityLabel("Solo difficulties completed")
                .accessibilityValue("\(completedSolo.count) of \(Difficulty.allCases.count)")
            if completedSolo.count == Difficulty.allCases.count {
                Label("All difficulties complete", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.teal)
            } else if let next = recommendedSoloDifficulty.next {
                Text("Next unlock: \(mode.difficultyLabel(next))")
                    .font(.subheadline.bold())
                Text("Complete \(mode.difficultyLabel(recommendedSoloDifficulty)) first. \(mode.soloCompletionRequirement)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Text("Final step: \(mode.difficultyLabel(recommendedSoloDifficulty))")
                    .font(.subheadline.bold())
                Text(mode.soloCompletionRequirement)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Group {
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Personal Best").font(.subheadline.bold())
                        Text(mode.difficultyLabel(selectedDifficulty)).font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer(minLength: 8)
                    Text(soloBestSummary == "--" ? (completedSolo.contains(selectedDifficulty) ? "Replay to set best" : "Not set yet") : soloBestSummary)
                        .font(.headline)
                        .foregroundStyle(AppTheme.accentBright)
                        .multilineTextAlignment(.trailing)
                }
                if soloBestSummary == "--" {
                    Text(completedSolo.contains(selectedDifficulty)
                         ? "Your completion is saved, but its difficulty-specific record wasn't recorded. Replay to set one. Your earlier overall best is still on your profile."
                         : "Complete this difficulty to save your personal best.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal)
    }

    private var onlinePresetSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.teal)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text("Standard Online Match")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(onlinePresetSummary)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }

}


private struct RankedAccessMeterView: View {
    let mode: GameMode
    let user: AppUser?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ranked Entry")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(statusText)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
            if let access = user?.rankedAccess, !access.hasPermanentAccess(to: mode) {
                Text("Ads \(access.rewardedAdsRemaining(for: mode))/\(RankedAccess.rewardedAdsPerModePerDay)")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.accentBright)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var statusText: String {
        guard let user else { return "Sign in to play ranked" }
        return user.rankedAccess.statusText(for: mode)
    }

    private var iconName: String {
        guard let user else { return "person.crop.circle.badge.exclamationmark" }
        return user.rankedAccess.canStartRanked(mode: mode) ? "ticket.fill" : "ticket"
    }

    private var color: Color {
        guard let user else { return AppTheme.textSecondary }
        return user.rankedAccess.canStartRanked(mode: mode) ? AppTheme.teal : AppTheme.crownGold
    }
}

private struct ModeLobbyHeader: View {
    let mode: GameMode

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.modeGradient(mode))
                    .frame(height: 118)
                    .shadow(color: AppTheme.modeShadow(mode), radius: 12)
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 64, height: 64)
                        .overlay(Image(systemName: mode.icon).font(.system(size: 30, weight: .bold)).foregroundStyle(.white))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(mode.displayName)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            }
            ModeMiniPreview(mode: mode)
        }
        .padding(.horizontal)
    }
}

private struct LobbyTabSelector: View {
    @Binding var selectedTab: GameLobbyTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(GameLobbyTab.allCases, id: \.self) { tab in
                Button {
                    guard selectedTab != tab else { return }
                    SoundManager.shared.appButtonTap()
                    selectedTab = tab
                } label: {
                    Label(tab.rawValue, systemImage: tab == .solo ? "person.fill" : "network")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? AppTheme.hotPink : Color.white.opacity(0.08))
                        .foregroundStyle(selectedTab == tab ? .white : AppTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

private struct ModeMiniPreview: View {
    let mode: GameMode

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<14, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(previewColor(index))
                    .frame(height: 10)
            }
        }
        .padding(8)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func previewColor(_ index: Int) -> Color {
        switch mode {
        case .colorLink:
            let colors: [Color] = [AppTheme.hotPink, AppTheme.iconBlue, AppTheme.teal, AppTheme.crownGold, AppTheme.iconPurple, AppTheme.royalBlue]
            return colors[index % colors.count].opacity(index % 3 == 0 ? 1 : 0.45)
        case .gridlock:
            let colors: [Color] = [Color.white, AppTheme.hotPink, AppTheme.royalBlue, AppTheme.crownGold]
            return colors[index % colors.count].opacity(index % 3 == 0 ? 1 : 0.72)
        case .wordle:
            return [Color(hex: "538D4E"), Color(hex: "C9B458"), Color(hex: "3A3A3C")][index % 3]
        case .hangman:
            return [Color(hex: "FF5A1F"), AppTheme.crownGold, AppTheme.hotPink, AppTheme.iconPurple][index % 4].opacity(index % 2 == 0 ? 0.9 : 0.45)
        default:
            return AppTheme.modeAccent(mode).opacity(index % 2 == 0 ? 0.85 : 0.35)
        }
    }
}

private struct LobbySummaryStrip: View {
    let rankText: String
    let secondTitle: String
    let secondValue: String
    let formatTitle: String
    let formatValue: String
    let fourthTitle: String
    let fourthValue: String
    let rankColor: Color

    var body: some View {
        HStack(spacing: 0) {
            summaryItem(icon: "trophy.fill", title: "Rank", value: rankText, color: rankColor)
            Divider().overlay(Color.white.opacity(0.18)).padding(.vertical, 8)
            summaryItem(icon: secondTitle == "Ranked W/L" ? "chart.bar.fill" : "sparkles", title: secondTitle, value: secondValue, color: AppTheme.teal)
            Divider().overlay(Color.white.opacity(0.18)).padding(.vertical, 8)
            summaryItem(icon: formatTitle == "Timer" ? "timer" : "slider.horizontal.3", title: formatTitle, value: formatValue, color: AppTheme.accentBright)
            Divider().overlay(Color.white.opacity(0.18)).padding(.vertical, 8)
            summaryItem(icon: fourthTitle == "Completed" ? "checkmark.circle.fill" : "sparkles", title: fourthTitle, value: fourthValue, color: AppTheme.crownGold)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(AppTheme.cardBackground.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.cardBorder.opacity(0.85), lineWidth: 1))
    }

    private func summaryItem(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

private struct ModeFactRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(AppTheme.textSecondary)
                Text(value).font(.caption.bold()).foregroundStyle(AppTheme.textPrimary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

private struct DifficultyCardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    let mode: GameMode
    let difficulty: Difficulty
    let isSelected: Bool
    let isDisabled: Bool
    let soloLockedReason: String?
    let isCompleted: Bool
    let bestText: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            cardContent
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(cardBorderColor, lineWidth: cardBorderWidth)
            )
        }
        .buttonStyle(SoloDifficultyButtonStyle())
        .disabled(isDisabled)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mode.difficultyLabel(difficulty))
                    .font(.headline.bold())
                    .foregroundStyle(isDisabled ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accentBright)
                }
            }

            Text(detailText)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            if auth.soloRewardsEnabled {
                Label("+\(SoloCoinRewards.amount(for: mode, difficulty: difficulty)) coins", systemImage: "centsign.circle")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.crownGold)
            }

            if let bestText {
                Text("Best: \(bestText)")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accentBright)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isCompleted {
                Text("Replay to set best")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label(isDisabled ? "Locked" : "Unlocked",
                      systemImage: isDisabled ? "lock.fill" : "lock.open.fill")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
            }

            lockReasonText
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if isDisabled {
            AppTheme.controlBackground
        } else if isSelected {
            AppTheme.modeGradient(mode)
                .opacity(0.26)
        } else {
            AppTheme.cardBackground
        }
    }

    @ViewBuilder
    private var lockReasonText: some View {
        if let soloLockedReason {
            Text(soloLockedReason)
                .font(.caption2)
                .foregroundStyle(AppTheme.crownGold)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var detailText: String {
        switch mode {
        case .sudoku: return "\(difficulty.sudokuClues) starting clues"
        case .minesweeper:
            let config = MinesweeperConfig.from(difficulty)
            return "\(config.rows) × \(config.cols) · \(config.mines) mines"
        case .gridlock: return SolitaireRules.rules(for: difficulty).redealLabel
        case .colorLink: return "Connect all colors; fill every cell"
        case .anagram: return "Build words from shared letters"
        case .wordHunt: return "Trace words through adjacent tiles"
        case .wordle: return "One five-letter word"
        case .hangman: return "Rescue before six wrong guesses"
        }
    }

    private var cardBorderColor: Color {
        if isDisabled { return AppTheme.cardBorder.opacity(0.6) }
        return isSelected ? AppTheme.accentBright : AppTheme.cardBorder
    }

    private var cardBorderWidth: CGFloat {
        isSelected ? 1.5 : 1
    }

}

private struct SoloDifficultyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private enum LobbyActionStyle {
    case primary
    case secondary
    case destructive
}

private struct LobbyActionChip: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    var usesCoinIcon: Bool = false
}

private struct OnlineActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let chips: [LobbyActionChip]
    let style: LobbyActionStyle
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title3.bold())
                        .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline.bold())
                        Text(subtitle)
                            .font(.caption)
                            .opacity(0.82)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }

                FlowChipLayout(chips: chips, disabled: disabled)
            }
            .padding(14)
            .background(backgroundStyle)
            .foregroundStyle(foregroundStyle)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(borderColor, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var backgroundStyle: AnyShapeStyle {
        if disabled { return AnyShapeStyle(Color.white.opacity(0.07)) }
        switch style {
        case .primary:
            return AnyShapeStyle(AppTheme.brandGradient)
        case .secondary:
            return AnyShapeStyle(AppTheme.cardBackground.opacity(0.9))
        case .destructive:
            return AnyShapeStyle(AppTheme.danger.opacity(0.75))
        }
    }

    private var foregroundStyle: Color {
        if disabled { return AppTheme.textSecondary }
        return style == .secondary ? AppTheme.textPrimary : .white
    }

    private var borderColor: Color {
        if disabled { return AppTheme.cardBorder.opacity(0.6) }
        return style == .secondary ? Color.white.opacity(0.22) : Color.white.opacity(0.18)
    }
}

private struct LobbyActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let style: LobbyActionStyle
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3.bold())
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline.bold())
                    Text(subtitle).font(.caption).opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
            }
            .padding()
            .background(backgroundStyle)
            .foregroundStyle(foregroundStyle)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(disabled ? AppTheme.cardBorder : Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var backgroundStyle: AnyShapeStyle {
        if disabled { return AnyShapeStyle(Color.white.opacity(0.08)) }
        switch style {
        case .primary:
            return AnyShapeStyle(AppTheme.brandGradient)
        case .secondary:
            return AnyShapeStyle(AppTheme.cardBackground)
        case .destructive:
            return AnyShapeStyle(AppTheme.danger.opacity(0.75))
        }
    }

    private var foregroundStyle: Color {
        if disabled { return AppTheme.textSecondary }
        return style == .secondary ? AppTheme.textPrimary : .white
    }
}

private struct FlowChipLayout: View {
    let chips: [LobbyActionChip]
    let disabled: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(chips) { chip in
                HStack(spacing: 4) {
                    if chip.usesCoinIcon {
                        CoinIconView(size: 12)
                    } else {
                        Image(systemName: chip.icon)
                    }
                    Text(chip.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(disabled ? 0.06 : 0.12))
                    .foregroundStyle(disabled ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .clipShape(Capsule())
            }
        }
    }
}

extension Difficulty {
    func rankedTimeLabel(for mode: GameMode) -> String {
        let seconds = rankedTimeLimit(for: mode)
        guard seconds > 0 else { return "Untimed" }
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

// MARK: - Game mode tile

struct GameModeCardView: View {
    let mode: GameMode
    let user: AppUser?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                AnimatedModeThumbnailView(mode: mode, size: 68)

                VStack(alignment: .leading, spacing: 7) {
                    Text(mode.displayName)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    if let user {
                        CompactModeStatsView(info: user.rank(for: mode))
                    } else {
                        Text("Tap to choose solo or online")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                modeStatColumn

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                cardBackground
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder.opacity(0.9), lineWidth: 1.35)
            }
            .shadow(color: AppTheme.softShadow, radius: 10, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.40))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.modeGradient(mode))
                    .opacity(0.14)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AppTheme.modeAccent(mode).opacity(0.44), lineWidth: 1)
            }
    }

    @ViewBuilder
    private var modeStatColumn: some View {
        if let user {
            let info = user.rank(for: mode)
            VStack(alignment: .trailing, spacing: 7) {
                modeStatPill(label: "Solo Best") {
                    Text(info.soloBest?.displayText(for: mode) ?? "--")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(AppTheme.accentBright.opacity(0.95))
                }
                modeStatPill(label: "Online Best") {
                    Text(info.onlineBest?.displayText(for: mode) ?? "--")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(AppTheme.teal.opacity(0.95))
                }
            }
            .frame(width: 92, alignment: .trailing)
        }
    }

    private func modeStatPill<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(.system(size: 8.5, weight: .black))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.textSecondary)

            content()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .center)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.58))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(AppTheme.cardBorder.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

private struct AnimatedModeThumbnailView: View {
    let mode: GameMode
    var size: CGFloat = 64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppPreferenceKeys.reduceExtraAnimations) private var reduceExtraAnimations = false
    @State private var isAnimating = false
    @State private var isVisible = false

    private var motionDisabled: Bool { reduceMotion || reduceExtraAnimations }
    private var shouldAnimate: Bool {
        isVisible && !motionDisabled && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    private var active: Bool { shouldAnimate && isAnimating }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(AppTheme.modeGradient(mode))

            movingHighlight

            ZStack {
                modeScene
            }
            .frame(width: size, height: size)
            .padding(size * 0.08)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: AppTheme.modeShadow(mode), radius: shouldAnimate ? (active ? 10 : 6) : 6, x: 0, y: 3)
        .scaleEffect(shouldAnimate ? (active ? thumbnailScale : 1) : 1)
        .animation(shouldAnimate ? .easeInOut(duration: duration).repeatForever(autoreverses: true) : nil, value: isAnimating)
        .onAppear {
            isVisible = true
            guard shouldAnimate else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard isVisible, shouldAnimate else { return }
                isAnimating = true
            }
        }
        .onDisappear {
            isVisible = false
            isAnimating = false
        }
        .onChange(of: reduceMotion) { _, reduced in
            isAnimating = isVisible && !(reduced || reduceExtraAnimations || ProcessInfo.processInfo.isLowPowerModeEnabled)
        }
        .onChange(of: reduceExtraAnimations) { _, reduced in
            isAnimating = isVisible && !(reduced || reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled)
        }
        .accessibilityHidden(true)
    }

    private var movingHighlight: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(motionDisabled ? 0.08 : 0.18), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * 0.34, height: size * 1.45)
            .rotationEffect(.degrees(18))
            .offset(x: motionDisabled ? 0 : (active ? size * 0.72 : -size * 0.72))
            .blendMode(.screen)
            .opacity(motionDisabled ? 0.20 : 0.55)
    }

    @ViewBuilder
    private var modeScene: some View {
        switch mode {
        case .colorLink:
            colorLinkScene
        case .gridlock:
            solitaireScene
        case .sudoku:
            sudokuScene
        case .minesweeper:
            minesweeperScene
        case .wordle:
            wordleScene
        case .hangman:
            lavaRescueScene
        case .wordHunt:
            wordHuntScene
        case .anagram:
            anagramScene
        }
    }

    private var colorLinkScene: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size * 0.20, y: size * 0.23))
                path.addLine(to: CGPoint(x: size * 0.40, y: size * 0.44))
                path.addLine(to: CGPoint(x: size * 0.62, y: size * 0.44))
                path.addLine(to: CGPoint(x: size * 0.78, y: size * 0.67))
            }
            .trim(from: 0, to: active ? 1 : 0.25)
            .stroke(Color.white.opacity(0.88), style: StrokeStyle(lineWidth: max(2, size * 0.055), lineCap: .round, lineJoin: .round))
            Circle().fill(AppTheme.hotPink).frame(width: size * 0.15, height: size * 0.15).position(x: size * 0.20, y: size * 0.23)
            Circle().fill(AppTheme.hotPink).frame(width: size * 0.15, height: size * 0.15).position(x: size * 0.78, y: size * 0.67)
            Circle().fill(AppTheme.teal).frame(width: size * 0.13, height: size * 0.13).position(x: size * 0.42, y: size * 0.72)
            Circle().fill(AppTheme.teal).frame(width: size * 0.13, height: size * 0.13).position(x: size * 0.68, y: size * 0.24)
        }
    }

    private var solitaireScene: some View {
        let boardSize = size * 0.68

        return ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .frame(width: boardSize + 8, height: boardSize + 8)

            ForEach(0..<4, id: \.self) { index in
                miniPlayingCard(
                    rank: ["A", "7", "Q", "K"][index],
                    suit: ["suit.heart.fill", "suit.spade.fill", "suit.diamond.fill", "suit.club.fill"][index],
                    red: index == 0 || index == 2
                )
                .offset(
                    x: (CGFloat(index) - 1.5) * size * 0.12,
                    y: CGFloat(index % 2) * size * 0.07 + (active ? -size * 0.035 : size * 0.02)
                )
                .rotationEffect(.degrees(Double(index - 1) * 5))
                .zIndex(Double(index))
            }
        }
        .frame(width: boardSize + 10, height: boardSize + 10)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func miniPlayingCard(rank: String, suit: String, red: Bool) -> some View {
        VStack(spacing: 1) {
            Text(rank)
                .font(.system(size: size * 0.105, weight: .black, design: .rounded))
            Image(systemName: suit)
                .font(.system(size: size * 0.075, weight: .black))
        }
        .foregroundStyle(red ? AppTheme.hotPink : AppTheme.royalBlue)
        .frame(width: size * 0.18, height: size * 0.25)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Color.black.opacity(0.12), lineWidth: 1))
    }

    private var sudokuScene: some View {
        let boardSize = size * 0.68
        let digits: [Int: String] = [1: "6", 4: "7", 6: "3"]

        return ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.24))
                .frame(width: boardSize + 8, height: boardSize + 8)

            MiniSudokuGrid(active: active, digits: digits)
                .frame(width: boardSize, height: boardSize)
        }
    }

    private var minesweeperScene: some View {
        ZStack {
            MiniTileGrid(rows: 3, columns: 3, spacing: 3) { index in
                if active {
                    return [0, 1, 3, 4].contains(index) ? Color.white.opacity(0.62) : Color.white.opacity(0.22)
                }
                return index == 4 ? Color.white.opacity(0.48) : Color.white.opacity(0.22)
            }
            .frame(width: size * 0.62, height: size * 0.62)
            Text("1")
                .font(.system(size: size * 0.12, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.royalBlue)
                .position(minesweeperCellCenter(row: 0, column: 0))
                .opacity(active ? 1 : 0.15)
            Text("2")
                .font(.system(size: size * 0.12, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.success)
                .position(minesweeperCellCenter(row: 1, column: 1))
                .opacity(active ? 1 : 0.2)
            Image(systemName: "burst.fill")
                .font(.system(size: size * 0.24, weight: .black))
                .foregroundStyle(active ? AppTheme.hotPink : AppTheme.crownGold)
                .scaleEffect(active ? 1.16 : 0.72)
                .position(minesweeperCellCenter(row: 2, column: 2))
        }
    }

    private var wordleScene: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Text(wordleLetters[index])
                    .font(.system(size: size * 0.13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.13, height: size * 0.18)
                    .background(wordleColor(index))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .opacity(motionDisabled ? 1 : (active ? 1 : wordleTypingOpacity(index)))
                    .scaleEffect(active ? 1 : 0.96)
                    .rotation3DEffect(.degrees(active ? 0 : 16), axis: (x: 1, y: 0, z: 0))
            }
        }
    }

    private var lavaRescueScene: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.14))
                .frame(width: size * 0.66, height: size * 0.66)
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: "FF5A1F"), AppTheme.hotPink], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.66, height: active ? size * 0.38 : size * 0.16)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Image(systemName: "flame.fill")
                .font(.system(size: size * 0.18, weight: .black))
                .foregroundStyle(AppTheme.crownGold)
                .offset(x: size * 0.22, y: -size * 0.05)
        }
    }

    private var wordHuntScene: some View {
        ZStack {
            MiniLetterGrid(letters: ["C", "A", "T", "R", "E", "A", "D", "O", "G"])
                .frame(width: size * 0.66, height: size * 0.66)
            Path { path in
                path.move(to: CGPoint(x: size * 0.24, y: size * 0.24))
                path.addLine(to: CGPoint(x: size * 0.40, y: size * 0.24))
                path.addLine(to: CGPoint(x: size * 0.56, y: size * 0.24))
            }
            .trim(from: 0, to: active ? 1 : 0.25)
            .stroke(AppTheme.crownGold, style: StrokeStyle(lineWidth: max(2, size * 0.05), lineCap: .round, lineJoin: .round))
            Text(active ? "CAT" : "CA")
                .font(.system(size: size * 0.12, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.crownGold)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.28))
                .clipShape(Capsule())
                .offset(y: size * 0.36)
        }
    }

    private var anagramScene: some View {
        HStack(spacing: 4) {
            ForEach(Array(["A", "B", "C", "D"].enumerated()), id: \.offset) { item in
                Text(item.element)
                    .font(.system(size: size * 0.16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.16, height: size * 0.22)
                    .background([AppTheme.hotPink, AppTheme.crownGold, AppTheme.teal, AppTheme.royalBlue][item.offset])
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .offset(y: active && item.offset.isMultiple(of: 2) ? -size * 0.07 : size * 0.03)
                    .rotationEffect(.degrees(active ? Double(item.offset - 1) * 5 : 0))
            }
        }
    }

    private func wordleColor(_ index: Int) -> Color {
        if motionDisabled { return Color(hex: "538D4E") }
        if !active { return Color(hex: "3A3A3C") }
        return [Color(hex: "538D4E"), Color(hex: "538D4E"), Color(hex: "538D4E"), Color(hex: "538D4E"), Color(hex: "538D4E")][index]
    }

    private var wordleLetters: [String] {
        ["P", "A", "R", "T", "Y"]
    }

    private func wordleTypingOpacity(_ index: Int) -> Double {
        [1.0, 0.86, 0.72, 0.58, 0.44][index]
    }

    private func minesweeperCellCenter(row: Int, column: Int) -> CGPoint {
        let gridSize = size * 0.62
        let gridOrigin = (size - gridSize) / 2
        let step = gridSize / 3
        return CGPoint(
            x: gridOrigin + CGFloat(column) * step + step / 2,
            y: gridOrigin + CGFloat(row) * step + step / 2
        )
    }

    private var thumbnailScale: CGFloat {
        switch mode {
        case .minesweeper, .hangman: return 1.025
        default: return 1.015
        }
    }

    private var duration: Double {
        switch mode {
        case .colorLink: return 3.8
        case .gridlock: return 3.4
        case .sudoku: return 4.2
        case .minesweeper: return 3.0
        case .wordle: return 3.6
        case .hangman: return 3.2
        case .wordHunt: return 4.0
        case .anagram: return 3.7
        }
    }

    private var delay: Double {
        Double(GameMode.allCases.firstIndex(of: mode) ?? 0) * 0.18
    }
}

private struct MiniTileGrid: View {
    let rows: Int
    let columns: Int
    let spacing: CGFloat
    let color: (Int) -> Color

    var body: some View {
        GeometryReader { geometry in
            let tileWidth = (geometry.size.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            let tileHeight = (geometry.size.height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(color(index))
                                .frame(width: tileWidth, height: tileHeight)
                        }
                    }
                }
            }
        }
    }
}

private struct MiniSudokuGrid: View {
    let active: Bool
    let digits: [Int: String]

    var body: some View {
        GeometryReader { geometry in
            let cell = geometry.size.width / 3
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.26))

                ForEach(0..<9, id: \.self) { index in
                    let row = index / 3
                    let column = index % 3
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(index == (active ? 4 : 1) ? Color.white.opacity(0.54) : Color.white.opacity(0.18))
                        .frame(width: cell - 3, height: cell - 3)
                        .position(x: CGFloat(column) * cell + cell / 2, y: CGFloat(row) * cell + cell / 2)

                    if let digit = digits[index] {
                        Text(digit)
                            .font(.system(size: geometry.size.width * 0.20, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.royalBlue)
                            .position(x: CGFloat(column) * cell + cell / 2, y: CGFloat(row) * cell + cell / 2)
                    }
                }

                Path { path in
                    for index in 1..<3 {
                        let position = CGFloat(index) * cell
                        path.move(to: CGPoint(x: position, y: 0))
                        path.addLine(to: CGPoint(x: position, y: geometry.size.height))
                        path.move(to: CGPoint(x: 0, y: position))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: position))
                    }
                }
                .stroke(Color.white.opacity(0.40), lineWidth: 1)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.white.opacity(0.70), lineWidth: 2)
            }
        }
    }
}

private struct MiniLetterGrid: View {
    let letters: [String]

    var body: some View {
        MiniTileGrid(rows: 3, columns: 3, spacing: 3) { _ in
            Color.white.opacity(0.18)
        }
        .overlay(
            GeometryReader { geometry in
                let stepX = geometry.size.width / 3
                let stepY = geometry.size.height / 3
                ForEach(0..<min(letters.count, 9), id: \.self) { index in
                    Text(letters[index])
                        .font(.system(size: geometry.size.width * 0.14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .position(
                            x: CGFloat(index % 3) * stepX + stepX / 2,
                            y: CGFloat(index / 3) * stepY + stepY / 2
                        )
                }
            }
        )
    }
}

private struct CompactModeStatsView: View {
    let info: RankInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                RankIconView(tier: info.displayTier, division: info.division, size: 18)
                Text(info.fullDisplayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(info.displayTier.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            VStack(spacing: 4) {
                RankDivisionProgressView(info: info, height: 3, spacing: 3)

                Text(info.divisionProgressDisplay)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: 170)
        }
    }
}

// Compact rank progress shown inside older tiles and other small surfaces
struct RankProgressMiniView: View {
    let info: RankInfo

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                RankIconView(tier: info.displayTier, division: info.division, size: 17)
                Text(info.fullDisplayName)
                    .font(.caption.bold())
                    .foregroundStyle(info.displayTier.color)
            }
            RecordTextView(
                wins: info.wins,
                losses: info.losses,
                font: .system(size: 10, weight: .semibold)
            )
            RankDivisionProgressView(info: info, height: 3, spacing: 3)
                .padding(.horizontal, 10)
            Text(info.divisionProgressDisplay)
                .font(.system(size: 9))
                .foregroundStyle(AppTheme.textSecondary)
            if let best = info.bestScore {
                Text("Best: \(best) pts").font(.system(size: 8.5, weight: .medium)).foregroundStyle(AppTheme.accentBright.opacity(0.9))
            } else if let best = info.bestTime {
                Text("Best: \(best / 60):\(String(format: "%02d", best % 60))")
                    .font(.system(size: 8.5, weight: .medium)).foregroundStyle(AppTheme.accentBright.opacity(0.9))
            }
        }
    }
}

// MARK: - Party Mode

struct PartyRoomView: View {
    let user: AppUser
    let mode: GameMode
    let difficulty: Difficulty
    var autoCreate: Bool = false
    var initialJoinCode: String?
    var stageRoundConfigurations: [PartyStageRoundConfiguration]? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = PartyRoomViewModel()
    @State private var didAutoCreate = false
    @State private var didAutoJoin = false
    @State private var showInviteFriends = false
    @State private var showStageScreen = false
    @State private var partyClockNow = Date()
    private let partyClock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()

            if let room = vm.room {
                switch room.status {
                case .lobby:
                    room.isStageRoom == true ? AnyView(partyStageLobby(room)) : AnyView(partyLobby(room))
                case .inProgress:
                    room.isStageRoom == true ? AnyView(partyStageGame(room)) : AnyView(partyGame(room))
                case .finished:
                    if room.isStageRoom == true {
                        PartyStageFinalView(room: room, currentUserID: user.id) {
                            dismiss()
                        }
                    } else {
                        PartyScoreboardView(room: room, currentUserID: user.id) {
                            dismiss()
                        }
                    }
                case .canceled:
                    partyClosed(title: "Party Canceled", message: "The host closed this party room.")
                case .expired:
                    partyClosed(title: "Party Expired", message: "Create a new room to keep playing.")
                }
            } else {
                createOrJoinView
            }

            if vm.isWorking {
                ProgressView()
                    .tint(AppTheme.hotPink)
                    .padding(20)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .navigationTitle("Party")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .interactiveDismissDisabled(shouldBlockPartyDismiss)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.room?.status != .inProgress {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.accentBright)
                }
            }
        }
        .alert("Party", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onDisappear {
            vm.stopListening()
        }
        .sheet(isPresented: $showInviteFriends) {
            if let room = vm.room {
                PartyInviteFriendsSheet(user: user, room: room)
            }
        }
        .fullScreenCover(isPresented: $showStageScreen) {
            if let room = vm.room {
                PartyStageScreenView(vm: vm, fallbackRoom: room, currentUserID: user.id)
            }
        }
        .task {
            if let initialJoinCode, !didAutoJoin, vm.room == nil {
                didAutoJoin = true
                vm.joinCode = initialJoinCode
                await vm.join(user: user)
            }
            guard autoCreate, !didAutoCreate, vm.room == nil else { return }
            didAutoCreate = true
            if let stageRoundConfigurations {
                await vm.createStage(user: user, rounds: stageRoundConfigurations)
            } else {
                await vm.create(user: user, mode: mode, difficulty: difficulty)
            }
        }
        .onReceive(partyClock) { now in
            partyClockNow = now
            Task { await vm.finalizeFinishWindowIfNeeded(now: now) }
        }
    }

    private var shouldBlockPartyDismiss: Bool {
        vm.room?.status == .inProgress
    }

    private var createOrJoinView: some View {
        ScrollView {
            VStack(spacing: 18) {
                partyHeader(title: "Party Mode", subtitle: "Create a room for \(mode.displayName), or join any party with a code.")

                VStack(spacing: 12) {
                    partyInfoRow(icon: mode.icon, title: "\(mode.displayName) Party", value: "\(mode.difficultyLabel(difficulty)) · same puzzle for everyone")
                    partyInfoRow(icon: "person.3.fill", title: "Room Size", value: "2-8 players · no rank, coins, or wagers")

                    Button {
                        Task { await vm.create(user: user, mode: mode, difficulty: difficulty) }
                    } label: {
                        Label("Create Party", systemImage: "plus.circle.fill")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.brandGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Join With Code")
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.textPrimary)

                    TextField("", text: $vm.joinCode, prompt: Text("ABC123").foregroundStyle(AppTheme.textMuted))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(AppTheme.controlBackground)
                        .foregroundStyle(AppTheme.textPrimary)
                        .tint(AppTheme.accentBright)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1.25))

                    Button {
                        Task { await vm.join(user: user) }
                    } label: {
                        Label("Join Party", systemImage: "number.circle.fill")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.cardBackground.opacity(0.95))
                            .foregroundStyle(AppTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(AppTheme.cardBackground.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1.25))
                .shadow(color: AppTheme.softShadow.opacity(0.32), radius: 10, x: 0, y: 5)
            }
            .padding()
        }
    }

    private func partyLobby(_ room: PartyRoom) -> some View {
        let isReady = room.isReady(user.id)
        let canStart = room.isHost(user.id) && room.allPlayersReady
        return ScrollView {
            VStack(spacing: 18) {
                partyHeader(title: "Code \(room.code)", subtitle: "\(room.mode.displayName) · \(room.mode.difficultyLabel(room.difficulty))")

                HStack(spacing: 10) {
                    ShareLink(item: partyShareMessage(room)) {
                        Label("Share Link", systemImage: "square.and.arrow.up")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.controlBackground)
                            .foregroundStyle(AppTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1.25))
                    }
                    .buttonStyle(.plain)

                    Button { showInviteFriends = true } label: {
                        Label("Invite Friends", systemImage: "person.crop.circle.badge.plus")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.hotPink.opacity(0.18))
                            .foregroundStyle(AppTheme.hotPink)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.hotPink.opacity(0.35), lineWidth: 1.25))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("\(room.players.count)/\(room.maxPlayers)", systemImage: "person.3.fill")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.crownGold)
                        Spacer()
                        Text("Ready \(room.readyCount)/\(room.players.count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.hotPink.opacity(0.14))
                            .foregroundStyle(AppTheme.hotPink)
                            .clipShape(Capsule())
                        Text(room.isHost(user.id) ? "Host" : "Joined")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.teal.opacity(0.18))
                            .foregroundStyle(AppTheme.teal)
                            .clipShape(Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], spacing: 10) {
                        ForEach(room.players) { player in
                            PartyPlayerTile(player: player, isReady: room.isReady(player.userID))
                        }
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))

                Button {
                    Task { await vm.setReady(userID: user.id, isReady: !isReady) }
                } label: {
                    Label(isReady ? "Ready" : "Ready Up", systemImage: isReady ? "checkmark.circle.fill" : "circle")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isReady ? AnyShapeStyle(AppTheme.teal.opacity(0.20)) : AnyShapeStyle(AppTheme.brandGradient))
                        .foregroundStyle(isReady ? AppTheme.teal : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isReady ? AppTheme.teal.opacity(0.35) : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)

                if room.isHost(user.id) {
                    Button {
                        Task { await vm.start(userID: user.id) }
                    } label: {
                        Label(canStart ? "Start Party" : (room.players.count < 2 ? "Need 2 Players" : "Waiting for Ready"), systemImage: "play.fill")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canStart ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(AppTheme.controlBackground))
                            .foregroundStyle(canStart ? .white : AppTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(canStart ? Color.clear : AppTheme.controlBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStart)
                }

                Button(role: .destructive) {
                    Task {
                        await vm.leave(userID: user.id)
                        dismiss()
                    }
                } label: {
                    Label(room.isHost(user.id) ? "Cancel Party" : "Leave Party", systemImage: "xmark.circle.fill")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.danger.opacity(0.18))
                        .foregroundStyle(AppTheme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }

    private func partyStageLobby(_ room: PartyRoom) -> some View {
        let isReady = room.isReady(user.id)
        let canStart = room.isHost(user.id) && room.allPlayersReady
        return ScrollView {
            VStack(spacing: 18) {
                partyHeader(title: "Code \(room.code)", subtitle: "3-round party playlist · post-round scores")

                if room.isHost(user.id) {
                    Button { showStageScreen = true } label: {
                        Label("Open Party Screen", systemImage: "airplayvideo")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.hotPink.opacity(0.18))
                            .foregroundStyle(AppTheme.hotPink)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.hotPink.opacity(0.36), lineWidth: 1.25))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    ShareLink(item: partyShareMessage(room)) {
                        Label("Share Link", systemImage: "square.and.arrow.up")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.controlBackground)
                            .foregroundStyle(AppTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1.25))
                    }
                    .buttonStyle(.plain)

                    Button { showInviteFriends = true } label: {
                        Label("Invite Friends", systemImage: "person.crop.circle.badge.plus")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.hotPink.opacity(0.18))
                            .foregroundStyle(AppTheme.hotPink)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.hotPink.opacity(0.35), lineWidth: 1.25))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("\(room.players.count)/\(room.maxPlayers)", systemImage: "person.3.fill")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.crownGold)
                        Spacer()
                        Text("Ready \(room.readyCount)/\(room.players.count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.hotPink.opacity(0.14))
                            .foregroundStyle(AppTheme.hotPink)
                            .clipShape(Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], spacing: 10) {
                        ForEach(room.players) { player in
                            PartyPlayerTile(player: player, isReady: room.isReady(player.userID))
                        }
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))

                partyStageRoundsCard(room)

                Button {
                    Task { await vm.setReady(userID: user.id, isReady: !isReady) }
                } label: {
                    Label(isReady ? "Ready" : "Ready Up", systemImage: isReady ? "checkmark.circle.fill" : "circle")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isReady ? AnyShapeStyle(AppTheme.teal.opacity(0.20)) : AnyShapeStyle(AppTheme.brandGradient))
                        .foregroundStyle(isReady ? AppTheme.teal : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isReady ? AppTheme.teal.opacity(0.35) : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)

                if room.isHost(user.id) {
                    Button {
                        Task { await vm.start(userID: user.id) }
                    } label: {
                        Label(canStart ? "Start Party" : (room.players.count < 2 ? "Need 2 Players" : "Waiting for Ready"), systemImage: "play.fill")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canStart ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(AppTheme.controlBackground))
                            .foregroundStyle(canStart ? .white : AppTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(canStart ? Color.clear : AppTheme.controlBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStart)
                }

                Button(role: .destructive) {
                    Task {
                        await vm.leave(userID: user.id)
                        dismiss()
                    }
                } label: {
                    Label(room.isHost(user.id) ? "Cancel Party" : "Leave Party", systemImage: "xmark.circle.fill")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.danger.opacity(0.18))
                        .foregroundStyle(AppTheme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }

    private func partyStageGame(_ room: PartyRoom) -> some View {
        guard let round = room.activeStageRound else {
            return AnyView(partyClosed(title: "Party Loading", message: "Waiting for the next round."))
        }

        switch round.status {
        case .waiting:
            return AnyView(partyClosed(title: "Round Waiting", message: "The host is setting up the next round."))
        case .finished:
            return AnyView(PartyStageRoundResultsView(
                room: room,
                round: round,
                currentUserID: user.id,
                isHost: room.isHost(user.id),
                onOpenStage: { showStageScreen = true },
                onAdvance: {
                    Task { await vm.advanceStageRound(userID: user.id) }
                }
            ))
        case .inProgress:
            let didSubmit = hasSubmittedStageResult(in: round)
            let finishWindowText = partyStageFinishWindowText(for: round)

            return AnyView(ZStack(alignment: .top) {
                SoloGameView(
                    mode: round.mode,
                    difficulty: round.difficulty,
                    user: user,
                    sessionID: room.code.hasPrefix("S1") ? "sv1_party_\(room.code)_\(round.index)" : "party_stage_\(room.code)_\(round.index)",
                    seed: round.seed,
                    puzzleData: round.puzzleData,
                    onMatchResult: { result in
                        Task { await vm.submit(result, roundIndex: round.index) }
                    }
                )
                .blur(radius: didSubmit ? 3 : 0)
                .opacity(didSubmit ? 0.42 : 1)
                .disabled(didSubmit)
                .allowsHitTesting(!didSubmit)

                if didSubmit {
                    AppTheme.royalBlue.opacity(0.18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {}
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Round \(round.index + 1)/3 · \(round.mode.displayName)")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.crownGold)
                        Text("\(submittedStageCount(room: room, round: round))/\(room.players.count) submitted")
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.textSecondary)
                        if let finishWindowText {
                            Text(finishWindowText)
                                .font(.caption2.bold())
                                .foregroundStyle(AppTheme.hotPink)
                        }
                    }
                    Spacer()
                    if room.isHost(user.id) {
                        Button { showStageScreen = true } label: {
                            Image(systemName: "airplayvideo")
                                .font(.headline.bold())
                                .foregroundStyle(AppTheme.hotPink)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(AppTheme.cardBackground.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 8)

                if didSubmit {
                    VStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title.bold())
                                .foregroundStyle(AppTheme.teal)
                            Text(vm.pendingRoundIndex == round.index ? "Submitting round" : "Round submitted")
                                .font(.headline.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(vm.submissionMessage ?? "Waiting on party")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            if let finishWindowText {
                                Text(finishWindowText)
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.hotPink)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.hotPink.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(20)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
                        .shadow(radius: 12)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            })
        }
    }

    private func partyGame(_ room: PartyRoom) -> some View {
        let didSubmit = hasSubmittedPartyResult(in: room)
        let finishWindowText = partyFinishWindowText(for: room)

        return ZStack(alignment: .top) {
            SoloGameView(
                mode: room.mode,
                difficulty: room.difficulty,
                user: user,
                sessionID: room.code.hasPrefix("S1") ? "sv1_party_\(room.code)_0" : "party_\(room.code)",
                seed: room.seed,
                puzzleData: room.puzzleData,
                onMatchResult: { result in
                    Task { await vm.submit(result) }
                }
            )
            .blur(radius: didSubmit ? 3 : 0)
            .opacity(didSubmit ? 0.42 : 1)
            .disabled(didSubmit)
            .allowsHitTesting(!didSubmit)

            if didSubmit {
                AppTheme.royalBlue.opacity(0.18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {}
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Party \(room.code)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.crownGold)
                    Text("\(submittedCount(room))/\(room.players.count) finished")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                    if let finishWindowText {
                        Text(finishWindowText)
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.hotPink)
                    }
                }
                Spacer()
            }
            .padding(10)
            .background(AppTheme.cardBackground.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)
            .padding(.top, 8)

            if didSubmit {
                VStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title.bold())
                            .foregroundStyle(AppTheme.teal)
                        Text(vm.pendingRoundIndex == 0 ? "Submitting turn" : "Turn submitted")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(vm.submissionMessage ?? "Waiting on party")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        if let finishWindowText {
                            Text(finishWindowText)
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.hotPink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.hotPink.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(20)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
                    .shadow(radius: 12)
                    Spacer()
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func partyClosed(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(AppTheme.crownGold)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Back") { dismiss() }
                .font(.headline.bold())
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppTheme.brandGradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .padding()
    }

    private func partyHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.brandGradient)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func partyShareMessage(_ room: PartyRoom) -> String {
        "Join my Puzzle Party room!\nCode: \(room.code)\npuzzleparty://join/\(room.code)"
    }

    private func partyInfoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.crownGold)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func partyStageRoundsCard(_ room: PartyRoom) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Party Playlist", systemImage: "list.number")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.accentBright)

            ForEach(room.stageRounds ?? []) { round in
                HStack(spacing: 12) {
                    Text("\(round.index + 1)")
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.textOnColor)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.modeGradient(round.mode))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(round.mode.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(round.mode.difficultyLabel(round.difficulty))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    stageRoundStatusPill(round.status)
                }
                .padding(10)
                .background(AppTheme.controlBackground.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func stageRoundStatusPill(_ status: PartyStageRoundStatus) -> some View {
        let text: String
        let color: Color
        switch status {
        case .waiting:
            text = "WAITING"
            color = AppTheme.textSecondary
        case .inProgress:
            text = "LIVE"
            color = AppTheme.hotPink
        case .finished:
            text = "DONE"
            color = AppTheme.teal
        }

        return Text(text)
            .font(.system(size: 9, weight: .black))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func submittedCount(_ room: PartyRoom) -> Int {
        room.players.filter { player in
            guard let result = player.result else { return false }
            return isFinalPartyResult(result)
        }.count
    }

    private func partyFinishWindowText(for room: PartyRoom) -> String? {
        guard room.status == .inProgress,
              let deadline = room.finishWindowDeadline else {
            return nil
        }
        let remaining = max(0, Int(ceil(deadline.timeIntervalSince(partyClockNow))))
        return "Finish window: \(partyTimeText(remaining))"
    }

    private func partyStageFinishWindowText(for round: PartyStageRound) -> String? {
        guard let deadline = round.finishWindowDeadline else { return nil }
        let remaining = max(0, Int(ceil(deadline.timeIntervalSince(partyClockNow))))
        return "Finish window: \(partyTimeText(remaining))"
    }

    private func partyTimeText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    private func submittedStageCount(room: PartyRoom, round: PartyStageRound) -> Int {
        room.players.filter { player in
            guard let result = round.results[player.userID] else { return false }
            return isFinalPartyResult(result)
        }.count
    }

    private func hasSubmittedPartyResult(in room: PartyRoom) -> Bool {
        if vm.pendingRoundIndex == 0 { return true }
        guard let result = room.players.first(where: { $0.userID == user.id })?.result else { return false }
        return isFinalPartyResult(result)
    }

    private func hasSubmittedStageResult(in round: PartyStageRound) -> Bool {
        if vm.pendingRoundIndex == round.index { return true }
        guard let result = round.results[user.id] else { return false }
        return isFinalPartyResult(result)
    }

    private func isFinalPartyResult(_ result: MatchPlayerResult) -> Bool {
        if result.status == "Abandoned" { return true }
        if result.summary["partyTimeout"] == "true" { return true }
        switch result.mode {
        case .wordle:
            return result.isFinalWordleResult
        case .hangman:
            return result.summary["final"] == "true" || result.completed || result.wrongGuessCount >= result.maxWrongGuesses
        default:
            return true
        }
    }
}

private struct PartyInviteFriendsSheet: View {
    let user: AppUser
    let room: PartyRoom
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = FriendsViewModel()
    @State private var sentIDs: Set<String> = []
    @State private var sendingID: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Send a room invite notification. You can still share the code with anyone.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal)
                            .padding(.top, 12)

                        if vm.friends.isEmpty {
                            Text("Add friends first, then invite them here.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
                                .padding(.horizontal)
                        }

                        ForEach(vm.friends) { friend in
                            HStack(spacing: 12) {
                                StickDuelerAvatarView(style: friend.avatarStyle, size: 44, initials: String(friend.username.prefix(1)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.username)
                                        .font(.headline.bold())
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("Room \(room.code) · \(room.mode.displayName)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                Button {
                                    Task { await send(to: friend) }
                                } label: {
                                    Text(sentIDs.contains(friend.userID) ? "Sent" : "Invite")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(sentIDs.contains(friend.userID) ? AppTheme.teal.opacity(0.18) : AppTheme.hotPink)
                                        .foregroundStyle(sentIDs.contains(friend.userID) ? AppTheme.teal : AppTheme.textOnColor)
                                        .clipShape(Capsule())
                                }
                                .disabled(sentIDs.contains(friend.userID) || sendingID == friend.userID)
                            }
                            .padding(12)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { vm.start(user: user) }
            .onDisappear { vm.stop() }
        }
    }

    private func send(to friend: FriendSummary) async {
        sendingID = friend.userID
        defer { sendingID = nil }
        do {
            try await FirestoreService.shared.createPartyInvite(room: room, from: user, to: friend)
            sentIDs.insert(friend.userID)
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }
}

private struct PartyPlayerTile: View {
    let player: PartyPlayer
    let isReady: Bool

    var body: some View {
        VStack(spacing: 8) {
            StickDuelerAvatarView(style: player.avatarStyle, size: 44)
            Text(player.username)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            HStack(spacing: 4) {
                if player.isHost {
                    Text("HOST")
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.crownGold.opacity(0.20))
                        .foregroundStyle(AppTheme.crownGold)
                        .clipShape(Capsule())
                }
                if isReady {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.teal)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(AppTheme.controlBackground.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
    }
}

private struct PartyScoreboardView: View {
    let room: PartyRoom
    let currentUserID: String
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("Party Results")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.brandGradient)
                    Text(room.winnerReason ?? "Same puzzle, no rank or coins")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    ForEach(PartyScoring.standings(for: room)) { standing in
                        PartyStandingRow(
                            standing: standing,
                            mode: room.mode,
                            isCurrentUser: standing.player.userID == currentUserID
                        )
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))

                Button(action: onDone) {
                    Label("Back to Games", systemImage: "house.fill")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }
}

private struct PartyStageRoundResultsView: View {
    let room: PartyRoom
    let round: PartyStageRound
    let currentUserID: String
    let isHost: Bool
    let onOpenStage: () -> Void
    let onAdvance: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("Round \(round.index + 1) Results")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.brandGradient)
                    Text("\(round.mode.displayName) · cumulative scores")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(spacing: 10) {
                    ForEach(round.scoreRows ?? []) { row in
                        PartyStageScoreRowView(row: row, isCurrentUser: row.userID == currentUserID)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))

                Button(action: onOpenStage) {
                    Label("Open Party Screen", systemImage: "airplayvideo")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.hotPink.opacity(0.18))
                        .foregroundStyle(AppTheme.hotPink)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.hotPink.opacity(0.36), lineWidth: 1.25))
                }
                .buttonStyle(.plain)

                if isHost && round.index < ((room.stageRounds?.count ?? 1) - 1) {
                    Button(action: onAdvance) {
                        Label("Start Round \(round.index + 2)", systemImage: "play.fill")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.brandGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else if !isHost && round.index < ((room.stageRounds?.count ?? 1) - 1) {
                    Text("Waiting for host to start the next round.")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding()
        }
    }
}

private struct PartyStageFinalView: View {
    let room: PartyRoom
    let currentUserID: String
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("Party Champion")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.brandGradient)
                    Text(room.winnerReason ?? "Final scores")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    ForEach(finalRows) { row in
                        PartyStageScoreRowView(row: row, isCurrentUser: row.userID == currentUserID)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))

                stageBreakdown

                Button(action: onDone) {
                    Label("Back to Games", systemImage: "house.fill")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }

    private var finalRows: [PartyStageRoundScore] {
        let scores = room.stageScores ?? [:]
        return room.players
            .map { player in
                PartyStageRoundScore(
                    userID: player.userID,
                    username: player.username,
                    placement: finalPlacement(for: player.userID, scores: scores),
                    roundPoints: 0,
                    cumulativePoints: scores[player.userID] ?? 0,
                    resultSummary: "\(roundWins(for: player.userID)) round wins"
                )
            }
            .sorted {
                if $0.cumulativePoints != $1.cumulativePoints { return $0.cumulativePoints > $1.cumulativePoints }
                if roundWins(for: $0.userID) != roundWins(for: $1.userID) { return roundWins(for: $0.userID) > roundWins(for: $1.userID) }
                return $0.username < $1.username
            }
    }

    private var stageBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Round Breakdown", systemImage: "list.number")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.accentBright)
            ForEach(room.stageRounds ?? []) { round in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Round \(round.index + 1) · \(round.mode.displayName)")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    ForEach(round.scoreRows ?? []) { row in
                        HStack {
                            Text("#\(row.placement) \(row.username)")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text("+\(row.roundPoints)")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.crownGold)
                        }
                    }
                }
                .padding(10)
                .background(AppTheme.controlBackground.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func finalPlacement(for userID: String, scores: [String: Int]) -> Int {
        let myScore = scores[userID] ?? 0
        return scores.values.filter { $0 > myScore }.count + 1
    }

    private func roundWins(for userID: String) -> Int {
        (room.stageRounds ?? []).reduce(0) { total, round in
            total + ((round.scoreRows ?? []).contains { $0.userID == userID && $0.placement == 1 } ? 1 : 0)
        }
    }
}

private struct PartyStageScoreRowView: View {
    let row: PartyStageRoundScore
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(row.placement)")
                .font(.headline.weight(.black))
                .foregroundStyle(row.placement == 1 ? AppTheme.crownGold : AppTheme.textSecondary)
                .frame(width: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(isCurrentUser ? "You" : row.username)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(row.resultSummary)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if row.roundPoints > 0 {
                    Text("+\(row.roundPoints)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.crownGold)
                }
                Text("\(row.cumulativePoints) pts")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.hotPink)
            }
        }
        .padding(10)
        .background(isCurrentUser ? AppTheme.crownGold.opacity(0.13) : AppTheme.controlBackground.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isCurrentUser ? AppTheme.crownGold.opacity(0.45) : AppTheme.controlBorder, lineWidth: 1))
    }
}

private struct PartyStageScreenView: View {
    @ObservedObject var vm: PartyRoomViewModel
    let fallbackRoom: PartyRoom
    let currentUserID: String
    @Environment(\.dismiss) private var dismiss
    @State private var now = Date()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var room: PartyRoom {
        vm.room ?? fallbackRoom
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "23182F"), Color(hex: "172E42"), Color(hex: "3A1730")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Puzzle Party")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.hotPink)
                        Text("Room \(room.code)")
                            .font(.title2.bold())
                            .foregroundStyle(.white.opacity(0.86))
                    }
                    Spacer()
                    Button("Close") { dismiss() }
                        .font(.headline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.14))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                content
            }
            .padding(28)
        }
        .onReceive(clock) { now = $0 }
    }

    @ViewBuilder
    private var content: some View {
        switch room.status {
        case .lobby:
            stageLobby
        case .inProgress:
            if let round = room.activeStageRound {
                stageRound(round)
            } else {
                stageMessage("Waiting for host")
            }
        case .finished:
            stageFinal
        case .canceled:
            stageMessage("Party canceled")
        case .expired:
            stageMessage("Party expired")
        }
    }

    private var stageLobby: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Join Code")
                    .font(.headline.bold())
                    .foregroundStyle(.white.opacity(0.72))
                Text(room.code)
                    .font(.system(size: 78, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Players ready \(room.readyCount)/\(room.players.count)")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.crownGold)
                stagePlayersGrid(showReady: true)
            }
            .stagePanel()

            stagePlaylistPanel
        }
    }

    private func stageRound(_ round: PartyStageRound) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text(round.status == .finished ? "Round \(round.index + 1) Results" : "Round \(round.index + 1) Live")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text(round.mode.displayName)
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.hotPink)
                Text("\(submittedCount(round))/\(room.players.count) submitted")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.crownGold)
                if let deadline = round.finishWindowDeadline {
                    Text("Finish window \(timeText(max(0, Int(ceil(deadline.timeIntervalSince(now))))))")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.hotPink)
                }
                stagePlayersGrid(showReady: false, round: round)
            }
            .stagePanel()

            VStack(alignment: .leading, spacing: 12) {
                Text("Scoreboard")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                if round.status == .finished {
                    ForEach(round.scoreRows ?? []) { row in
                        stageScoreLine(row)
                    }
                } else {
                    ForEach(cumulativeRows) { row in
                        stageScoreLine(row)
                    }
                }
            }
            .stagePanel()
        }
    }

    private var stageFinal: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Final Scores")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text(room.winnerReason ?? "Party complete")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.crownGold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .stagePanel()

            VStack(alignment: .leading, spacing: 12) {
                ForEach(cumulativeRows) { row in
                    stageScoreLine(row)
                }
            }
            .stagePanel()
        }
    }

    private var stagePlaylistPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playlist")
                .font(.title2.bold())
                .foregroundStyle(.white)
            ForEach(room.stageRounds ?? []) { round in
                HStack {
                    Text("\(round.index + 1)")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.modeGradient(round.mode))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(round.mode.displayName)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Text(round.mode.difficultyLabel(round.difficulty))
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .stagePanel()
    }

    private func stagePlayersGrid(showReady: Bool, round: PartyStageRound? = nil) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            ForEach(room.players) { player in
                VStack(spacing: 6) {
                    StickDuelerAvatarView(style: player.avatarStyle, size: 52)
                    Text(player.username)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if showReady {
                        Text(room.isReady(player.userID) ? "READY" : "JOINED")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(room.isReady(player.userID) ? AppTheme.teal : .white.opacity(0.62))
                    } else if let round {
                        Text(isSubmitted(playerID: player.userID, round: round) ? "SUBMITTED" : "PLAYING")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(isSubmitted(playerID: player.userID, round: round) ? AppTheme.teal : AppTheme.crownGold)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var cumulativeRows: [PartyStageRoundScore] {
        let scores = room.stageScores ?? [:]
        return room.players
            .map { player in
                PartyStageRoundScore(
                    userID: player.userID,
                    username: player.username,
                    placement: scores.values.filter { $0 > (scores[player.userID] ?? 0) }.count + 1,
                    roundPoints: 0,
                    cumulativePoints: scores[player.userID] ?? 0,
                    resultSummary: "Total"
                )
            }
            .sorted {
                if $0.cumulativePoints != $1.cumulativePoints { return $0.cumulativePoints > $1.cumulativePoints }
                return $0.username < $1.username
            }
    }

    private func stageScoreLine(_ row: PartyStageRoundScore) -> some View {
        HStack {
            Text("#\(row.placement)")
                .font(.headline.weight(.black))
                .foregroundStyle(row.placement == 1 ? AppTheme.crownGold : .white.opacity(0.68))
                .frame(width: 42)
            Text(row.username)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Spacer()
            if row.roundPoints > 0 {
                Text("+\(row.roundPoints)")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.crownGold)
            }
            Text("\(row.cumulativePoints)")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.hotPink)
        }
        .padding(10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func stageMessage(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 42, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .stagePanel()
    }

    private func submittedCount(_ round: PartyStageRound) -> Int {
        room.players.filter { isSubmitted(playerID: $0.userID, round: round) }.count
    }

    private func isSubmitted(playerID: String, round: PartyStageRound) -> Bool {
        guard let result = round.results[playerID] else { return false }
        if result.status == "Abandoned" || result.summary["partyTimeout"] == "true" { return true }
        if result.mode == .wordle { return result.isFinalWordleResult }
        if result.mode == .hangman { return result.summary["final"] == "true" || result.completed || result.wrongGuessCount >= result.maxWrongGuesses }
        return true
    }

    private func timeText(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

private extension View {
    func stagePanel() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

private struct PartyStandingRow: View {
    let standing: PartyStanding
    let mode: GameMode
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(standing.placement)")
                .font(.headline.weight(.black))
                .foregroundStyle(standing.placement == 1 ? AppTheme.crownGold : AppTheme.textSecondary)
                .frame(width: 38)

            StickDuelerAvatarView(style: standing.player.avatarStyle, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(isCurrentUser ? "You" : standing.player.username)
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    if standing.player.abandoned {
                        Text("LEFT")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(AppTheme.danger)
                    }
                }
                Text(PartyScoring.summary(for: standing.result, mode: mode))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(isCurrentUser ? AppTheme.crownGold.opacity(0.13) : AppTheme.controlBackground.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isCurrentUser ? AppTheme.crownGold.opacity(0.45) : AppTheme.controlBorder, lineWidth: 1))
    }
}

@MainActor
private final class PartyRoomViewModel: ObservableObject {
    @Published var room: PartyRoom?
    @Published var joinCode = ""
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var pendingRoundIndex: Int?
    @Published var submissionMessage: String?

    private let store = FirestoreService.shared
    private var listener: ListenerRegistration?
    private var isFinalizingFinishWindow = false
    private var currentUserID: String?
    private var heartbeat: Task<Void, Never>?
    private var isSubmitting = false

    private func pendingKey(_ code: String, _ userID: String) -> String {
        "verifiedPartyEvidence_\(userID)_\(code)"
    }

    func create(user: AppUser, mode: GameMode, difficulty: Difficulty) async {
        await run {
            let created = try await self.store.createPartyRoom(host: user, mode: mode, difficulty: difficulty)
            self.attach(to: created.code, userID: user.id)
            self.room = created
        }
    }

    func createStage(user: AppUser, rounds: [PartyStageRoundConfiguration]) async {
        await run {
            let created = try await self.store.createPartyStageRoom(host: user, rounds: rounds)
            self.attach(to: created.code, userID: user.id)
            self.room = created
        }
    }

    func join(user: AppUser) async {
        await run {
            let joined = try await self.store.joinPartyRoom(code: self.joinCode, user: user)
            self.attach(to: joined.code, userID: user.id)
            self.room = joined
        }
    }

    func start(userID: String) async {
        guard let room else { return }
        await run {
            self.room = try await self.store.startPartyRoom(code: room.code, hostID: userID)
        }
    }

    func setReady(userID: String, isReady: Bool) async {
        guard let room else { return }
        await run {
            self.room = try await self.store.setPartyReady(code: room.code, userID: userID, isReady: isReady)
        }
    }

    func submit(_ result: MatchPlayerResult, roundIndex: Int = 0) async {
        guard let room, room.status == .inProgress else { return }
        if room.code.hasPrefix("S1") {
            guard MatchResolver.isFinalResult(result), let evidence = result.rewardEvidenceJSON,
                  result.userID == currentUserID, pendingRoundIndex == nil,
                  roundIndex == (room.currentStageRoundIndex ?? 0), result.mode == room.mode else { return }
            let index = room.currentStageRoundIndex ?? 0
            let key = pendingKey(room.code, result.userID)
            UserDefaults.standard.set(["roundIndex": index, "evidence": evidence], forKey: key)
            pendingRoundIndex = index
            await retrySubmission(code: room.code, userID: result.userID)
            return
        }
        do {
            if room.isStageRoom == true {
                self.room = try await self.store.submitPartyStageResult(code: room.code, userID: result.userID, result: result)
            } else {
                self.room = try await self.store.submitPartyResult(code: room.code, userID: result.userID, result: result)
            }
            _ = try? await self.store.recordDailyPlay(userID: result.userID, activityID: "party_\(room.code)_\(result.userID)")
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func advanceStageRound(userID: String) async {
        guard let room, room.isStageRoom == true else { return }
        await run {
            self.room = try await self.store.advancePartyStageRound(code: room.code, hostID: userID)
        }
    }

    func finalizeFinishWindowIfNeeded(now: Date) async {
        // The verified heartbeat uses the server clock, including normal game timers.
        guard room?.code.hasPrefix("S1") != true else { return }
        guard !isFinalizingFinishWindow,
              let room,
              room.status == .inProgress,
              let deadline = activeFinishWindowDeadline(for: room),
              now >= deadline else {
            return
        }
        isFinalizingFinishWindow = true
        defer { isFinalizingFinishWindow = false }
        do {
            self.room = try await self.store.finalizeExpiredPartyFinishWindow(code: room.code)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func activeFinishWindowDeadline(for room: PartyRoom) -> Date? {
        if room.isStageRoom == true {
            return room.activeStageRound?.finishWindowDeadline
        }
        return room.finishWindowDeadline
    }

    func leave(userID: String) async {
        guard let room else { return }
        await run {
            self.room = try await self.store.leavePartyRoom(code: room.code, userID: userID)
        }
    }

    func stopListening() {
        self.listener?.remove()
        self.listener = nil
        heartbeat?.cancel()
        heartbeat = nil
    }

    private func retrySubmission(code: String, userID: String) async {
        let key = pendingKey(code, userID)
        guard !isSubmitting,
              let pending = UserDefaults.standard.dictionary(forKey: key),
              let index = pending["roundIndex"] as? Int, let evidence = pending["evidence"] as? String else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let updated = try await store.verifiedPartyAction("submit", code: code, userID: userID, roundIndex: index, evidenceJSON: evidence)
            self.room = updated
            UserDefaults.standard.removeObject(forKey: key)
            pendingRoundIndex = nil
            submissionMessage = nil
        } catch {
            // Retain the lock and evidence through network failure or app restart.
            submissionMessage = "Turn saved on this device. Reconnecting to submit."
        }
    }

    private func attach(to code: String, userID: String) {
        self.stopListening()
        self.currentUserID = userID
        let key = pendingKey(code, userID)
        self.pendingRoundIndex = UserDefaults.standard.dictionary(forKey: key)?["roundIndex"] as? Int
        self.listener = self.store.listenForPartyRoom(code: code) { [weak self] room in
            Task { @MainActor in
                self?.room = room
            }
        }
        if code.hasPrefix("S1") {
            heartbeat = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { return }
                    await self.retrySubmission(code: code, userID: userID)
                    if let updated = try? await self.store.verifiedPartyAction("tick", code: code, userID: userID) {
                        self.room = updated
                        if [.finished, .canceled, .expired].contains(updated.status) { return }
                    }
                    do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
                }
            }
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) async {
        self.isWorking = true
        defer { self.isWorking = false }
        do {
            try await operation()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
