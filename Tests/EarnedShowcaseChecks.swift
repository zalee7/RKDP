import Foundation

enum AppPreferenceKeys { static let reduceExtraAnimations = "reduceExtraAnimations" }

@main
struct EarnedShowcaseChecks {
    static func main() throws {
        var checks = 0
        func check(_ value: Bool, _ message: String) {
            precondition(value, message)
            checks += 1
        }
        var user = AppUser.makeNew(id: "test", username: "Player", email: "")
        let startingCoins = user.coins
        let startingInventory = user.cosmetics.purchasedIDs
        check(user.earnedRewards.isEmpty, "New players don't receive achievement rewards")
        check(EarnedRewardCatalog.all.count == 77, "Tier catalog count")
        check(EarnedRewardCatalog.collectionCount == 37, "Tier families collapse collection entries")
        check(user.collectionRewards.filter { $0.slot == .badge }.count == 24, "Twenty-four distinct wearable badges")
        check(Set(EarnedRewardCatalog.all.map(\.id)).count == 77, "Reward IDs are unique")
        check(Set(EarnedRewardCatalog.all.map(\.id)).isDisjoint(with: CosmeticCatalog.all.map(\.id)), "Earned rewards cannot enter paid catalog/packs")
        for reward in EarnedRewardCatalog.all {
            check(!user.equipEarnedReward(reward.id, in: reward.slot), "Locked reward cannot be equipped")
            check(!user.hasEarned(reward), "Failed equip doesn't unlock it")
        }
        check(!user.equipEarnedReward("unknown", in: .badge), "Unknown reward rejected")
        for mode in GameMode.allCases {
            let reward = EarnedRewardCatalog.all.first { $0.id == "earned_mastery_\(mode.rawValue)" }!
            let badge = EarnedRewardCatalog.reward("earned_badge_mastery_\(mode.rawValue)")!
            for difficulty in Difficulty.allCases {
                user.recordSoloCompletion(mode: mode, difficulty: difficulty)
                user.recordSoloCompletion(mode: mode, difficulty: difficulty)
                check(user.completedSoloDifficulties(for: mode).count <= 4, "Repeated completions don't inflate progress")
                check(user.hasEarned(reward) == (user.completedSoloDifficulties(for: mode).count == 4), "Mastery requires all four difficulties")
                check(user.hasEarned(badge) == user.hasEarned(reward), "Mode badge and title share mastery requirements")
            }
            check(user.equipEarnedReward(reward.id, in: .title), "Completed mode can equip its title")
            check(user.displayedTitle == reward.name, "Mastery title appears in shared identity")
            check(!user.equipEarnedReward(reward.id, in: .frame), "Title cannot be equipped as frame")
            check(user.equipEarnedReward(badge.id, in: .badge), "Each mode badge can be equipped")
            check(user.displayedTitle == reward.name, "Badge equip doesn't replace title")
        }
        let polymath = EarnedRewardCatalog.reward("earned_all_solo_mastery")!
        check(user.hasEarned(polymath) && polymath.progress(for: user).current == 32, "All 32 difficulties unlock Polymath")
        var oneMissing = user
        oneMissing.earnedShowcase = .empty
        oneMissing.soloCompletions[.sudoku] = [.easy, .medium, .hard]
        check(!oneMissing.hasEarned(polymath) && polymath.progress(for: oneMissing).current == 31, "31 difficulties does not unlock Polymath")
        check(user.hasEarned(EarnedRewardCatalog.reward("earned_first_finish")!), "First Finish uses saved completions")
        check(user.hasEarned(EarnedRewardCatalog.reward("earned_all_rounder")!), "All eight modes unlock All-Rounder")
        user.playProgress.longestStreak = 6
        check(!user.hasEarned(EarnedRewardCatalog.reward("earned_week_streak")!), "Six days doesn't count as seven")
        user.playProgress.longestStreak = 7
        check(user.equipEarnedReward("earned_week_streak", in: .badge), "Seven-day badge equips")
        user.playProgress.currentStreak = 0
        check(user.equippedEarnedReward(in: .badge)?.id == "earned_week_streak", "Historical streak keeps badge")

        for (id, days) in [("earned_fortnight_streak", 14), ("earned_month_streak", 30)] {
            var player = AppUser.makeNew(id: "streak", username: "Streak", email: "")
            let badge = EarnedRewardCatalog.reward(id)!
            player.playProgress.totalGamesPlayed = 1000
            player.playProgress.longestStreak = days - 1
            check(!player.hasEarned(badge), "Games played cannot substitute for consecutive days")
            player.playProgress.longestStreak = days
            check(player.equipEarnedReward(id, in: .badge), "Exact streak threshold unlocks badge")
            player.playProgress.currentStreak = 0
            let restored = try JSONDecoder().decode(AppUser.self, from: JSONEncoder().encode(player))
            check(restored.equippedEarnedReward(in: .badge)?.id == id, "Streak badge selection survives reload and broken current streak")
        }

        for target in [1, 10, 25, 100, 250, 500, 1000] {
            let id = "earned_ranked_\(target)"
            var player = AppUser.makeNew(id: "winner", username: "Winner", email: "")
            let badge = EarnedRewardCatalog.reward(id)!
            var rank = RankInfo.empty
            rank.wins = target - 1
            rank.losses = 500
            rank.points = 20000
            player.ranks[.wordle] = rank
            check(!player.hasEarned(badge), "Points and losses aren't ranked wins")
            var otherRank = RankInfo.empty
            otherRank.wins = 1
            player.ranks[.colorLink] = otherRank
            check(badge.progress(for: player).current == target, "Ranked wins aggregate across modes")
            check(player.equipEarnedReward(id, in: .badge), "Ranked win badge equips at exact threshold")
            player.reconcileEarnedRewards()
            let before = player.earnedShowcase
            player.reconcileEarnedRewards()
            check(player.earnedShowcase == before, "Repeated evaluation doesn't create duplicate wins/unlocks")
            rank.wins = Int.max
            player.ranks[.wordle] = rank
            otherRank.wins = -5
            player.ranks[.sudoku] = otherRank
            check(badge.progress(for: player).current == target, "Progress stays bounded for malformed counters")
            let restored = try JSONDecoder().decode(AppUser.self, from: JSONEncoder().encode(player))
            check(restored.equippedEarnedReward(in: .badge)?.id == "earned_ranked_1000", "Equipped ranked family automatically upgrades from new progress")
        }

        for mode in GameMode.allCases {
            var player = AppUser.makeNew(id: "specialist", username: "Specialist", email: "")
            let badge = EarnedRewardCatalog.reward("earned_ranked_specialist_\(mode.rawValue)")!
            for other in GameMode.allCases where other != mode {
                player.ranks[other]?.wins = 1000
            }
            player.soloCompletions[mode] = Difficulty.allCases
            player.ranks[mode]?.wins = 24
            player.ranks[mode]?.losses = 1000
            check(!player.hasEarned(badge), "Other modes, solo completions and losses cannot unlock a specialist")
            player.ranks[mode]?.wins = -1
            check(badge.progress(for: player).current == 0, "Negative specialist counters are bounded")
            player.ranks.removeValue(forKey: mode)
            check(badge.progress(for: player).current == 0, "Missing mode starts at zero")
            player.ranks[mode] = .empty
            player.ranks[mode]?.wins = 25
            check(player.equipEarnedReward(badge.id, in: .badge), "Exact specialist threshold equips")
            player.ranks[mode]?.wins = Int.max
            check(badge.progress(for: player).current == 25, "Specialist progress stays bounded")
            player.ranks[mode] = .empty
            let restored = try JSONDecoder().decode(AppUser.self, from: JSONEncoder().encode(player))
            check(restored.equippedEarnedReward(in: .badge)?.id == badge.id, "Specialist is permanently earned and survives reload")
        }

        for target in [3, 5, 8] {
            var player = AppUser.makeNew(id: "versatile", username: "Versatile", email: "")
            let badge = EarnedRewardCatalog.reward("earned_ranked_variety_\(target)")!
            for mode in GameMode.allCases { player.ranks[mode]?.wins = 9 }
            check(badge.progress(for: player).current == 0, "Nine wins per game cannot satisfy ten-win variety")
            for mode in GameMode.allCases.prefix(target - 1) { player.ranks[mode]?.wins = Int.max }
            check(!player.hasEarned(badge), "Extra wins in fewer games cannot satisfy variety")
            check(badge.progress(for: player).current == target - 1, "Variety progress counts qualifying games, not wins")
            player.ranks[GameMode.allCases[target - 1]]?.wins = 10
            check(player.equipEarnedReward(badge.id, in: .badge), "Exact variety threshold equips")
            for mode in GameMode.allCases { player.ranks[mode]?.wins = 1000 }
            check(badge.progress(for: player).current == target, "Variety progress stays bounded")
            player.ranks = [:]
            let restored = try JSONDecoder().decode(AppUser.self, from: JSONEncoder().encode(player))
            check(restored.equippedEarnedReward(in: .badge)?.id == badge.id, "Variety unlock and equip survive reload")
        }

        var rankedLegacy = AppUser.makeNew(id: "legacy", username: "Legacy Rival", email: "")
        for mode in GameMode.allCases { rankedLegacy.ranks[mode]?.wins = 125 }
        rankedLegacy.reconcileEarnedRewards()
        check(rankedLegacy.earnedRewards.filter { $0.slot == .badge }.count == 10, "Competitive families backfill from old win records without duplicate tiers")
        check(rankedLegacy.soloCompletions.isEmpty, "Competitive backfill does not invent solo completions")

        var tierPlayer = AppUser.makeNew(id: "tiers", username: "Tiers", email: "")
        tierPlayer.earnedShowcase = EarnedShowcase(unlockedIDs: ["earned_ranked_100", "earned_fortnight_streak"], badgeID: "earned_ranked_100")
        check(tierPlayer.equippedEarnedReward(in: .badge)?.tierLevel == 4, "Legacy saved badge maps to correct tier without stats")
        check(tierPlayer.hasEarned(EarnedRewardCatalog.reward("earned_ranked_1")!), "Historical higher tier implies lower unlocks")
        check(tierPlayer.earnedRewards.count == 2, "Legacy milestones show one reward per family")
        tierPlayer.ranks[.wordle]?.wins = 250
        check(tierPlayer.equippedEarnedReward(in: .badge)?.tierLevel == 5, "Worn badge upgrades without re-equipping")
        tierPlayer.reconcileEarnedRewards()
        tierPlayer.ranks = [:]
        check(tierPlayer.equippedEarnedReward(in: .badge)?.tierLevel == 5, "Highest reconciled tier is permanent")
        let next = tierPlayer.nextTier(after: tierPlayer.equippedEarnedReward(in: .badge)!)!
        check(next.progress(for: tierPlayer).target == 500, "Next tier advances one step")

        for mode in GameMode.allCases {
            var specialist = AppUser.makeNew(id: "tiers", username: "Tiers", email: "")
            let family = EarnedRewardCatalog.reward("earned_ranked_specialist_\(mode.rawValue)")!
            for (index, target) in [3, 10, 25, 100].enumerated() {
                specialist.ranks[mode]?.wins = target - 1
                let reward = EarnedRewardCatalog.tiers(for: family)[index]
                check(!specialist.hasEarned(reward), "Specialist tier needs its exact threshold")
                specialist.ranks[mode]?.wins = target
                check(specialist.equipEarnedReward(reward.id, in: .badge), "Specialist tier equips at threshold")
                check(specialist.collectionRewards.filter { $0.collectionID == family.collectionID }.count == 1, "Specialist appears only once")
            }
            check(specialist.nextTier(after: specialist.equippedEarnedReward(in: .badge)!) == nil, "Max tier has no next target")
        }

        func badgeSession(_ id: String, kind: SessionKind = .exhibition, ownPoints: Int = 100, opponentPoints: Int = 200) -> GameSession {
            let players = [
                MatchPlayer(userID: "winner", username: "Winner", wager: 0, rankTier: RankTier.tier(for: ownPoints), rankPoints: ownPoints),
                MatchPlayer(userID: "rival", username: "Rival", wager: 0, rankTier: RankTier.tier(for: opponentPoints), rankPoints: opponentPoints)
            ]
            let results = Dictionary(uniqueKeysWithValues: players.enumerated().map { index, player in
                (player.userID, MatchPlayerResult(userID: player.userID, mode: .colorLink, completed: true,
                    elapsedSeconds: 20 + index * 10, score: 100, progress: 1, status: "Complete", summary: [:], details: []))
            })
            return GameSession(id: id, mode: .colorLink, difficulty: .expert, status: .finished, players: players,
                               seed: 42, puzzleData: "", createdAt: Date(), winnerID: "winner", playerResults: results, matchKind: kind)
        }
        var rival = AppUser.makeNew(id: "winner", username: "Winner", email: "")
        check(rival.recordCompetitiveBadgeWin(from: badgeSession("live")), "Live friend win counts")
        check(!rival.recordCompetitiveBadgeWin(from: badgeSession("live")), "Repeated callbacks cannot duplicate credit")
        check(rival.recordCompetitiveBadgeWin(from: badgeSession("async", kind: .asyncExhibition)), "Play Later win counts")
        check(rival.earnedShowcase.friendlyWins == 2 && rival.earnedShowcase.underdogWins == 0, "Friend match cannot award ranked Underdog")
        check(rival.recordCompetitiveBadgeWin(from: badgeSession("underdog", kind: .ranked)), "One higher starting division unlocks Underdog")
        check(rival.earnedShowcase.underdogWins == 1, "Ranked higher-division win credited")
        check(!rival.recordCompetitiveBadgeWin(from: badgeSession("same", kind: .ranked, opponentPoints: 199)), "More points in same division is not Underdog")
        check(!rival.recordCompetitiveBadgeWin(from: badgeSession("lower", kind: .ranked, ownPoints: 200, opponentPoints: 100)), "Lower opponent cannot award Underdog")
        for kind in [SessionKind.casual, .party] {
            check(!rival.recordCompetitiveBadgeWin(from: badgeSession("other_\(kind)", kind: kind)), "Other match kinds do not award friend/ranked badges")
        }
        var invalid = badgeSession("invalid")
        invalid.players[1].isBot = true
        check(!rival.recordCompetitiveBadgeWin(from: invalid), "Bots excluded")
        invalid = badgeSession("invalid"); invalid.winnerID = nil
        check(!rival.recordCompetitiveBadgeWin(from: invalid), "Draw excluded")
        invalid.winnerID = "rival"
        check(!rival.recordCompetitiveBadgeWin(from: invalid), "Loss excluded")
        invalid = badgeSession("invalid"); invalid.status = .inProgress
        check(!rival.recordCompetitiveBadgeWin(from: invalid), "Unfinished match excluded")
        invalid = badgeSession("invalid"); invalid.playerResults = nil
        check(!rival.recordCompetitiveBadgeWin(from: invalid), "No result evidence excluded")
        invalid = badgeSession("invalid"); invalid.playerResults?["rival"]?.status = "Forfeited"
        check(!rival.recordCompetitiveBadgeWin(from: invalid), "Forfeit status excluded")
        invalid = badgeSession("invalid"); invalid.playerResults?["winner"]?.summary["forfeitWin"] = "true"
        check(!rival.recordCompetitiveBadgeWin(from: invalid), "Forfeit marker excluded")
        invalid = badgeSession("invalid"); invalid.playerResults?["winner"]?.elapsedSeconds = 50
        check(!rival.recordCompetitiveBadgeWin(from: invalid), "Declared winner must match the result resolver")
        invalid = badgeSession("invalid", kind: .ranked); invalid.players[0].rankTier = .master
        check(!rival.recordCompetitiveBadgeWin(from: invalid), "Inconsistent legacy rank snapshots excluded")
        invalid = badgeSession("missing_rank", kind: .ranked)
        var playerJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(invalid.players[0])) as! [String: Any]
        playerJSON.removeValue(forKey: "rankPoints")
        invalid.players[0] = try JSONDecoder().decode(MatchPlayer.self, from: JSONSerialization.data(withJSONObject: playerJSON))
        check(!invalid.players[0].hasRankPointSnapshot, "Legacy absent points aren't treated as known zero")
        check(!rival.recordCompetitiveBadgeWin(from: invalid), "Missing starting rank excludes Underdog")
        let restoredPlayer = try JSONDecoder().decode(MatchPlayer.self, from: JSONEncoder().encode(invalid.players[0]))
        check(!restoredPlayer.hasRankPointSnapshot, "Re-encoding a legacy player doesn't invent a snapshot")
        invalid = badgeSession("invalid"); invalid.playerResults?["winner"]?.mode = .sudoku
        check(!rival.recordCompetitiveBadgeWin(from: invalid), "Wrong mode result excluded")
        var reloadedRival = try JSONDecoder().decode(AppUser.self, from: JSONEncoder().encode(rival))
        check(!reloadedRival.recordCompetitiveBadgeWin(from: badgeSession("live")), "Deduplication survives reload")
        check(reloadedRival.earnedShowcase.friendlyWins == 2, "Competitive counters survive reload")
        let untouchedCoins = rival.coins
        let untouchedRanks = rival.ranks.mapValues(\.points)
        for index in 0..<110 {
            rival.recordCompetitiveBadgeWin(from: badgeSession("friend_\(index)"))
            rival.recordCompetitiveBadgeWin(from: badgeSession("ranked_\(index)", kind: .ranked))
        }
        check(rival.earnedShowcase.friendlyWins == 100 && rival.earnedShowcase.underdogWins == 100, "Counters stop at highest badge target")
        check(rival.earnedShowcase.creditedWinSessionIDs.count == 200, "Session ledger stays bounded to credited milestones")
        check(rival.coins == untouchedCoins && rival.ranks.mapValues(\.points) == untouchedRanks, "Badge credit never changes match payouts or rank points")
        for target in [1, 5, 25, 100] {
            for family in ["friendly", "underdog"] {
                var player = AppUser.makeNew(id: "counter", username: "Counter", email: "")
                let reward = EarnedRewardCatalog.reward("earned_\(family)_\(target)")!
                player.earnedShowcase.friendlyWins = target - 1
                player.earnedShowcase.underdogWins = target - 1
                check(!player.hasEarned(reward), "New family exact threshold")
                player.earnedShowcase.friendlyWins = target
                player.earnedShowcase.underdogWins = target
                check(player.equipEarnedReward(reward.id, in: .badge), "New family tier equips")
            }
        }

