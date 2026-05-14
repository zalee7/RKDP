import Foundation

/// Linear-congruential PRNG used across all game generators for reproducible seeded puzzles.
/// Matches the LCG constants used in WordHuntGame and AnagramGame.
struct SeededRNG {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        // Warm up
        _ = next()
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 33
    }

    mutating func shuffled<T>(_ array: [T]) -> [T] {
        var arr = array
        for i in stride(from: arr.count - 1, through: 1, by: -1) {
            let j = Int(next()) % (i + 1)
            arr.swapAt(i, j)
        }
        return arr
    }
}
