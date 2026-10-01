import Foundation

struct BotMatchProgress: Codable, Equatable {
    static let rewardedWinsPerDay = 3

    var rewardedBotWins: RankedDailyCounter = .empty

    static let empty = BotMatchProgress()

    func rewardedWinsRemaining(dayKey: String = RankedAccess.todayKey()) -> Int {
        let used = rewardedBotWins.dayKey == dayKey ? rewardedBotWins.count : 0
        return max(0, Self.rewardedWinsPerDay - used)
    }

    mutating func recordRewardedWin(dayKey: String = RankedAccess.todayKey()) -> Bool {
        guard rewardedWinsRemaining(dayKey: dayKey) > 0 else { return false }
        let used = rewardedBotWins.dayKey == dayKey ? rewardedBotWins.count : 0
        rewardedBotWins = RankedDailyCounter(dayKey: dayKey, count: used + 1)
        return true
    }
}

struct DailyPlayProgress: Codable, Equatable {
    var lastPlayedDay: String? = nil
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalGamesPlayed: Int = 0
    var lastRewardDay: String? = nil
    var processedActivityIDs: [String: Bool] = [:]

    static let empty = DailyPlayProgress()

    var hasPlayedToday: Bool {
        lastPlayedDay == RankedAccess.todayKey()
    }

    var canEarnDailyBonusToday: Bool {
        lastRewardDay != RankedAccess.todayKey()
    }

    var canEarnSoloRewardToday: Bool { canEarnDailyBonusToday }
    var totalSoloResults: Int { totalGamesPlayed }

    var displayStreak: Int {
        hasPlayedToday ? currentStreak : 0
    }

    mutating func recordGamePlayed(activityID: String, dayKey: String = RankedAccess.todayKey()) -> Int {
        guard processedActivityIDs[activityID] != true else { return 0 }
        processedActivityIDs[activityID] = true
        totalGamesPlayed += 1

        if lastPlayedDay != dayKey {
            if let lastPlayedDay, Self.isConsecutiveDay(after: lastPlayedDay, current: dayKey) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            lastPlayedDay = dayKey
            longestStreak = max(longestStreak, currentStreak)
        }

        guard lastRewardDay != dayKey else { return 0 }
        lastRewardDay = dayKey
        return CoinWallet.dailyPlayReward
    }

    mutating func recordSoloResult(completed: Bool, dayKey: String = RankedAccess.todayKey()) -> Int {
        guard completed else { return 0 }
        return recordGamePlayed(activityID: "solo_legacy_\(dayKey)_\(totalGamesPlayed + 1)", dayKey: dayKey)
    }

    enum CodingKeys: String, CodingKey {
        case lastPlayedDay, currentStreak, longestStreak, totalGamesPlayed, totalSoloResults, lastRewardDay, processedActivityIDs
    }

    init(
        lastPlayedDay: String? = nil,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        totalGamesPlayed: Int = 0,
        lastRewardDay: String? = nil,
        processedActivityIDs: [String: Bool] = [:]
    ) {
        self.lastPlayedDay = lastPlayedDay
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.totalGamesPlayed = totalGamesPlayed
        self.lastRewardDay = lastRewardDay
        self.processedActivityIDs = processedActivityIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastPlayedDay = try c.decodeIfPresent(String.self, forKey: .lastPlayedDay)
        currentStreak = (try? c.decode(Int.self, forKey: .currentStreak)) ?? 0
        longestStreak = (try? c.decode(Int.self, forKey: .longestStreak)) ?? 0
        totalGamesPlayed = (try? c.decode(Int.self, forKey: .totalGamesPlayed))
            ?? ((try? c.decode(Int.self, forKey: .totalSoloResults)) ?? 0)
        lastRewardDay = try c.decodeIfPresent(String.self, forKey: .lastRewardDay)
        processedActivityIDs = (try? c.decode([String: Bool].self, forKey: .processedActivityIDs)) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(lastPlayedDay, forKey: .lastPlayedDay)
        try c.encode(currentStreak, forKey: .currentStreak)
        try c.encode(longestStreak, forKey: .longestStreak)
        try c.encode(totalGamesPlayed, forKey: .totalGamesPlayed)
        try c.encodeIfPresent(lastRewardDay, forKey: .lastRewardDay)
        try c.encode(processedActivityIDs, forKey: .processedActivityIDs)
    }

