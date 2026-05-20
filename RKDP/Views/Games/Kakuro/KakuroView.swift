import SwiftUI

struct ColorLinkView: View {
    let difficulty: Difficulty
    let userID: String?
    let sessionID: String?
    let onMatchResult: (MatchPlayerResult) -> Void
    let onSoloResult: (SoloGameResult) -> Void
    let onPlayAgain: () -> Void
    let onChangeDifficulty: () -> Void
    let onTryRanked: () -> Void
    let onHome: () -> Void

    @StateObject private var vm: ColorLinkViewModel
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
        _vm = StateObject(wrappedValue: ColorLinkViewModel(difficulty: difficulty, seed: seed))
    }

    var body: some View {
        ZStack {
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
                    vm.beginDraw(row: row, col: col)
                } onContinue: { row, col in
                    vm.continueDraw(row: row, col: col)
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

            if let soloResult {
                SoloResultOverlay(result: soloResult, onPlayAgain: onPlayAgain, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            }
        }
        .navigationTitle("Color Link")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.isComplete) { _, complete in
            if complete {
                if sessionID == nil { showSoloResult() }
                reportMatchResult(status: "Board filled")
            }
        }
        .onChange(of: vm.elapsedSeconds) { _, seconds in
            if sessionID != nil && seconds >= difficulty.rankedTimeLimit(for: .colorLink) {
                reportMatchResult(status: "Time expired")
            }
        }
    }

    private func showSoloResult() {
        guard soloResult == nil else { return }
        let fillPercent = Int((vm.fillProgress * 100).rounded())
        let result = SoloGameResult(
            mode: .colorLink,
            difficulty: difficulty,
            completed: true,
            title: "Board Filled",
            message: "Every color path is connected.",
            elapsedSeconds: vm.elapsedSeconds,
            score: vm.filledCellCount,
            progress: vm.fillProgress,
            stats: [
                SoloResultStat(label: "Board Fill", value: "\(fillPercent)%"),
                SoloResultStat(label: "Pairs", value: "\(vm.solvedPairCount)/\(vm.board.pairs.count)"),
                SoloResultStat(label: "Time", value: formattedTime(vm.elapsedSeconds)),
                SoloResultStat(label: "Difficulty", value: difficulty.displayName)
            ]
        )
        soloResult = result
        onSoloResult(result)
    }

    private var activeStatus: String {
        if let activePairID = vm.activePairID {
            return "Color \(activePairID + 1) selected"
        }
        return "Drag from an endpoint to draw a path"
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
                "totalPairs": "\(vm.board.pairs.count)",
                "boardSize": "\(vm.board.size)",
                "boardRows": colorLinkBoardRows(board: vm.board, paths: vm.paths)
            ],
            details: [
                "\(vm.filledCellCount) of \(vm.board.totalCells) cells filled",
                "\(vm.solvedPairCount) of \(vm.board.pairs.count) color pairs connected"
            ]
        ))
    }
    private func colorLinkBoardRows(board: ColorLinkBoard, paths: [Int: [ColorLinkPosition]]) -> String {
        var owners = Array(repeating: Array(repeating: ".", count: board.size), count: board.size)
        for pair in board.pairs {
            let mark = colorLinkMark(pair.id)
            owners[pair.start.row][pair.start.col] = mark
            owners[pair.end.row][pair.end.col] = mark
        }
        for (pairID, path) in paths {
            let mark = colorLinkMark(pairID)
            for position in path where board.contains(position) {
                owners[position.row][position.col] = mark
            }
        }
        return owners.map { $0.joined() }.joined(separator: "/")
    }

    private func colorLinkMark(_ pairID: Int) -> String {
        let marks = Array("123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        guard marks.indices.contains(pairID) else { return "?" }
        return String(marks[pairID])
    }

}

struct ColorLinkBoardView: View {
    let board: ColorLinkBoard
    let paths: [Int: [ColorLinkPosition]]
    let activePairID: Int?
    let onBegin: (Int, Int) -> Void
    let onContinue: (Int, Int) -> Void

    @State private var isDragging = false

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
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let col = Int(value.location.x / cellSize)
                        let row = Int(value.location.y / cellSize)
                        guard row >= 0, row < board.size, col >= 0, col < board.size else { return }
                        if isDragging {
                            onContinue(row, col)
                        } else {
                            isDragging = true
                            onBegin(row, col)
                        }
                    }
                    .onEnded { _ in isDragging = false }
            )
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
