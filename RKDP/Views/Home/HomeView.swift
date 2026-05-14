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

                VStack(spacing: 20) {
                    if let user = auth.user { userHeader(user: user) }

                    HStack {
                        Text("Choose Your Game")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Button { showHowToPlay = true } label: {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.accentBright)
                        }
                    }
                    .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(GameMode.allCases) { mode in
                            GameModeCardView(mode: mode, user: auth.user) { selectedMode = mode }
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("GridDuel").font(.headline.bold()).foregroundStyle(AppTheme.textPrimary)
                }
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
                if let user = auth.user { ShopView(user: user) }
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

// MARK: - Mode Detail sheet

struct GameModeDetailView: View {
    let mode: GameMode
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedDifficulty: Difficulty = .medium
    @State private var destination: NavigationPath = .init()

    var body: some View {
        NavigationStack(path: $destination) {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AppTheme.modeGradient(mode))
                            .frame(width: 80, height: 80)
                            .overlay(Image(systemName: mode.icon).font(.system(size: 36)).foregroundStyle(.white))
                            .shadow(color: AppTheme.modeShadow(mode), radius: 14)
                        Text(mode.displayName).font(.title.bold()).foregroundStyle(AppTheme.textPrimary)
                        Text(mode.description)
                            .font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(mode == .anagram ? "Word Length" : "Difficulty")
                            .font(.headline).foregroundStyle(AppTheme.textPrimary)
                        Picker("Difficulty", selection: $selectedDifficulty) {
                            ForEach(Difficulty.allCases, id: \.self) { d in
                                Text(mode.difficultyLabel(d)).tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)

                    Divider().overlay(Color.white.opacity(0.12))

                    VStack(spacing: 12) {
                        NavigationLink(value: "solo") {
                            Label("Play Solo", systemImage: "person.fill")
                                .frame(maxWidth: .infinity).padding()
                                .background(AppTheme.brandGradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: AppTheme.accent.opacity(0.4), radius: 8)
                        }
                        .padding(.horizontal)

                        NavigationLink(value: "ranked") {
                            Label("Ranked Match", systemImage: "flag.checkered.2.crossed")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.white.opacity(0.08))
                                .foregroundStyle(AppTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.accent, lineWidth: 1.5))
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
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
                    SoloGameView(mode: mode, difficulty: selectedDifficulty, user: auth.user)
                } else if dest == "ranked", let user = auth.user {
                    MatchmakingView(user: user, mode: mode, difficulty: selectedDifficulty)
                }
            }
        }
    }
}

// MARK: - Game mode tile

struct GameModeCardView: View {
    let mode: GameMode
    let user: AppUser?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.modeGradient(mode))
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: mode.icon).font(.system(size: 28)).foregroundStyle(.white))
                    .shadow(color: AppTheme.modeShadow(mode), radius: 8)

                Text(mode.displayName)
                    .font(.headline).foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                if let user {
                    RankProgressMiniView(info: user.rank(for: mode))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(AppTheme.modeGradient(mode).opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.modeAccent(mode).opacity(0.45), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
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
                Text(info.tier.icon).font(.caption)
                Text(info.tier.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(info.tier.color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.15)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.accentBright)
                        .frame(width: geo.size.width * progress, height: 5)
                }
            }
            .frame(height: 5)
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
