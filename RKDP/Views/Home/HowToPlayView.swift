import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground
                    .ignoresSafeArea()

                TabView(selection: $selectedTab) {
                    ForEach(GameMode.allCases.indices, id: \.self) { index in
                        gameGuide(for: GameMode.allCases[index]).tag(index)
                    }
                    RankGuideView().tag(GameMode.allCases.count)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .navigationTitle("How to Play")
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
    private func gameGuide(for mode: GameMode) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Icon header
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.modeGradient(mode))
                        .frame(width: 80, height: 80)
                        .overlay(Image(systemName: mode.icon).font(.system(size: 36)).foregroundStyle(AppTheme.textPrimary))
                        .shadow(color: AppTheme.modeShadow(mode), radius: 12)
                    Text(mode.displayName)
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.top, 20)

                // Rules
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(rulesFor(mode), id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.modeAccent(mode))
                            ForEach(section.bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(AppTheme.modeAccent(mode))
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    Text(bullet)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal)

                // Difficulty breakdown
                VStack(alignment: .leading, spacing: 10) {
                    Text("Difficulties")
                        .font(.headline)
                        .foregroundStyle(AppTheme.modeAccent(mode))
                    ForEach(Difficulty.allCases, id: \.self) { d in
                        HStack {
                            Text(mode.difficultyLabel(d)).font(.subheadline.bold()).foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text("\(String(format: "%.1f", mode.pointMultiplier(for: d)))x ranked points").font(.caption).foregroundStyle(AppTheme.textMuted)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(AppTheme.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.controlBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }

    private struct RuleSection { let title: String; let bullets: [String] }

    private func rulesFor(_ mode: GameMode) -> [RuleSection] {
        switch mode {
        case .sudoku:
            return [
                RuleSection(title: "Objective", bullets: [
                    "Fill every cell in the 9×9 grid with a digit from 1 to 9.",
                    "Each row must contain all nine digits with no repeats.",
                    "Each column must contain all nine digits with no repeats.",
                    "Each 3×3 box must contain all nine digits with no repeats.",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Tap a cell to select it, then tap a number on the pad.",
                    "Use Notes mode (pencil icon) to mark possible candidates.",
                    "Tap the lightbulb to reveal a hint for the selected cell.",
                    "Tap Erase to clear a cell.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players receive the same generated puzzle.",
                    "Completion beats incomplete boards.",
                    "If both complete, faster time wins; if neither finishes, valid progress decides, then time.",
                ]),
            ]
        case .minesweeper:
            return [
                RuleSection(title: "Objective", bullets: [
                    "Uncover every safe cell without triggering a mine.",
                    "Numbers show how many mines touch that cell's 8 neighbours.",
                    "An empty reveal cascades automatically to adjacent empty cells.",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Tap a hidden cell to reveal it.",
                    "Long-press (or toggle flag mode) to plant or remove a flag.",
                    "Tap a numbered cell that already has the right flag count to chord-reveal its remaining neighbours.",
                    "First tap is always safe — mines are placed after it.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players get identically seeded boards.",
                    "Hitting a mine loses against an opponent who stays safe.",
                    "If both stay safe, clears win; safe cells and time break remaining ties.",
                ]),
            ]
        case .colorLink:
            return [
                RuleSection(title: "Objective", bullets: [
                    "Connect each pair of matching color endpoints.",
                    "Paths cannot overlap or pass through another color's endpoint.",
                    "The strongest board fills every cell with a valid color path.",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Drag from a color endpoint to draw that color's path.",
                    "Drag through adjacent cells without crossing another color.",
                    "Drag back over an earlier cell in the same path to rewind to that point.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players get the same seeded board.",
                    "Full board completion beats incomplete boards.",
                    "If neither player finishes, board fill wins before solved pair count, then time.",
                ]),
            ]
        case .gridlock:
            return [
                RuleSection(title: "Objective", bullets: [
                    "Recreate the target color pattern on your playable grid.",
                    "Every cell is filled; the challenge is rotating rows and columns into the target layout.",
                    "The puzzle ends automatically when your grid exactly matches the target.",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Drag a row sideways to rotate that row.",
                    "Drag a column up or down to rotate that column.",
                    "Each whole-cell shift counts as one move.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players receive the same target and scrambled board.",
                    "Completion wins; if both finish, fewer moves wins, then time.",
                    "If neither player finishes, higher pattern-match percent wins, then fewer moves and time.",
                ]),
            ]
        case .anagram:
            return [
                RuleSection(title: "Objective", bullets: [
                    "Use the letter set to make as many valid words as possible.",
                    "Longer words score more points.",
                    "The round ends when the 1:00 timer expires.",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Tap letter tiles to build a word.",
                    "Tap a placed tile to return it to the bank.",
                    "Use Shuffle to randomize the bank order for a fresh look.",
                    "Submit valid words to add them to your score.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players get the same seeded letters.",
                    "Highest score when the 1:00 timer ends wins.",
                    "Ties use word count, then longest word.",
                ]),
            ]
        case .wordHunt:
            return [
                RuleSection(title: "Objective", bullets: [
                    "Find as many valid words as you can in the letter grid.",
                    "Difficulty changes only the board size: 4×4, 5×5, 6×6, or 7×7.",
                    "Words must be 3 or more letters and traced through adjacent tiles.",
                    "Tiles can only be used once per word; diagonal connections count, but traced paths cannot be undone by dragging backward.",
                    "Longer words score more points — a 7-letter word earns 5 pts.",
                    "The round ends when the 1:15 timer expires.",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Drag your finger across adjacent tiles to trace a word.",
                    "Release to submit — valid words are added to your list.",
                    "The current path glows as you trace it; lift your finger to reset if you want a different route.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players get the same seeded grid for the selected board size.",
                    "Highest score when the 1:15 timer ends wins.",
                    "Ties use word count, then longest word.",
                ]),
            ]
        case .hangman:
            return [
                RuleSection(title: "Objective", bullets: [
                    "Guess letters to reveal the category word and rescue the puzzle piece.",
                    "Difficulty changes word length: 5 letters, 6 letters, 7 letters, or 8+ letters.",
                    "You get 6 wrong letters before the rescue fails.",
                    "Repeated guesses do not raise the lava.",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Tap letters on the keyboard to guess.",
                    "Correct letters fill every matching slot in the word.",
                    "Wrong letters raise the lava meter and appear in the wrong letters row.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players get the same three categories, starter letters, and target words.",
                    "Online Lava Rescue is best-of-3: first to rescue 2 words wins.",
                    "If nobody clinches, solved rounds win; wrong letters and time break ties.",
                ]),
            ]
        case .wordle:
            return [
                RuleSection(title: "Objective", bullets: [
                    "Guess the secret 5-letter word within your allotted attempts.",
                    "Each guess must be a valid 5-letter word — tap ENTER to submit.",
                    "Solo mode is one word: solve it before your guesses run out.",
                ]),
                RuleSection(title: "Color Feedback", bullets: [
                    "🟩 Green — correct letter in the correct position.",
                    "🟨 Yellow — the letter is in the word but in the wrong spot.",
                    "⬛ Gray — the letter does not appear in the word at all.",
                    "The keyboard updates after each guess so you can track letters.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players receive the same shared words in a best-of-3 match.",
                    "Solving 2 rounds wins immediately; guesses and time break ties if both finish.",
                    "Difficulty controls how many guesses you get: 6 guesses is the standard 1.0× game.",
                ]),
            ]
        }
    }
}

// MARK: - Rank guide page

struct RankGuideView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.crownGold)
                        .padding(.top, 24)
                    Text("Rank System")
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Each game mode has its own independent rank.\nWin matches to climb divisions, then promote tiers. Ranked coin wagers are fixed by tier.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 10) {
                    ForEach(RankTier.allCases, id: \.self) { tier in
                        RankTierRow(tier: tier)
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("How Ranked Works")
                        .font(.headline)
                        .foregroundStyle(AppTheme.crownGold)

                    infoRow(icon: "checkmark.circle.fill", color: .green,  text: "Win: +30 pts (×difficulty multiplier)")
                    infoRow(icon: "xmark.circle.fill",    color: .red,    text: "Loss: −15 pts (×difficulty multiplier)")
                    infoRow(icon: "equal.circle.fill",    color: .blue,   text: "Draw: +5 pts and no coin change")
                    infoRow(icon: "arrow.left.circle.fill", color: .orange, text: "Abandon: −20 pts and a ranked loss")
                    coinInfoRow(text: "Tier wager: one fixed coin stake for your current rank tier. Win +wager, loss -wager.")
                    infoRow(icon: "cpu.fill", color: .yellow, text: "Bronze queues may fill with a Training Bot after a short wait. Bot matches use limited ranked rewards.")
                    infoRow(icon: "rectangle.split.3x1.fill", color: .purple, text: "Each tier has III, II, and I divisions. Fill Division I to promote.")
                    infoRow(icon: "clock.fill",           color: .purple, text: "Difficulty and opponent division set rank points; time is a tie-breaker in some modes")
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.subheadline).foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func coinInfoRow(text: String) -> some View {
        HStack(spacing: 10) {
            CoinIconView(size: 19)
            Text(text).font(.subheadline).foregroundStyle(AppTheme.textSecondary)
        }
    }
}

