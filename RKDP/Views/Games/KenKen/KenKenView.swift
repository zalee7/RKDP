import SwiftUI

struct GridlockView: View {
    let difficulty: Difficulty
    let userID: String?
    let sessionID: String?
    let onMatchResult: (MatchPlayerResult) -> Void

    @StateObject private var vm: GridlockViewModel
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
        _vm = StateObject(wrappedValue: GridlockViewModel(difficulty: difficulty, seed: seed))
    }

    var body: some View {
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

            GridlockBoardView(board: vm.board, selectedVehicleID: vm.selectedVehicleID) { vehicleID in
                vm.selectVehicle(id: vehicleID)
            }
            .padding(.horizontal)
            .aspectRatio(1, contentMode: .fit)

            GridlockControlsView(board: vm.board, selectedVehicleID: vm.selectedVehicleID) { delta in
                vm.moveSelected(delta: delta)
            }
            .padding(.horizontal)

            Spacer(minLength: 0)
        }
        .navigationTitle("Gridlock")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.isComplete) { _, complete in
            if complete {
                showComplete = sessionID == nil
                reportMatchResult(status: "Escaped")
            }
        }
        .onChange(of: vm.elapsedSeconds) { _, seconds in
            if sessionID != nil && seconds >= difficulty.rankedTimeLimit(for: .gridlock) {
                reportMatchResult(status: "Time expired")
            }
        }
        .alert("Gridlock Cleared", isPresented: $showComplete) {
            Button("OK") {}
        } message: {
            Text("Escaped in \(vm.moveCount) moves.")
        }
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
    let onSelect: (String) -> Void

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

private struct GridlockControlsView: View {
    let board: GridlockBoard
    let selectedVehicleID: String?
    let onMove: (Int) -> Void

    private var selectedVehicle: GridlockVehicle? {
        guard let selectedVehicleID else { return nil }
        return board.vehicles.first { $0.id == selectedVehicleID }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(selectedVehicle?.isTarget == true ? "Red car selected" : "Select a piece, then slide it")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let selectedVehicle {
                HStack(spacing: 16) {
                    if selectedVehicle.orientation == .horizontal {
                        moveButton(systemName: "arrow.left", delta: -1)
                        moveButton(systemName: "arrow.right", delta: 1)
                    } else {
                        moveButton(systemName: "arrow.up", delta: -1)
                        moveButton(systemName: "arrow.down", delta: 1)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func moveButton(systemName: String, delta: Int) -> some View {
        Button { onMove(delta) } label: {
            Image(systemName: systemName)
                .font(.title2.bold())
                .frame(width: 56, height: 44)
        }
        .buttonStyle(.borderedProminent)
    }
}
