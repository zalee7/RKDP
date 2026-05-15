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
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                GridDuelBoardView(board: vm.board) { axis, index, steps in
                    vm.shift(axis: axis, index: index, steps: steps)
                }
                .padding(.horizontal)
                .aspectRatio(1, contentMode: .fit)

                progressPanel

                Spacer(minLength: 0)
            }
            .padding(.top, 8)

            if let soloResult {
                SoloResultOverlay(result: soloResult, onPlayAgain: onPlayAgain, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            }
        }
        .navigationTitle("Grid Duel")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.isComplete) { _, complete in
            if complete {
                if sessionID == nil { showSoloResult() }
                reportMatchResult(status: "Symmetry complete")
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
        HStack {
            TimerView(seconds: vm.elapsedSeconds)
            Spacer()
            Label("\(vm.moveCount)", systemImage: "arrow.left.arrow.right")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Label("\(vm.boardSize)x\(vm.boardSize)", systemImage: "square.grid.3x3.fill")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.accentBright)
        }
        .padding(.horizontal)
    }

    private var progressPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Mirror symmetry")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(Int((vm.progress * 100).rounded()))%")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.accentBright)
            }
            ProgressView(value: vm.progress)
                .tint(AppTheme.accentBright)
            Text("Drag rows sideways or columns up and down until the grid mirrors itself.")
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
            title: "Grid Duel Solved",
            message: "The grid reached mirror symmetry.",
            elapsedSeconds: vm.elapsedSeconds,
            score: max(0, 600 - vm.moveCount),
            progress: vm.progress,
            moves: vm.moveCount,
            stats: [
                SoloResultStat(label: "Moves", value: "\(vm.moveCount)"),
                SoloResultStat(label: "Time", value: formattedTime(vm.elapsedSeconds)),
                SoloResultStat(label: "Symmetry", value: "\(Int((vm.progress * 100).rounded()))%"),
                SoloResultStat(label: "Grid", value: "\(vm.boardSize)x\(vm.boardSize)")
            ],
            details: [
                "\(vm.colorCount) colors",
                "\(vm.board.solvedPairCount)/\(vm.board.totalPairCount) mirror pairs aligned"
            ]
        )
        soloResult = result
        onSoloResult(result)
    }

    private func reportMatchResult(status: String) {
        guard !didReportMatchResult, sessionID != nil, let userID else { return }
        didReportMatchResult = true
        vm.stop()
        let progressPercent = Int((vm.progress * 100).rounded())
        onMatchResult(MatchPlayerResult(
            userID: userID,
            mode: .gridlock,
            completed: vm.isComplete,
            elapsedSeconds: vm.elapsedSeconds,
            score: max(0, 600 - vm.moveCount),
            progress: vm.progress,
            status: status,
            summary: [
                "moves": "\(vm.moveCount)",
                "symmetryPercent": "\(progressPercent)",
                "boardSize": "\(vm.boardSize)",
                "colorCount": "\(vm.colorCount)"
            ],
            details: [
                vm.isComplete ? "Solved in \(vm.moveCount) moves" : "Reached \(progressPercent)% symmetry",
                "\(vm.boardSize)x\(vm.boardSize) grid",
                "\(vm.colorCount) colors",
                "\(vm.board.solvedPairCount)/\(vm.board.totalPairCount) mirror pairs aligned"
            ]
        ))
    }
}

struct GridDuelBoardView: View {
    let board: GridlockBoard
    let onShift: (GridDuelAxis, Int, Int) -> Void
    @State private var activeDrag: GridDuelMove?

    var body: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / CGFloat(board.size)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppTheme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.cardBorder, lineWidth: 1.5))

                ForEach(0..<board.size, id: \.self) { row in
                    ForEach(0..<board.size, id: \.self) { col in
                        GridDuelTile(colorIndex: board.tiles[row][col], colorCount: board.colorCount)
                            .frame(width: cellSize, height: cellSize)
                            .offset(x: CGFloat(col) * cellSize, y: CGFloat(row) * cellSize)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(cellSize: cellSize))
        }
    }

    private func dragGesture(cellSize: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                let startCol = clampedIndex(value.startLocation.x / cellSize)
                let startRow = clampedIndex(value.startLocation.y / cellSize)
                let horizontal = abs(value.translation.width) >= abs(value.translation.height)
                let axis: GridDuelAxis = horizontal ? .row : .column
                let index = horizontal ? startRow : startCol
                let translation = horizontal ? value.translation.width : value.translation.height
                let steps = Int((translation / cellSize).rounded(.towardZero))

                if activeDrag == nil || activeDrag?.axis != axis || activeDrag?.index != index {
                    activeDrag = GridDuelMove(axis: axis, index: index, steps: 0)
                }

                let previousSteps = activeDrag?.steps ?? 0
                let delta = steps - previousSteps
                guard delta != 0 else { return }
                activeDrag = GridDuelMove(axis: axis, index: index, steps: steps)
                onShift(axis, index, delta)
            }
            .onEnded { _ in
                activeDrag = nil
            }
    }

    private func clampedIndex(_ value: CGFloat) -> Int {
        max(0, min(board.size - 1, Int(value)))
    }
}

private struct GridDuelTile: View {
    let colorIndex: Int
    let colorCount: Int

    private var tileColor: Color {
        let palette: [Color] = [
            AppTheme.hotPink,
            AppTheme.teal,
            AppTheme.crownGold,
            AppTheme.iconBlue,
            AppTheme.iconPurple,
            AppTheme.royalBlue
        ]
        return palette[colorIndex % min(colorCount, palette.count)]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(tileColor.gradient)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.82), lineWidth: 2))
            .shadow(color: tileColor.opacity(0.22), radius: 5)
            .padding(3)
    }
}
