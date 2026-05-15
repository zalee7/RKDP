import Foundation

struct KenKenGenerator {
    static func generate(difficulty: Difficulty) -> KenKenBoard {
        let size: Int
        switch difficulty {
        case .easy:   size = 4
        case .medium: size = 5
        case .hard:   size = 6
        case .expert: size = 6
        }
        return generateBoard(size: size, difficulty: difficulty)
    }

    private static func generateBoard(size: Int, difficulty: Difficulty) -> KenKenBoard {
        // 1. Generate a valid Latin square solution
        let solution = latinSquare(size: size)

        // 2. Partition cells into cages
        var cageMap = Array(repeating: -1, count: size * size)
        var cages: [KenKenCage] = []
        var unassigned = Set((0..<size * size))
        var cageID = 0

        let maxCageSize: Int
        switch difficulty {
        case .easy:   maxCageSize = 2
        case .medium: maxCageSize = 3
        case .hard:   maxCageSize = 4
        case .expert: maxCageSize = 5
        }

        while !unassigned.isEmpty {
            let start = unassigned.min()!
            var cage = [start]
            unassigned.remove(start)

            // Grow cage greedily up to maxCageSize
            var frontier = orthogonalNeighbours(of: start, size: size)
            while cage.count < maxCageSize, let next = frontier.first(where: { unassigned.contains($0) }) {
                cage.append(next)
                unassigned.remove(next)
                frontier.formUnion(orthogonalNeighbours(of: next, size: size))
            }

            let vals = cage.map { solution[$0 / size][$0 % size] }
            let op = assignOperation(to: vals, cageSize: cage.count)
            let target = computeTarget(vals: vals, op: op)!

            for id in cage { cageMap[id] = cageID }
            cages.append(KenKenCage(id: cageID, target: target, operation: op, cellIDs: cage))
            cageID += 1
        }

        // 3. Build cells
        let cells: [KenKenCell] = (0..<size * size).map { idx in
            let cage = cageMap[idx]
            let isTopLeft = cages[cage].cellIDs.min() == idx
            return KenKenCell(
                id: idx, row: idx / size, col: idx % size,
                value: 0, cageID: cage,
                isSelected: false, isInvalid: false, notes: [],
                isTopLeft: isTopLeft
            )
        }

        return KenKenBoard(size: size, cells: cells, cages: cages)
    }

    private static func latinSquare(size: Int) -> [[Int]] {
        var base = (0..<size).map { offset in (0..<size).map { (($0 + offset) % size) + 1 } }
        // Shuffle rows and columns for variety
        base.shuffle()
        var result = base
        for i in 0..<size { for j in 0..<size { result[j][i] = base[j][i] } }
        // Column shuffle
        let colPerm = (0..<size).shuffled()
        return result.map { row in colPerm.map { row[$0] } }
    }

    private static func orthogonalNeighbours(of idx: Int, size: Int) -> Set<Int> {
        let r = idx / size, c = idx % size
        var result: Set<Int> = []
        if r > 0        { result.insert((r-1) * size + c) }
        if r < size - 1 { result.insert((r+1) * size + c) }
        if c > 0        { result.insert(r * size + (c-1)) }
        if c < size - 1 { result.insert(r * size + (c+1)) }
        return result
    }

    private static func assignOperation(to vals: [Int], cageSize: Int) -> KenKenOperation {
        if cageSize == 1 { return .given }
        if cageSize == 2 {
            let (a, b) = (max(vals[0], vals[1]), min(vals[0], vals[1]))
            // Prefer divide when evenly divisible to keep numbers small
            if b != 0 && a % b == 0 { return Bool.random() ? .divide : .subtract }
            return Bool.random() ? .add : .subtract
        }
        return Bool.random() ? .add : .multiply
    }

    private static func computeTarget(vals: [Int], op: KenKenOperation) -> Int? {
        op.apply(vals)
    }
}