        for tier in RankTier.allCases where tier != .bronze {
            let id = "earned_rank_\(tier.rawValue)"
            var competitor = AppUser.makeNew(id: "rank", username: "Rank", email: "")
            var rank = RankInfo.empty
            rank.points = tier.pointsRequired - 1
            rank.tier = .master // Cached labels must never grant a frame.
            competitor.ranks[.colorLink] = rank
            check(!competitor.equipEarnedReward(id, in: .frame), "Rank threshold uses points, not stale tier labels")
            rank.points += 1
            competitor.ranks[.colorLink] = rank
            check(competitor.equipEarnedReward(id, in: .frame), "Exact rank threshold unlocks")
            competitor.ranks[.colorLink] = .empty
            check(competitor.equippedEarnedReward(in: .frame)?.id == id, "Earned frame survives demotion")
            let roundtrip = try JSONDecoder().decode(AppUser.self, from: JSONEncoder().encode(competitor))
            check(roundtrip.equippedEarnedReward(in: .frame)?.id == id, "Frame and permanent unlock survive reload")
        }

        user.reconcileEarnedRewards()
        let owned = user.earnedShowcase.unlockedIDs
        user.reconcileEarnedRewards()
        check(owned == user.earnedShowcase.unlockedIDs, "Reconciliation is idempotent")
        check(user.coins == startingCoins && user.cosmetics.purchasedIDs == startingInventory, "Earned status does not mutate coins or paid inventory")
        let saved = try JSONEncoder().encode(user)
        let restored = try JSONDecoder().decode(AppUser.self, from: saved)
        check(restored.earnedShowcase == user.earnedShowcase, "Showcase round-trip")
        check(restored.displayedTitle == user.displayedTitle, "Equipped earned title round-trip")
        var legacyJSON = try JSONSerialization.jsonObject(with: saved) as! [String: Any]
        legacyJSON.removeValue(forKey: "earnedShowcase")
        var legacy = try JSONDecoder().decode(AppUser.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
        check(legacy.earnedShowcase == .empty, "Old accounts decode with empty showcase")
        legacy.reconcileEarnedRewards()
        check(legacy.earnedRewards.count == 20, "Existing mastery and streak records backfill without replay")
        let partial = try JSONDecoder().decode(EarnedShowcase.self, from: Data("{}".utf8))
        check(partial == .empty, "Partial showcase fields decode safely")
        user.cosmetics.equippedTitle = "title_puzzler"
        check(user.equippedEarnedReward(in: .title) == nil && user.displayedTitle == "Puzzler", "Shop titles replace earned titles in the same slot")
        check(user.equipEarnedReward(nil, in: .badge) && user.equippedEarnedReward(in: .badge) == nil, "Badge can be removed")
        user.earnedShowcase.frameID = "earned_mastery_colorLink"
        check(user.equippedEarnedReward(in: .frame) == nil, "Malformed cross-slot saved selection isn't displayed")
        var unearned = AppUser.makeNew(id: "empty", username: "Empty", email: "")
        unearned.cosmetics.equippedTitle = "earned_mastery_\(GameMode.wordle.rawValue)"
        check(unearned.displayedTitle == "Puzzler", "Locked title selection isn't displayed")
        print("Passed \(checks) earned showcase checks.")
    }
}
