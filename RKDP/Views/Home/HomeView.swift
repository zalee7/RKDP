import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var selectedMode: GameMode?
    @State private var showProfile = false
    @State private var showShop = false
    @State private var showHowToPlay = false

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
                        .padding(.bottom, 124)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3).foregroundStyle(AppTheme.accentBright)
                    }
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
        }
    }

    @ViewBuilder
    private func userHeader(user: AppUser) -> some View {
        HStack(spacing: 12) {
            StickDuelerAvatarView(style: user.cosmetics.avatarStyle, size: 58)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                CoinBadgeView(amount: user.coins)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 320, alignment: .center)
        .background(AppTheme.cardBackground.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(AppTheme.cardBorder.opacity(0.9), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

private struct HomeBrandHeader: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("Grid Duel")
                .font(.system(size: 33, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.brandGradient)
                .shadow(color: AppTheme.crownGold.opacity(0.32), radius: 12, x: 0, y: 4)
            Text("Ranked Puzzle Arena")
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
                    .foregroundStyle(AppTheme.crownGold)
                Button(action: onHelp) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accentBright)
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("How to play")
            }
            Text("Solo, ranked, casual, and events")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
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

    var body: some View {
        VStack(spacing: 10) {
            ForEach(GameMode.allCases) { mode in
                GameModeCardView(mode: mode, user: user) {
                    onSelect(mode)
                }
                .frame(height: 108)
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
    private var rankedLockedReason: String? {
        mode.rankedLockReason(for: selectedDifficulty)
    }
    private var casualLockedReason: String? {
        mode.casualLockReason(for: selectedDifficulty)
    }
    private var hasRankedEntry: Bool {
        user?.rankedAccess.canStartRanked(mode: mode) ?? false
    }
    private var rankedButtonTitle: String {
        if rankedLockedReason != nil { return "Ranked Locked" }
        return hasRankedEntry ? "Ranked" : "Ranked Access"
    }
    private var rankedButtonSubtitle: String {
        if let rankedLockedReason { return rankedLockedReason }
        if hasRankedEntry {
            let status = user?.rankedAccess.statusText(for: mode) ?? "Free entry available"
            return "\(mode.difficultyLabel(selectedDifficulty)) · \(status) · \(divisionWagerText)"
        }
        return "Watch ad or unlock ranked"
    }
    private var rankedButtonIcon: String {
        if rankedLockedReason != nil { return "lock.fill" }
        return hasRankedEntry ? "flag.checkered.2.crossed" : "lock.open.fill"
    }
    private var divisionWagerText: String {
        guard let user else { return "Division wager" }
        return "\(Wager.fixed(for: user.rank(for: mode)).amount) coin wager"
    }
    private var onlineFormatSummary: String {
        mode.difficultyLabel(selectedDifficulty)
    }
    private var timerOrFormatValue: String {
        selectedTab == .solo ? selectedDifficulty.rankedTimeLabel(for: mode) : onlineFormatSummary
    }
    private var pointsSummary: String {
        "\(String(format: "%.1f", mode.pointMultiplier(for: selectedDifficulty)))x"
    }
    private var onlineDifficultyTitle: String {
        if mode.rankedDifficulties.count == 1,
           mode.casualDifficulties.count == 1,
           mode.rankedDifficulties.first == mode.casualDifficulties.first {
            return "Online Format"
        }
        return "Choose Online Format"
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

                        LobbySummaryStrip(
                            rankText: rankInfo.fullDisplayName,
                            recordText: rankInfo.recordDisplay,
                            formatTitle: selectedTab == .solo ? "Timer" : "Format",
                            formatValue: timerOrFormatValue,
                            fourthTitle: selectedTab == .solo ? "Best" : "Points",
                            fourthValue: selectedTab == .solo ? bestSummary : pointsSummary,
                            rankColor: rankInfo.displayTier.color
                        )
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedTab == .online ? onlineDifficultyTitle : ((mode == .anagram || mode == .hangman) ? "Word Length" : "Difficulty"))
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(selectedTab == .online ? "Unavailable formats are locked to keep queues healthy." : "Solo progression unlocks one step at a time.")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if selectedTab == .online {
                                    Text(onlineFormatSummary)
                                        .font(.caption.bold())
                                        .foregroundStyle(AppTheme.crownGold)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(AppTheme.crownGold.opacity(0.16))
                                        .clipShape(Capsule())
                                } else {
                                    Text(bestSummary)
                                        .font(.caption.bold())
                                        .foregroundStyle(AppTheme.accentBright)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                                    let onlineDisabled = selectedTab == .online &&
                                        !mode.rankedDifficulties.contains(difficulty) &&
                                        !mode.casualDifficulties.contains(difficulty)
                                    DifficultyCardView(
                                        mode: mode,
                                        difficulty: difficulty,
                                        isSelected: selectedDifficulty == difficulty,
                                        showsOnlineAvailability: selectedTab == .online,
                                        isDisabled: onlineDisabled,
                                        soloLockedReason: selectedTab == .solo ? user?.soloUnlockReason(mode: mode, difficulty: difficulty) : nil,
                                        rankedLockedReason: selectedTab == .online ? mode.rankedLockReason(for: difficulty) : nil,
                                        casualLockedReason: selectedTab == .online ? mode.casualLockReason(for: difficulty) : nil
                                    ) {
                                        if !onlineDisabled {
                                            selectedDifficulty = difficulty
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        VStack(spacing: 12) {
                            if selectedTab == .solo {
                                LobbyActionButton(
                                    title: soloLockedReason == nil ? "Play Solo" : "Solo Locked",
                                    subtitle: soloLockedReason ?? "Practice \(mode.difficultyLabel(selectedDifficulty))",
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
                                    disabled: rankedLockedReason != nil || user == nil
                                ) {
                                    if hasRankedEntry {
                                        destination.append("ranked")
                                    } else {
                                        showRankedAccessStore = true
                                    }
                                }

                                OnlineActionCard(
                                    title: casualLockedReason == nil ? "Casual" : "Casual Locked",
                                    subtitle: casualLockedReason ?? "\(mode.difficultyLabel(selectedDifficulty)) · same puzzle, random opponent",
                                    icon: casualLockedReason == nil ? "shuffle.circle.fill" : "lock.fill",
                                    chips: casualChips,
                                    style: .secondary,
                                    disabled: casualLockedReason != nil || user == nil
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
                guard tab == .online else { return }
                if mode.rankedDifficulties.count == 1,
                   mode.casualDifficulties.count == 1,
                   mode.rankedDifficulties.first == mode.casualDifficulties.first {
                    selectedDifficulty = mode.rankedDifficulties[0]
                } else if !mode.rankedDifficulties.contains(selectedDifficulty),
                          !mode.casualDifficulties.contains(selectedDifficulty) {
                    selectedDifficulty = mode.casualDifficulties.first ?? mode.rankedDifficulties.first ?? mode.defaultDifficulty
                }
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
                            if mode.rankedDifficulties.contains(mode.defaultDifficulty) {
                                selectedDifficulty = mode.defaultDifficulty
                            } else {
                                selectedDifficulty = mode.rankedDifficulties.first ?? .medium
                            }
                            destination.removeLast()
                            if auth.user != nil {
                                destination.append("ranked")
                            }
                        },
                        onHome: { dismiss() }
                    )
                } else if dest == "ranked", let user = auth.user {
                    MatchmakingView(user: user, mode: mode, difficulty: selectedDifficulty) {
                        Task { await auth.refreshUser() }
                    }
                } else if dest == "casual", let user = auth.user {
                    MatchmakingView(user: user, mode: mode, difficulty: selectedDifficulty, entryKind: .casual) {
                        Task { await auth.refreshUser() }
                    }
                }
            }
        }
    }

    private var rankedChips: [LobbyActionChip] {
        var chips = [
            LobbyActionChip(text: mode.difficultyLabel(selectedDifficulty), icon: "slider.horizontal.3"),
            LobbyActionChip(text: divisionWagerText, icon: "centsign.circle.fill"),
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
            LobbyActionChip(text: mode.difficultyLabel(selectedDifficulty), icon: "slider.horizontal.3"),
            LobbyActionChip(text: "No rank", icon: "minus.circle.fill"),
            LobbyActionChip(text: "No wager", icon: "centsign.circle"),
            LobbyActionChip(text: "+10 win", icon: "sparkles")
        ]
    }

    private var bestSummary: String {
        switch mode {
        case .gridlock:
            if let moves = rankInfo.bestMoves { return "Best \(moves) moves" }
            if let progress = rankInfo.bestProgress { return "Best \(Int((progress * 100).rounded()))% match" }
            if let time = rankInfo.bestTime { return "Best \(formattedTime(time))" }
        case .wordle:
            if let guesses = rankInfo.bestGuesses { return "Best \(guesses) guesses" }
            if let time = rankInfo.bestTime { return "Best \(formattedTime(time))" }
        case .hangman:
            if let time = rankInfo.bestTime { return "Best \(formattedTime(time))" }
        case .anagram, .wordHunt:
            if let score = rankInfo.bestScore { return "Best \(score) pts" }
        case .colorLink:
            if let progress = rankInfo.bestProgress { return "Best \(Int((progress * 100).rounded()))% fill" }
            if let time = rankInfo.bestTime { return "Best \(formattedTime(time))" }
        case .minesweeper:
            if let time = rankInfo.bestTime { return "Best \(formattedTime(time))" }
            if let progress = rankInfo.bestProgress { return "Best \(Int((progress * 100).rounded()))%" }
        case .sudoku:
            if let time = rankInfo.bestTime { return "Best \(formattedTime(time))" }
        }
        return "No solo best yet"
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
                    selectedTab = tab
                } label: {
                    Label(tab.rawValue, systemImage: tab == .solo ? "person.fill" : "network")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? AppTheme.crownGold : Color.white.opacity(0.08))
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
            let colors: [Color] = [AppTheme.crownGold, AppTheme.teal, AppTheme.hotPink, AppTheme.iconBlue]
            let mirrorIndex = index < 9 ? index : 17 - index
            return colors[mirrorIndex % colors.count].opacity(index % 2 == 0 ? 1 : 0.72)
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
    let recordText: String
    let formatTitle: String
    let formatValue: String
    let fourthTitle: String
    let fourthValue: String
    let rankColor: Color

    var body: some View {
        HStack(spacing: 0) {
            summaryItem(icon: "trophy.fill", title: "Rank", value: rankText, color: rankColor)
            Divider().overlay(Color.white.opacity(0.18)).padding(.vertical, 8)
            summaryItem(icon: "chart.bar.fill", title: "W/L", value: recordText, color: AppTheme.teal)
            Divider().overlay(Color.white.opacity(0.18)).padding(.vertical, 8)
            summaryItem(icon: formatTitle == "Timer" ? "timer" : "slider.horizontal.3", title: formatTitle, value: formatValue, color: AppTheme.accentBright)
            Divider().overlay(Color.white.opacity(0.18)).padding(.vertical, 8)
            summaryItem(icon: fourthTitle == "Best" ? "sparkles" : "star.fill", title: fourthTitle, value: fourthValue, color: AppTheme.crownGold)
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
    let mode: GameMode
    let difficulty: Difficulty
    let isSelected: Bool
    let showsOnlineAvailability: Bool
    let isDisabled: Bool
    let soloLockedReason: String?
    let rankedLockedReason: String?
    let casualLockedReason: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            cardContent
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: showsOnlineAvailability ? 118 : 104, alignment: .topLeading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(cardBorderColor, lineWidth: cardBorderWidth)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.38 : 1)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mode.difficultyLabel(difficulty))
                    .font(.headline.bold())
                    .foregroundStyle(isDisabled ? AppTheme.textSecondary : AppTheme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accentBright)
                }
            }

            Text(detailText)
                .font(.caption)
                .foregroundStyle(isDisabled ? AppTheme.textSecondary.opacity(0.7) : AppTheme.textSecondary)

            HStack(spacing: 6) {
                if !showsOnlineAvailability {
                    availabilityBadge(soloLockedReason == nil ? "Solo" : "Locked", locked: soloLockedReason != nil)
                } else {
                    availabilityBadge("Ranked", locked: rankedLockedReason != nil)
                    availabilityBadge("Casual", locked: casualLockedReason != nil)
                }
            }

            lockReasonText
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if isDisabled {
            Color.black.opacity(0.20)
                .overlay(Color.white.opacity(0.035))
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
                .lineLimit(2)
        } else if let rankedLockedReason {
            Text(rankedLockedReason)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
        } else if let casualLockedReason {
            Text(casualLockedReason)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
        }
    }

    private var detailText: String {
        if showsOnlineAvailability {
            return "\(String(format: "%.1f", mode.pointMultiplier(for: difficulty)))x points"
        }
        if soloLockedReason != nil {
            return "Complete the previous step"
        }
        return mode == .anagram || mode == .hangman || mode == .wordHunt || mode == .wordle ? "Solo format" : "Solo difficulty"
    }

    private var cardBorderColor: Color {
        if isDisabled { return AppTheme.cardBorder.opacity(0.25) }
        return isSelected ? AppTheme.accentBright : AppTheme.cardBorder
    }

    private var cardBorderWidth: CGFloat {
        isSelected ? 1.5 : 1
    }

    private func availabilityBadge(_ label: String, locked: Bool) -> some View {
        Label(label, systemImage: locked ? "lock.fill" : "checkmark.circle.fill")
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background((locked ? Color.white.opacity(0.10) : AppTheme.teal.opacity(0.22)))
            .foregroundStyle(locked ? AppTheme.textSecondary : AppTheme.teal)
            .clipShape(Capsule())
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
                Label(chip.text, systemImage: chip.icon)
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
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.modeGradient(mode))
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: mode.icon).font(.system(size: 29, weight: .semibold)).foregroundStyle(.white))
                    .shadow(color: AppTheme.modeShadow(mode), radius: 6)

                VStack(alignment: .leading, spacing: 7) {
                    Text(mode.displayName)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let user {
                        CompactModeStatsView(info: user.rank(for: mode))
                    } else {
                        Text("Tap to choose solo or online")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                modeBestColumn
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                cardBackground
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.68), lineWidth: 1.35)
            }
            .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.black.opacity(0.18))
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
    private var modeBestColumn: some View {
        if let user {
            let info = user.rank(for: mode)
            VStack(alignment: .trailing, spacing: 5) {
                Text("Best")
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(bestText(info))
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accentBright.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.85))
            }
            .frame(width: 72, alignment: .trailing)
        } else {
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary.opacity(0.85))
        }
    }

    private func bestText(_ info: RankInfo) -> String {
        if let score = info.bestScore { return "\(score) pts" }
        if let time = info.bestTime { return "\(time / 60):\(String(format: "%02d", time % 60))" }
        if let moves = info.bestMoves { return "\(moves) moves" }
        if let guesses = info.bestGuesses { return "\(guesses) guesses" }
        if let progress = info.bestProgress { return "\(Int((progress * 100).rounded()))%" }
        return "--"
    }
}

private struct CompactModeStatsView: View {
    let info: RankInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    RankIconView(tier: info.displayTier, division: info.division, size: 16)
                    Text(info.fullDisplayName)
                        .font(.caption.bold())
                        .foregroundStyle(info.displayTier.color)
                        .lineLimit(1)
                }

                RecordTextView(
                    wins: info.wins,
                    losses: info.losses,
                    font: .system(size: 11, weight: .bold)
                )
            }

            RankDivisionProgressView(info: info, height: 3, spacing: 3)
                .frame(maxWidth: 152)

            Text(info.divisionProgressDisplay)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
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
