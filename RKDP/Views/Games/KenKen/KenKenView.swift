import SwiftUI

struct KenKenView: View {
    let difficulty: Difficulty
    let sessionID: String?

    @StateObject private var vm: KenKenViewModel
    @State private var showComplete = false

    init(difficulty: Difficulty, sessionID: String?) {
        self.difficulty = difficulty
        self.sessionID = sessionID
        _vm = StateObject(wrappedValue: KenKenViewModel(difficulty: difficulty))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TimerView(seconds: vm.elapsedSeconds)
                Spacer()
                Text("KenKen \(vm.board.size)×\(vm.board.size) · \(difficulty.displayName)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            KenKenBoardView(board: vm.board, selectedID: vm.selectedID) { id in
                vm.selectCell(id: id)
            }
            .padding(12)
            .aspectRatio(1, contentMode: .fit)

            Divider()

            NumberPadView(
                size: vm.board.size,
                onDigit: { vm.enterDigit($0) },
                onErase: { vm.erase() },
                onNote: { vm.isNoteMode.toggle() },
                isNoteMode: vm.isNoteMode
            )
            .padding(.vertical, 12)
        }
        .navigationTitle("KenKen")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.isComplete) { _, v in if v { showComplete = true } }
        .alert("KenKen Solved! 🎉", isPresented: $showComplete) { Button("OK") {} }
    }
}

struct KenKenBoardView: View {
    let board: KenKenBoard
    let selectedID: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / CGFloat(board.size)
            ZStack {
                // Cells
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: board.size),
                    spacing: 0
                ) {
                    ForEach(board.cells) { cell in
                        KenKenCellView(
                            cell: cell,
                            cage: board.cages[cell.cageID],
                            cellSize: cellSize,
                            isSelected: cell.id == selectedID
                        )
                        .onTapGesture { onSelect(cell.id) }
                    }
                }

                // Thick cage borders drawn on top
                CageBordersView(board: board, cellSize: cellSize)
            }
        }
    }
}

struct KenKenCellView: View {
    let cell: KenKenCell
    let cage: KenKenCage
    let cellSize: CGFloat
    let isSelected: Bool

    private var bg: Color {
        if isSelected    { return .orange.opacity(0.35) }
        if cell.isInvalid { return .red.opacity(0.2) }
        return .white
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            bg
            // Thin inner border
            Rectangle().stroke(Color(.systemGray4), lineWidth: 0.5)

            if cell.isTopLeft {
                Text("\(cage.target)\(cage.operation.rawValue)")
                    .font(.system(size: cellSize * 0.22, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(2)
            }

            if cell.value != 0 {
                Text("\(cell.value)")
                    .font(.system(size: cellSize * 0.5, weight: .medium))
                    .foregroundStyle(cell.isInvalid ? .red : .primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: cellSize, height: cellSize)
    }
}

// Draws thick borders around cage boundaries
struct CageBordersView: View {
    let board: KenKenBoard
    let cellSize: CGFloat

    var body: some View {
        Canvas { context, _ in
            for cage in board.cages {
                let path = cageBorderPath(cage: cage)
                context.stroke(path, with: .color(.primary), lineWidth: 2.5)
            }
        }
        .allowsHitTesting(false)
    }

    private func cageBorderPath(cage: KenKenCage) -> Path {
        let ids = Set(cage.cellIDs)
        var path = Path()
        let s = board.size

        for id in cage.cellIDs {
            let r = id / s, c = id % s
            let x = CGFloat(c) * cellSize, y = CGFloat(r) * cellSize

            // Top edge
            if !ids.contains((r-1)*s+c) {
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + cellSize, y: y))
            }
            // Bottom edge
            if !ids.contains((r+1)*s+c) {
                path.move(to: CGPoint(x: x, y: y + cellSize))
                path.addLine(to: CGPoint(x: x + cellSize, y: y + cellSize))
            }
            // Left edge
            if !ids.contains(r*s+(c-1)) {
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + cellSize))
            }
            // Right edge
            if !ids.contains(r*s+(c+1)) {
                path.move(to: CGPoint(x: x + cellSize, y: y))
                path.addLine(to: CGPoint(x: x + cellSize, y: y + cellSize))
            }
        }
        return path
    }
}
