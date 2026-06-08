import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        if auth.isSignedIn {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var partyLink: PartyDeepLink?

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Play", systemImage: "gamecontroller.fill") }

            if let user = auth.user {
                FriendsView(user: user)
                    .tabItem { Label("Friends", systemImage: "person.2.fill") }
            }

            if let user = auth.user {
                TournamentView(user: user)
                    .tabItem { Label("Events", systemImage: "trophy.fill") }
            }

            LeaderboardView()
                .tabItem { Label("Leaderboard", systemImage: "chart.bar.fill") }

            if let user = auth.user {
                ProfileView(user: user)
                    .tabItem { Label("Profile", systemImage: "person.fill") }
            }
        }
        .tint(AppTheme.accentBright)
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
}

private struct PartyDeepLink: Identifiable {
    let id = UUID()
    let code: String
}
