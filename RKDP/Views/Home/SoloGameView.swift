import SwiftUI

// Routes to the correct game view. In multiplayer, pass seed so both players get identical puzzles.
struct SoloGameView: View {
    let mode: GameMode
    let difficulty: Difficulty
    let user: AppUser?
    var sessionID: String? = nil
    var seed: Int? = nil
    var puzzleData: String? = nil
    var onMatchResult: (MatchPlayerResult) -> Void = { _ in }
    var onSoloResult: (SoloGameResult) -> Void = { _ in }
    var onPlayAgain: () -> Void = {}
    var onChangeDifficulty: () -> Void = {}
    var onTryRanked: () -> Void = {}
    var onHome: () -> Void = {}

    @State private var runID = UUID()

    private var replay: () -> Void {
        {
            runID = UUID()
            onPlayAgain()
        }
    }

    var body: some View {
        Group {
            switch mode {
            case .sudoku:
                SudokuView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: seed, onMatchResult: onMatchResult, onSoloResult: onSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .minesweeper:
                MinesweeperView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: seed, onMatchResult: onMatchResult, onSoloResult: onSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .colorLink:
                ColorLinkView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: seed, onMatchResult: onMatchResult, onSoloResult: onSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .gridlock:
                GridlockView(difficulty: difficulty, userID: user?.id, sessionID: sessionID, seed: seed, onMatchResult: onMatchResult, onSoloResult: onSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .anagram:
                AnagramView(difficulty: difficulty, user: user, sessionID: sessionID, seed: seed, puzzleData: puzzleData, onMatchResult: onMatchResult, onSoloResult: onSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .wordHunt:
                WordHuntView(difficulty: difficulty, user: user, sessionID: sessionID, seed: seed, puzzleData: puzzleData, onMatchResult: onMatchResult, onSoloResult: onSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .wordle:
                WordleView(difficulty: difficulty, user: user, sessionID: sessionID, seed: seed, puzzleData: puzzleData, onMatchResult: onMatchResult, onSoloResult: onSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            case .hangman:
                HangmanView(difficulty: difficulty, user: user, sessionID: sessionID, seed: seed, puzzleData: puzzleData, onMatchResult: onMatchResult, onSoloResult: onSoloResult, onPlayAgain: replay, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            }
        }
        .id(runID)
        .environment(\.boardCosmetics, user?.cosmetics ?? .default)
    }
}

struct SoloResultOverlay: View {
    let result: SoloGameResult
    let onPlayAgain: () -> Void
    let onChangeDifficulty: () -> Void
    let onTryRanked: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            AppTheme.royalBlue.opacity(0.42).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppTheme.modeGradient(result.mode))
                        .frame(width: 88, height: 88)
                        .overlay(Image(systemName: result.completed ? "checkmark.seal.fill" : "flag.fill").font(.system(size: 42)).foregroundStyle(.white))
                        .shadow(color: AppTheme.modeShadow(result.mode), radius: 18)

                    VStack(spacing: 6) {
                        Text(result.title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(result.message)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(result.stats) { stat in
                            VStack(spacing: 3) {
                                Text(stat.value)
                                    .font(.title2.bold())
                                    .foregroundStyle(AppTheme.accentBright)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Text(stat.label)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                        }
                    }

                    if !result.details.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(result.details.prefix(8), id: \.self) { detail in
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(spacing: 10) {
                        resultButton("Play Again", icon: "arrow.clockwise", action: onPlayAgain, filled: true)
                        resultButton("Change Difficulty", icon: "slider.horizontal.3", action: onChangeDifficulty)
                        resultButton("Try Ranked", icon: "flag.checkered.2.crossed", action: onTryRanked)
                        resultButton("Home", icon: "house.fill", action: onHome)
                    }
                }
                .padding(22)
            }
            .background(AppTheme.backgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(AppTheme.cardBorder, lineWidth: 1))
            .padding(18)
        }
        .transition(.opacity)
    }

    private func resultButton(_ title: String, icon: String, action: @escaping () -> Void, filled: Bool = false) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(filled ? AnyShapeStyle(AppTheme.modeGradient(result.mode)) : AnyShapeStyle(AppTheme.controlBackground))
                .foregroundStyle(filled ? AppTheme.textOnColor : AppTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(filled ? Color.clear : AppTheme.controlBorder, lineWidth: filled ? 0 : 1.5))
        }
    }
}

func formattedTime(_ seconds: Int) -> String {
    "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}
