import SwiftUI

struct GridlockView: View {
    let difficulty: Difficulty
    let userID: String?
    let sessionID: String?
    let onMatchResult: (MatchPlayerResult) -> Void
    let onSoloResult: (SoloGameResult) -> Void
    let onPlayAgain: () -> Void
    let onChangeDifficulty: () -> Void
    let onTryRanked: () -> Void
    let onHome: () -> Void

    @StateObject private var vm: GridlockViewModel
    @State private var soloResult: SoloGameResult?
    @State private var didReportMatchResult = false

    init(
        difficulty: Difficulty,
        userID: String? = nil,
        sessionID: String?,
        seed: Int? = nil,
        onMatchResult: @escaping (MatchPlayerResult) -> Void = { _ in },
        onSoloResult: @escaping (SoloGameResult) -> Void = { _ in },
        onPlayAgain: @escaping () -> Void = {},
        onChangeDifficulty: @escaping () -> Void = {},
        onTryRanked: @escaping () -> Void = {},
        onHome: @escaping () -> Void = {}
    ) {
        self.difficulty = difficulty
        self.userID = userID
        self.sessionID = sessionID
        self.onMatchResult = onMatchResult
        self.onSoloResult = onSoloResult
        self.onPlayAgain = onPlayAgain
        self.onChangeDifficulty = onChangeDifficulty
        self.onTryRanked = onTryRanked
        self.onHome = onHome
        _vm = StateObject(wrappedValue: GridlockViewModel(difficulty: difficulty, seed: seed))
    }

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()

