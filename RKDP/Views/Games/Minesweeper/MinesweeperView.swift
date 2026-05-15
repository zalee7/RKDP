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

                if vm.status == .won {
                    Text(sessionID == nil ? "Board Cleared" : "Board Cleared")
                        .font(.title.bold()).foregroundStyle(.green).padding()
                } else if vm.status == .lost {
                    Text(sessionID == nil ? "Mine Hit" : "Mine Hit")
                        .font(.title.bold()).foregroundStyle(.red).padding()
                }

                // Board
                ScrollView([.horizontal, .vertical]) {
                    MinesweeperGridView(board: vm.board) { row, col in
                        vm.tap(row: row, col: col)
                    } onLongPress: { row, col in
                        vm.longPress(row: row, col: col)
                    }
                    .padding(8)
                }
            }

            if let soloResult {
                SoloResultOverlay(result: soloResult, onPlayAgain: onPlayAgain, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            }
        }
        .navigationTitle("Minesweeper")
        .navigationBarTitleDisplayMode(.inline)
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

    private func reportMatchResult() {
        guard !didReportMatchResult, sessionID != nil, let userID else { return }
        didReportMatchResult = true
        vm.stop()
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
                "totalSafeCells": "\(vm.board.safeCells)"
            ],
            details: [
                "\(vm.board.revealedCount) of \(vm.board.safeCells) safe cells revealed",
                hitMine ? "Mine hit" : (completed ? "Board cleared" : "No mine hit")
            ]
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
            ]
        )
        soloResult = result
        onSoloResult(result)
    }
}

struct MinesweeperGridView: View {
    let board: MinesweeperBoard
    let onTap: (Int, Int) -> Void
    let onLongPress: (Int, Int) -> Void

    private let cellSize: CGFloat = 36

    var body: some View {
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
    }
}

struct MinesweeperCellView: View {
    let cell: MinesweeperCell
    let size: CGFloat

    private static let adjColors: [Color] = [
        .clear, .blue, .green, .red, .purple, .brown, .cyan, .black, .gray
    ]

    var body: some View {
        ZStack {
            switch cell.state {
            case .hidden:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
            case .flagged:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                Text("🚩").font(.system(size: size * 0.55))
            case .exploded:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.red.opacity(0.8))
                Text("💥").font(.system(size: size * 0.55))
            case .revealed(let adj):
                RoundedRectangle(cornerRadius: 4)
                    .fill(cell.hasMine ? Color.red.opacity(0.5) : Color(.systemGray6))
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
