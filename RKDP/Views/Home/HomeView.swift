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
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        HomeBrandHeader()
                        if let user = auth.user { userHeader(user: user) }

                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Choose Your Game")
                                    .font(.headline.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Pick a mode, practice, or queue ranked")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Button { showHowToPlay = true } label: {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.accentBright)
                            }
                            .accessibilityLabel("How to play")
                        }
                        .padding(.horizontal)

                        VStack(spacing: 14) {
                            HomeGameCategorySection(
                                title: "Grid Games",
                                subtitle: "Paths, boards, mines, and symmetry",
                                modes: [.colorLink, .gridlock, .sudoku, .minesweeper],
                                user: auth.user
                            ) { mode in
                                selectedMode = mode
                            }

                            HomeGameCategorySection(
                                title: "Word Games",
                                subtitle: "Guesses, searches, and fast vocabulary plays",
                                modes: [.wordle, .wordHunt, .anagram],
                                user: auth.user
                            ) { mode in
                                selectedMode = mode
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.top, 12)
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
                if let user = auth.user { ProfileView(user: user).environmentObject(auth) }
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
        HStack(spacing: 14) {
            Circle()
                .fill(AppTheme.brandGradient)
                .frame(width: 48, height: 48)
                .overlay(Text(String(user.username.prefix(1))).font(.title3.bold()).foregroundStyle(.white))
                .shadow(color: AppTheme.accent.opacity(0.6), radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.username).font(.headline).foregroundStyle(AppTheme.textPrimary)
                CoinBadgeView(amount: user.coins)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

private struct HomeBrandHeader: View {
    var body: some View {
        VStack(spacing: 3) {
            Text("Grid Duel")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.brandGradient)
                .shadow(color: AppTheme.crownGold.opacity(0.32), radius: 12, x: 0, y: 4)
            Text("Ranked Puzzle Arena")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.horizontal)
    }
}

private struct HomeGameCategorySection: View {
    let title: String
    let subtitle: String
    let modes: [GameMode]
    let user: AppUser?
    let onSelect: (GameMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(modes) { mode in
                        GameModeCardView(mode: mode, user: user) {
                            onSelect(mode)
                        }
                        .frame(width: 204, height: 248)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Mode Detail sheet

struct GameModeDetailView: View {
    let mode: GameMode
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedDifficulty: Difficulty
    @State private var destination: NavigationPath = .init()

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

    var body: some View {
        NavigationStack(path: $destination) {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        ModeLobbyHeader(mode: mode)

                        VStack(spacing: 10) {
                            HStack {
                                ModeFactRow(icon: "trophy.fill", title: "Rank", value: rankInfo.fullDisplayName, color: rankInfo.tier.color)
                                ModeFactRow(icon: "chart.bar.fill", title: "W/L", value: rankInfo.recordDisplay, color: AppTheme.teal)
                            }
                            HStack {
                                ModeFactRow(icon: "timer", title: "Ranked timer", value: selectedDifficulty.rankedTimeLabel(for: mode), color: AppTheme.accentBright)
                                ModeFactRow(icon: "star.fill", title: "Rank Points", value: "\(String(format: "%.1f", mode.pointMultiplier(for: selectedDifficulty)))x ranked points", color: .yellow)
                            }
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(mode == .anagram ? "Word Length" : "Difficulty")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Text(bestSummary)
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.accentBright)
                            }
                            .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                                    DifficultyCardView(
                                        mode: mode,
                                        difficulty: difficulty,
                                        isSelected: selectedDifficulty == difficulty,
                                        soloLockedReason: user?.soloUnlockReason(mode: mode, difficulty: difficulty),
                                        rankedLockedReason: mode.rankedLockReason(for: difficulty)
                                    ) {
                                        selectedDifficulty = difficulty
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        VStack(spacing: 12) {
                            LobbyActionButton(
                                title: soloLockedReason == nil ? "Play Solo" : "Solo Locked",
                                subtitle: soloLockedReason ?? "Practice \(mode.difficultyLabel(selectedDifficulty))",
                                icon: soloLockedReason == nil ? "person.fill" : "lock.fill",
                                gradient: AppTheme.brandGradient,
                                disabled: soloLockedReason != nil
                            ) {
                                destination.append("solo")
                            }

                            LobbyActionButton(
                                title: rankedLockedReason == nil ? "Ranked Match" : "Ranked Locked",
                                subtitle: rankedLockedReason ?? "Queue \(mode.difficultyLabel(selectedDifficulty))",
                                icon: rankedLockedReason == nil ? "flag.checkered.2.crossed" : "lock.fill",
                                gradient: AppTheme.modeGradient(mode),
                                disabled: rankedLockedReason != nil || user == nil
                            ) {
                                destination.append("ranked")
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
                }
            }
        }
    }

    private var bestSummary: String {
        switch mode {
        case .gridlock:
            if let moves = rankInfo.bestMoves { return "Best \(moves) moves" }
            if let progress = rankInfo.bestProgress { return "Best \(Int((progress * 100).rounded()))% symmetry" }
            if let time = rankInfo.bestTime { return "Best \(formattedTime(time))" }
        case .wordle:
            if let guesses = rankInfo.bestGuesses { return "Best \(guesses) guesses" }
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

private struct ModeLobbyHeader: View {
    let mode: GameMode

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.modeGradient(mode))
                    .frame(height: 150)
                    .shadow(color: AppTheme.modeShadow(mode), radius: 18)
                HStack(spacing: 18) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 84, height: 84)
                        .overlay(Image(systemName: mode.icon).font(.system(size: 38, weight: .bold)).foregroundStyle(.white))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(mode.displayName)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text(mode.description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(3)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
            }
            ModeMiniPreview(mode: mode)
        }
        .padding(.horizontal)
    }
}

private struct ModeMiniPreview: View {
    let mode: GameMode

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<18, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(previewColor(index))
                    .frame(height: 18)
            }
        }
        .padding(10)
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
        default:
            return AppTheme.modeAccent(mode).opacity(index % 2 == 0 ? 0.85 : 0.35)
        }
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
    let soloLockedReason: String?
    let rankedLockedReason: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            cardContent
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(cardBorderColor, lineWidth: cardBorderWidth)
            )
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mode.difficultyLabel(difficulty))
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accentBright)
                }
            }

            Text(rewardText)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 6) {
                availabilityBadge("Solo", locked: soloLockedReason != nil)
                availabilityBadge("Ranked", locked: rankedLockedReason != nil)
            }

            lockReasonText
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if isSelected {
            AppTheme.modeGradient(mode)
                .opacity(0.32)
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
        }
    }

    private var rewardText: String {
        "\(String(format: "%.1f", mode.pointMultiplier(for: difficulty)))x ranked points"
    }

    private var cardBorderColor: Color {
        isSelected ? AppTheme.accentBright : AppTheme.cardBorder
    }

    private var cardBorderWidth: CGFloat {
        isSelected ? 2 : 1
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

private struct LobbyActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
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
            .background(disabled ? AnyShapeStyle(Color.white.opacity(0.08)) : AnyShapeStyle(gradient))
            .foregroundStyle(disabled ? AppTheme.textSecondary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(disabled ? AppTheme.cardBorder : Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
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
            VStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.modeGradient(mode))
                    .frame(width: 86, height: 86)
                    .overlay(Image(systemName: mode.icon).font(.system(size: 38, weight: .semibold)).foregroundStyle(.white))
                    .shadow(color: AppTheme.modeShadow(mode), radius: 8)

                Text(mode.displayName)
                    .font(.headline.bold()).foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let user {
                    RankProgressMiniView(info: user.rank(for: mode))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                cardBackground
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.62), lineWidth: 1.4)
            }
            .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
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
                    .opacity(0.24)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AppTheme.modeAccent(mode).opacity(0.58), lineWidth: 1)
            }
    }
}

