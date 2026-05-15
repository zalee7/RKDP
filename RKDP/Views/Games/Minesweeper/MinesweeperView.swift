import SwiftUI

struct MinesweeperView: View {
    let difficulty: Difficulty
    let sessionID: String?

    @StateObject private var vm: MinesweeperViewModel

    init(difficulty: Difficulty, sessionID: String?, seed: Int? = nil) {
        self.difficulty = difficulty
        self.sessionID = sessionID
        _vm = StateObject(wrappedValue: MinesweeperViewModel(difficulty: difficulty, seed: seed))
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
                Text("You Won! 🎉").font(.title.bold()).foregroundStyle(.green).padding()
            } else if vm.status == .lost {
                Text("Game Over 💥").font(.title.bold()).foregroundStyle(.red).padding()
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

            if vm.isFinished {
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
