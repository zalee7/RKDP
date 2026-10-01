import Foundation

enum AppPreferenceKeys { static let reduceExtraAnimations = "reduceExtraAnimations" }

@main struct RankedAccessDecodingChecks {
    static func main() throws {
        let decoder = JSONDecoder()
        func decode(_ json: String) throws -> RankedAccess {
            try decoder.decode(RankedAccess.self, from: Data(json.utf8))
        }
        let all = try decode(#"{"allModesUnlocked":true,"unlockedModeIDs":[]}"#)
        precondition(GameMode.allCases.allSatisfy { all.hasPermanentAccess(to: $0) })
        precondition(all.dailyFreeUses.isEmpty && all.rewardedTickets.isEmpty)
        precondition(all.totalRewardedAdUses == .empty)
        let single = try decode(#"{"allModesUnlocked":false,"unlockedModeIDs":["sudoku"]}"#)
        precondition(single.hasPermanentAccess(to: .sudoku))
        precondition(!single.hasPermanentAccess(to: .wordle))
        let empty = try decode("{}")
        precondition(empty == .empty)
        let revoked = try decode(#"{"allModesUnlocked":false,"unlockedModeIDs":[]}"#)
        precondition(!revoked.hasPermanentAccess(to: .sudoku))
        var full = single
        full.dailyFreeUses["wordle"] = RankedDailyCounter(dayKey: "2026-09-30", count: 1)
        full.rewardedTickets["wordle"] = 1
        full.dailyRewardedAdUses["wordle"] = RankedDailyCounter(dayKey: "2026-09-30", count: 1)
        full.totalRewardedAdUses = RankedDailyCounter(dayKey: "2026-09-30", count: 1)
        full.consumedSessionIDs["session"] = true
        let roundTrip = try decoder.decode(RankedAccess.self, from: JSONEncoder().encode(full))
        precondition(roundTrip == full)
        do {
            _ = try decode(#"{"allModesUnlocked":"true"}"#)
            fatalError("Malformed grant must not decode")
        } catch DecodingError.typeMismatch { }
        print("Ranked access decoding checks passed: all modes, single mode, defaults, revocation, full round trip, malformed grant.")
    }
}
