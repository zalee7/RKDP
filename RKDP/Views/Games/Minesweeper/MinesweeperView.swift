import SwiftUI

struct MinesweeperView: View {
    let difficulty: Difficulty
    let userID: String?
    let sessionID: String?
    let onMatchResult: (MatchPlayerResult) -> Void
    let onSoloResult: (SoloGameResult) -> Void
    let onPlayAgain: () -> Void
    let onChangeDifficulty: () -> Void
    let onTryRanked: () -> Void
    let onHome: () -> Void

    @StateObject private var vm: MinesweeperViewModel
    @State private var didReportMatchResult = false
    @State private var soloResult: SoloGameResult?

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
        _vm = StateObject(wrappedValue: MinesweeperViewModel(difficulty: difficulty, seed: seed, ranked: sessionID != nil))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    Label("\(vm.board.remainingMines)", systemImage: "flag.fill")
                        .foregroundStyle(.red)
                        .font(.headline)
                    Spacer()
                    TimerView(seconds: vm.elapsedSeconds)
                    Spacer()
                    Toggle(isOn: $vm.isFlagMode) {
                        Image(systemName: vm.isFlagMode ? "flag.fill" : "hand.tap.fill")
                    }
                    .toggleStyle(.button)
                    .tint(.red)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Board
                ScrollView([.horizontal, .vertical]) {
                    MinesweeperGridView(board: vm.board) { row, col in
                        vm.tap(row: row, col: col)
                        if vm.firstCell != nil && !vm.isFinished {
                            reportMatchResult(isFinal: false)
                        }
                    } onLongPress: { row, col in
                        vm.longPress(row: row, col: col)
                    }
                    .padding(8)
                }
            }
            .disabled(vm.isFinished || didReportMatchResult)
            .allowsHitTesting(!vm.isFinished && !didReportMatchResult)

            if let soloResult {
                SoloResultOverlay(result: soloResult, onPlayAgain: onPlayAgain, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            }
        }
        .navigationTitle("Minesweeper")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { vm.stop() }
        .onChange(of: vm.status) { _, status in
            if status == .won || status == .lost {
                if sessionID == nil { showSoloResult() }
                reportMatchResult()
            }
        }
        .onChange(of: vm.elapsedSeconds) { _, seconds in
            if sessionID != nil && seconds >= difficulty.rankedTimeLimit(for: .minesweeper) {
                reportMatchResult()
            }
        }
    }

    private func reportMatchResult(isFinal: Bool = true) {
        guard !didReportMatchResult, sessionID != nil, let userID else { return }
        if isFinal {
            didReportMatchResult = true
            vm.stop()
        }
        let hitMine = vm.status == .lost
        let completed = vm.status == .won
        onMatchResult(MatchPlayerResult(
            userID: userID,
            mode: .minesweeper,
            completed: completed,
            elapsedSeconds: vm.elapsedSeconds,
            score: vm.board.revealedCount,
            progress: Double(vm.board.revealedCount) / Double(max(1, vm.board.safeCells)),
            status: completed ? "Cleared board" : (hitMine ? "Hit a mine" : "Time expired"),
            summary: [
                "hitMine": hitMine ? "true" : "false",
                "safeCells": "\(vm.board.revealedCount)",
                "totalSafeCells": "\(vm.board.safeCells)",
                "boardRows": minesweeperBoardRows(vm.board),
                "boardRowsCount": "\(vm.board.config.rows)",
                "boardColsCount": "\(vm.board.config.cols)",
                "isFinal": isFinal ? "true" : "false"
            ],
            details: [
                "\(vm.board.revealedCount) of \(vm.board.safeCells) safe cells revealed",
                hitMine ? "Mine hit" : (completed ? "Board cleared" : "No mine hit")
            ],
            rewardEvidenceJSON: GameSession.needsMatchEvidence(sessionID) ? SoloCoinRewards.evidence([
                "firstCell": vm.firstCell ?? -1,
                "revealed": vm.board.cells.filter { cell in
                    if case .revealed = cell.state { return !cell.hasMine }
                    return false
                }.map(\.id)
            ].merging(vm.board.cells.first(where: { $0.state == .exploded }).map { ["explodedCell": $0.id] } ?? [:]) { _, new in new }) : nil
        ))
    }

    private func showSoloResult() {
        guard soloResult == nil else { return }
        vm.stop()
        let completed = vm.status == .won
        let progress = Double(vm.board.revealedCount) / Double(max(1, vm.board.safeCells))
        let result = SoloGameResult(
            mode: .minesweeper,
            difficulty: difficulty,
            completed: completed,
            title: completed ? "Board Cleared" : "Mine Hit",
            message: completed ? "Every safe cell is open." : "You revealed \(vm.board.revealedCount) safe cells.",
            elapsedSeconds: vm.elapsedSeconds,
            score: nil,
            progress: progress,
            stats: [
                SoloResultStat(label: "Safe Cells", value: "\(vm.board.revealedCount)/\(vm.board.safeCells)"),
                SoloResultStat(label: "Progress", value: "\(Int((progress * 100).rounded()))%"),
                SoloResultStat(label: "Time", value: formattedTime(vm.elapsedSeconds)),
                SoloResultStat(label: "Result", value: completed ? "Clear" : "Lost")
            ],
            rewardEvidenceJSON: SoloCoinRewards.evidence([
                "firstCell": vm.firstCell ?? -1,
                "revealed": vm.board.cells.filter { cell in
                    if case .revealed = cell.state { return !cell.hasMine }
                    return false
                }.map(\.id)
            ].merging(vm.board.cells.first(where: { $0.state == .exploded }).map { ["explodedCell": $0.id] } ?? [:]) { _, new in new })
        )
        soloResult = result
        onSoloResult(result)
    }
    private func minesweeperBoardRows(_ board: MinesweeperBoard) -> String {
        (0..<board.config.rows).map { row in
            (0..<board.config.cols).map { col -> String in
                let cell = board.cells[row * board.config.cols + col]
                switch cell.state {
                case .hidden:
                    return "H"
                case .flagged:
                    return "F"
                case .exploded:
                    return "X"
                case .revealed(let adjacent):
                    return cell.hasMine ? "M" : "\(adjacent)"
                }
            }.joined()
        }.joined(separator: "/")
    }

}

