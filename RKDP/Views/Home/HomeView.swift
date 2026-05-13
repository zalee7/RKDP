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
                // Background gradient
                LinearGradient(
                    colors: [Color(red: 0.07, green: 0.07, blue: 0.18), Color(red: 0.12, green: 0.08, blue: 0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    if let user = auth.user {
                        userHeader(user: user)
                    }

                    HStack {
                        Text("Choose Your Game")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Spacer()
                        Button { showHowToPlay = true } label: {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(GameMode.allCases) { mode in
                            GameModeCardView(mode: mode, user: auth.user) {
                                selectedMode = mode
                            }
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
                    Text("RKDP")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showShop = true } label: {
                        Image(systemName: "bag.fill")
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $selectedMode) { mode in
                GameModeDetailView(mode: mode).environmentObject(auth)
            }
            .sheet(isPresented: $showProfile) {
                if let user = auth.user {
                    ProfileView(user: user).environmentObject(auth)
                }
            }
            .sheet(isPresented: $showShop) {
                if let user = auth.user { ShopView(user: user) }
            }
            .sheet(isPresented: $showHowToPlay) {
                HowToPlayView()
            }
        }
    }

    @ViewBuilder
    private func userHeader(user: AppUser) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .overlay(Text(String(user.username.prefix(1))).font(.title3.bold()).foregroundStyle(.white))
                .shadow(color: .purple.opacity(0.5), radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.username).font(.headline).foregroundStyle(.white)
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
                LinearGradient(
                    colors: [Color(red: 0.07, green: 0.07, blue: 0.18), Color(red: 0.12, green: 0.08, blue: 0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(mode.accentColor.gradient)
                            .frame(width: 80, height: 80)
                            .overlay(Image(systemName: mode.icon).font(.system(size: 36)).foregroundStyle(.white))
                            .shadow(color: mode.accentColor.opacity(0.5), radius: 12)
                        Text(mode.displayName).font(.title.bold()).foregroundStyle(.white)
                        Text(mode.description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Difficulty").font(.headline).foregroundStyle(.white)
                        Picker("Difficulty", selection: $selectedDifficulty) {
                            ForEach(Difficulty.allCases, id: \.self) { d in
                                Text(d.displayName).tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)

                    Divider().overlay(Color.white.opacity(0.15))

                    VStack(spacing: 12) {
                        NavigationLink(value: "solo") {
                            Label("Play Solo", systemImage: "person.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(mode.accentColor.gradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: mode.accentColor.opacity(0.4), radius: 8)
                        }
                        .padding(.horizontal)

                        NavigationLink(value: "ranked") {
                            Label("Ranked Match", systemImage: "flag.checkered.2.crossed")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(mode.accentColor, lineWidth: 1.5))
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
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
            .navigationDestination(for: String.self) { dest in
                if dest == "solo" {
                    SoloGameView(mode: mode, difficulty: selectedDifficulty)
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
        Button(action: { if !mode.isComingSoon { onTap() } }) {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(mode.isComingSoon ? AnyShapeStyle(Color.white.opacity(0.15)) : AnyShapeStyle(mode.accentColor.gradient))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Group {
                            if mode.isComingSoon {
                                Image(systemName: "lock.fill").font(.system(size: 26)).foregroundStyle(.white.opacity(0.5))
                            } else {
                                Image(systemName: mode.icon).font(.system(size: 28)).foregroundStyle(.white)
                            }
                        }
                    )
                    .shadow(color: mode.isComingSoon ? .clear : mode.accentColor.opacity(0.5), radius: 8)

                Text(mode.displayName)
                    .font(.headline)
                    .foregroundStyle(mode.isComingSoon ? .white.opacity(0.4) : .white)
                    .multilineTextAlignment(.center)

                if mode.isComingSoon {
                    Text("Coming Soon")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.4))
                } else if let user {
                    RankProgressMiniView(info: user.rank(for: mode), accentColor: mode.accentColor)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Color.white.opacity(mode.isComingSoon ? 0.04 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// Compact rank progress shown inside each tile
struct RankProgressMiniView: View {
    let info: RankInfo
    let accentColor: Color

    private var progress: Double {
        guard let next = RankTier(rawValue: info.tier.rawValue + 1) else { return 1.0 }
        let start = Double(info.tier.pointsRequired)
        let end   = Double(next.pointsRequired)
        return (Double(info.points) - start) / (end - start)
    }

    private var pointsLabel: String {
        if let pts = info.pointsToNextTier {
            return "\(info.points) / \(info.tier.pointsRequired + pts) pts"
        }
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
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentColor)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 5)
                }
            }
            .frame(height: 5)

            Text(pointsLabel)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
