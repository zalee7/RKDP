import Foundation

struct RankedDailyCounter: Codable, Equatable {
    var dayKey: String
    var count: Int

    static let empty = RankedDailyCounter(dayKey: "", count: 0)
}

enum RankedEntrySource: String, Codable {
    case permanent
    case dailyFree
    case rewardedTicket
    case alreadyConsumed
}

enum RankedAccessProduct {
    static let allAccessProductID = "com.gridduel.ranked.all"
    static let allAccessLegacyID = "ranked_all_access"

    static var storeKitProductIDs: [String] {
        [allAccessProductID] + GameMode.allCases.map { productID(for: $0) }
    }

    static func productID(for mode: GameMode) -> String {
        switch mode {
        case .colorLink:   return "com.gridduel.ranked.colorlink"
        case .gridlock:    return "com.gridduel.ranked.gridduel"
        case .sudoku:      return "com.gridduel.ranked.sudoku"
        case .minesweeper: return "com.gridduel.ranked.minesweeper"
        case .wordle:      return "com.gridduel.ranked.wordle"
        case .hangman:     return "com.gridduel.ranked.hangman"
        case .wordHunt:    return "com.gridduel.ranked.wordhunt"
        case .anagram:     return "com.gridduel.ranked.anagrams"
        }
    }

    static func legacyProductID(for mode: GameMode) -> String {
        switch mode {
        case .colorLink:   return "ranked_mode_color_link"
        case .gridlock:    return "ranked_mode_grid_duel"
        case .sudoku:      return "ranked_mode_sudoku"
        case .minesweeper: return "ranked_mode_minesweeper"
        case .wordle:      return "ranked_mode_wordle"
        case .hangman:     return "ranked_mode_hangman"
        case .wordHunt:    return "ranked_mode_word_hunt"
        case .anagram:     return "ranked_mode_anagrams"
        }
    }

    static func mode(for productID: String) -> GameMode? {
        GameMode.allCases.first { productID == self.productID(for: $0) || productID == self.legacyProductID(for: $0) }
    }

    static func fallbackPrice(for productID: String) -> String {
        productID == allAccessProductID ? "$9.99" : "$2.99"
    }
}

struct RankedAccess: Codable, Equatable {
    static let freeEntriesPerModePerDay = 1
    static let rewardedAdsPerModePerDay = 1
    static let rewardedAdsTotalPerDay = 4

    var allModesUnlocked: Bool = false
    var unlockedModeIDs: Set<String> = []
    var dailyFreeUses: [String: RankedDailyCounter] = [:]
    var rewardedTickets: [String: Int] = [:]
    var dailyRewardedAdUses: [String: RankedDailyCounter] = [:]
    var totalRewardedAdUses: RankedDailyCounter = .empty
    var consumedSessionIDs: [String: Bool] = [:]