    private static func isConsecutiveDay(after previous: String, current: String) -> Bool {
        guard let previousDate = date(from: previous),
              let currentDate = date(from: current) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.dateComponents([.day], from: previousDate, to: currentDate).day == 1
    }

    private static func date(from key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }
}

struct NotificationSettings: Codable, Equatable {
    var friendRequests: Bool = true
    var playNowInvites: Bool = true
    var playLaterInvites: Bool = true
    var partyInvites: Bool = true
    var rematches: Bool = true

    static let `default` = NotificationSettings()

    func enabled(for type: NotificationPreferenceType) -> Bool {
        switch type {
        case .friendRequests: return friendRequests
        case .playNowInvites: return playNowInvites
        case .playLaterInvites: return playLaterInvites
        case .partyInvites: return partyInvites
        case .rematches: return rematches
        }
    }

    mutating func set(_ enabled: Bool, for type: NotificationPreferenceType) {
        switch type {
        case .friendRequests: friendRequests = enabled
        case .playNowInvites: playNowInvites = enabled
        case .playLaterInvites: playLaterInvites = enabled
        case .partyInvites: partyInvites = enabled
        case .rematches: rematches = enabled
        }
    }
}

enum NotificationPreferenceType: String, CaseIterable, Identifiable {
    case friendRequests
    case playNowInvites
    case playLaterInvites
    case partyInvites
    case rematches

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friendRequests: return "Friend Requests"
        case .playNowInvites: return "Play Now Invites"
        case .playLaterInvites: return "Play Later Turns & Results"
        case .partyInvites: return "Party Invites"
        case .rematches: return "Rematches"
        }
    }

    var detail: String {
        switch self {
        case .friendRequests: return "New requests from other players."
        case .playNowInvites: return "Live exhibition invites from friends."
        case .playLaterInvites: return "Async challenge turns and completed results."
        case .partyInvites: return "Room codes and party invitations."
        case .rematches: return "Requests after online matches."
        }
    }
}

struct AppUser: Codable, Identifiable {
    var id: String
    var username: String
    var email: String
    var avatarURL: String?
    var coins: Int
    var createdAt: Date
    var ranks: [GameMode: RankInfo]
    var cosmetics: OwnedCosmetics = .default
    var soloCompletions: [GameMode: [Difficulty]] = [:]
    var appliedRankedOutcomes: [String: Bool] = [:]
    var appliedCasualOutcomes: [String: Bool] = [:]
    var rankedAccess: RankedAccess = .empty
    var coinWallet: CoinWallet = .empty
    var botMatchProgress: BotMatchProgress = .empty
    var playProgress: DailyPlayProgress = .empty
    var dailyChallengeBonusDays: [String: Bool] = [:]
    var notificationSettings: NotificationSettings = .default
    var earnedShowcase: EarnedShowcase = .empty

    var totalRankPoints: Int { ranks.values.reduce(0) { $0 + $1.points } }

    func rank(for mode: GameMode) -> RankInfo {
        var info = ranks[mode] ?? .empty
        info.tier = RankTier.tier(for: info.points)
        return info
    }

    func completedSoloDifficulties(for mode: GameMode) -> Set<Difficulty> {
        Set(soloCompletions[mode] ?? [])
    }

    func isSoloDifficultyUnlocked(mode: GameMode, difficulty: Difficulty) -> Bool {
        guard let prerequisite = difficulty.previous else { return true }
        return completedSoloDifficulties(for: mode).contains(prerequisite)
    }

