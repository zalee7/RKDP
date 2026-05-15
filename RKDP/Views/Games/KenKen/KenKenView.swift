import SwiftUI

struct GridlockView: View {
    let difficulty: Difficulty
    let userID: String?
    let sessionID: String?
    let onMatchResult: (MatchPlayerResult) -> Void
    let onSoloResult: (SoloGameResult) -> Void
    let onPlayAgain: () -> Void
    let onChangeDifficulty: () -> Void
    let onTryRanked: () -> Void
    let onHome: () -> Void

    @StateObject private var vm: GridlockViewModel
    @State private var soloResult: SoloGameResult?
    @State private var didReportMatchResult = false
    @State private var dragStepsByVehicle: [String: Int] = [:]

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
        _vm = StateObject(wrappedValue: GridlockViewModel(difficulty: difficulty, seed: seed))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
                HStack {
                    TimerView(seconds: vm.elapsedSeconds)
                    Spacer()
                    Label("\(vm.moveCount)", systemImage: "arrow.left.arrow.right")
                        .font(.headline)
                    Spacer()
                    Label("\(difficulty.displayName)", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(difficulty == .expert ? .orange : .secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                GridlockBoardView(
                    board: vm.board,
                    selectedVehicleID: vm.selectedVehicleID,
                    dragStepsByVehicle: $dragStepsByVehicle
                ) { vehicleID in
                    vm.selectVehicle(id: vehicleID)
                } onDrag: { vehicleID, steps in
                    vm.moveVehicle(id: vehicleID, steps: steps)
                }
                .padding(.horizontal)
                .aspectRatio(1, contentMode: .fit)

                Spacer(minLength: 0)
            }

            if let soloResult {
                SoloResultOverlay(result: soloResult, onPlayAgain: onPlayAgain, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            }
        }
        .navigationTitle("Gridlock")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.isComplete) { _, complete in
            if complete {
                if sessionID == nil { showSoloResult() }
                reportMatchResult(status: "Escaped")
            }
        }
        .onChange(of: vm.elapsedSeconds) { _, seconds in
            if sessionID != nil && seconds >= difficulty.rankedTimeLimit(for: .gridlock) {
                reportMatchResult(status: "Time expired")
            }
        }
    }

    private func showSoloResult() {
        guard soloResult == nil else { return }
        let result = SoloGameResult(
            mode: .gridlock,
            difficulty: difficulty,
            completed: true,
            title: "Gridlock Cleared",
            message: "The red car escaped.",
            elapsedSeconds: vm.elapsedSeconds,
            score: max(0, 500 - vm.moveCount),
            progress: vm.progress,
            moves: vm.moveCount,
            stats: [
                SoloResultStat(label: "Moves", value: "\(vm.moveCount)"),
                SoloResultStat(label: "Time", value: formattedTime(vm.elapsedSeconds)),
                SoloResultStat(label: "Progress", value: "\(Int((vm.progress * 100).rounded()))%"),
                SoloResultStat(label: "Difficulty", value: difficulty.displayName)
            ]
        )
        soloResult = result
        onSoloResult(result)
    }

    private func reportMatchResult(status: String) {
        guard !didReportMatchResult, sessionID != nil, let userID else { return }
        didReportMatchResult = true
        vm.stop()
        let progressPercent = Int((vm.progress * 100).rounded())
        onMatchResult(MatchPlayerResult(
            userID: userID,
            mode: .gridlock,
            completed: vm.isComplete,
            elapsedSeconds: vm.elapsedSeconds,
            score: max(0, 500 - vm.moveCount),
            progress: vm.progress,
            status: status,
            summary: [
                "moves": "\(vm.moveCount)",
                "escapeProgressPercent": "\(progressPercent)",
                "blockers": "\(vm.board.blockerCount)"
            ],
            details: [
                vm.isComplete ? "Escaped in \(vm.moveCount) moves" : "Reached \(progressPercent)% escape progress",
                "\(vm.board.blockerCount) blocker cells in the escape lane"
            ]
        ))
    }
}

struct GridlockBoardView: View {
    let board: GridlockBoard
    let selectedVehicleID: String?
    @Binding var dragStepsByVehicle: [String: Int]
    let onSelect: (String) -> Void
    let onDrag: (String, Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / CGFloat(board.size)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))

                ForEach(0..<board.size, id: \.self) { row in
                    ForEach(0..<board.size, id: \.self) { col in
                        Rectangle()
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                            .frame(width: cellSize, height: cellSize)
                            .offset(x: CGFloat(col) * cellSize, y: CGFloat(row) * cellSize)
                    }
                }

                ExitMarker(cellSize: cellSize)
                    .offset(x: CGFloat(board.size) * cellSize - 4, y: CGFloat(board.exitRow) * cellSize)

                ForEach(board.vehicles) { vehicle in
                    GridlockVehicleView(
                        vehicle: vehicle,
                        cellSize: cellSize,
                        isSelected: vehicle.id == selectedVehicleID
                    )
                    .offset(x: CGFloat(vehicle.col) * cellSize, y: CGFloat(vehicle.row) * cellSize)
                    .onTapGesture { onSelect(vehicle.id) }
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { value in
                                onSelect(vehicle.id)
                                let translation = vehicle.orientation == .horizontal ? value.translation.width : value.translation.height
                                let steps = Int(translation / (cellSize * 0.72))
                                let previous = dragStepsByVehicle[vehicle.id] ?? 0
                                let delta = steps - previous
                                if delta != 0 {
                                    dragStepsByVehicle[vehicle.id] = steps
                                    onDrag(vehicle.id, delta)
                                }
                            }
                            .onEnded { _ in
                                dragStepsByVehicle[vehicle.id] = 0
                            }
                    )
                }
            }
        }
    }
}

private struct ExitMarker: View {
    let cellSize: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.green.opacity(0.7))
            .frame(width: 8, height: cellSize)
            .overlay(
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            )
    }
}

private struct GridlockVehicleView: View {
    let vehicle: GridlockVehicle
    let cellSize: CGFloat
    let isSelected: Bool

    private var vehicleColor: Color {
        if vehicle.isTarget { return .red }
        let palette: [Color] = [.blue, .green, .orange, .purple, .cyan, .pink, .mint, .indigo]
        return palette[vehicle.colorIndex % palette.count]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(vehicleColor.gradient)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white : Color.black.opacity(0.16), lineWidth: isSelected ? 3 : 1)
            )
            .overlay(
                Image(systemName: vehicle.isTarget ? "car.fill" : "capsule.fill")
                    .foregroundStyle(.white.opacity(0.9))
                    .rotationEffect(vehicle.orientation == .vertical ? .degrees(90) : .zero)
            )
            .padding(3)
            .frame(
                width: cellSize * CGFloat(vehicle.orientation == .horizontal ? vehicle.length : 1),
                height: cellSize * CGFloat(vehicle.orientation == .vertical ? vehicle.length : 1)
            )
            .shadow(color: vehicleColor.opacity(isSelected ? 0.45 : 0.2), radius: isSelected ? 8 : 3)
    }
}
