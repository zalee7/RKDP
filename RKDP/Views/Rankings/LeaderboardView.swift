import SwiftUI

struct LeaderboardView: View {
    @StateObject private var vm = RankViewModel()
    @State private var selectedMode: GameMode = .sudoku

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(GameMode.allCases) { mode in
                            Button {
                                Task { await vm.loadLeaderboard(mode: mode) }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: mode.icon)
                                    Text(mode.displayName)
                                }
                                .font(.subheadline.weight(vm.selectedMode == mode ? .bold : .regular))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(vm.selectedMode == mode ? mode.accentColor : Color(.secondarySystemBackground))
                                .foregroundStyle(vm.selectedMode == mode ? .white : .primary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }

                Divider()

                if vm.isLoading {
                    ProgressView().padding(.top, 40)
                } else {
                    List {
                        ForEach(Array(vm.leaderboard.enumerated()), id: \.element.id) { idx, entry in
                            LeaderboardRowView(rank: idx + 1, entry: entry)
                        }
                    }
                    .listStyle(.plain)
                }

                if let err = vm.errorMessage {
                    Text(err).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Leaderboard")
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
                .frame(width: 36)

            Circle()
                .fill(entry.rankTier.color.gradient)
                .frame(width: 40, height: 40)
                .overlay(Text(String(entry.username.prefix(1))).font(.headline).foregroundStyle(.white))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username).font(.headline)
                if let title = entry.equippedTitle {
                    Text(title)
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    RankBadgeView(tier: entry.rankTier)
                    Text("·").foregroundStyle(.secondary)
                    Text("\(entry.wins)W").font(.caption).foregroundStyle(.green)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.rankPoints) pts").font(.subheadline.bold())
                if let best = entry.bestTime {
                    Text(String(format: "Best: %d:%02d", best/60, best%60))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
