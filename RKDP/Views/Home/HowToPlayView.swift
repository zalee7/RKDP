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

                // Difficulty choices belong to solo, not online matchmaking.
                VStack(alignment: .leading, spacing: 10) {
                    Text("Solo Difficulties")
                        .font(.headline)
                        .foregroundStyle(AppTheme.modeAccent(mode))
                    Text("Choose your challenge in solo play. Online rules are automatic. Ranked Sudoku, Minesweeper, Color Link, and Word Guess become harder at Platinum; casual keeps the starting rules.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    ForEach(Difficulty.allCases, id: \.self) { d in
                        Text(mode.difficultyLabel(d))
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                    "In solo play, tap the lightbulb to reveal a hint for the selected cell.",
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
                    "Move every card into the four foundation piles.",
                    "Foundations build by suit from Ace to King.",
                    "The game clears automatically when all 52 cards reach the foundations.",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Tap the stock to draw cards into the waste pile.",
                    "Tap a face-up card, then tap a tableau lane or foundation to move it.",
                    "Tableau lanes build downward with alternating red and black cards.",
                    "Only Kings can start an empty tableau lane.",
                    "Use Auto to send available top cards to foundations.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players receive the same shuffled deck and fixed draw rules.",
                    "Clearing wins. If neither player clears, more foundation cards wins, then score, moves, and time.",
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
                    "In solo, difficulty changes only the board size: 4×4, 5×5, 6×6, or 7×7.",
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
                    "Both players get the same seeded grid at the fixed online board size.",
                    "Highest score when the 1:15 timer ends wins.",
                    "Ties use word count, then longest word.",
                ]),
            ]
        case .hangman:
            return [
                RuleSection(title: "Objective", bullets: [
                    "Guess letters to reveal the category word and rescue the puzzle piece.",
                    "In solo, difficulty changes word length: 5 letters, 6 letters, 7 letters, or 8+ letters.",
                    "You get 6 wrong letters before the rescue fails.",
                    "Repeated guesses do not raise the lava.",
                    "Solo has no time limit. Your best at each difficulty uses fewer wrong letters, then faster time.",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Tap letters on the keyboard to guess.",
                    "Correct letters fill every matching slot in the word.",
                    "Wrong letters raise the lava meter and appear in the wrong letters row.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players get the same three categories, starter letters, and target words.",
                    "Play up to three words; your turn ends after two rescues or all three attempts.",
                    "Both players finish before comparison: most rescues, fewer wrong letters, more revealed letters, then faster time.",
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
                    "Ranked and casual use one shared word. The first verified solve wins immediately.",
                    "Rank points still account for your opponent's division. A winning solve in fewer guesses earns a small bonus; a solve under 30 seconds can add one more point, capped at +6.",
                    "Ranked gives 6 guesses below Platinum and 5 from Platinum onward. Casual gives 6. Friend and party turns can still contain multiple words.",
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
                    Text("Each game mode has its own independent rank.\nWin matches to climb divisions, then promote tiers. Higher tiers earn more coins per win, with no coins lost.")
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

                    infoRow(icon: "slider.horizontal.3", color: AppTheme.accentBright, text: "Ranked uses fixed rules for each game. There is no difficulty selection.")
                    infoRow(icon: "checkmark.circle.fill", color: .green, text: "Win: gain rank points. The amount depends on the game's fixed rules and your opponent's rank.")
                    infoRow(icon: "xmark.circle.fill", color: .red, text: "Loss: lose rank points, with the amount adjusted for the game and your opponent's rank.")
                    infoRow(icon: "equal.circle.fill", color: .blue, text: "Draw: no coin change. Draws against another player also award rank points.")
                    infoRow(icon: "arrow.left.circle.fill", color: .orange, text: "Forfeiting an active ranked match counts as a loss.")
                    coinInfoRow(text: "Win rewards use your rank at match start: Bronze +20, Silver +30, Gold +40, Platinum +50, Diamond +60, Master +75 coins.")
                    coinInfoRow(text: "A completed loss earns +\(RankedCoinRewards.loss); a draw earns +\(RankedCoinRewards.draw). Quitting earns no coins. No coin balance is required to enter; ranked entry access still applies.")
                    coinInfoRow(text: "Human ranked rewards have no daily coin cap. Training bots reward wins only, up to 3 per day. A forfeit alone does not earn coins without a completed attempt.")
                    infoRow(icon: "cpu.fill", color: .yellow, text: "Bronze queues may fill with a Training Bot after a short wait. Bot matches use limited ranked rewards.")
                    infoRow(icon: "rectangle.split.3x1.fill", color: .purple, text: "Each tier has III, II, and I divisions. Fill Division I to promote.")
                    infoRow(icon: "clock.fill", color: .purple, text: "Time breaks tied results in some games. See each game's rules for its win conditions.")
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
        if let nextPoints {
            return "\(tier.pointsRequired) to \(nextPoints - 1) pts"
        }
        return "\(tier.pointsRequired)+ pts"
    }

    private var sampleInfo: RankInfo {
        RankInfo(points: tier.pointsRequired, tier: tier, wins: 0, losses: 0, bestTime: nil, bestScore: nil)
    }

    var body: some View {
        HStack(spacing: 14) {
            RankIconView(tier: tier, division: .one, size: 34)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.displayName)
                        .font(.headline)
                        .foregroundStyle(tier.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                        .allowsTightening(true)
                    Text(tierRangeText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .allowsTightening(true)
                }
                VStack(spacing: 4) {
                    RankDivisionProgressView(info: sampleInfo, height: 4, spacing: 4, showLabels: false)
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(RankDivision.progression, id: \.self) { division in
                            divisionRangeColumn(for: division)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    CoinIconView(size: 16)
                    Text("\(RankedCoinRewards.win(for: tier))")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Text("per win").font(.caption2).foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tier.color.opacity(0.45), lineWidth: 1))
    }

    private func divisionRangeColumn(for division: RankDivision) -> some View {
        let start = tier.divisionStart(for: division)
        let rangeText: String
        if let end = tier.divisionEndExclusive(for: division) {
            rangeText = "\(start) to \(end - 1)"
        } else {
            rangeText = "\(start)+"
        }

        return VStack(spacing: 1) {
            Text(division.label)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(division == .three ? tier.color : AppTheme.textPrimary.opacity(0.72))
            Text(rangeText)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity)
    }
}
