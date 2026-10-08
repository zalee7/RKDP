import SwiftUI

struct SudokuView: View {
    let difficulty: Difficulty
    let userID: String?
    let sessionID: String?
    let onMatchResult: (MatchPlayerResult) -> Void
    let onSoloResult: (SoloGameResult) -> Void
    let onPlayAgain: () -> Void
    let onChangeDifficulty: () -> Void
    let onTryRanked: () -> Void
    let onHome: () -> Void

    @StateObject private var vm: SudokuViewModel
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
        _vm = StateObject(wrappedValue: SudokuViewModel(difficulty: difficulty, seed: seed))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    TimerView(seconds: vm.elapsedSeconds)
                    Spacer()
                    Label("\(difficulty.displayName)", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(difficulty == .expert ? AppTheme.warning : AppTheme.textSecondary)
                    Spacer()
                    if sessionID == nil {
                        Button { vm.useHint() } label: {
                            Label("Hint", systemImage: "lightbulb.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Board
                SudokuBoardView(board: vm.board, selectedID: vm.selectedID) { id in
                    vm.selectCell(id: id)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .aspectRatio(1, contentMode: .fit)

                Divider()

                // Number pad
                NumberPadView(
                    size: 9,
                    onDigit: {
                        vm.enterDigit($0)
                        reportMatchProgress()
                    },
                    onErase: {
                        vm.erase()
                        reportMatchProgress()
                    },
                    onNote: { vm.isNoteMode.toggle() },
                    isNoteMode: vm.isNoteMode
                )
                .padding(.vertical, 12)
            }
            .disabled(vm.isComplete || didReportMatchResult)
            .allowsHitTesting(!vm.isComplete && !didReportMatchResult)

            if let soloResult {
                SoloResultOverlay(
                    result: soloResult,
                    onPlayAgain: onPlayAgain,
                    onChangeDifficulty: onChangeDifficulty,
                    onTryRanked: onTryRanked,
                    onHome: onHome
                )
            }
        }
        .navigationTitle("Sudoku")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { vm.stop() }
        .onChange(of: vm.isComplete) { _, complete in
            if complete {
                if sessionID == nil { showSoloResult() }
                reportMatchResult(status: "Solved")
            }
        }
        .onChange(of: vm.elapsedSeconds) { _, seconds in
            if sessionID != nil && seconds >= difficulty.rankedTimeLimit(for: .sudoku) {
                reportMatchResult(status: "Time expired")
            }
        }
    }

    private func showSoloResult() {
        guard soloResult == nil else { return }
        let result = SoloGameResult(
            mode: .sudoku,
            difficulty: difficulty,
            completed: true,
            title: "Sudoku Solved",
            message: vm.hintsUsed == 0 ? "Solved \(difficulty.displayName) without hints." : "Solved \(difficulty.displayName) with \(vm.hintsUsed) hint\(vm.hintsUsed == 1 ? "" : "s").",
            elapsedSeconds: vm.elapsedSeconds,
            score: nil,
            progress: vm.progress,
            stats: [
                SoloResultStat(label: "Time", value: formattedTime(vm.elapsedSeconds)),
                SoloResultStat(label: "Hints", value: "\(vm.hintsUsed)"),
                SoloResultStat(label: "Conflicts", value: "\(vm.mistakeCount)"),
                SoloResultStat(label: "Filled", value: "81/81")
            ],
            details: ["Conflicts count entries that duplicated a number in a row, column, or box."],
            rewardEvidenceJSON: SoloCoinRewards.evidence(["cells": vm.board.cells.map(\.value)])
        )
        soloResult = result
        onSoloResult(result)
    }

    private func reportMatchProgress() {
        guard !vm.isComplete else { return }
        reportMatchResult(status: "In progress", isFinal: false)
    }

    private func reportMatchResult(status: String, isFinal: Bool = true) {
        guard !didReportMatchResult, sessionID != nil, let userID else { return }
        if isFinal {
            didReportMatchResult = true
            vm.stop()
        }
        onMatchResult(MatchPlayerResult(
            userID: userID,
            mode: .sudoku,
            completed: vm.isComplete,
            elapsedSeconds: vm.elapsedSeconds,
            score: Int((vm.progress * 100).rounded()),
            progress: vm.progress,
            status: status,
            summary: [
                "progressPercent": "\(Int((vm.progress * 100).rounded()))",
                "boardRows": sudokuBoardRows(vm.board),
                "boardSize": "9",
                "isFinal": isFinal ? "true" : "false"
            ],
            details: [
                vm.isComplete ? "Completed the Sudoku" : "Reached \(Int((vm.progress * 100).rounded()))% progress"
            ],
            rewardEvidenceJSON: GameSession.needsMatchEvidence(sessionID) ? SoloCoinRewards.evidence(["cells": vm.board.cells.map(\.value)]) : nil
        ))
    }
    private func sudokuBoardRows(_ board: SudokuBoard) -> String {
        (0..<9).map { row in
            (0..<9).map { col -> String in
                let value = board[row, col].value
                return value == 0 ? "." : "\(value)"
            }.joined()
        }.joined(separator: "/")
    }

}

struct SudokuBoardView: View {
    let board: SudokuBoard
    let selectedID: Int?
    let onSelect: (Int) -> Void
    private let thickBorder: CGFloat = 2.2
    private let thinBorder: CGFloat = 0.65

    var body: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / 9
            ZStack {
                Color.white

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 9), spacing: 0) {
                    ForEach(board.cells) { cell in
                        Button { onSelect(cell.id) } label: {
                            SudokuCellView(cell: cell, cellSize: cellSize)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Row \(cell.id / 9 + 1), column \(cell.id % 9 + 1)")
                        .accessibilityValue(cell.value == 0 ? "Empty" : "\(cell.value)")
                    }
                }

                Canvas { context, size in
                    for i in 0...9 {
                        let x = CGFloat(i) * cellSize
                        let y = CGFloat(i) * cellSize
                        let isBoxLine = i % 3 == 0
                        let lineWidth = isBoxLine ? thickBorder : thinBorder
                        let color = isBoxLine ? AppTheme.plum.opacity(0.72) : AppTheme.plum.opacity(0.18)

                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                            },
                            with: .color(color),
                            lineWidth: lineWidth
                        )
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: size.width, y: y))
                            },
                            with: .color(color),
                            lineWidth: lineWidth
                        )
                    }
                }
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.plum.opacity(0.72), lineWidth: 1.8)
            )
            .shadow(color: AppTheme.softShadow, radius: 8, x: 0, y: 4)
        }
    }
}

