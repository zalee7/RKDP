import SwiftUI

struct ProfileView: View {
    let user: AppUser
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Avatar & name header
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 64, height: 64)
                            .overlay(Text(String(user.username.prefix(1))).font(.largeTitle.bold()).foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.username).font(.title3.bold())
                            Text(user.email).font(.caption).foregroundStyle(.secondary)
                            CoinBadgeView(amount: user.coins)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Per-mode ranks
                Section("Rankings") {
                    ForEach(GameMode.allCases) { mode in
                        let info = user.rank(for: mode)
                        ModeRankRow(mode: mode, info: info)
                    }
                }

                // Stats
                Section("Career Stats") {
                    let totalWins   = user.ranks.values.reduce(0) { $0 + $1.wins }
                    let totalLosses = user.ranks.values.reduce(0) { $0 + $1.losses }
                    StatRow(label: "Total Wins",   value: "\(totalWins)")
                    StatRow(label: "Total Losses", value: "\(totalLosses)")
                    StatRow(label: "Total Points", value: "\(user.totalRankPoints)")
                }

                Section {
                    Button("Sign Out", role: .destructive) { auth.signOut(); dismiss() }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

struct ModeRankRow: View {
    let mode: GameMode
    let info: RankInfo

    var body: some View {
        HStack {
            Image(systemName: mode.icon)
                .frame(width: 28)
                .foregroundStyle(mode.accentColor)
            Text(mode.displayName)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                RankBadgeView(tier: info.tier)
                Text("\(info.points) pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold()
        }
    }
}
