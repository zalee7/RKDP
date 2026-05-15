import SwiftUI

struct LeaderboardView: View {
    @StateObject private var vm = RankViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Mode picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(GameMode.allCases) { mode in
                                Button {
                                    Task { await vm.loadLeaderboard(mode: mode) }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: mode.icon)
                                        Text(mode.displayName)
                                    }
                                    .font(.subheadline.weight(vm.selectedMode == mode ? .bold : .regular))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(vm.selectedMode == mode ? AppTheme.brandGradient : LinearGradient(colors: [AppTheme.cardBackground], startPoint: .leading, endPoint: .trailing))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(vm.selectedMode == mode ? Color.clear : AppTheme.cardBorder, lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }

                    Divider().overlay(AppTheme.cardBorder)

                    if vm.isLoading {
                        Spacer()
                        ProgressView().tint(AppTheme.accentBright)
                        Spacer()
                    } else {
                        List {
                            ForEach(Array(vm.leaderboard.enumerated()), id: \.element.id) { idx, entry in
                                LeaderboardRowView(rank: idx + 1, entry: entry)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparatorTint(AppTheme.cardBorder)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }

                    if let err = vm.errorMessage {
                        Text(err).foregroundStyle(.red).padding()
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task { await vm.loadLeaderboard(mode: .sudoku) }
        }
    }
}

struct LeaderboardRowView: View {
    let rank: Int
    let entry: LeaderboardEntry

    private var rankBadge: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(rankBadge)
                .font(rank <= 3 ? .title2 : .subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 36)

            Circle()
                .fill(AppTheme.brandGradient)
                .frame(width: 40, height: 40)
                .overlay(Text(String(entry.username.prefix(1))).font(.headline).foregroundStyle(.white))
                .shadow(color: AppTheme.accent.opacity(0.4), radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username).font(.headline).foregroundStyle(AppTheme.textPrimary)
                if let title = entry.equippedTitle {
                    Text(title).font(.caption.italic()).foregroundStyle(AppTheme.accentBright)
                }
                HStack(spacing: 4) {
                    RankBadgeView(tier: entry.rankTier)
                    Text("·").foregroundStyle(AppTheme.textSecondary)
                    Text("\(entry.wins)W").font(.caption).foregroundStyle(.green)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.rankPoints) pts").font(.subheadline.bold()).foregroundStyle(AppTheme.textPrimary)
                if let best = entry.bestTime {
                    Text(String(format: "%d:%02d", best/60, best%60))
                        .font(.caption).foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
