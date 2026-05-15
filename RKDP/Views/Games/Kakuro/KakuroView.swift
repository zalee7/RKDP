import SwiftUI

struct KakuroView: View {
    let difficulty: Difficulty
    let userID: String?
    let sessionID: String?
    let onMatchResult: (MatchPlayerResult) -> Void

    @StateObject private var vm: KakuroViewModel
    @State private var showComplete = false
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
        _vm = StateObject(wrappedValue: KakuroViewModel(difficulty: difficulty, seed: seed))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TimerView(seconds: vm.elapsedSeconds)
                Spacer()
                Text(difficulty.displayName).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            KakuroBoardView(board: vm.board, selectedID: vm.selectedID) { id in
                vm.selectCell(id: id)
            }
            .padding(12)
            .aspectRatio(1, contentMode: .fit)

            Divider()

            NumberPadView(
                size: 9,
                onDigit: { vm.enterDigit($0) },
                onErase: { vm.erase() },
                onNote: { vm.isNoteMode.toggle() },
                isNoteMode: vm.isNoteMode
            )
            .padding(.vertical, 12)
        }
        .navigationTitle("Kakuro")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.isComplete) { _, v in
            if v {
                showComplete = sessionID == nil
                reportMatchResult(status: "Solved")
            }
        }
        .onChange(of: vm.elapsedSeconds) { _, seconds in
            if sessionID != nil && seconds >= difficulty.rankedTimeLimit(for: .kakuro) {
                reportMatchResult(status: "Time expired")
            }
        }
        .alert("Kakuro Solved! 🎉", isPresented: $showComplete) { Button("OK") {} }
    }

    private func reportMatchResult(status: String) {
        guard !didReportMatchResult, sessionID != nil, let userID else { return }
        didReportMatchResult = true
        vm.stop()
        onMatchResult(MatchPlayerResult(
            userID: userID,
            mode: .kakuro,
            completed: vm.isComplete,
            elapsedSeconds: vm.elapsedSeconds,
            score: Int((vm.progress * 100).rounded()),
            progress: vm.progress,
            status: status,
            summary: ["progressPercent": "\(Int((vm.progress * 100).rounded()))"],
            details: [
                vm.isComplete ? "Completed the Kakuro" : "Reached \(Int((vm.progress * 100).rounded()))% progress"
            ]
        ))
    }
}

struct KakuroBoardView: View {
    let board: KakuroBoard
    let selectedID: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / CGFloat(board.cols)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: board.cols), spacing: 1) {
                ForEach(board.cells) { cell in
                    KakuroCellView(cell: cell, cellSize: cellSize, isSelected: cell.id == selectedID)
                        .onTapGesture { onSelect(cell.id) }
                }
            }
        }
    }
}

struct KakuroCellView: View {
    let cell: KakuroCell
    let cellSize: CGFloat
    let isSelected: Bool

    var body: some View {
        ZStack {
            switch cell.type {
            case .black:
                Rectangle().fill(Color(.systemGray))
            case .white(let ac, let dc):
                // Clue cell: split diagonally
                ZStack {
                    Rectangle().fill(Color(.systemGray2))
                    if let ac, let dc {
                        ClueCell(across: ac, down: dc, size: cellSize)
                    } else if let ac {
                        Text("\(ac)").font(.system(size: cellSize * 0.28)).bold()
                            .foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(2)
                    } else if let dc {
                        Text("\(dc)").font(.system(size: cellSize * 0.28)).bold()
                            .foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(2)
                    }
                }
            case .entry:
                Rectangle()
                    .fill(isSelected ? Color.green.opacity(0.3) : (cell.isInvalid ? Color.red.opacity(0.2) : Color.white))
                if cell.value != 0 {
                    Text("\(cell.value)")
                        .font(.system(size: cellSize * 0.5, weight: .semibold))
                        .foregroundStyle(cell.isInvalid ? .red : .primary)
                }
            }
        }
        .frame(width: cellSize, height: cellSize)
        .border(Color(.systemGray4), width: 0.5)
    }
}

struct ClueCell: View {
    let across: Int
    let down: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            // Diagonal divider
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: size, y: size))
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)

            Text("\(across)")
                .font(.system(size: size * 0.26, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(2)

            Text("\(down)")
                .font(.system(size: size * 0.26, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(2)
        }
    }
}