    static let empty = RankedAccess()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case allModesUnlocked, unlockedModeIDs, dailyFreeUses, rewardedTickets
        case dailyRewardedAdUses, totalRewardedAdUses, consumedSessionIDs
    }

    // Server-issued purchase grants may omit unused daily entry counters.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        allModesUnlocked = try c.decodeIfPresent(Bool.self, forKey: .allModesUnlocked) ?? false
        unlockedModeIDs = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedModeIDs) ?? []
        dailyFreeUses = try c.decodeIfPresent([String: RankedDailyCounter].self, forKey: .dailyFreeUses) ?? [:]
        rewardedTickets = try c.decodeIfPresent([String: Int].self, forKey: .rewardedTickets) ?? [:]
        dailyRewardedAdUses = try c.decodeIfPresent([String: RankedDailyCounter].self, forKey: .dailyRewardedAdUses) ?? [:]
        totalRewardedAdUses = try c.decodeIfPresent(RankedDailyCounter.self, forKey: .totalRewardedAdUses) ?? .empty
        consumedSessionIDs = try c.decodeIfPresent([String: Bool].self, forKey: .consumedSessionIDs) ?? [:]
    }

    static func todayKey(date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    func hasPermanentAccess(to mode: GameMode) -> Bool {
        allModesUnlocked || unlockedModeIDs.contains(mode.rawValue)
    }

    func freeEntriesRemaining(for mode: GameMode, dayKey: String = todayKey()) -> Int {
        max(0, Self.freeEntriesPerModePerDay - count(in: dailyFreeUses[mode.rawValue], dayKey: dayKey))
    }

    func rewardedTicketsRemaining(for mode: GameMode) -> Int {
        max(0, rewardedTickets[mode.rawValue] ?? 0)
    }

    func rewardedAdsRemaining(for mode: GameMode, dayKey: String = todayKey()) -> Int {
        let modeRemaining = Self.rewardedAdsPerModePerDay - count(in: dailyRewardedAdUses[mode.rawValue], dayKey: dayKey)
        let totalRemaining = Self.rewardedAdsTotalPerDay - count(in: totalRewardedAdUses, dayKey: dayKey)
        return max(0, min(modeRemaining, totalRemaining))
    }

    func canStartRanked(mode: GameMode, dayKey: String = todayKey()) -> Bool {
        hasPermanentAccess(to: mode) || freeEntriesRemaining(for: mode, dayKey: dayKey) > 0 || rewardedTicketsRemaining(for: mode) > 0
    }

    func statusText(for mode: GameMode, dayKey: String = todayKey()) -> String {
        if hasPermanentAccess(to: mode) { return "Unlocked forever" }
        if rewardedTicketsRemaining(for: mode) > 0 { return "Ad ticket ready" }
        if freeEntriesRemaining(for: mode, dayKey: dayKey) > 0 { return "Free entry available" }
        return "0 free entries left today"
    }

    mutating func consumeEntry(for mode: GameMode, sessionID: String, dayKey: String = todayKey()) throws -> RankedEntrySource {
        if consumedSessionIDs[sessionID] == true { return .alreadyConsumed }
        consumedSessionIDs[sessionID] = true

        if hasPermanentAccess(to: mode) { return .permanent }

        let modeKey = mode.rawValue
        let tickets = rewardedTicketsRemaining(for: mode)
        if tickets > 0 {
            rewardedTickets[modeKey] = tickets - 1
            return .rewardedTicket
        }

        let freeUsed = count(in: dailyFreeUses[modeKey], dayKey: dayKey)
        guard freeUsed < Self.freeEntriesPerModePerDay else {
            consumedSessionIDs[sessionID] = nil
            throw RankedAccessError.noEntryAvailable
        }
        dailyFreeUses[modeKey] = RankedDailyCounter(dayKey: dayKey, count: freeUsed + 1)
        return .dailyFree
    }

    mutating func grantRewardedTicket(for mode: GameMode, dayKey: String = todayKey()) throws {
        guard rewardedAdsRemaining(for: mode, dayKey: dayKey) > 0 else { throw RankedAccessError.rewardedLimitReached }
        let modeKey = mode.rawValue
        let modeAdCount = count(in: dailyRewardedAdUses[modeKey], dayKey: dayKey)
        let totalAdCount = count(in: totalRewardedAdUses, dayKey: dayKey)
        dailyRewardedAdUses[modeKey] = RankedDailyCounter(dayKey: dayKey, count: modeAdCount + 1)
        totalRewardedAdUses = RankedDailyCounter(dayKey: dayKey, count: totalAdCount + 1)
        rewardedTickets[modeKey] = rewardedTicketsRemaining(for: mode) + 1
    }

    mutating func applyPurchasedProductIDs(_ productIDs: Set<String>) {
        if productIDs.contains(RankedAccessProduct.allAccessProductID) || productIDs.contains(RankedAccessProduct.allAccessLegacyID) {
            allModesUnlocked = true
        }
        for productID in productIDs {
            guard let mode = RankedAccessProduct.mode(for: productID) else { continue }
            unlockedModeIDs.insert(mode.rawValue)
        }
    }

    private func count(in counter: RankedDailyCounter?, dayKey: String) -> Int {
        counter?.dayKey == dayKey ? max(0, counter?.count ?? 0) : 0
    }
}

enum RankedAccessError: LocalizedError {
    case noEntryAvailable
    case rewardedLimitReached

    var errorDescription: String? {
        switch self {
        case .noEntryAvailable:
            return "No ranked entry is available for this mode today."
        case .rewardedLimitReached:
            return "You have reached today's rewarded ad limit for ranked entries."
        }
    }
}