struct MinesweeperGridView: View {
    let board: MinesweeperBoard
    let onTap: (Int, Int) -> Void
    let onLongPress: (Int, Int) -> Void

    private let cellSize: CGFloat = 36
    @Environment(\.boardCosmetics) private var cosmetics

    var body: some View {
        let theme = cosmetics.themeStyle
        VStack(spacing: 1) {
            ForEach(0..<board.config.rows, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<board.config.cols, id: \.self) { col in
                        let cell = board.cells[row * board.config.cols + col]
                        MinesweeperCellView(cell: cell, size: cellSize)
                            .onTapGesture { onTap(row, col) }
                            .onLongPressGesture { onLongPress(row, col) }
                    }
                }
            }
        }
        .padding(4)
        .background(theme.cellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(theme.gridLineMajor.opacity(0.8), lineWidth: 1.5))
    }
}

struct MinesweeperCellView: View {
    let cell: MinesweeperCell
    let size: CGFloat
    @Environment(\.boardCosmetics) private var cosmetics

    private static let adjColors: [Color] = [
        .clear, .blue, .green, .red, .purple, .brown, .cyan, .black, .gray
    ]

    var body: some View {
        let theme = cosmetics.themeStyle
        ZStack {
            switch cell.state {
            case .hidden:
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.tileGradient)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.gridLineMinor.opacity(0.8), lineWidth: 1))
                    .shadow(color: theme.gridLineMajor.opacity(0.2), radius: 2)
            case .flagged:
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.tileGradient)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.activeTraceColor.opacity(0.9), lineWidth: 1.5))
                Text("🚩").font(.system(size: size * 0.55))
            case .exploded:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.red.opacity(0.8))
                Text("💥").font(.system(size: size * 0.55))
            case .revealed(let adj):
                RoundedRectangle(cornerRadius: 4)
                    .fill(cell.hasMine ? Color.red.opacity(0.5) : theme.cellBackground.opacity(0.92))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.gridLineMinor, lineWidth: 1))
                if cell.hasMine {
                    Text("💣").font(.system(size: size * 0.55))
                } else if adj > 0 {
                    Text("\(adj)")
                        .font(.system(size: size * 0.55, weight: .bold))
                        .foregroundStyle(Self.adjColors[adj])
                }
            }
        }
        .frame(width: size, height: size)
    }
}
