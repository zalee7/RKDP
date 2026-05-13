import SwiftUI

struct SudokuView: View {
    let difficulty: Difficulty
    let sessionID: String?

    @StateObject private var vm: SudokuViewModel
    @State private var showComplete = false

    init(difficulty: Difficulty, sessionID: String?) {
        self.difficulty = difficulty
        self.sessionID = sessionID
        _vm = StateObject(wrappedValue: SudokuViewModel(difficulty: difficulty))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                TimerView(seconds: vm.elapsedSeconds)
                Spacer()
                Label("\(difficulty.displayName)", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(difficulty == .expert ? .orange : .secondary)
                Spacer()
                Button { vm.useHint() } label: {
                    Label("Hint", systemImage: "lightbulb.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Board
            SudokuBoardView(board: vm.board, selectedID: vm.selectedID) { id in
                vm.selectCell(id: id)
            }
            .padding(12)
            .aspectRatio(1, contentMode: .fit)

            Divider()

            // Number pad
            NumberPadView(
                size: 9,
                onDigit: { vm.enterDigit($0) },
                onErase: { vm.erase() },
                onNote: { vm.isNoteMode.toggle() },
                isNoteMode: vm.isNoteMode
            )
            .padding(.vertical, 12)
        }
        .navigationTitle("Sudoku")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.isComplete) { _, complete in
            if complete { showComplete = true }
        }
        .alert("Puzzle Complete! 🎉", isPresented: $showComplete) {
            Button("OK") {}
        } message: {
            Text("Solved in \(vm.elapsedSeconds / 60)m \(vm.elapsedSeconds % 60)s")
        }
    }
}

struct SudokuBoardView: View {
    let board: SudokuBoard
    let selectedID: Int?
    let onSelect: (Int) -> Void

    private let thickBorder: CGFloat = 2.5
    private let thinBorder: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / 9
            Canvas { context, size in
                // Draw grid lines
                for i in 0...9 {
                    let x = CGFloat(i) * cellSize
                    let y = CGFloat(i) * cellSize
                    let lw: CGFloat = (i % 3 == 0) ? thickBorder : thinBorder
                    let color = Color.primary.opacity(i % 3 == 0 ? 1 : 0.3)

                    context.stroke(Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)) },
                                   with: .color(color), lineWidth: lw)
                    context.stroke(Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)) },
                                   with: .color(color), lineWidth: lw)
                }
            }
            .overlay(
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 9), spacing: 0) {
                    ForEach(board.cells) { cell in
                        SudokuCellView(cell: cell, cellSize: cellSize)
                            .onTapGesture { onSelect(cell.id) }
                    }
                }
            )
        }
    }
}

struct SudokuCellView: View {
    let cell: SudokuCell
    let cellSize: CGFloat

    private var bg: Color {
        if cell.isSelected    { return .blue.opacity(0.35) }
        if cell.isInvalid     { return .red.opacity(0.2) }
        if cell.isHighlighted { return .blue.opacity(0.1) }
        return .clear
    }

    var body: some View {
        ZStack {
            bg
            if cell.value != 0 {
                Text("\(cell.value)")
                    .font(.system(size: cellSize * 0.55, weight: cell.isGiven ? .bold : .regular))
                    .foregroundStyle(cell.isInvalid ? .red : (cell.isGiven ? .primary : .blue))
            } else if !cell.notes.isEmpty {
                noteGrid
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    private var noteGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)
        return LazyVGrid(columns: cols, spacing: 0) {
            ForEach(1...9, id: \.self) { n in
                Text(cell.notes.contains(n) ? "\(n)" : " ")
                    .font(.system(size: cellSize * 0.18))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
