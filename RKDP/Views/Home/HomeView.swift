import SwiftUI
import FirebaseFirestore

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
                .frame(height: 124)
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

                                OnlineActionCard(
                                    title: "Party",
                                    subtitle: "\(mode.difficultyLabel(selectedDifficulty)) · create or join with a code",
                                    icon: "person.3.fill",
                                    chips: partyChips,
                                    style: .secondary,
                                    disabled: user == nil
                                ) {
                                    destination.append("party")
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
                } else if dest == "party", let user = auth.user {
                    PartyRoomView(user: user, mode: mode, difficulty: selectedDifficulty)
                }
            }
        }
    }

    private var rankedChips: [LobbyActionChip] {
        var chips = [
            LobbyActionChip(text: mode.difficultyLabel(selectedDifficulty), icon: "slider.horizontal.3"),
            LobbyActionChip(text: divisionWagerText, icon: "circle.fill", usesCoinIcon: true),
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
            LobbyActionChip(text: "No wager", icon: "slash.circle"),
            LobbyActionChip(text: "+10 win", icon: "sparkles", usesCoinIcon: true)
        ]
    }

    private var partyChips: [LobbyActionChip] {
        [
            LobbyActionChip(text: "Join code", icon: "number.circle.fill"),
            LobbyActionChip(text: "Up to 8", icon: "person.3.sequence.fill"),
            LobbyActionChip(text: "No rank", icon: "minus.circle.fill"),
            LobbyActionChip(text: "Same puzzle", icon: "square.grid.3x3.fill")
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
    private var modeStatColumn: some View {
        if let user {
            let info = user.rank(for: mode)
            VStack(alignment: .trailing, spacing: 7) {
                modeStatPill(label: "W/L") {
                    RecordTextView(
                        wins: info.wins,
                        losses: info.losses,
                        font: .system(size: 13, weight: .black)
                    )
                }

                modeStatPill(label: "Best") {
                    Text(bestText(info))
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(AppTheme.accentBright.opacity(0.95))
                }
            }
            .frame(width: 88, alignment: .trailing)
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
                .fill(Color.white.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
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

private struct AnimatedModeThumbnailView: View {
    let mode: GameMode
    var size: CGFloat = 64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(AppTheme.modeGradient(mode))

            movingHighlight
            modeMotionOverlay

            Image(systemName: mode.icon)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
                .offset(iconOffset)
                .rotationEffect(iconRotation)
                .scaleEffect(iconScale)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: AppTheme.modeShadow(mode), radius: reduceMotion ? 6 : (isAnimating ? 9 : 6), x: 0, y: 3)
        .scaleEffect(reduceMotion ? 1 : (isAnimating ? thumbnailScale : 1))
        .animation(reduceMotion ? nil : .easeInOut(duration: duration).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            guard !reduceMotion else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                isAnimating = true
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            isAnimating = !reduced
        }
        .accessibilityHidden(true)
    }

    private var movingHighlight: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(reduceMotion ? 0.08 : 0.22), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * 0.34, height: size * 1.45)
            .rotationEffect(.degrees(18))
            .offset(x: reduceMotion ? 0 : (isAnimating ? size * 0.72 : -size * 0.72))
            .blendMode(.screen)
            .opacity(reduceMotion ? 0.25 : 0.7)
    }

    @ViewBuilder
    private var modeMotionOverlay: some View {
        switch mode {
        case .colorLink:
            Circle()
                .stroke(Color.white.opacity(isAnimating ? 0.22 : 0.10), lineWidth: 2)
                .frame(width: size * 0.55, height: size * 0.55)
                .offset(x: isAnimating ? 4 : -3, y: isAnimating ? -2 : 3)
        case .gridlock, .sudoku:
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: size * 0.58, weight: .bold))
                .foregroundStyle(Color.white.opacity(isAnimating ? 0.16 : 0.08))
                .offset(x: isAnimating ? 3 : -2, y: isAnimating ? -2 : 2)
        case .minesweeper:
            Circle()
                .fill(AppTheme.hotPink.opacity(isAnimating ? 0.22 : 0.08))
                .frame(width: size * 0.72, height: size * 0.72)
                .scaleEffect(isAnimating ? 1.06 : 0.92)
        case .wordle:
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        .frame(width: size * 0.15, height: size * 0.15)
                }
            }
            .offset(y: isAnimating ? -12 : -9)
        case .hangman:
            Circle()
                .fill(Color(hex: "FF5A1F").opacity(isAnimating ? 0.18 : 0.08))
                .blur(radius: 2)
                .frame(width: size * 0.82, height: size * 0.82)
        case .wordHunt:
            Circle()
                .stroke(Color.white.opacity(isAnimating ? 0.18 : 0.08), lineWidth: 2)
                .frame(width: size * 0.62, height: size * 0.62)
                .offset(x: isAnimating ? -3 : 3)
        case .anagram:
            Text("Aa")
                .font(.system(size: size * 0.28, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(isAnimating ? 0.20 : 0.08))
                .offset(x: isAnimating ? 13 : 9, y: isAnimating ? -14 : -10)
        }
    }

    private var iconOffset: CGSize {
        guard !reduceMotion else { return .zero }
        switch mode {
        case .wordHunt:
            return CGSize(width: isAnimating ? 1.7 : -1.7, height: 0)
        case .anagram:
            return CGSize(width: 0, height: isAnimating ? -1.3 : 1.3)
        case .hangman, .minesweeper:
            return CGSize(width: 0, height: isAnimating ? -1.1 : 1.1)
        default:
            return CGSize(width: 0, height: isAnimating ? -1.6 : 1.6)
        }
    }

    private var iconRotation: Angle {
        guard !reduceMotion else { return .zero }
        switch mode {
        case .anagram:
            return .degrees(isAnimating ? 2 : -2)
        case .wordHunt:
            return .degrees(isAnimating ? -1.5 : 1.5)
        default:
            return .zero
        }
    }

    private var iconScale: CGFloat {
        guard !reduceMotion else { return 1 }
        return isAnimating ? 1.035 : 0.995
    }

    private var thumbnailScale: CGFloat {
        switch mode {
        case .minesweeper, .hangman: return 1.025
        default: return 1.015
        }
    }

    private var duration: Double {
        switch mode {
        case .colorLink: return 3.6
        case .gridlock: return 3.2
        case .sudoku: return 4.2
        case .minesweeper: return 2.9
        case .wordle: return 3.4
        case .hangman: return 3.0
        case .wordHunt: return 3.8
        case .anagram: return 4.0
        }
    }

    private var delay: Double {
        Double(GameMode.allCases.firstIndex(of: mode) ?? 0) * 0.18
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

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = PartyRoomViewModel()

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()

            if let room = vm.room {
                switch room.status {
                case .lobby:
                    partyLobby(room)
                case .inProgress:
                    partyGame(room)
                case .finished:
                    PartyScoreboardView(room: room, currentUserID: user.id) {
                        dismiss()
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
                    .tint(AppTheme.crownGold)
                    .padding(20)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .navigationTitle("Party")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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

                    TextField("ABC123", text: $vm.joinCode)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white.opacity(0.10))
                        .foregroundStyle(AppTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

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
                .background(AppTheme.cardBackground.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
            }
            .padding()
        }
    }

    private func partyLobby(_ room: PartyRoom) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                partyHeader(title: "Code \(room.code)", subtitle: "\(room.mode.displayName) · \(room.mode.difficultyLabel(room.difficulty))")

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("\(room.players.count)/\(room.maxPlayers)", systemImage: "person.3.fill")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.crownGold)
                        Spacer()
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
                            PartyPlayerTile(player: player)
                        }
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))

                if room.isHost(user.id) {
                    Button {
                        Task { await vm.start(userID: user.id) }
                    } label: {
                        Label(room.players.count >= 2 ? "Start Party" : "Need 2 Players", systemImage: "play.fill")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(room.players.count >= 2 ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                            .foregroundStyle(room.players.count >= 2 ? .white : AppTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(room.players.count < 2)
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

    private func partyGame(_ room: PartyRoom) -> some View {
        ZStack(alignment: .top) {
            SoloGameView(
                mode: room.mode,
                difficulty: room.difficulty,
                user: user,
                sessionID: "party_\(room.code)",
                seed: room.seed,
                puzzleData: room.puzzleData,
                onMatchResult: { result in
                    Task { await vm.submit(result) }
                }
            )

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Party \(room.code)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.crownGold)
                    Text("\(submittedCount(room))/\(room.players.count) finished")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Button {
                    Task {
                        await vm.leave(userID: user.id)
                        dismiss()
                    }
                } label: {
                    Label("Leave", systemImage: "xmark.circle.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.danger.opacity(0.18))
                        .foregroundStyle(AppTheme.danger)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(AppTheme.cardBackground.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)
            .padding(.top, 8)
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

    private func submittedCount(_ room: PartyRoom) -> Int {
        room.players.filter { player in
            guard let result = player.result else { return false }
            if result.status == "Abandoned" { return true }
            if result.mode == .wordle { return result.isFinalWordleResult }
            if result.mode == .hangman { return result.summary["final"] == "true" || result.completed }
            return true
        }.count
    }
}

private struct PartyPlayerTile: View {
    let player: PartyPlayer

    var body: some View {
        VStack(spacing: 8) {
            StickDuelerAvatarView(style: player.avatarStyle, size: 44)
            Text(player.username)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            if player.isHost {
                Text("HOST")
                    .font(.system(size: 9, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.crownGold.opacity(0.20))
                    .foregroundStyle(AppTheme.crownGold)
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
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

private struct PartyStandingRow: View {
    let standing: PartyStanding
    let mode: GameMode
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(standing.placement)")
                .font(.headline.black())
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
        .background(isCurrentUser ? AppTheme.crownGold.opacity(0.13) : Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isCurrentUser ? AppTheme.crownGold.opacity(0.45) : Color.white.opacity(0.10), lineWidth: 1))
    }
}

@MainActor
private final class PartyRoomViewModel: ObservableObject {
    @Published var room: PartyRoom?
    @Published var joinCode = ""
    @Published var errorMessage: String?
    @Published var isWorking = false

    private let store = FirestoreService.shared
    private var listener: ListenerRegistration?

    func create(user: AppUser, mode: GameMode, difficulty: Difficulty) async {
        await run {
            let created = try await store.createPartyRoom(host: user, mode: mode, difficulty: difficulty)
            attach(to: created.code)
            room = created
        }
    }

    func join(user: AppUser) async {
        await run {
            let joined = try await store.joinPartyRoom(code: joinCode, user: user)
            attach(to: joined.code)
            room = joined
        }
    }

    func start(userID: String) async {
        guard let room else { return }
        await run {
            self.room = try await store.startPartyRoom(code: room.code, hostID: userID)
        }
    }

    func submit(_ result: MatchPlayerResult) async {
        guard let room, room.status == .inProgress else { return }
        do {
            self.room = try await store.submitPartyResult(code: room.code, userID: result.userID, result: result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leave(userID: String) async {
        guard let room else { return }
        await run {
            self.room = try await store.leavePartyRoom(code: room.code, userID: userID)
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    private func attach(to code: String) {
        stopListening()
        listener = store.listenForPartyRoom(code: code) { [weak self] room in
            Task { @MainActor in
                self?.room = room
            }
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