            VStack(spacing: 12) {
                header
                topPiles
                tableau
                statusPanel
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .disabled(vm.isComplete || didReportMatchResult)
            .allowsHitTesting(!vm.isComplete && !didReportMatchResult)

            if let message = vm.message {
                VStack {
                    Text(message)
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.hotPink)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                        .padding(.top, 56)
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            if let soloResult {
                SoloResultOverlay(result: soloResult, onPlayAgain: onPlayAgain, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            }
        }
        .navigationTitle("Solitaire")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: vm.message) {
            guard vm.message != nil else { return }
            do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
            vm.message = nil
        }
        .onChange(of: vm.isComplete) { _, complete in
            if complete {
                if sessionID == nil { showSoloResult() }
                reportMatchResult(status: "Cleared Solitaire")
            }
        }
        .onChange(of: vm.moveCount) { _, moveCount in
            if moveCount > 0 && !vm.isComplete {
                reportMatchResult(status: "In progress", isFinal: false)
            }
        }
        .onChange(of: vm.elapsedSeconds) { _, seconds in
            if sessionID != nil && seconds >= difficulty.rankedTimeLimit(for: .gridlock) {
                reportMatchResult(status: "Time expired")
            }
        }
        .onDisappear { vm.stop() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            TimerView(seconds: vm.elapsedSeconds)

            Spacer()

            Button {
                vm.autoMoveToFoundations()
            } label: {
                Label("Auto", systemImage: "arrow.up.doc.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.teal.opacity(0.18))
                    .foregroundStyle(AppTheme.teal)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.teal.opacity(0.42), lineWidth: 1))
            }
            .disabled(vm.isComplete)

            Label("\(vm.moveCount)", systemImage: "arrow.left.arrow.right")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text(vm.rules.drawLabel)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.crownGold)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(AppTheme.crownGold.opacity(0.16))
                .clipShape(Capsule())
        }
        .padding(.horizontal)
    }

    private var topPiles: some View {
        GeometryReader { geo in
            let pileWidth = min(54, (geo.size.width - 54) / 7)
            let pileHeight = pileWidth * 1.36

            HStack(spacing: 9) {
                SolitairePileView(
                    title: "Stock",
                    count: vm.stockCount,
                    card: nil,
                    isSelected: false,
                    symbol: "rectangle.stack.fill"
                ) {
                    vm.drawFromStock()
                }
                .frame(width: pileWidth, height: pileHeight)

                SolitairePileView(
                    title: "Waste",
                    count: vm.wasteCount,
                    card: vm.waste.last,
                    isSelected: vm.selected == .waste,
                    symbol: "rectangle.portrait.fill"
                ) {
                    vm.tapWaste()
                }
                .frame(width: pileWidth, height: pileHeight)

                Spacer(minLength: 8)

                ForEach(SolitaireSuit.allCases, id: \.self) { suit in
                    SolitairePileView(
                        title: suit.shortName,
                        count: vm.foundations[suit]?.count ?? 0,
                        card: vm.foundations[suit]?.last,
                        isSelected: false,
                        symbol: suit.symbol
                    ) {
                        vm.tapFoundation(suit)
                    }
                    .frame(width: pileWidth, height: pileHeight)
                }
            }
        }
        .frame(height: 78)
        .padding(.horizontal)
    }

    private var tableau: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 5
            let cardWidth = (geo.size.width - spacing * 6) / 7
            let cardHeight = cardWidth * 1.38
            let overlap = max(20, min(30, cardHeight * 0.40))

            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(vm.tableau.indices, id: \.self) { column in
                        SolitaireTableauColumn(
                            cards: vm.tableau[column],
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            overlap: overlap,
                            selected: vm.selected,
                            column: column
                        ) { index in
                            vm.tapTableau(column: column, index: index)
                        } onEmptyTap: {
                            vm.tapTableau(column: column, index: nil)
                        }
                    }
                }
                .frame(height: cardHeight + CGFloat(max(0, (vm.tableau.map(\.count).max() ?? 1) - 1)) * overlap, alignment: .top)
            }
        }
        .frame(minHeight: 300)
        .padding(.horizontal)
    }

    private var statusPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Foundations")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(vm.foundationCount) / 52")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.accentBright)
            }
            ProgressView(value: vm.progress)
                .tint(AppTheme.accentBright)
            HStack(spacing: 8) {
                StatChip(label: "Redeals", value: vm.redealsRemainingText, color: AppTheme.crownGold)
                StatChip(label: "Face up", value: "\(vm.faceUpTableauCount)", color: AppTheme.teal)
                StatChip(label: "Score", value: "\(vm.score)", color: AppTheme.hotPink)
            }
            Text("Build A through K by suit. Tableau builds down with alternating colors.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }

    private func showSoloResult() {
        guard soloResult == nil else { return }
        let result = SoloGameResult(
            mode: .gridlock,
            difficulty: difficulty,
            completed: true,
            title: "Solitaire Cleared",
            message: "All four foundations are complete.",
            elapsedSeconds: vm.elapsedSeconds,
            score: vm.score,
            progress: vm.progress,
            moves: vm.moveCount,
            stats: [
                SoloResultStat(label: "Moves", value: "\(vm.moveCount)"),
                SoloResultStat(label: "Time", value: formattedTime(vm.elapsedSeconds)),
                SoloResultStat(label: "Score", value: "\(vm.score)"),
                SoloResultStat(label: "Draw", value: vm.rules.drawLabel)
            ],
            details: [
                "\(vm.rules.drawLabel) · \(vm.rules.redealLabel)",
                "Redeals used: \(vm.redealsUsed)",
                "All 52 cards moved to foundations"
            ],
            rewardEvidenceJSON: SoloCoinRewards.evidence(["moves": vm.rewardMoves])
        )
        soloResult = result
        onSoloResult(result)
    }

    private func reportMatchResult(status: String, isFinal: Bool = true) {
        guard !didReportMatchResult, sessionID != nil, let userID else { return }
        if isFinal {
            didReportMatchResult = true
            vm.stop()
        }
        let progressPercent = Int((vm.progress * 100).rounded())
        onMatchResult(MatchPlayerResult(
            userID: userID,
            mode: .gridlock,
            completed: vm.isComplete,
            elapsedSeconds: vm.elapsedSeconds,
            score: vm.score,
            progress: vm.progress,
            status: status,
            summary: [
                "moves": "\(vm.moveCount)",
                "foundationCount": "\(vm.foundationCount)",
                "faceUpTableauCount": "\(vm.faceUpTableauCount)",
                "stockCount": "\(vm.stockCount)",
                "wasteCount": "\(vm.wasteCount)",
                "drawCount": "\(vm.rules.drawCount)",
                "redealsUsed": "\(vm.redealsUsed)",
                "redealLimit": vm.rules.maxRedeals.map(String.init) ?? "unlimited",
                "isFinal": isFinal ? "true" : "false"
            ],
            details: [
                vm.isComplete ? "Cleared Solitaire in \(vm.moveCount) moves" : "Reached \(progressPercent)% foundation progress",
                "\(vm.foundationCount)/52 cards in foundations",
                "\(vm.rules.drawLabel) · \(vm.rules.redealLabel)",
                "Stock \(vm.stockCount) · Waste \(vm.wasteCount)"
            ],
            rewardEvidenceJSON: GameSession.needsMatchEvidence(sessionID) ? SoloCoinRewards.evidence(["moves": vm.rewardMoves]) : nil
        ))
    }
}