struct SudokuCellView: View {
    let cell: SudokuCell
    let cellSize: CGFloat
    @Environment(\.boardCosmetics) var cosmetics

    private var bg: Color {
        if cell.isSelected { return AppTheme.royalBlue.opacity(0.30) }
        if cell.isInvalid { return AppTheme.danger.opacity(0.20) }
        if cell.isHighlighted { return AppTheme.royalBlue.opacity(0.10) }
        if cell.value != 0 && !cell.isGiven { return AppTheme.teal.opacity(0.08) }
        return .clear
    }

    var body: some View {
        let fs = cosmetics.fontStyle
        ZStack {
            bg
            if cell.value != 0 {
                Text("\(cell.value)")
                    .font(.system(size: cellSize * 0.55,
                                  weight: cell.isGiven ? .bold : fs.weight,
                                  design: fs.design))
                    .foregroundStyle(cell.isInvalid ? AppTheme.danger : (cell.isGiven ? AppTheme.textPrimary : AppTheme.teal))
            } else if !cell.notes.isEmpty {
                noteGrid(fs: fs)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .contentShape(Rectangle())
    }

    private func noteGrid(fs: NumberFontStyle) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)
        return LazyVGrid(columns: cols, spacing: 0) {
            ForEach(1...9, id: \.self) { n in
                Text(cell.notes.contains(n) ? "\(n)" : " ")
                    .font(.system(size: cellSize * 0.18, weight: fs.weight, design: fs.design))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}
