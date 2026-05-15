import Foundation
import Combine

@MainActor
final class ColorLinkViewModel: ObservableObject {
    @Published var board: ColorLinkBoard
    @Published var activePairID: Int?
    @Published var paths: [Int: [ColorLinkPosition]] = [:]
    @Published var elapsedSeconds: Int = 0
    @Published var isComplete = false

    let difficulty: Difficulty
    private var timer: AnyCancellable?

    var occupiedPositions: Set<ColorLinkPosition> {
        var occupied = Set<ColorLinkPosition>()
        for pair in board.pairs {
            occupied.insert(pair.start)
            occupied.insert(pair.end)
        }
        for path in paths.values {
            occupied.formUnion(path)
        }
        return occupied
    }

    var filledCellCount: Int { occupiedPositions.count }
    var fillProgress: Double { Double(filledCellCount) / Double(max(1, board.totalCells)) }
    var solvedPairCount: Int { board.pairs.filter { isPairConnected($0.id) }.count }

    init(difficulty: Difficulty, seed: Int? = nil) {
        self.difficulty = difficulty
        self.board = ColorLinkGenerator.generate(difficulty: difficulty, seed: seed)
        startTimer()
    }

    func beginDraw(row: Int, col: Int) {
        guard !isComplete else { return }
        let position = ColorLinkPosition(row: row, col: col)
        guard board.contains(position), let endpointPairID = board.pairID(at: position) else { return }
        activePairID = endpointPairID
        paths[endpointPairID] = [position]
    }

    func continueDraw(row: Int, col: Int) {
        guard !isComplete else { return }
        let position = ColorLinkPosition(row: row, col: col)
        guard board.contains(position), let activePairID else { return }

        if let endpointPairID = board.pairID(at: position), endpointPairID != activePairID { return }
        extendActivePath(to: position, pairID: activePairID)

        checkCompletion()
    }

    func clearActivePath() {
        guard let activePairID else { return }
        paths[activePairID] = nil
    }

    private func extendActivePath(to position: ColorLinkPosition, pairID: Int) {
        guard owner(of: position) == nil || owner(of: position) == pairID else { return }
        guard var path = paths[pairID], let last = path.last else { return }

        if let existingIndex = path.firstIndex(of: position) {
            paths[pairID] = Array(path.prefix(existingIndex + 1))
            return
        }

        guard position.isAdjacent(to: last) else { return }
        path.append(position)
        paths[pairID] = path
    }

    private func owner(of position: ColorLinkPosition) -> Int? {
        for (pairID, path) in paths where path.contains(position) {
            return pairID
        }
        return board.pairID(at: position)
    }

    private func isPairConnected(_ pairID: Int) -> Bool {
        guard let pair = board.pair(for: pairID), let path = paths[pairID], path.count >= 2 else { return false }
        let endpoints = Set([pair.start, pair.end])
        guard let first = path.first, let last = path.last else { return false }
        return endpoints.contains(first) && endpoints.contains(last) && first != last
    }

    private func checkCompletion() {
        if solvedPairCount == board.pairs.count && filledCellCount == board.totalCells {
            isComplete = true
            timer?.cancel()
        }
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    func stop() { timer?.cancel() }
}