    func soloUnlockReason(mode: GameMode, difficulty: Difficulty) -> String? {
        guard !isSoloDifficultyUnlocked(mode: mode, difficulty: difficulty),
              let prerequisite = difficulty.previous else { return nil }
        return "Complete \(mode.difficultyLabel(prerequisite)) solo first"
    }

    mutating func recordSoloCompletion(mode: GameMode, difficulty: Difficulty) {
        var completed = completedSoloDifficulties(for: mode)
        completed.insert(difficulty)
        soloCompletions[mode] = Difficulty.allCases.filter { completed.contains($0) }
    }

    static func makeNew(id: String, username: String, email: String) -> AppUser {
        var ranks: [GameMode: RankInfo] = [:]
        for mode in GameMode.allCases {
            ranks[mode] = .empty
        }
        return AppUser(
            id: id,
            username: username,
            email: email,
            avatarURL: nil,
            coins: 500,
            createdAt: Date(),
            ranks: ranks
        )
    }
}

extension AppUser {
    enum CodingKeys: String, CodingKey {
        case id, username, email, avatarURL, coins, createdAt, ranks, cosmetics, soloCompletions, appliedRankedOutcomes, appliedCasualOutcomes, rankedAccess, coinWallet, botMatchProgress, playProgress, dailyChallengeBonusDays, notificationSettings, earnedShowcase
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        username  = try c.decode(String.self, forKey: .username)
        email     = try c.decode(String.self, forKey: .email)
        avatarURL = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        coins     = try c.decode(Int.self, forKey: .coins)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        cosmetics = (try? c.decode(OwnedCosmetics.self, forKey: .cosmetics)) ?? .default

        let rawRanks = try c.decode([String: RankInfo].self, forKey: .ranks)
        var decoded: [GameMode: RankInfo] = [:]
        for (key, value) in rawRanks {
            if let mode = GameMode(rawValue: key) { decoded[mode] = value }
        }
        ranks = decoded

        let rawSolo = (try? c.decode([String: [String]].self, forKey: .soloCompletions)) ?? [:]
        soloCompletions = rawSolo.reduce(into: [GameMode: [Difficulty]]()) { partial, item in
            guard let mode = GameMode(rawValue: item.key) else { return }
            partial[mode] = item.value.compactMap { Difficulty(rawValue: $0) }
        }
        appliedRankedOutcomes = (try? c.decode([String: Bool].self, forKey: .appliedRankedOutcomes)) ?? [:]
        appliedCasualOutcomes = (try? c.decode([String: Bool].self, forKey: .appliedCasualOutcomes)) ?? [:]
        rankedAccess = (try? c.decode(RankedAccess.self, forKey: .rankedAccess)) ?? .empty
        coinWallet = (try? c.decode(CoinWallet.self, forKey: .coinWallet)) ?? .empty
        botMatchProgress = (try? c.decode(BotMatchProgress.self, forKey: .botMatchProgress)) ?? .empty
        playProgress = (try? c.decode(DailyPlayProgress.self, forKey: .playProgress)) ?? .empty
        dailyChallengeBonusDays = (try? c.decode([String: Bool].self, forKey: .dailyChallengeBonusDays)) ?? [:]
        notificationSettings = (try? c.decode(NotificationSettings.self, forKey: .notificationSettings)) ?? .default
        earnedShowcase = try c.decodeIfPresent(EarnedShowcase.self, forKey: .earnedShowcase) ?? .empty
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,        forKey: .id)
        try c.encode(username,  forKey: .username)
        try c.encode(email,     forKey: .email)
        try c.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try c.encode(coins,     forKey: .coins)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(cosmetics, forKey: .cosmetics)

        var rawRanks: [String: RankInfo] = [:]
        for (mode, info) in ranks { rawRanks[mode.rawValue] = info }
        try c.encode(rawRanks, forKey: .ranks)

