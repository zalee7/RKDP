import SwiftUI

struct AnagramView: View {
    @StateObject private var vm: AnagramViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.boardCosmetics) var cosmetics
    private let userID: String?
    private let sessionID: String?
    private let onMatchResult: (MatchPlayerResult) -> Void
    private let onSoloResult: (SoloGameResult) -> Void
    private let onPlayAgain: () -> Void
    private let onChangeDifficulty: () -> Void
    private let onTryRanked: () -> Void
    private let onHome: () -> Void
    @State private var didReportMatchResult = false
    @State private var didReportSoloResult = false

    init(
        difficulty: Difficulty,
        user: AppUser? = nil,
        sessionID: String? = nil,
        seed: Int? = nil,
        puzzleData: String? = nil,
        onMatchResult: @escaping (MatchPlayerResult) -> Void = { _ in },
        onSoloResult: @escaping (SoloGameResult) -> Void = { _ in },
        onPlayAgain: @escaping () -> Void = {},
        onChangeDifficulty: @escaping () -> Void = {},
        onTryRanked: @escaping () -> Void = {},
        onHome: @escaping () -> Void = {}
    ) {
        self.userID = user?.id
        self.sessionID = sessionID
        self.onMatchResult = onMatchResult
        self.onSoloResult = onSoloResult
        self.onPlayAgain = onPlayAgain
        self.onChangeDifficulty = onChangeDifficulty
        self.onTryRanked = onTryRanked
        self.onHome = onHome
        _vm = StateObject(wrappedValue: AnagramViewModel(
            difficulty: difficulty,
            userID: user?.id,
            priorBest: user?.rank(for: .anagram).bestScore,
            seed: seed,
            puzzleData: MultiplayerPuzzleDataFactory.decodeAnagram(puzzleData)
        ))
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 12)

                resultBanner
                    .padding(.top, 6)

                foundWordsScroll
                    .padding(.top, 10)

                Spacer(minLength: 0)

                placedRow
                    .padding(.top, 12)

                submitButton
                    .padding(.top, 10)
                    .padding(.horizontal)

                bankSection
                    .padding(.top, 10)

                controlRow
                    .padding(.top, 12)
                    .padding(.horizontal)
                    .padding(.bottom, 28)
            }

            if vm.isFinished && sessionID == nil { finishedOverlay }
        }
        .navigationBarBackButtonHidden()
        .onDisappear { vm.stop() }
        .onChange(of: vm.isFinished) { _, finished in
            if finished {
                if sessionID == nil { reportSoloResult() }
                reportMatchResult()
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { vm.stop(); dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(vm.difficulty.displayName.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.modeAccent(.anagram))
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                    Text("\(vm.timeRemaining)s")
                        .monospacedDigit()
                }
                .font(.headline)
                .foregroundStyle(vm.timeRemaining <= 15 ? .red : AppTheme.textPrimary)
                .animation(.easeInOut, value: vm.timeRemaining)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(vm.score)")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.accentBright)
                Text("pts")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Result banner

    @ViewBuilder
    private var resultBanner: some View {
        if let result = vm.lastResult {
            Group {
                switch result {
                case .valid(let word, let pts):
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(word).bold()
                        Text("+\(pts) pts").foregroundStyle(.green)
                    }
                case .invalid:
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        Text("Not a word")
                    }
                case .alreadyFound:
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text("Already found!")
                    }
                case .tooShort:
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text("Need 3+ letters")
                    }
                }
            }
            .font(.subheadline.bold())
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 1))
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.25), value: vm.lastResult)
        }
    }

    // MARK: - Found words

    private var foundWordsScroll: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Words Found")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1)
                Spacer()
                Text("\(vm.foundWords.count) / \(vm.game.validWords.count)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal)

            if vm.foundWords.isEmpty {
                Text("Start typing to find words!")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                LetterWrapLayout(spacing: 6) {
                    ForEach(vm.sortedFoundWords.prefix(12), id: \.self) { word in
                        foundWordChip(word)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.3), value: vm.foundWords)

                if vm.sortedFoundWords.count > 12 {
                    Text("+\(vm.sortedFoundWords.count - 12) more")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func foundWordChip(_ word: String) -> some View {
        let score = AnagramGame.score(for: word)
        return HStack(spacing: 6) {
            Text(word.capitalized)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text("+\(score)")
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.accentBright)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.modeAccent(.anagram).opacity(0.16))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.modeAccent(.anagram).opacity(0.28), lineWidth: 1))
    }

    // MARK: - Placed (current word)

    private var placedRow: some View {
        VStack(spacing: 6) {
            Text("Current Word")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(1)

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.modeAccent(.anagram).opacity(0.4), lineWidth: 1))

                if vm.placed.isEmpty {
                    Text("Tap letters below")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.placed, id: \.id) { tile in
                                LetterTile(letter: tile.letter, size: 52)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.25)) { vm.returnToBank(id: tile.id) }
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
            .frame(height: 72)
            .padding(.horizontal)
        }
    }

    // MARK: - Submit button (above letter bank)

    private var submitButton: some View {
        Button { vm.submit() } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").font(.headline)
                Text("Enter").font(.headline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(vm.placed.count >= 3
                        ? AnyShapeStyle(cosmetics.themeStyle.tileGradient)
                        : AnyShapeStyle(AppTheme.cardBackground))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: vm.placed.count >= 3 ? cosmetics.themeStyle.activeTraceColor.opacity(0.35) : .clear, radius: 8)
        }
        .disabled(vm.placed.count < 3)
        .animation(.easeInOut(duration: 0.15), value: vm.placed.count)
    }

    // MARK: - Bank (horizontal scroll)

    private var bankSection: some View {
        VStack(spacing: 6) {
            Text("Your Letters")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.bank, id: \.id) { tile in
                        LetterTile(letter: tile.letter, size: 62)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.25)) { vm.pickFromBank(id: tile.id) }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: 10) {
            iconButton(label: "Shuffle", icon: "shuffle") {
                withAnimation(.spring(response: 0.35)) { vm.shuffleBank() }
            }
            iconButton(label: "Clear", icon: "arrow.uturn.backward") {
                withAnimation(.spring(response: 0.35)) { vm.clearPlaced() }
            }
            Button {
                withAnimation { vm.showHint.toggle() }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: vm.showHint ? "lightbulb.fill" : "lightbulb")
                        .font(.headline)
                    Text("Hint")
                        .font(.caption2.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(vm.showHint ? AppTheme.accentBright.opacity(0.2) : AppTheme.cardBackground)
                .foregroundStyle(vm.showHint ? AppTheme.accentBright : AppTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(vm.showHint ? AppTheme.accentBright.opacity(0.5) : AppTheme.cardBorder, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func iconButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.headline)
                Text(label).font(.caption2.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.cardBackground)
            .foregroundStyle(AppTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Hint overlay

    private var hintSection: some View {
        Group {
            if vm.showHint, let hint = vm.hintWord {
                Text("Hint: \(hint.prefix(1))\(String(repeating: "·", count: hint.count - 1))")
                    .font(.subheadline.italic())
                    .foregroundStyle(AppTheme.accentBright)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Finished overlay

    private var finishedOverlay: some View {
        Group {
            SoloResultOverlay(
                result: makeSoloResult(),
                onPlayAgain: onPlayAgain,
                onChangeDifficulty: onChangeDifficulty,
                onTryRanked: onTryRanked,
                onHome: onHome
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: vm.isFinished)
    }

    private func makeSoloResult() -> SoloGameResult {
        let longest = vm.foundWords.map(\.count).max() ?? 0
        return SoloGameResult(
            mode: .anagram,
            difficulty: vm.difficulty,
            completed: vm.score > 0,
            title: "Time's Up",
            message: vm.score > 0 ? "Nice word haul." : "Find at least one word to unlock the next level.",
            elapsedSeconds: vm.elapsedSeconds,
            score: vm.score,
            progress: Double(vm.score),
            stats: [
                SoloResultStat(label: "Points", value: "\(vm.score)"),
                SoloResultStat(label: "Words", value: "\(vm.foundWords.count)"),
                SoloResultStat(label: "Longest", value: longest > 0 ? "\(longest)" : "-"),
                SoloResultStat(label: "Missed", value: "\(vm.missedWords.count)")
            ],
            details: vm.sortedFoundWords.prefix(8).map { "\($0.capitalized) (+\(AnagramGame.score(for: $0)))" }
        )
    }

    private func reportSoloResult() {
        guard !didReportSoloResult else { return }
        didReportSoloResult = true
        onSoloResult(makeSoloResult())
    }

    private func reportMatchResult() {
        guard !didReportMatchResult, sessionID != nil, let userID else { return }
        didReportMatchResult = true
        let longest = vm.foundWords.map(\.count).max() ?? 0
        onMatchResult(MatchPlayerResult(
            userID: userID,
            mode: .anagram,
            completed: true,
            elapsedSeconds: vm.elapsedSeconds,
            score: vm.score,
            progress: Double(vm.score),
            status: "Time expired",
            summary: [
                "wordCount": "\(vm.foundWords.count)",
                "longestWordLength": "\(longest)",
                "missedWords": "\(vm.missedWords.count)"
            ],
            details: vm.sortedFoundWords.prefix(12).map { "\($0.capitalized) (+\(AnagramGame.score(for: $0)))" }
        ))
    }

    @ViewBuilder
    private func statBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(AppTheme.textSecondary)
        }
    }
}

// MARK: - Shared subviews

private struct LetterTile: View {
    let letter: Character
    var size: CGFloat = 44
    @Environment(\.boardCosmetics) var cosmetics

    var body: some View {
        let fs = cosmetics.fontStyle
        Text(String(letter))
            .font(.system(size: size * 0.42, weight: .bold, design: fs.design))
            .frame(width: size, height: size)
            .background(cosmetics.themeStyle.tileGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
    }
}

// MARK: - Wrapping layout for letter bank

private struct LetterWrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? UIScreen.main.bounds.width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (subview, origin) in zip(subviews, result.origins) {
            let size = subview.sizeThatFits(.unspecified)
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                          proposal: ProposedViewSize(size))
        }
    }

    private struct LayoutResult { var size: CGSize; var origins: [CGPoint] }

    private func layout(subviews: Subviews, width: CGFloat) -> LayoutResult {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowH + spacing; x = 0; rowH = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }

        // Centre each row
        var centred: [CGPoint] = []
        var rowStart = 0
        var ry: CGFloat = 0
        while rowStart < origins.count {
            var rowEnd = rowStart
            while rowEnd + 1 < origins.count && origins[rowEnd + 1].y == origins[rowStart].y {
                rowEnd += 1
            }
            let lastOrigin = origins[rowEnd]
            let lastSize = subviews[rowEnd].sizeThatFits(.unspecified)
            let rowWidth = lastOrigin.x + lastSize.width
            let offset = (width - rowWidth) / 2
            let rh = subviews[rowStart...rowEnd].map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for i in rowStart...rowEnd {
                centred.append(CGPoint(x: origins[i].x + offset, y: ry))
            }
            ry += rh + spacing
            rowStart = rowEnd + 1
        }

        let totalH = ry > spacing ? ry - spacing : 0
        return LayoutResult(size: CGSize(width: width, height: totalH), origins: centred)
    }
}