private struct SolitaireTableauColumn: View {
    @Environment(\.boardCosmetics) private var cosmetics

    let cards: [SolitaireCard]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let overlap: CGFloat
    let selected: SolitaireSelection?
    let column: Int
    let onCardTap: (Int) -> Void
    let onEmptyTap: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(cosmetics.cardThemeStyle.accent.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(cosmetics.cardThemeStyle.border.opacity(0.45), lineWidth: 1))
                .frame(width: cardWidth, height: cardHeight)
                .onTapGesture(perform: onEmptyTap)

            ForEach(cards.indices, id: \.self) { index in
                SolitaireCardView(
                    card: cards[index],
                    isSelected: selected == .tableau(column: column, index: index),
                    compact: true
                )
                .frame(width: cardWidth, height: cardHeight)
                .offset(y: CGFloat(index) * overlap)
                .zIndex(Double(index))
                .onTapGesture {
                    onCardTap(index)
                }
            }
        }
        .frame(width: cardWidth, height: max(cardHeight, cardHeight + CGFloat(max(0, cards.count - 1)) * overlap), alignment: .top)
    }
}

private struct SolitairePileView: View {
    @Environment(\.boardCosmetics) private var cosmetics

    let title: String
    let count: Int
    let card: SolitaireCard?
    let isSelected: Bool
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if let card {
                    SolitaireCardView(card: card, isSelected: isSelected, compact: true)
                } else if count > 0 {
                    SolitaireCardBackView()
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(cosmetics.cardThemeStyle.accent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(cosmetics.cardThemeStyle.border.opacity(0.48), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        )
                    Image(systemName: symbol)
                        .font(.title3.weight(.black))
                        .foregroundStyle(cosmetics.cardThemeStyle.accent.opacity(0.75))
                }

                VStack {
                    Spacer()
                    Text(title)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.22))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) cards")
    }
}

private struct SolitaireCardView: View {
    @Environment(\.boardCosmetics) private var cosmetics

    let card: SolitaireCard
    let isSelected: Bool
    var compact = false

    var body: some View {
        if card.isFaceUp {
            VStack(alignment: .leading, spacing: 0) {
                Text(card.rank.label)
                    .font(.system(size: compact ? 13 : 18, weight: .black, design: .rounded))
                Image(systemName: card.suit.symbol)
                    .font(.system(size: compact ? 11 : 15, weight: .bold))
                Spacer(minLength: 0)
                Text(card.rank.label)
                    .font(.system(size: compact ? 13 : 18, weight: .black, design: .rounded))
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(compact ? 5 : 7)
            .foregroundStyle(card.isRed ? cosmetics.cardThemeStyle.redSuit : cosmetics.cardThemeStyle.blackSuit)
            .background(cosmetics.cardThemeStyle.frontFill)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 7 : 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 7 : 10, style: .continuous)
                    .stroke(isSelected ? cosmetics.cardThemeStyle.accent : cosmetics.cardThemeStyle.border.opacity(0.72), lineWidth: isSelected ? 3 : 1)
            )
            .shadow(color: isSelected ? cosmetics.cardThemeStyle.accent.opacity(0.45) : cosmetics.cardThemeStyle.shadow, radius: isSelected ? 8 : 3)
        } else {
            SolitaireCardBackView()
        }
    }
}

private struct SolitaireCardBackView: View {
    @Environment(\.boardCosmetics) private var cosmetics

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(cosmetics.cardThemeStyle.backFill)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .overlay(
                Image(systemName: cosmetics.cardThemeStyle.backSymbol)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white.opacity(0.9))
            )
            .shadow(color: cosmetics.cardThemeStyle.shadow, radius: 3)
    }
}

private struct StatChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.28), lineWidth: 1))
    }
}
