import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        if auth.isSignedIn {
            #if PP_RANKED_SANDBOX
            RankedSandboxView()
            #elseif PP_SOCIAL_SANDBOX
            if let user = auth.user {
                FriendsView(user: user)
                    .safeAreaInset(edge: .bottom) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Friend / Party Test").font(.caption.bold())
                                Text("puzzlepartytest").font(.caption2)
                            }
                            Spacer()
                            Text("\(user.coins) coins").font(.caption.monospacedDigit())
                            Button("Sign Out") { auth.signOut() }.font(.caption.bold())
                        }
                        .padding(12)
                        .background(.regularMaterial)
                    }
            }
            #else
            MainTabView()
            #endif
        } else {
            LoginView()
        }
    }
}

#if PP_RANKED_SANDBOX
private struct RankedSandboxView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var casual = false
    @State private var selectedMode: GameMode?
    @State private var showFriends = false

    var body: some View {
        NavigationStack {
            if let user = auth.user {
                List {
                    Section {
                        LabeledContent("Firebase", value: "puzzlepartytest")
                        LabeledContent("Player", value: user.username)
                        LabeledContent("Coins", value: String(user.coins))
                        Button("Refresh Account", systemImage: "arrow.clockwise") {
                            Task { await auth.refreshUser() }
                        }
                    }
                    Section {
                        Picker("Match", selection: $casual) {
                            Text("Ranked").tag(false)
                            Text("Casual").tag(true)
                        }
                        .pickerStyle(.segmented)
                        ForEach(GameMode.allCases, id: \.self) { mode in
                            Button { selectedMode = mode } label: {
                                HStack {
                                    Text(mode.displayName)
                                    Spacer()
                                    if !casual {
                                        Text("\(user.rank(for: mode).points) pts")
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                }
                            }
                        }
                    }
                    Section {
                        Button("Friends and Parties", systemImage: "person.2.fill") { showFriends = true }
                        Button("Sign Out", role: .destructive) { auth.signOut() }
                    }
                }
                .navigationTitle("Online Test")
                .fullScreenCover(item: $selectedMode, onDismiss: {
                    Task { await auth.refreshUser() }
                }) { mode in
                    NavigationStack {
                        MatchmakingView(user: user, mode: mode, difficulty: mode.onlinePresetDifficulty,
                            entryKind: casual ? .casual : .ranked)
                    }
                }
                .sheet(isPresented: $showFriends, onDismiss: {
                    Task { await auth.refreshUser() }
                }) {
                    FriendsView(user: user)
                }
            } else {
                ProgressView("Loading test account")
            }
        }
    }
}
#endif

struct MainTabView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var partyLink: PartyDeepLink?
    @State private var selectedTab: MainTab = .play

    var body: some View {
        selectedTabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                MainBottomBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
        .onReceive(NotificationCenter.default.publisher(for: .openFriendsTabRequested)) { _ in
            switchTab(.friends)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDailyTabRequested)) { _ in
            switchTab(.daily)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openEventsTabRequested)) { _ in
            switchTab(.daily)
        }
        .onOpenURL { url in
            guard let code = PartyJoinLink.code(from: url) else { return }
            partyLink = PartyDeepLink(code: code)
        }
        .onReceive(NotificationCenter.default.publisher(for: .partyJoinRequested)) { _ in
            guard let code = PartyJoinLink.consumePending() else { return }
            partyLink = PartyDeepLink(code: code)
        }
        .onAppear {
            guard let code = PartyJoinLink.consumePending() else { return }
            partyLink = PartyDeepLink(code: code)
        }
        .fullScreenCover(item: $partyLink) { link in
            if let user = auth.user {
                NavigationStack {
                    PartyRoomView(
                        user: user,
                        mode: .colorLink,
                        difficulty: .expert,
                        autoCreate: false,
                        initialJoinCode: link.code
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .play:
            HomeView()
        case .friends:
            if let user = auth.user {
                FriendsView(user: user)
            } else {
                signedInUserLoadingView
            }
        case .daily:
            if let user = auth.user {
                TournamentView(user: user)
            } else {
                signedInUserLoadingView
            }
        case .profile:
            if let user = auth.user {
                ProfileView(user: user)
            } else {
                signedInUserLoadingView
            }
        }
    }

    private var signedInUserLoadingView: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()
            ProgressView()
                .tint(AppTheme.accentBright)
        }
    }

    private func switchTab(_ tab: MainTab) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            selectedTab = tab
        }
    }
}

private enum MainTab: Hashable, CaseIterable {
    case play
    case friends
    case daily
    case profile

    var title: String {
        switch self {
        case .play: return "Play"
        case .friends: return "Friends"
        case .daily: return "Daily"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .play: return "gamecontroller.fill"
        case .friends: return "person.2.fill"
        case .daily: return "calendar.badge.checkmark"
        case .profile: return "person.fill"
        }
    }
}

private struct MainBottomBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    let selected = selectedTab == tab
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: .bold))
                            .symbolEffect(.bounce, value: selected)
                        Text(tab.title)
                            .font(.caption.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(selected ? AppTheme.hotPink : AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background {
                        if selected {
                            Capsule()
                                .fill(AppTheme.hotPink.opacity(0.16))
                                .overlay(Capsule().stroke(AppTheme.hotPink.opacity(0.32), lineWidth: 1))
                        }
                    }
                    .clipShape(Capsule())
                    .scaleEffect(selected ? 1.04 : 1.0)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(8)
        .background {
            Capsule()
                .fill(AppTheme.cardBackground.opacity(0.92))
                .overlay(
                    LinearGradient(
                        colors: [
                            AppTheme.hotPink.opacity(0.20),
                            AppTheme.crownGold.opacity(0.14),
                            AppTheme.teal.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(Capsule())
                )
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.cardBorder.opacity(0.95), lineWidth: 1.2))
        .shadow(color: AppTheme.hotPink.opacity(0.18), radius: 12, x: 0, y: 6)
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: selectedTab)
    }
}

private struct PartyDeepLink: Identifiable {
    let id = UUID()
    let code: String
}

extension Notification.Name {
    static let openFriendsTabRequested = Notification.Name("openFriendsTabRequested")
    static let openDailyTabRequested = Notification.Name("openDailyTabRequested")
    static let openEventsTabRequested = Notification.Name("openEventsTabRequested")
}
