import SwiftUI

struct WordHuntView: View {
    @StateObject private var vm: WordHuntViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.boardCosmetics) var cosmetics
    @State private var lastDragLocation: CGPoint?
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
        _vm = StateObject(wrappedValue: WordHuntViewModel(
            difficulty: difficulty,
            userID: user?.id,
            priorBest: user?.rank(for: .wordHunt).bestScore,
            seed: seed,
            puzzleData: MultiplayerPuzzleDataFactory.decodeWordHunt(puzzleData)
        ))
    }

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                wordStatsDashboard
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                letterGrid
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                currentWordDisplay
                    .padding(.top, 12)

                foundWordsList
                    .padding(.top, 8)
            }

            VStack {
                wordFeedbackBanner
                    .padding(.top, 74)
                Spacer()
            }
            .padding(.horizontal)
            .allowsHitTesting(false)

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
                Text(GameMode.wordHunt.difficultyLabel(vm.difficulty).uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.modeAccent(.wordHunt))
                HStack(spacing: 6) {
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


    private var wordStatsDashboard: some View {
        HStack(spacing: 8) {
            wordStatTile(value: "\(vm.score)", label: "Points", color: AppTheme.accentBright)
            wordStatTile(value: "\(vm.foundWords.count)", label: "Words", color: AppTheme.modeAccent(.wordHunt))
            wordStatTile(value: longestWordText, label: "Longest", color: AppTheme.crownGold)
            wordStatTile(value: averageWordText, label: "Avg", color: AppTheme.textPrimary)
        }
    }

    private func wordStatTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var longestWordText: String {
        let longest = vm.foundWords.map(\.count).max() ?? 0
        return longest > 0 ? "\(longest)" : "-"
    }

    private var averageWordText: String {
        guard !vm.foundWords.isEmpty else { return "-" }
        let total = vm.foundWords.reduce(0) { $0 + $1.count }
        return String(format: "%.1f", Double(total) / Double(vm.foundWords.count))
    }

    private var groupedFoundWords: [(Int, [String])] {
        Dictionary(grouping: vm.sortedFoundWords, by: { $0.count })
            .map { ($0.key, $0.value.sorted()) }
            .sorted { $0.0 > $1.0 }
    }

    private var lengthDistributionText: String {
        groupedFoundWords.map { "\($0.0):\($0.1.count)" }.joined(separator: ",")
    }

    private var encodedFoundWords: String {
        vm.sortedFoundWords.prefix(80).joined(separator: "|")
    }

    private var topWordText: String {
        vm.sortedFoundWords.first ?? ""
    }

    // MARK: - Word feedback banner

    @ViewBuilder
    private var wordFeedbackBanner: some View {
        if let result = vm.lastWordResult {
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
            .animation(.easeInOut(duration: 0.3), value: vm.lastWordResult)
        }
    }

    // MARK: - Letter grid

    private var letterGrid: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / CGFloat(vm.game.size)
            ZStack(alignment: .topLeading) {
                // Grid cells — each occupies exactly cellSize × cellSize
                VStack(spacing: 0) {
                    ForEach(0..<vm.game.size, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<vm.game.size, id: \.self) { col in
                                GridCell(
                                    letter: vm.game.grid[row][col],
                                    isActive: vm.isInPath(row: row, col: col),
                                    pathIndex: vm.pathIndex(row: row, col: col),
                                    cellSize: cellSize
                                )
                            }
                        }
                    }
                }

                // Finger trace — drawn over cells, doesn't intercept touches
                let traceColor = cosmetics.themeStyle.activeTraceColor
                Canvas { context, _ in
                    let path = vm.currentPath
                    guard path.count >= 2 else { return }
                    var tracePath = Path()
                    for (i, cell) in path.enumerated() {
                        let pt = CGPoint(
                            x: (CGFloat(cell.col) + 0.5) * cellSize,
                            y: (CGFloat(cell.row) + 0.5) * cellSize
                        )
                        if i == 0 { tracePath.move(to: pt) } else { tracePath.addLine(to: pt) }
                    }
                    context.stroke(
                        tracePath,
                        with: .color(traceColor),
                        style: StrokeStyle(lineWidth: cellSize * 0.28, lineCap: .round, lineJoin: .round)
                    )
                }
                .allowsHitTesting(false)
                .animation(.none, value: vm.currentPath.count)
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .contentShape(Rectangle())
            .gesture(dragGesture(cellSize: cellSize))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dragGesture(cellSize: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let loc = value.location
                if vm.currentPath.isEmpty {
                    let (r, c) = floorCell(loc, cellSize: cellSize)
                    vm.startPath(row: r, col: c)
                } else {
                    snapExtend(to: loc, cellSize: cellSize)
                }
                lastDragLocation = loc
            }
            .onEnded { _ in
                vm.submitPath()
                lastDragLocation = nil
            }
    }

    /// Floor-division mapping: point → (row, col).
    private func floorCell(_ p: CGPoint, cellSize: CGFloat) -> (Int, Int) {
        let col = max(0, min(vm.game.size - 1, Int(p.x / cellSize)))
        let row = max(0, min(vm.game.size - 1, Int(p.y / cellSize)))
        return (row, col)
    }

    /// Extend by at most one forward cell per drag update. Diagonals are based on
    /// the cell under the finger, which avoids recursive "catch up" jumps.
    private func snapExtend(to point: CGPoint, cellSize: CGFloat) {
        guard let last = vm.currentPath.last else { return }
        let target = floorCell(point, cellSize: cellSize)
        let rowDelta = target.0 - last.row
        let colDelta = target.1 - last.col
        guard rowDelta != 0 || colDelta != 0 else { return }

        let nextRow = last.row + rowDelta.signum()
        let nextCol = last.col + colDelta.signum()
        guard !vm.isInPath(row: nextRow, col: nextCol) else { return }

        vm.extendPath(row: nextRow, col: nextCol)
    }

    // MARK: - Current word display

    private var currentWordDisplay: some View {
        HStack(spacing: 6) {
            if vm.currentWord.isEmpty {
                Text("Drag to trace a word")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(Array(vm.currentWord.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .frame(height: 36)
        .padding(.horizontal, 20)
    }

    // MARK: - Found words list

    private var foundWordsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Found Words")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1)
                Spacer()
                Text("\(vm.foundWords.count) / \(vm.game.validWords.count)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 20)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(groupedFoundWords.prefix(5), id: \.0) { length, words in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(length) letters")
                                .font(.caption2.bold())
                                .foregroundStyle(AppTheme.textSecondary)
                            FlowLayout(spacing: 6) {
                                ForEach(words.prefix(16), id: \.self) { word in
                                    wordChip(word)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.spring(response: 0.3), value: vm.foundWords)
            }
            .frame(maxHeight: 150)
        }
    }


    private func wordChip(_ word: String) -> some View {
        HStack(spacing: 4) {
            Text(word.capitalized)
                .font(.caption.bold())
            Text("+\(WordHuntGame.score(for: word))")
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.accentBright)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(AppTheme.modeAccent(.wordHunt).opacity(0.15))
        .foregroundStyle(AppTheme.textPrimary)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.modeAccent(.wordHunt).opacity(0.3), lineWidth: 1))
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
            mode: .wordHunt,
            difficulty: vm.difficulty,
            completed: vm.score > 0,
            title: "Time's Up",
            message: vm.score > 0 ? "You found \(vm.foundWords.count) words." : "Find at least one word to unlock the next level.",
            elapsedSeconds: vm.elapsedSeconds,
            score: vm.score,
            progress: Double(vm.score),
            stats: [
                SoloResultStat(label: "Points", value: "\(vm.score)"),
                SoloResultStat(label: "Words", value: "\(vm.foundWords.count)"),
                SoloResultStat(label: "Longest", value: longest > 0 ? "\(longest)" : "-"),
                SoloResultStat(label: "Avg Len", value: averageWordText),
                SoloResultStat(label: "Missed", value: "\(vm.missedWords.count)")
            ],
            details: vm.sortedFoundWords.prefix(30).map { "\($0.capitalized) (+\(WordHuntGame.score(for: $0)))" }
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
            mode: .wordHunt,
            completed: true,
            elapsedSeconds: vm.elapsedSeconds,
            score: vm.score,
            progress: Double(vm.score),
            status: "Time expired",
            summary: [
                "wordCount": "\(vm.foundWords.count)",
                "longestWordLength": "\(longest)",
                "averageWordLength": averageWordText,
                "topWord": topWordText,
                "wordsByLength": lengthDistributionText,
                "foundWords": encodedFoundWords,
                "missedWords": "\(vm.missedWords.count)"
            ],
            details: vm.sortedFoundWords.prefix(50).map { "\($0.capitalized) (+\(WordHuntGame.score(for: $0)))" }
        ))
    }
}

