import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.07, green: 0.07, blue: 0.18), Color(red: 0.12, green: 0.08, blue: 0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                TabView(selection: $selectedTab) {
                    gameGuide(for: .sudoku).tag(0)
                    gameGuide(for: .minesweeper).tag(1)
                    gameGuide(for: .colorLink).tag(2)
                    gameGuide(for: .gridlock).tag(3)
                    gameGuide(for: .anagram).tag(4)
                    gameGuide(for: .wordHunt).tag(5)
                    gameGuide(for: .wordle).tag(6)
                    RankGuideView().tag(7)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
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
                        .fill(mode.accentColor.gradient)
                        .frame(width: 80, height: 80)
                        .overlay(Image(systemName: mode.icon).font(.system(size: 36)).foregroundStyle(.white))
                        .shadow(color: mode.accentColor.opacity(0.5), radius: 12)
                    Text(mode.displayName)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
                .padding(.top, 20)

                // Rules
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(rulesFor(mode), id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(mode.accentColor)
                            ForEach(section.bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(mode.accentColor)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    Text(bullet)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)

                // Difficulty breakdown
                VStack(alignment: .leading, spacing: 10) {
                    Text("Difficulties")
                        .font(.headline)
                        .foregroundStyle(mode.accentColor)
                    ForEach(Difficulty.allCases, id: \.self) { d in
                        HStack {
                            Text(d.displayName).font(.subheadline.bold()).foregroundStyle(.white)
                            Spacer()
                            Text("×\(String(format: "%.1f", d.pointMultiplier)) points").font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    "First to correctly complete it wins.",
                    "Winner takes the full coin pot and earns rank points.",
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
                    "Fastest clear wins. Exploding loses immediately.",
                    "Higher grid sizes award more rank points.",
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
                    "A completed full board wins.",
                    "If neither player finishes, higher board fill wins before solved pair count.",
                ]),
            ]
        case .gridlock:
            return [
                RuleSection(title: "Objective", bullets: [
                    "Move the red car to the exit on the right side of the grid.",
                    "Horizontal pieces slide left and right.",
                    "Vertical pieces slide up and down.",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Drag a car or block along its allowed direction.",
                    "Horizontal pieces only slide left and right; vertical pieces only slide up and down.",
                    "Clear blockers from the red car's row to open the escape lane.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players receive the same seeded traffic puzzle.",
                    "Escaping wins; if both escape, fewer moves wins before time.",
                    "If neither player escapes, better escape progress wins.",
                ]),
            ]
        case .anagram:
            return [
                RuleSection(title: "Objective", bullets: [
                    "You and your opponent receive the same scrambled word.",
                    "Unscramble it correctly before your opponent does.",
                    "Longer words and harder difficulties award more rank points.",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Tap letter tiles in the bank to move them to your answer row.",
                    "Tap a placed tile to return it to the bank.",
                    "Use Shuffle to randomise the bank order for a fresh look.",
                    "Hit Submit when you have your answer — wrong guesses add 5s.",
                    "Tap the lightbulb to reveal a one-line hint.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "First correct answer wins the coin pot.",
                    "Wrong submissions add a 5-second penalty to your time.",
                ]),
            ]
        case .wordHunt:
            return [
                RuleSection(title: "Objective", bullets: [
                    "Find as many hidden words as you can in the 4×4 letter grid.",
                    "Words must be 3 or more letters and traced through adjacent tiles.",
                    "Tiles can only be used once per word; diagonal connections count.",
                    "Longer words score more points — a 7-letter word earns 5 pts!",
                ]),
                RuleSection(title: "Controls", bullets: [
                    "Drag your finger across adjacent tiles to trace a word.",
                    "Release to submit — valid words are added to your list.",
                    "The current path glows as you trace it.",
                ]),
                RuleSection(title: "Ranked Mode", bullets: [
                    "Both players get the same 4×4 grid.",
                    "After 90 seconds whoever found more total points wins.",
                    "Ties go to the player who found the most distinct words.",
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
                    "Difficulty controls how many guesses you get (4–7).",
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
                        .foregroundStyle(.yellow)
                        .padding(.top, 24)
                    Text("Rank System")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Each game mode has its own independent rank.\nWin matches to climb the ladder.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
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
                    Text("How Points Work")
                        .font(.headline)
                        .foregroundStyle(.yellow)

                    infoRow(icon: "checkmark.circle.fill", color: .green,  text: "Win: +30 pts (×difficulty multiplier)")
                    infoRow(icon: "xmark.circle.fill",    color: .red,    text: "Loss: −15 pts (×difficulty multiplier)")
                    infoRow(icon: "equal.circle.fill",    color: .blue,   text: "Draw: +5 pts")
                    infoRow(icon: "arrow.left.circle.fill", color: .orange, text: "Abandon: −20 pts")
                    infoRow(icon: "clock.fill",           color: .purple, text: "Faster solves earn the same points — speed just wins the pot")
                }
                .padding()
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.subheadline).foregroundStyle(.white.opacity(0.85))
        }
    }
}

struct RankTierRow: View {
    let tier: RankTier

    private var nextPoints: Int? {
        RankTier(rawValue: tier.rawValue + 1)?.pointsRequired
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(tier.icon).font(.title2).frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(tier.displayName)
                    .font(.headline)
                    .foregroundStyle(tier.color)
                Text("\(tier.pointsRequired)\(nextPoints.map { " – \($0 - 1)" } ?? "+") pts")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            // Wager range
            let options = Wager.options(for: tier)
            if let lo = options.first?.amount, let hi = options.last?.amount {
                Text("\(lo)–\(hi) 🪙")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tier.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tier.color.opacity(0.3), lineWidth: 1))
    }
}