        var rawSolo: [String: [String]] = [:]
        for (mode, difficulties) in soloCompletions {
            rawSolo[mode.rawValue] = difficulties.map(\.rawValue)
        }
        try c.encode(rawSolo, forKey: .soloCompletions)
        try c.encode(appliedRankedOutcomes, forKey: .appliedRankedOutcomes)
        try c.encode(appliedCasualOutcomes, forKey: .appliedCasualOutcomes)
        try c.encode(rankedAccess, forKey: .rankedAccess)
        try c.encode(coinWallet, forKey: .coinWallet)
        try c.encode(botMatchProgress, forKey: .botMatchProgress)
        try c.encode(playProgress, forKey: .playProgress)
        try c.encode(dailyChallengeBonusDays, forKey: .dailyChallengeBonusDays)
        try c.encode(notificationSettings, forKey: .notificationSettings)
        try c.encode(earnedShowcase, forKey: .earnedShowcase)
    }
}

// MARK: - Earned identity (kept separate from the purchasable cosmetic catalog)

enum EarnedRewardSlot: String, CaseIterable, Identifiable {
    case title = "Titles"
    case badge = "Badges"
    case frame = "Frames"
    var id: String { rawValue }
}

struct EarnedShowcase: Codable, Equatable {
    var unlockedIDs: Set<String> = []
    var badgeID: String?
    var frameID: String?
    var friendlyWins: Int = 0
    var underdogWins: Int = 0
    var creditedWinSessionIDs: Set<String> = []
    static let empty = EarnedShowcase()

    enum CodingKeys: String, CodingKey { case unlockedIDs, badgeID, frameID, friendlyWins, underdogWins, creditedWinSessionIDs }

    init(unlockedIDs: Set<String> = [], badgeID: String? = nil, frameID: String? = nil) {
        self.unlockedIDs = unlockedIDs
        self.badgeID = badgeID
        self.frameID = frameID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unlockedIDs = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedIDs) ?? []
        badgeID = try c.decodeIfPresent(String.self, forKey: .badgeID)
        frameID = try c.decodeIfPresent(String.self, forKey: .frameID)
        friendlyWins = max(0, try c.decodeIfPresent(Int.self, forKey: .friendlyWins) ?? 0)
        underdogWins = max(0, try c.decodeIfPresent(Int.self, forKey: .underdogWins) ?? 0)
        creditedWinSessionIDs = try c.decodeIfPresent(Set<String>.self, forKey: .creditedWinSessionIDs) ?? []
    }
}

enum EarnedRequirement {
    case modeMastery(GameMode)
    case firstFinish
    case allRounder
    case allSoloMastery
    case rankedWins(Int)
    case modeRankedWins(GameMode, Int)
    case rankedVariety(winsPerMode: Int, modes: Int)
    case streak(Int)
    case rank(RankTier)
    case friendlyWins(Int)
    case underdogWins(Int)
}

struct EarnedReward: Identifiable {
    let id: String
    let name: String
    let slot: EarnedRewardSlot
    let symbol: String
    let requirement: EarnedRequirement
    var familyID: String? = nil
    var tierLevel: Int? = nil

    var collectionID: String { familyID ?? id }
    var displayName: String { tierLevel.map { "\(name) - Tier \($0)" } ?? name }

    var tierTargetLabel: String {
        switch requirement {
        case .rankedWins(let wins), .modeRankedWins(_, let wins), .friendlyWins(let wins), .underdogWins(let wins):
            return "\(wins) \(wins == 1 ? "win" : "wins")"
        case .streak(let days): return "\(days) days"
        case .rankedVariety(_, let modes): return "\(modes) games"
        default: return ""
        }
    }

