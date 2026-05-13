import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var selectedMode: GameMode?
    @State private var showProfile = false
    @State private var showShop = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let user = auth.user {
                    userHeader(user: user)
                }

                Text("Choose Your Game")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            .navigationTitle("RKDP")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showShop = true } label: {
                        Label("Shop", systemImage: "bag.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(item: $selectedMode) { mode in
                GameModeDetailView(mode: mode)
                    .environmentObject(auth)
            }
            .sheet(isPresented: $showProfile) {
                if let user = auth.user {
                    ProfileView(user: user)
                        .environmentObject(auth)
                }
            }
            .sheet(isPresented: $showShop) {
                if let user = auth.user {
                    ShopView(user: user)
                }
            }
        }
    }

    @ViewBuilder
    private func userHeader(user: AppUser) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 52, height: 52)
                .overlay(Text(String(user.username.prefix(1))).font(.title2.bold()).foregroundStyle(.white))

            VStack(alignment: .leading, spacing: 2) {
                Text(user.username).font(.headline)
                CoinBadgeView(amount: user.coins)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Mode Detail sheet (difficulty + play / ranked picker)

struct GameModeDetailView: View {
    let mode: GameMode
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedDifficulty: Difficulty = .medium
    @State private var destination: NavigationPath = .init()

    var body: some View {
        NavigationStack(path: $destination) {
            VStack(spacing: 24) {
                // Mode icon + name
                VStack(spacing: 8) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(mode.accentColor)
                    Text(mode.displayName).font(.title.bold())
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Difficulty picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty").font(.headline)
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                Divider()

                // Play buttons
                VStack(spacing: 12) {
                    NavigationLink(value: "solo") {
                        Label("Play Solo", systemImage: "person.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(mode.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    NavigationLink(value: "ranked") {
                        Label("Ranked Match", systemImage: "flag.checkered.2.crossed")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(mode.accentColor, lineWidth: 1.5))
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle(mode.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
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

struct GameModeCardView: View {
    let mode: GameMode
    let user: AppUser?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(mode.accentColor.gradient)
                    .frame(width: 72, height: 72)
                    .overlay(Image(systemName: mode.icon).font(.system(size: 30)).foregroundStyle(.white))

                Text(mode.displayName)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Spacer(minLength: 0)

                if let user {
                    RankBadgeView(tier: user.rank(for: mode).tier, showLabel: false)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