struct RankTierRow: View {
    let tier: RankTier

    private var nextPoints: Int? {
        tier.nextTier?.pointsRequired
    }

    private var tierRangeText: String {
        "\(tier.pointsRequired)\(nextPoints.map { " – \($0 - 1)" } ?? "+") pts"
    }

    private var sampleInfo: RankInfo {
        RankInfo(points: tier.pointsRequired, tier: tier, wins: 0, losses: 0, bestTime: nil, bestScore: nil)
    }

    var body: some View {
        HStack(spacing: 14) {
            RankIconView(tier: tier, division: .one, size: 34)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(tier.displayName)
                        .font(.headline)
                        .foregroundStyle(tier.color)
                    Text(tierRangeText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
                VStack(spacing: 4) {
                    RankDivisionProgressView(info: sampleInfo, height: 4, spacing: 4, showLabels: true)
                    HStack(spacing: 0) {
                        ForEach(RankDivision.progression, id: \.self) { division in
                            Text(tier.divisionRangeLabel(for: division))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .frame(width: 156)
            }

            Spacer()

            if let amount = Wager.options(for: tier).first?.amount {
                HStack(spacing: 5) {
                    CoinIconView(size: 16)
                    Text("\(amount)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tier.color.opacity(0.45), lineWidth: 1))
    }
}