    var requirementText: String {
        switch requirement {
        case .modeMastery(let mode): return "Complete all four solo difficulties in \(mode.displayName)."
        case .firstFinish: return "Complete your first solo difficulty."
        case .allRounder: return "Complete at least one solo difficulty in all eight games."
        case .allSoloMastery: return "Complete all 32 solo difficulties across all eight games."
        case .rankedWins(let wins): return "Record \(wins) ranked \(wins == 1 ? "win" : "wins") across any games. Rewarded training-bot wins also count."
        case .modeRankedWins(let mode, let wins): return "Record \(wins) ranked wins in \(mode.displayName). Rewarded training-bot wins also count."
        case .rankedVariety(let wins, let modes): return "Record at least \(wins) ranked wins in each of \(modes) different games. Rewarded training-bot wins also count."
        case .streak(let days): return "Reach a \(days)-day daily play streak."
        case .rank(let tier): return "Reach \(tier.displayName) in any ranked game."
        case .friendlyWins(let wins): return "Win \(wins) Play Now or Play Later \(wins == 1 ? "match" : "matches") against friends. Forfeits and bots do not count."
        case .underdogWins(let wins): return "Win \(wins) ranked \(wins == 1 ? "match" : "matches") against a human at least one division above you at match start. Forfeits do not count."
        }
    }

    func progress(for user: AppUser) -> (current: Int, target: Int) {
        switch requirement {
        case .modeMastery(let mode):
            return (min(4, user.completedSoloDifficulties(for: mode).count), 4)
        case .firstFinish:
            return (user.soloCompletions.values.contains { !$0.isEmpty } ? 1 : 0, 1)
        case .allRounder:
            return (GameMode.allCases.filter { !user.completedSoloDifficulties(for: $0).isEmpty }.count, 8)
        case .allSoloMastery:
            return (GameMode.allCases.reduce(0) { $0 + user.completedSoloDifficulties(for: $1).count }, 32)
        case .rankedWins(let wins):
            // Cap each contribution before summing; negative/corrupt counters cannot undo progress.
            return (min(wins, user.ranks.values.reduce(0) { $0 + min(wins, max(0, $1.wins)) }), wins)
        case .modeRankedWins(let mode, let wins):
            return (min(wins, max(0, user.ranks[mode]?.wins ?? 0)), wins)
        case .rankedVariety(let wins, let modes):
            return (min(modes, GameMode.allCases.filter { (user.ranks[$0]?.wins ?? 0) >= wins }.count), modes)
        case .streak(let days):
            return (min(days, max(0, user.playProgress.longestStreak)), days)
        case .rank(let tier):
            return (min(tier.pointsRequired, max(0, user.ranks.values.map(\.points).max() ?? 0)), tier.pointsRequired)
        case .friendlyWins(let wins): return (min(wins, user.earnedShowcase.friendlyWins), wins)
        case .underdogWins(let wins): return (min(wins, user.earnedShowcase.underdogWins), wins)
        }
    }
}

enum EarnedRewardCatalog {
    // Legacy IDs stay valid; collection views collapse milestones into their shared family.
    static let all: [EarnedReward] = legacyRewards.map { reward in
        var reward = reward
        switch reward.requirement {
        case .rankedWins(let wins):
            reward = EarnedReward(id: reward.id, name: "Ranked Victor", slot: .badge, symbol: "trophy.fill",
                                  requirement: reward.requirement, familyID: "ranked_victor",
                                  tierLevel: [1, 10, 25, 100, 250, 500, 1000].firstIndex(of: wins).map { $0 + 1 })
        case .streak(let days):
            reward = EarnedReward(id: reward.id, name: "Daily Flame", slot: .badge, symbol: "flame.fill",
                                  requirement: reward.requirement, familyID: "daily_flame",
                                  tierLevel: [7, 14, 30].firstIndex(of: days).map { $0 + 1 })
        case .rankedVariety(_, let modes):
            reward = EarnedReward(id: reward.id, name: "Versatile Rival", slot: .badge, symbol: "circle.grid.3x3.fill",
                                  requirement: reward.requirement, familyID: "ranked_variety",
                                  tierLevel: [3, 5, 8].firstIndex(of: modes).map { $0 + 1 })
        case .modeRankedWins(let mode, _):
            reward.familyID = "specialist_\(mode.rawValue)"
            reward.tierLevel = 3
        default: break
        }
        return reward
    } + GameMode.allCases.flatMap { mode in
        [3, 10, 100].map { wins in
            EarnedReward(id: "earned_ranked_specialist_\(mode.rawValue)_\(wins)", name: "\(mode.displayName) Specialist",
                         slot: .badge, symbol: mode.icon, requirement: .modeRankedWins(mode, wins),
                         familyID: "specialist_\(mode.rawValue)", tierLevel: wins == 3 ? 1 : (wins == 10 ? 2 : 4))
        }
    } + [1, 5, 25, 100].enumerated().flatMap { index, wins in
        [EarnedReward(id: "earned_friendly_\(wins)", name: "Friendly Fire", slot: .badge, symbol: "person.2.fill",
                      requirement: .friendlyWins(wins), familyID: "friendly_fire", tierLevel: index + 1),
         EarnedReward(id: "earned_underdog_\(wins)", name: "Underdog", slot: .badge, symbol: "bolt.shield.fill",
                      requirement: .underdogWins(wins), familyID: "underdog", tierLevel: index + 1)]
    }

