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

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Play", systemImage: "gamecontroller.fill") }

            LeaderboardView()
                .tabItem { Label("Leaderboard", systemImage: "chart.bar.fill") }

            if let user = auth.user {
                ProfileView(user: user)
                    .tabItem { Label("Profile", systemImage: "person.fill") }
            }
        }
    }
}
