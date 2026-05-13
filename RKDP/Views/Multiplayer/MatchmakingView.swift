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
            case .matchFound(let sessionID):
                matchFoundView(sessionID: sessionID)
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

    private func matchFoundView(sessionID: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.2.fill").font(.system(size: 48)).foregroundStyle(mode.accentColor)
            Text("Match Found!").font(.largeTitle.bold())
            Text("Preparing puzzle…").foregroundStyle(.secondary)
            ProgressView()
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

            // Game board
            SoloGameView(mode: session.mode, difficulty: session.difficulty)

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
        return VStack(spacing: 20) {
            Spacer()
            Text(isWinner ? "Victory! 🏆" : "Defeat 😔")
                .font(.largeTitle.bold())
                .foregroundStyle(isWinner ? .yellow : .secondary)

            let delta = session.rankPointsDelta(for: user.id)
            VStack(spacing: 8) {
                Text("Rank Points: \(delta >= 0 ? "+" : "")\(delta)")
                    .font(.title3.bold())
                    .foregroundStyle(delta >= 0 ? .green : .red)
                if let wager = vm.selectedWager {
                    let coinDelta = isWinner ? wager.amount : -wager.amount
                    Text("Coins: \(coinDelta >= 0 ? "+" : "")\(coinDelta)")
                        .font(.headline)
                        .foregroundStyle(coinDelta >= 0 ? .green : .red)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button { vm.reset() } label: {
                Text("Play Again")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(mode.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            Button("Back to Home") { dismiss() }
                .foregroundStyle(.secondary)
            Spacer()
        }
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