    private static let legacyRewards: [EarnedReward] = GameMode.allCases.map { mode in
        EarnedReward(id: "earned_mastery_\(mode.rawValue)", name: "\(mode.displayName) Master",
                     slot: .title, symbol: mode.icon, requirement: .modeMastery(mode))
    } + [
        EarnedReward(id: "earned_first_finish", name: "First Finish", slot: .badge,
                     symbol: "flag.checkered", requirement: .firstFinish),
        EarnedReward(id: "earned_all_rounder", name: "All-Rounder", slot: .badge,
                     symbol: "puzzlepiece.extension.fill", requirement: .allRounder),
        EarnedReward(id: "earned_week_streak", name: "Seven-Day Spark", slot: .badge,
                     symbol: "flame.fill", requirement: .streak(7)),
        EarnedReward(id: "earned_fortnight_streak", name: "Steady Flame", slot: .badge,
                     symbol: "flame.fill", requirement: .streak(14)),
        EarnedReward(id: "earned_month_streak", name: "Unbroken", slot: .badge,
                     symbol: "flame.fill", requirement: .streak(30)),
        EarnedReward(id: "earned_all_solo_mastery", name: "Puzzle Polymath", slot: .badge,
                     symbol: "crown.fill", requirement: .allSoloMastery)
    ] + [
        EarnedReward(id: "earned_ranked_1", name: "First Victory", slot: .badge,
                     symbol: "flag.checkered", requirement: .rankedWins(1)),
        EarnedReward(id: "earned_ranked_10", name: "On the Rise", slot: .badge,
                     symbol: "arrow.up.right", requirement: .rankedWins(10)),
        EarnedReward(id: "earned_ranked_25", name: "Ranked Contender", slot: .badge,
                     symbol: "trophy.fill", requirement: .rankedWins(25)),
        EarnedReward(id: "earned_ranked_100", name: "Century Winner", slot: .badge,
                     symbol: "trophy.fill", requirement: .rankedWins(100)),
        EarnedReward(id: "earned_ranked_250", name: "Arena Veteran", slot: .badge,
                     symbol: "star.fill", requirement: .rankedWins(250)),
        EarnedReward(id: "earned_ranked_500", name: "Arena Elite", slot: .badge,
                     symbol: "crown.fill", requirement: .rankedWins(500)),
        EarnedReward(id: "earned_ranked_1000", name: "Thousand Victories", slot: .badge,
                     symbol: "trophy.fill", requirement: .rankedWins(1000)),
        EarnedReward(id: "earned_ranked_variety_3", name: "Triple Threat", slot: .badge,
                     symbol: "triangle.fill", requirement: .rankedVariety(winsPerMode: 10, modes: 3)),
        EarnedReward(id: "earned_ranked_variety_5", name: "Versatile Rival", slot: .badge,
                     symbol: "star.fill", requirement: .rankedVariety(winsPerMode: 10, modes: 5)),
        EarnedReward(id: "earned_ranked_variety_8", name: "Complete Competitor", slot: .badge,
                     symbol: "circle.grid.3x3.fill", requirement: .rankedVariety(winsPerMode: 10, modes: 8))
    ] + GameMode.allCases.map { mode in
        EarnedReward(id: "earned_ranked_specialist_\(mode.rawValue)", name: "\(mode.displayName) Specialist",
                     slot: .badge, symbol: mode.icon, requirement: .modeRankedWins(mode, 25))
    } + GameMode.allCases.map { mode in
        EarnedReward(id: "earned_badge_mastery_\(mode.rawValue)", name: "\(mode.displayName) Mastery",
                     slot: .badge, symbol: mode.icon, requirement: .modeMastery(mode))
    } + RankTier.allCases.filter { $0 != .bronze }.map { tier in
        EarnedReward(id: "earned_rank_\(tier.rawValue)", name: "\(tier.displayName) Crest",
                     slot: .frame, symbol: "crown.fill", requirement: .rank(tier))
    }

