import SwiftUI

struct ProfileView: View {
    let user: AppUser
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var shop: ShopViewModel

    init(user: AppUser) {
        self.user = user
        _shop = StateObject(wrappedValue: ShopViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Avatar header card
                        VStack(spacing: 12) {
                            Circle()
                                .fill(AppTheme.brandGradient)
                                .frame(width: 72, height: 72)
                                .overlay(Text(String(user.username.prefix(1))).font(.largeTitle.bold()).foregroundStyle(.white))
                                .shadow(color: AppTheme.accent.opacity(0.6), radius: 12)

                            Text(user.username).font(.title2.bold()).foregroundStyle(AppTheme.textPrimary)
                            Text(shop.equippedTitleName)
                                .font(.subheadline.italic())
                                .foregroundStyle(AppTheme.accentBright)
                            Text(user.email).font(.caption).foregroundStyle(AppTheme.textSecondary)
                            CoinBadgeView(amount: user.coins)
                        }
                        .padding(.top, 24)

                        // Per-mode ranks
                        sectionCard(title: "Rankings") {
                            VStack(spacing: 10) {
                                ForEach(GameMode.allCases) { mode in
                                    ModeRankRow(mode: mode, info: user.rank(for: mode))
                                    if mode != GameMode.allCases.last {
                                        Divider().overlay(AppTheme.cardBorder)
                                    }
                                }
                            }
                        }

                        // Career stats
                        sectionCard(title: "Career Stats") {
                            let totalWins   = user.ranks.values.reduce(0) { $0 + $1.wins }
                            let totalLosses = user.ranks.values.reduce(0) { $0 + $1.losses }
                            VStack(spacing: 8) {
                                StatRow(label: "Total Wins",   value: "\(totalWins)")
                                StatRow(label: "Total Losses", value: "\(totalLosses)")
                                StatRow(label: "Total Points", value: "\(user.totalRankPoints)")
                            }
                        }

                        // Sign out
                        Button(role: .destructive) {
                            auth.signOut(); dismiss()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.3), lineWidth: 1))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(AppTheme.accentBright)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(AppTheme.accentBright)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }
}

struct ModeRankRow: View {
    let mode: GameMode
    let info: RankInfo

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.modeGradient(mode))
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: mode.icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white))

            Text(mode.displayName).foregroundStyle(AppTheme.textPrimary)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                RankBadgeView(tier: info.displayTier, division: info.division, iconSize: 22, labelFont: .subheadline.bold())
                RankDivisionProgressView(info: info, height: 4, spacing: 3)
                    .frame(width: 112)
                Text(info.nextRankStepText).font(.caption).foregroundStyle(AppTheme.textSecondary)
                if let best = info.bestScore {
                    Text("Best \(best) pts").font(.system(size: 10)).foregroundStyle(AppTheme.accentBright)
                } else if let best = info.bestTime {
                    Text("Best \(best / 60):\(String(format: "%02d", best % 60))")
                        .font(.system(size: 10)).foregroundStyle(AppTheme.accentBright)
                }
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value).bold().foregroundStyle(AppTheme.textPrimary)
        }
        .font(.subheadline)
    }
}
