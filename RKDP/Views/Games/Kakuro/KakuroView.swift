import SwiftUI

struct ColorLinkView: View {
    let difficulty: Difficulty
    let userID: String?
    let sessionID: String?
    let onMatchResult: (MatchPlayerResult) -> Void

    @StateObject private var vm: ColorLinkViewModel
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
        _vm = StateObject(wrappedValue: ColorLinkViewModel(difficulty: difficulty, seed: seed))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                TimerView(seconds: vm.elapsedSeconds)
                Spacer()
                Label("\(Int((vm.fillProgress * 100).rounded()))%", systemImage: "square.grid.3x3.fill")
                    .font(.headline)
                Spacer()
                Label("\(vm.solvedPairCount)/\(vm.board.pairs.count)", systemImage: "link")
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ColorLinkBoardView(
                board: vm.board,
                paths: vm.paths,
                activePairID: vm.activePairID
            ) { row, col in
                vm.tap(row: row, col: col)
            }
            .padding(.horizontal)
            .aspectRatio(1, contentMode: .fit)

            HStack {
                Text(activeStatus)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { vm.clearActivePath() } label: {
                    Label("Clear", systemImage: "eraser.fill")
                }
                .buttonStyle(.bordered)
                .disabled(vm.activePairID == nil)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Spacer(minLength: 0)
        }
        .navigationTitle("Color Link")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.isComplete) { _, complete in
            if complete {
                showComplete = sessionID == nil
                reportMatchResult(status: "Board filled")
            }
        }
        .onChange(of: vm.elapsedSeconds) { _, seconds in
            if sessionID != nil && seconds >= difficulty.rankedTimeLimit(for: .colorLink) {
                reportMatchResult(status: "Time expired")
            }
        }
        .alert("Color Link Complete", isPresented: $showComplete) {
            Button("OK") {}
        } message: {
            Text("Filled the board in \(vm.elapsedSeconds / 60)m \(vm.elapsedSeconds % 60)s.")
        }
    }

    private var activeStatus: String {
        if let activePairID = vm.activePairID {
            return "Color \(activePairID + 1) selected"
        }
        return "Tap an endpoint to start a path"
    }

    private func reportMatchResult(status: String) {
        guard !didReportMatchResult, sessionID != nil, let userID else { return }
        didReportMatchResult = true
        vm.stop()
        let fillPercent = Int((vm.fillProgress * 100).rounded())
        onMatchResult(MatchPlayerResult(
            userID: userID,
            mode: .colorLink,
            completed: vm.isComplete,
            elapsedSeconds: vm.elapsedSeconds,
            score: vm.filledCellCount,
            progress: vm.fillProgress,
            status: status,
            summary: [
                "fillPercent": "\(fillPercent)",
                "filledCells": "\(vm.filledCellCount)",
                "totalCells": "\(vm.board.totalCells)",
                "solvedPairs": "\(vm.solvedPairCount)",
                "totalPairs": "\(vm.board.pairs.count)"
            ],
            details: [
                "\(vm.filledCellCount) of \(vm.board.totalCells) cells filled",
                "\(vm.solvedPairCount) of \(vm.board.pairs.count) color pairs connected"
            ]
        ))
    }
}

struct ColorLinkBoardView: View {
    let board: ColorLinkBoard
    let paths: [Int: [ColorLinkPosition]]
    let activePairID: Int?
    let onTap: (Int, Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / CGFloat(board.size)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))

                ForEach(0..<board.size, id: \.self) { row in
                    ForEach(0..<board.size, id: \.self) { col in
                        let position = ColorLinkPosition(row: row, col: col)
                        ColorLinkCellView(
                            position: position,
                            pairID: owner(of: position),
                            isEndpoint: board.pairID(at: position) != nil,
                            isActive: owner(of: position) == activePairID,
                            cellSize: cellSize
                        )
                        .offset(x: CGFloat(col) * cellSize, y: CGFloat(row) * cellSize)
                        .onTapGesture { onTap(row, col) }
                    }
                }
            }
        }
    }

    private func owner(of position: ColorLinkPosition) -> Int? {
        for (pairID, path) in paths where path.contains(position) {
            return pairID
        }
        return board.pairID(at: position)
    }
}

private struct ColorLinkCellView: View {
    let position: ColorLinkPosition
    let pairID: Int?
    let isEndpoint: Bool
    let isActive: Bool
    let cellSize: CGFloat

    private var color: Color {
        guard let pairID else { return Color(.systemBackground) }
        let palette: [Color] = [.red, .blue, .green, .orange, .purple, .cyan, .pink, .mint]
        return palette[pairID % palette.count]
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemBackground))
                .overlay(Rectangle().stroke(Color.secondary.opacity(0.16), lineWidth: 1))

            if pairID != nil {
                RoundedRectangle(cornerRadius: isEndpoint ? cellSize * 0.28 : cellSize * 0.16)
                    .fill(color.gradient)
                    .frame(
                        width: isEndpoint ? cellSize * 0.72 : cellSize * 0.58,
                        height: isEndpoint ? cellSize * 0.72 : cellSize * 0.58
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: isEndpoint ? cellSize * 0.28 : cellSize * 0.16)
                            .stroke(isActive ? Color.white : Color.black.opacity(0.12), lineWidth: isActive ? 3 : 1)
                    )
            }
        }
        .frame(width: cellSize, height: cellSize)
    }
}
