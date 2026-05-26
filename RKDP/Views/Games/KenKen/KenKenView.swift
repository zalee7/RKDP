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

            VStack(spacing: 14) {
                header

                targetPanel

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
                reportMatchResult(status: "Pattern matched")
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
            Button {
                vm.undoLastMove()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(vm.canUndo ? AppTheme.crownGold.opacity(0.22) : Color.white.opacity(0.08))
                    .foregroundStyle(vm.canUndo ? AppTheme.crownGold : AppTheme.textSecondary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(vm.canUndo ? AppTheme.crownGold.opacity(0.45) : AppTheme.cardBorder, lineWidth: 1))
            }
            .disabled(!vm.canUndo)
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


    private var targetPanel: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Target")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.crownGold)
                Text("Recreate this pattern by sliding rows and columns.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            GridDuelMiniBoardView(tiles: vm.board.targetTiles, colorCount: vm.colorCount)
                .frame(width: 104, height: 104)
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }

    private var progressPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Pattern Match")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(Int((vm.progress * 100).rounded()))%")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.accentBright)
            }
            ProgressView(value: vm.progress)
                .tint(AppTheme.accentBright)
            Text("Match the target by sliding full rows sideways or full columns up and down.")
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
            message: "Your grid matched the target pattern.",
            elapsedSeconds: vm.elapsedSeconds,
            score: max(0, 600 - vm.moveCount),
            progress: vm.progress,
            moves: vm.moveCount,
            stats: [
                SoloResultStat(label: "Moves", value: "\(vm.moveCount)"),
                SoloResultStat(label: "Time", value: formattedTime(vm.elapsedSeconds)),
                SoloResultStat(label: "Pattern", value: "\(Int((vm.progress * 100).rounded()))%"),
                SoloResultStat(label: "Grid", value: "\(vm.boardSize)x\(vm.boardSize)")
            ],
            details: [
                "\(vm.colorCount) colors",
                "\(vm.board.matchingCellCount)/\(vm.board.totalPairCount) cells match the target"
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
                "patternPercent": "\(progressPercent)",
                "boardSize": "\(vm.boardSize)",
                "colorCount": "\(vm.colorCount)",
                "tileRows": gridDuelTileRows(vm.board.tiles),
                "targetRows": gridDuelTileRows(vm.board.targetTiles)
            ],
            details: [
                vm.isComplete ? "Matched the target in \(vm.moveCount) moves" : "Reached \(progressPercent)% pattern match",
                "\(vm.boardSize)x\(vm.boardSize) grid",
                "\(vm.colorCount) colors",
                "\(vm.board.matchingCellCount)/\(vm.board.totalPairCount) cells match the target"
            ]
        ))
    }
    private func gridDuelTileRows(_ tiles: [[Int]]) -> String {
        tiles.map { row in
            row.map { String($0, radix: 16, uppercase: true) }.joined()
        }.joined(separator: "/")
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

private struct GridDuelMiniBoardView: View {
    let tiles: [[Int]]
    let colorCount: Int

    var body: some View {
        GeometryReader { geo in
            let size = max(1, tiles.count)
            let cellSize = geo.size.width / CGFloat(size)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.20))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.24), lineWidth: 1))
                if !tiles.isEmpty {
                    ForEach(0..<tiles.count, id: \.self) { row in
                        ForEach(0..<min(size, tiles[row].count), id: \.self) { col in
                            GridDuelTile(colorIndex: tiles[row][col], colorCount: colorCount, compact: true)
                                .frame(width: cellSize, height: cellSize)
                                .offset(x: CGFloat(col) * cellSize, y: CGFloat(row) * cellSize)
                        }
                    }
                }
            }
        }
    }
}

private struct GridDuelTile: View {
    let colorIndex: Int
    let colorCount: Int
    var compact = false
    @Environment(\.boardCosmetics) private var cosmetics

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
        let tile = cosmetics.tileThemeStyle
        RoundedRectangle(cornerRadius: compact ? 4 : 10)
            .fill(tileColor.gradient)
            .overlay(RoundedRectangle(cornerRadius: compact ? 4 : 10).stroke(tile.border.opacity(compact ? 0.55 : 0.82), lineWidth: compact ? 1 : 2))
            .shadow(color: tile.shadow.opacity(compact ? 0.45 : 0.9), radius: compact ? 2 : 5)
            .padding(compact ? 1 : 3)
    }
}
