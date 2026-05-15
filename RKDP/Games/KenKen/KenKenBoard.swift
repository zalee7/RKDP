import Foundation

enum GridlockOrientation: String, Codable {
    case horizontal
    case vertical
}

struct GridlockVehicle: Identifiable, Codable, Equatable {
    var id: String
    var row: Int
    var col: Int
    var length: Int
    var orientation: GridlockOrientation
    var isTarget: Bool
    var colorIndex: Int
}

struct GridlockBoard: Codable, Equatable {
    var size: Int
    var exitRow: Int
    var vehicles: [GridlockVehicle]

    var target: GridlockVehicle? {
        vehicles.first { $0.isTarget }
    }

    var isSolved: Bool {
        guard let target else { return false }
        return target.orientation == .horizontal && target.row == exitRow && target.col + target.length == size
    }

    var blockerCount: Int {
        guard let target else { return 0 }
        let startCol = target.col + target.length
        guard startCol < size else { return 0 }
        return (startCol..<size).filter { col in
            guard let vehicle = vehicle(atRow: exitRow, col: col) else { return false }
            return vehicle.id != target.id
        }.count
    }

    var escapeProgress: Double {
        guard let target else { return 0 }
        if isSolved { return 1 }
        let exitDistance = max(0, size - (target.col + target.length))
        let penalty = exitDistance + blockerCount * 2
        let maxPenalty = max(1, size + size)
        return max(0, min(1, 1 - Double(penalty) / Double(maxPenalty)))
    }

    func vehicle(atRow row: Int, col: Int) -> GridlockVehicle? {
        vehicles.first { vehicle in
            cells(for: vehicle).contains(row * size + col)
        }
    }

    func cells(for vehicle: GridlockVehicle) -> [Int] {
        (0..<vehicle.length).map { offset in
            let row = vehicle.row + (vehicle.orientation == .vertical ? offset : 0)
            let col = vehicle.col + (vehicle.orientation == .horizontal ? offset : 0)
            return row * size + col
        }
    }

    mutating func move(vehicleID: String, delta: Int) -> Bool {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicleID }) else { return false }
        guard canMove(vehicle: vehicles[index], delta: delta) else { return false }
        switch vehicles[index].orientation {
        case .horizontal:
            vehicles[index].col += delta
        case .vertical:
            vehicles[index].row += delta
        }
        return true
    }

    func canMove(vehicle: GridlockVehicle, delta: Int) -> Bool {
        guard delta == -1 || delta == 1 else { return false }
        let nextRow: Int
        let nextCol: Int
        switch vehicle.orientation {
        case .horizontal:
            nextRow = vehicle.row
            nextCol = delta < 0 ? vehicle.col - 1 : vehicle.col + vehicle.length
        case .vertical:
            nextRow = delta < 0 ? vehicle.row - 1 : vehicle.row + vehicle.length
            nextCol = vehicle.col
        }

        guard nextRow >= 0, nextRow < size, nextCol >= 0, nextCol < size else { return false }
        return vehicle(atRow: nextRow, col: nextCol)?.id == nil
    }
}
