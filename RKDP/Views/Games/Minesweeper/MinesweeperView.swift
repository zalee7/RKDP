import SwiftUI

struct MinesweeperView: View {
    let difficulty: Difficulty
    let userID: String?
    let sessionID: String?
    let onMatchResult: (MatchPlayerResult) -> Void

    @StateObject private var vm: MinesweeperViewModel
    @State private var didReportMatchResult = false

    init(
        difficulty: Difficulty,
        userID: String? = nil,
        sessionID: String?,
        seed: Int? = nil,
        onMatchResult: @escaping (MatchPlayerResult) -> Void = { _ in }
    ) {
        self.difficulty = difficulty
        self.userID = userID
        self.sessionID = sessionID
        self.onMatchResult = onMatchResult
        _vm = StateObject(wrappedValue: MinesweeperViewModel(difficulty: difficulty, seed: seed, ranked: sessionID != nil))
    }

    var body: some View {
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
                Text(sessionID == nil ? "You Won! 🎉" : "Board Cleared")
                    .font(.title.bold()).foregroundStyle(.green).padding()
            } else if vm.status == .lost {
                Text(sessionID == nil ? "Game Over 💥" : "Mine Hit")
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

            if vm.isFinished && sessionID == nil {
                Button { vm.restart() } label: {
                    Label("New Game", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
        }
        .navigationTitle("Minesweeper")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.status) { _, status in
            if status == .won || status == .lost { reportMatchResult() }
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