// Compact rank progress shown inside each tile
struct RankProgressMiniView: View {
    let info: RankInfo

    private var progress: Double {
        guard let next = RankTier(rawValue: info.tier.rawValue + 1) else { return 1.0 }
        let span = Double(next.pointsRequired - info.tier.pointsRequired)
        let done = Double(info.points - info.tier.pointsRequired)
        return max(0, min(1, done / span))
    }

    private var pointsLabel: String {
        if let pts = info.pointsToNextTier { return "\(info.points) / \(info.points + pts)" }
        return "MAX"
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                RankIconView(tier: info.tier, division: info.division, size: 17)
                Text(info.fullDisplayName)
                    .font(.caption.bold())
                    .foregroundStyle(info.tier.color)
            }
            RecordTextView(
                wins: info.wins,
                losses: info.losses,
                font: .system(size: 10, weight: .semibold)
            )
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.13)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.accentBright)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 10)
            Text(pointsLabel).font(.system(size: 9)).foregroundStyle(AppTheme.textSecondary)
            if let best = info.bestScore {
                Text("Best: \(best) pts").font(.system(size: 9)).foregroundStyle(AppTheme.accentBright)
            } else if let best = info.bestTime {
                Text("Best: \(best / 60):\(String(format: "%02d", best % 60))")
                    .font(.system(size: 9)).foregroundStyle(AppTheme.accentBright)
            }
        }
    }
}