// MARK: - Grid cell

private struct GridCell: View {
    let letter: Character
    let isActive: Bool
    let pathIndex: Int?
    let cellSize: CGFloat
    @Environment(\.boardCosmetics) var cosmetics

    var body: some View {
        let theme = cosmetics.themeStyle
        let fs = cosmetics.fontStyle
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive
                      ? theme.tileGradient
                      : LinearGradient(colors: [AppTheme.cardBackground], startPoint: .leading, endPoint: .trailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? theme.activeTraceColor : AppTheme.cardBorder, lineWidth: isActive ? 2 : 1)
                )
                .shadow(color: isActive ? theme.activeTraceColor.opacity(0.5) : .clear, radius: 6)

            VStack(spacing: 1) {
                Text(String(letter))
                    .font(.system(size: cellSize * 0.38, weight: .bold, design: fs.design))
                    .foregroundStyle(AppTheme.textPrimary)
                if let idx = pathIndex {
                    Text("\(idx + 1)")
                        .font(.system(size: cellSize * 0.18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.7))
                }
            }
        }
        .padding(4)
        .frame(width: cellSize, height: cellSize)
        .animation(.spring(response: 0.2), value: isActive)
    }
}

// MARK: - Flow layout for missed words

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? UIScreen.main.bounds.width
        var y: CGFloat = 0, rowH: CGFloat = 0, x: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY, rowH: CGFloat = 0, x = bounds.minX
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }
    }
}
