import SwiftUI

struct MatchmakingView: View {
    let user: AppUser
    let mode: GameMode
    let difficulty: Difficulty

    @StateObject private var vm = MultiplayerViewModel()
    @State private var selectedWager: WagerTier?
    @Environment(\.dismiss) var dismiss

    private var wagerOptions: [WagerTier] {
        Wager.options(for: user.rank(for: mode).tier)
    }

    var body: some View {
        VStack(spacing: 24) {
            switch vm.state {
            case .idle:
                wagerPicker
            case .searching:
                searchingView
            case .matchFound(let session):
                matchFoundView(session: session)
            case .inMatch(let session):
                inMatchView(session: session)
            case .finished(let session):
                resultView(session: session)
            case .error(let msg):
                errorView(msg)
            }
        }
        .navigationTitle("Ranked Match")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { vm.reset() }
    }

    // MARK: - Wager picker

    private var wagerPicker: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(mode.accentColor)
                    Text("\(mode.displayName) · \(difficulty.displayName)")
                        .font(.headline)
                    HStack {
                        Text("Your balance:")
                        CoinBadgeView(amount: user.coins)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Text("Choose Your Wager").font(.title3.bold())

                VStack(spacing: 12) {
                    ForEach(wagerOptions) { option in
                        WagerOptionRow(
                            option: option,
                            isSelected: selectedWager?.id == option.id,
                            canAfford: user.coins >= option.amount
                        ) {
                            selectedWager = option
                        }
                    }
                }
                .padding(.horizontal)

                if let wager = selectedWager {
                    VStack(spacing: 6) {
                        Text("Winner takes: \(wager.amount * 2) coins").font(.subheadline.bold()).foregroundStyle(.green)
                        Text("Both players wager \(wager.amount) coins each").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                Button {
                    guard let wager = selectedWager else { return }
                    Task { await vm.startSearch(user: user, mode: mode, difficulty: difficulty, wager: wager) }
                } label: {
                    Text("Find Match")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedWager != nil ? mode.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(selectedWager == nil)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Searching

    private var searchingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text("Finding a match…")
                .font(.title3.bold())
            if let wager = vm.selectedWager {
                Text("Wager: \(wager.amount) coins").foregroundStyle(.secondary)
            }
            Button("Cancel") { Task { await vm.cancelSearch() } }
                .foregroundStyle(.red)
            Spacer()
        }
    }

    // MARK: - Match found

    private func matchFoundView(session: GameSession) -> some View {
        let opponent = session.players.first { $0.userID != user.id }
        let oppUser  = vm.opponentUser

        return VStack(spacing: 24) {
            Spacer()

            Text("Match Found!")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.textPrimary)

            // Opponent card
            VStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.brandGradient)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text(String((opponent?.username ?? "?").prefix(1)))
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    )
                    .shadow(color: AppTheme.accent.opacity(0.5), radius: 10)

                VStack(spacing: 4) {
                    Text(opponent?.username ?? "Opponent")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)

                    if let title = oppUser?.cosmetics.equippedTitle,
                       let item = CosmeticCatalog.allTitles.first(where: { $0.id == title }) {
                        Text(item.name)
                            .font(.caption.italic())
                            .foregroundStyle(AppTheme.accentBright)
                    }

                    if let opp = opponent {
                        let oppRank = RankInfo(points: opp.rankPoints, tier: opp.rankTier,
                                              wins: 0, losses: 0, bestTime: nil, bestScore: nil)
                        Text(oppRank.fullDisplayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(opp.rankTier.color)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.cardBorder, lineWidth: 1))
            .padding(.horizontal)

            // Countdown ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: CGFloat(vm.matchCountdown) / 5.0)
                    .stroke(mode.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: vm.matchCountdown)
                Text("\(vm.matchCountdown)")
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Text("Game starts automatically…")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                Task { await vm.abortMatchFound(session: session) }
            } label: {
                Label("Abort (−1 coin)", systemImage: "xmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
    }

    // MARK: - In match

    private func inMatchView(session: GameSession) -> some View {
        VStack(spacing: 0) {
            // Opponent status bar
            HStack {
                Label("Opponent", systemImage: "person.fill")
                Spacer()
                if let oppFinish = vm.finishTimes.first(where: { $0.key != user.id })?.value {
                    Label("Finished \(oppFinish/60)m\(oppFinish%60)s", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("In progress…").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))

            // Game board — seed ensures both players get identical puzzle
            SoloGameView(mode: session.mode, difficulty: session.difficulty, user: vm.user, seed: session.seed)

            // Submit button (normally triggered by game completion)
            Button {
                Task { await vm.submitFinish(sessionID: session.id) }
            } label: {
                Label("Submit Solution", systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }

    // MARK: - Result

    private func resultView(session: GameSession) -> some View {
        let isWinner = session.winnerID == user.id
        let isDraw   = session.winnerID == nil
        let myPlayer    = session.players.first { $0.userID == user.id }
        let oppPlayer   = session.players.first { $0.userID != user.id }
        let divBonus    = isWinner && (oppPlayer?.rankPoints ?? 0) > (myPlayer?.rankPoints ?? 0) ? 5 : 0
        let base        = isDraw ? 5 : (isWinner ? 30 + divBonus : -15)
        let rankDelta   = Int(Double(base) * session.difficulty.pointMultiplier)

        let myTime       = vm.finishTimes[user.id]
        let opponentID   = session.players.first(where: { $0.userID != user.id })?.userID ?? ""
        let opponentTime = vm.finishTimes[opponentID]

        return VStack(spacing: 20) {
            Spacer()
            Text(isDraw ? "Draw 🤝" : (isWinner ? "Victory! 🏆" : "Defeat 😔"))
                .font(.largeTitle.bold())
                .foregroundStyle(isDraw ? .orange : (isWinner ? .yellow : .secondary))

            Text(mode.winConditionText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Performance breakdown
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    performanceColumn(label: "You", time: myTime, highlight: isWinner)
                    Divider().frame(height: 60)
                    performanceColumn(label: "Opponent", time: opponentTime, highlight: !isWinner && !isDraw)
                }
                .padding(.vertical, 10)

                Divider()

                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("Rank Points").font(.caption).foregroundStyle(.secondary)
                        Text("\(rankDelta >= 0 ? "+" : "")\(rankDelta)")
                            .font(.title3.bold())
                            .foregroundStyle(rankDelta >= 0 ? .green : .red)
                        if divBonus > 0 {
                            Text("↑ Higher Division Bonus")
                                .font(.system(size: 10))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if let wager = vm.selectedWager {
                        Divider().frame(height: 40)
                        let coinDelta = isDraw ? 0 : (isWinner ? wager.amount : -wager.amount)
                        VStack(spacing: 2) {
                            Text("Coins").font(.caption).foregroundStyle(.secondary)
                            Text("\(coinDelta >= 0 ? "+" : "")\(coinDelta)")
                                .font(.title3.bold())
                                .foregroundStyle(coinDelta >= 0 ? .green : .red)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Button { vm.reset() } label: {
                Text("Play Again")
                    .frame(maxWidth: .infinity).padding()
                    .background(mode.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            Button("Back to Home") { dismiss() }.foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func performanceColumn(label: String, time: Int?, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            if let t = time {
                Text("\(t / 60):\(String(format: "%02d", t % 60))")
                    .font(.title2.bold())
                    .foregroundStyle(highlight ? .green : .primary)
                Text("finished").font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                Text("—").font(.title2.bold()).foregroundStyle(.secondary)
                Text("unfinished").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(.red)
            Text("Something went wrong").font(.title3.bold())
            Text(msg).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry") { vm.reset() }
        }
        .padding()
    }
}

// MARK: - Wager option row

struct WagerOptionRow: View {
    let option: WagerTier
    let isSelected: Bool
    let canAfford: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label).font(.headline)
                    Text("\(option.amount) coins").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if !canAfford {
                    Text("Insufficient coins").font(.caption).foregroundStyle(.red)
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            .padding()
            .background(isSelected ? Color.green.opacity(0.1) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.green : Color.clear, lineWidth: 2))
        }
        .disabled(!canAfford)
        .opacity(canAfford ? 1 : 0.4)
        .buttonStyle(.plain)
    }
}