    static func reward(_ id: String?) -> EarnedReward? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static var collectionCount: Int { Set(all.map(\.collectionID)).count }

    static func tiers(for reward: EarnedReward) -> [EarnedReward] {
        all.filter { $0.collectionID == reward.collectionID }.sorted { ($0.tierLevel ?? 0) < ($1.tierLevel ?? 0) }
    }
}

extension AppUser {
    func hasEarned(_ reward: EarnedReward) -> Bool {
        let progress = reward.progress(for: self)
        if earnedShowcase.unlockedIDs.contains(reward.id) || progress.current >= progress.target { return true }
        guard let level = reward.tierLevel else { return false }
        return EarnedRewardCatalog.tiers(for: reward).contains {
            ($0.tierLevel ?? 0) > level && earnedShowcase.unlockedIDs.contains($0.id)
        }
    }

    var collectionRewards: [EarnedReward] {
        var seen: Set<String> = []
        return EarnedRewardCatalog.all.compactMap { reward in
            guard seen.insert(reward.collectionID).inserted else { return nil }
            let tiers = EarnedRewardCatalog.tiers(for: reward)
            return tiers.last(where: { hasEarned($0) }) ?? tiers.first
        }
    }

    var earnedRewards: [EarnedReward] { collectionRewards.filter { hasEarned($0) } }

    func nextTier(after reward: EarnedReward) -> EarnedReward? {
        EarnedRewardCatalog.tiers(for: reward).first { ($0.tierLevel ?? 0) > (reward.tierLevel ?? 0) }
    }

    mutating func reconcileEarnedRewards() {
        earnedShowcase.unlockedIDs.formUnion(EarnedRewardCatalog.all.filter { hasEarned($0) }.map(\.id))
    }

    func equippedEarnedReward(in slot: EarnedRewardSlot) -> EarnedReward? {
        let id: String?
        switch slot {
        case .title: id = cosmetics.equippedTitle
        case .badge: id = earnedShowcase.badgeID
        case .frame: id = earnedShowcase.frameID
        }
        guard let reward = EarnedRewardCatalog.reward(id), reward.slot == slot, hasEarned(reward) else { return nil }
        return EarnedRewardCatalog.tiers(for: reward).last(where: { hasEarned($0) }) ?? reward
    }

    var displayedTitle: String {
        equippedEarnedReward(in: .title)?.name
            ?? CosmeticCatalog.allTitles.first { $0.id == cosmetics.equippedTitle }?.name
            ?? "Puzzler"
    }

    // Validate against current records and previously earned IDs; no caller-supplied unlock flag.
    @discardableResult
    mutating func equipEarnedReward(_ id: String?, in slot: EarnedRewardSlot) -> Bool {
        if let id {
            guard let reward = EarnedRewardCatalog.reward(id), reward.slot == slot, hasEarned(reward) else { return false }
        }
        reconcileEarnedRewards()
        switch slot {
        case .title: cosmetics.equippedTitle = id ?? "title_puzzler"
        case .badge: earnedShowcase.badgeID = id
        case .frame: earnedShowcase.frameID = id
        }
        return true
    }
}
