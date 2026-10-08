import SwiftUI
import UIKit

// MARK: - Shared earned identity views

extension EarnedReward {
    var tint: Color {
        switch requirement {
        case .modeMastery(let mode): return mode.accentColor
        case .rank(let tier): return tier.color
        case .firstFinish: return AppTheme.teal
        case .allRounder: return AppTheme.crownGold
        case .allSoloMastery: return AppTheme.crownGold
        case .rankedWins(let wins):
            if wins >= 1000 { return AppTheme.crownGold }
            if wins >= 500 { return AppTheme.hotPink }
            if wins >= 250 { return Color(hex: "8849D8") }
            return wins >= 100 ? AppTheme.crownGold : Color(hex: "266EDD")
        case .modeRankedWins(let mode, _): return mode.accentColor
        case .rankedVariety(_, let modes): return modes >= 8 ? AppTheme.crownGold : (modes >= 5 ? AppTheme.hotPink : AppTheme.teal)
        case .friendlyWins: return AppTheme.hotPink
        case .underdogWins: return Color(hex: "266EDD")
        case .streak(let days): return days >= 30 ? AppTheme.crownGold : (days >= 14 ? AppTheme.teal : AppTheme.hotPink)
        }
    }

    var emblemShape: String {
        guard slot == .badge else { return "seal" }
        switch requirement {
        case .modeMastery: return "shield"
        case .rankedWins: return "hexagon"
        case .modeRankedWins: return "seal"
        case .rankedVariety: return "diamond"
        case .friendlyWins: return "seal"
        case .underdogWins: return "shield"
        case .streak: return "circle"
        default: return "seal"
        }
    }

    var milestoneNumber: Int? {
        switch requirement {
        case .streak(let days): return days
        case .rankedWins(let wins): return wins
        case .modeRankedWins(_, let wins): return wins
        case .rankedVariety(_, let modes): return modes
        case .allSoloMastery: return 32
        default: return nil
        }
    }
}

struct EarnedRewardEmblem: View {
    let reward: EarnedReward
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Image(systemName: "\(reward.emblemShape).fill")
                .resizable().scaledToFit()
                .foregroundStyle(reward.tint.opacity(0.14))
            Image(systemName: reward.emblemShape)
                .resizable().scaledToFit()
                .foregroundStyle(reward.tint.opacity(0.65))
            if let tier = reward.tierLevel, tier >= 3 {
                Image(systemName: reward.emblemShape)
                    .resizable().scaledToFit().padding(size * 0.08)
                    .foregroundStyle(reward.tint.opacity(0.4))
            }
            Image(systemName: reward.symbol)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(reward.tint)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if let tier = reward.tierLevel {
                Text("\(tier)")
                    .font(.system(size: size >= 36 ? 10 : 8, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: size >= 36 ? 15 : 11)
                    .padding(.vertical, 1)
                    .background(reward.tint, in: Capsule())
            } else if size >= 36, let milestone = reward.milestoneNumber {
                Text("\(milestone)")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(reward.tint, in: Capsule())
            }
        }
        .accessibilityHidden(true)
    }
}

struct EarnedAvatarView: View {
    let style: AvatarStyle
    var frame: EarnedReward?
    var size: CGFloat = 84
    var allowsMotion = true

    var body: some View {
        ZStack {
            StickDuelerAvatarView(style: style, size: size * 0.83, allowsMotion: allowsMotion)
            if let frame {
                Circle()
                    .strokeBorder(LinearGradient(colors: [frame.tint, frame.tint.opacity(0.4), frame.tint],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                Circle().inset(by: 5).strokeBorder(frame.tint.opacity(0.4), lineWidth: 1)
                VStack {
                    Spacer()
                    Image(systemName: "crown.fill")
                        .font(.system(size: size * 0.13, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(frame.tint, in: Capsule())
                }
                .offset(y: 4)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(frame.map { "Avatar, \($0.name) earned frame" } ?? "Avatar")
    }
}

struct EarnedBadgeLabel: View {
    let reward: EarnedReward
    var body: some View {
        HStack(spacing: 6) {
            EarnedRewardEmblem(reward: reward, size: 24)
            Text(reward.displayName).font(.caption.bold()).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(reward.tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reward.displayName), earned badge. \(reward.requirementText)")
    }
}

struct EarnedTrophyShelf: View {
    let user: AppUser
    @State private var selectedReward: EarnedReward?

    var body: some View {
        Group {
        if user.earnedRewards.isEmpty {
            Label("Complete a solo difficulty to earn First Finish.", systemImage: "flag.checkered")
                .font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), alignment: .top)], spacing: 14) {
                ForEach(user.earnedRewards) { reward in
                    Button { selectedReward = reward } label: {
                    VStack(spacing: 6) {
                        EarnedRewardEmblem(reward: reward)
                        Text(reward.displayName)
                            .font(.caption.bold()).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(AppTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(reward.displayName). \(reward.requirementText)")
                }
            }
        }
        }
        .alert(selectedReward?.displayName ?? "Earned Reward", isPresented: Binding(get: { selectedReward != nil }, set: { if !$0 { selectedReward = nil } })) {
            Button("OK") { selectedReward = nil }
        } message: { Text(selectedReward?.requirementText ?? "") }
    }
}

struct EarnedCollectionView: View {
    let user: AppUser
    let onEquip: (String?, EarnedRewardSlot) async throws -> Void
    @State private var slot: EarnedRewardSlot = .title
    @State private var unlockedOnly = false
    @State private var isSaving = false
    @State private var saveError: String?

    private var rewards: [EarnedReward] {
        user.collectionRewards.filter { $0.slot == slot && (!unlockedOnly || user.hasEarned($0)) }
    }

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 16) {
                        EarnedAvatarView(style: user.cosmetics.avatarStyle, frame: user.equippedEarnedReward(in: .frame))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(user.username).font(.headline)
                            Text(user.displayedTitle).font(.subheadline).foregroundStyle(AppTheme.hotPink)
                            if let badge = user.equippedEarnedReward(in: .badge) { EarnedBadgeLabel(reward: badge) }
                            Text("\(user.earnedRewards.count) of \(EarnedRewardCatalog.collectionCount) earned")
                                .font(.caption).foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Picker("Reward category", selection: $slot) {
                        ForEach(EarnedRewardSlot.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Unlocked only", isOn: $unlockedOnly).tint(AppTheme.teal)

                    if let equipped = user.equippedEarnedReward(in: slot) {
                        Button {
                            save(nil)
                        } label: {
                            Label("Remove \(equipped.displayName)", systemImage: "minus.circle")
                                .font(.subheadline)
                        }
                        .disabled(isSaving)
                    }

                    if rewards.isEmpty {
                        Text("No \(slot.rawValue.lowercased()) earned yet.")
                            .foregroundStyle(AppTheme.textSecondary).padding(.vertical)
                    }
                    LazyVStack(spacing: 12) {
                        ForEach(rewards, id: \.collectionID) { reward in rewardRow(reward) }
                    }
                }
                .padding()
            }
        }
        .foregroundStyle(AppTheme.textPrimary)
        .navigationTitle("Earned Collection")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Could not save showcase", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "") }
    }

    private func rewardRow(_ reward: EarnedReward) -> some View {
        let unlocked = user.hasEarned(reward)
        let equipped = user.equippedEarnedReward(in: slot)?.id == reward.id
        let nextTier = unlocked ? user.nextTier(after: reward) : nil
        let progressReward = nextTier ?? reward
        let progress = progressReward.progress(for: user)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if reward.slot == .frame {
                    EarnedAvatarView(style: user.cosmetics.avatarStyle, frame: reward, size: 48, allowsMotion: false)
                } else {
                    EarnedRewardEmblem(reward: reward, size: 48)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.displayName).font(.headline)
                    Text(reward.requirementText)
                        .font(.caption).foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if unlocked {
                HStack {
                    Label("Earned", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold()).foregroundStyle(reward.tint)
                    Spacer()
                    Button { save(reward.id) } label: {
                        Label(equipped ? "Equipped" : "Equip", systemImage: equipped ? "checkmark.circle.fill" : "plus.circle")
                            .font(.subheadline.bold()).padding(.vertical, 6)
                    }
                    .disabled(equipped || isSaving)
                    .accessibilityLabel("\(equipped ? "Equipped" : "Equip") \(reward.displayName)")
                }
            }
            if let nextTier {
                Text("Next: Tier \(nextTier.tierLevel ?? 1)").font(.caption.bold())
                Text(nextTier.requirementText).font(.caption).foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !unlocked || nextTier != nil {
                ProgressView(value: Double(progress.current), total: Double(max(1, progress.target)))
                    .tint(reward.tint)
                    .accessibilityLabel("\(progressReward.displayName) progress")
                HStack {
                    Label(unlocked ? "Next tier" : "Locked", systemImage: unlocked ? "arrow.up.circle" : "lock.fill")
                    Spacer()
                    Text("\(progress.current) / \(progress.target)").monospacedDigit()
                }
                .font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
            if reward.familyID != nil {
                DisclosureGroup("All Tiers") {
                    VStack(spacing: 8) {
                        ForEach(EarnedRewardCatalog.tiers(for: reward)) { tier in
                            HStack {
                                Text("Tier \(tier.tierLevel ?? 1)")
                                Spacer()
                                Text(tier.tierTargetLabel)
                                Image(systemName: user.hasEarned(tier) ? "checkmark.circle.fill" : "lock.fill")
                            }
                            .font(.caption).foregroundStyle(user.hasEarned(tier) ? reward.tint : AppTheme.textMuted)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(tier.displayName). \(tier.requirementText). \(user.hasEarned(tier) ? "Earned" : "Locked")")
                        }
                    }.padding(.top, 8)
                }
                .font(.caption.bold()).tint(reward.tint)
                if unlocked && nextTier == nil {
                    Text("Highest tier earned").font(.caption.bold()).foregroundStyle(reward.tint)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(reward.tint.opacity(equipped ? 0.85 : 0.25), lineWidth: equipped ? 2 : 1))
    }

    private func save(_ id: String?) {
        guard !isSaving else { return }
        let selectedSlot = slot
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do { try await onEquip(id, selectedSlot) }
            catch { saveError = error.localizedDescription }
        }
    }
}

struct PreMatchIdentityView: View {
    let profile: AppUser?
    let player: MatchPlayer?
    let mode: GameMode
    let isLocal: Bool

    private var rank: RankInfo {
        profile?.rank(for: mode) ?? RankInfo(points: player?.rankPoints ?? 0,
            tier: RankTier.tier(for: player?.rankPoints ?? 0), wins: 0, losses: 0, bestTime: nil, bestScore: nil)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(isLocal ? "YOU" : "OPPONENT")
                .font(.caption2.bold()).foregroundStyle(AppTheme.textSecondary)
            EarnedAvatarView(style: profile?.cosmetics.avatarStyle ?? player?.avatarStyle ?? .default,
                             frame: profile?.equippedEarnedReward(in: .frame), size: 80, allowsMotion: false)
            Text(profile?.username ?? player?.username ?? "Opponent")
                .font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.75)
                .frame(height: 38)
            Text(player?.isBot == true ? "Training Bot" : (profile?.displayedTitle ?? "Puzzler"))
                .font(.caption.bold()).foregroundStyle(AppTheme.hotPink)
                .lineLimit(2).minimumScaleFactor(0.85).frame(height: 32)
            if let badge = profile?.equippedEarnedReward(in: .badge) {
                EarnedBadgeLabel(reward: badge).frame(minHeight: 32)
            } else {
                Color.clear.frame(height: 32).accessibilityHidden(true)
            }
            Text(rank.fullDisplayName)
                .font(.subheadline.bold()).foregroundStyle(rank.displayTier.color)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(mode.displayName).font(.caption2).foregroundStyle(AppTheme.textSecondary)
            if player?.isBot == true {
                Text("Limited ranked rewards").font(.caption2).foregroundStyle(AppTheme.textSecondary)
            } else {
                RecordTextView(wins: profile?.rank(for: mode).wins, losses: profile?.rank(for: mode).losses,
                               prefix: "W/L ", font: .caption2)
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal, 10).padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isLocal ? AppTheme.teal.opacity(0.4) : AppTheme.hotPink.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Profile

struct ProfileView: View {
    let user: AppUser
    let onDone: (() -> Void)?
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var shop: ShopViewModel
    @State private var isGrantingTesterAccess = false
    @State private var wordGuessTestTargetEnabled = false
    @State private var isUpdatingWordGuessTestTarget = false
    @State private var selectedOwnedCategory: CosmeticCategory = .title
    @State private var recentGames: [GameSession] = []
    @State private var onlineStatGames: [GameSession] = []
    @State private var isLoadingRecentGames = false
    @State private var recentGamesError: String?
    @State private var selectedRecentGame: GameSession?
    @State private var showAllRecentGames = false

    private var currentUser: AppUser {
        if let refreshed = auth.user, refreshed.id == user.id { return refreshed }
        return user
    }

    init(user: AppUser, onDone: (() -> Void)? = nil) {
        self.user = user
        self.onDone = onDone
        _shop = StateObject(wrappedValue: ShopViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Avatar header card
                        VStack(spacing: 12) {
                            EarnedAvatarView(style: currentUser.cosmetics.avatarStyle, frame: currentUser.equippedEarnedReward(in: .frame), size: 108)

                            VStack(spacing: 10) {
                                HStack(spacing: 10) {
                                    NavigationLink(value: ProfileRoute.customizeProfile) {
                                        Label("Customize Profile", systemImage: "sparkles")
                                            .font(.caption.bold())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(AppTheme.hotPink.opacity(0.18))
                                            .foregroundStyle(AppTheme.hotPink)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(AppTheme.hotPink.opacity(0.45), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)

                                    NavigationLink(value: ProfileRoute.gameCustomization) {
                                        Label("Game Customization", systemImage: "paintpalette.fill")
                                            .font(.caption.bold())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(AppTheme.teal.opacity(0.18))
                                            .foregroundStyle(AppTheme.teal)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(AppTheme.teal.opacity(0.45), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }

                                NavigationLink(value: ProfileRoute.settings) {
                                    Label("Settings", systemImage: "gearshape.fill")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.controlBackground)
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(AppTheme.controlBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }

                            Text(user.username).font(.title2.bold()).foregroundStyle(AppTheme.textPrimary)
                            Text(currentUser.displayedTitle)
                                .font(.subheadline.italic())
                                .foregroundStyle(AppTheme.accentBright)
                            if let badge = currentUser.equippedEarnedReward(in: .badge) {
                                EarnedBadgeLabel(reward: badge)
                            }
                            Text(user.email).font(.caption).foregroundStyle(AppTheme.textSecondary)
                            CoinBadgeView(amount: user.coins)

                            #if PP_SOCIAL_SANDBOX
                            Button {
                                Task {
                                    isGrantingTesterAccess = true
                                    await auth.setTesterRankedAccess(enabled: auth.user?.rankedAccess.allModesUnlocked != true)
                                    isGrantingTesterAccess = false
                                }
                            } label: {
                                Label(
                                    auth.user?.rankedAccess.allModesUnlocked == true ? "Unlimited Rank Test On" : "Enable Unlimited Rank Test",
                                    systemImage: auth.user?.rankedAccess.allModesUnlocked == true ? "checkmark.seal.fill" : "hammer.fill"
                                )
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background((auth.user?.rankedAccess.allModesUnlocked == true ? AppTheme.teal : AppTheme.crownGold).opacity(0.2))
                                .foregroundStyle(auth.user?.rankedAccess.allModesUnlocked == true ? AppTheme.teal : AppTheme.crownGold)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke((auth.user?.rankedAccess.allModesUnlocked == true ? AppTheme.teal : AppTheme.crownGold).opacity(0.45), lineWidth: 1))
                            }
                            .disabled(isGrantingTesterAccess)

                            Button {
                                guard let userID = auth.user?.id else { return }
                                Task {
                                    isUpdatingWordGuessTestTarget = true
                                    defer { isUpdatingWordGuessTestTarget = false }
                                    do {
                                        wordGuessTestTargetEnabled = try await FirestoreService.shared.setWordGuessTestTarget(
                                            enabled: !wordGuessTestTargetEnabled,
                                            userID: userID
                                        )
                                    } catch {
                                        print("Word Guess test target update failed: \(error.localizedDescription)")
                                    }
                                }
                            } label: {
                                Label(
                                    wordGuessTestTargetEnabled ? "Word Guess ATEST On" : "Use ATEST in Word Guess",
                                    systemImage: wordGuessTestTargetEnabled ? "checkmark.circle.fill" : "testtube.2"
                                )
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background((wordGuessTestTargetEnabled ? AppTheme.teal : AppTheme.hotPink).opacity(0.2))
                                .foregroundStyle(wordGuessTestTargetEnabled ? AppTheme.teal : AppTheme.hotPink)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke((wordGuessTestTargetEnabled ? AppTheme.teal : AppTheme.hotPink).opacity(0.45), lineWidth: 1))
                            }
                            .disabled(isUpdatingWordGuessTestTarget)
                            #endif
                        }
                        .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 14) {
                            NavigationLink(value: ProfileRoute.earned) {
                                HStack {
                                    Label("Earned Collection", systemImage: "medal.fill")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(currentUser.earnedRewards.count) / \(EarnedRewardCatalog.all.count)")
                                        .font(.subheadline.monospacedDigit())
                                    Image(systemName: "chevron.right")
                                }
                                .foregroundStyle(AppTheme.hotPink)
                                .padding(.vertical, 8)
                            }
                            EarnedTrophyShelf(user: currentUser)
                        }
                        .padding(.horizontal)

                        dailyProgressSection

                        // Per-mode ranks
                        sectionCard(title: "Rankings") {
                            VStack(spacing: 10) {
                                ForEach(GameMode.allCases) { mode in
                                    ModeRankRow(mode: mode, info: user.rank(for: mode))
                                    if mode != GameMode.allCases.last {
                                        Divider().overlay(AppTheme.cardBorder)
                                    }
                                }
                            }
                        }

                        recentGamesSection

                        sectionCard(title: "Online Stats") {
                            RecentOnlineStatsView(sessions: onlineStatGames, currentUserID: user.id, totalRankPoints: user.totalRankPoints)
                        }

                        // Sign out
                        Button(role: .destructive) {
                            auth.signOut(); dismiss()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.3), lineWidth: 1))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if let onDone {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { onDone() }.foregroundStyle(AppTheme.accentBright)
                    }
                }
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .customizeProfile:
                    AvatarEditorView(shop: shop) {
                        await auth.refreshUser()
                    }
                case .gameCustomization:
                    GameCustomizationView(shop: shop) {
                        await auth.refreshUser()
                    }
                case .settings:
                    SettingsView(user: auth.user ?? user)
                        .environmentObject(auth)
                case .earned:
                    EarnedCollectionView(user: currentUser) { id, slot in
                        try await auth.equipEarnedReward(id, in: slot)
                        shop.refreshIdentity(from: currentUser)
                    }
                }
            }
            .sheet(item: $selectedRecentGame) { session in
                MatchBreakdownView(
                    session: session,
                    currentUserID: user.id,
                    results: session.playerResults ?? [:]
                )
            }
            .sheet(isPresented: $showAllRecentGames) {
                RecentGamesListView(sessions: recentGames, currentUserID: user.id)
            }
            .task {
                await loadRecentGames()
                #if PP_SOCIAL_SANDBOX
                await loadWordGuessTestTarget()
                #endif
            }
            .onAppear {
                shop.refreshIdentity(from: currentUser)
                Task { await loadRecentGames() }
            }
            .onChange(of: currentUser.cosmetics.equippedTitle) { _, _ in
                shop.refreshIdentity(from: currentUser)
            }
        }
    }

    #if PP_SOCIAL_SANDBOX
    @MainActor
    private func loadWordGuessTestTarget() async {
        guard let userID = auth.user?.id else { return }
        do {
            wordGuessTestTargetEnabled = try await FirestoreService.shared.wordGuessTestTargetEnabled(userID: userID)
        } catch {
            // The normal production build and unapproved accounts never expose this tool.
            wordGuessTestTargetEnabled = false
        }
    }
    #endif

    private var dailyProgressSection: some View {
        sectionCard(title: "Daily Play Streak") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Submit or finish any game each day to keep your streak.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    profileMetric(
                        icon: "flame.fill",
                        title: "Streak",
                        value: user.playProgress.hasPlayedToday ? "\(max(1, user.playProgress.currentStreak)) days" : "Play today",
                        color: AppTheme.hotPink
                    )
                    profileMetric(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Best",
                        value: "\(user.playProgress.longestStreak) days",
                        color: AppTheme.crownGold
                    )
                }
                HStack(spacing: 10) {
                    profileMetric(
                        icon: "gamecontroller.fill",
                        title: "Games Played",
                        value: "\(user.playProgress.totalGamesPlayed)",
                        color: AppTheme.teal
                    )
                    profileMetric(
                        icon: "gift.fill",
                        title: "Daily Bonus",
                        value: user.playProgress.canEarnDailyBonusToday ? "+\(CoinWallet.dailyPlayReward) ready" : "Claimed Today",
                        color: AppTheme.accentBright
                    )
                }
            }
        }
    }

    private func profileMetric(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
                .frame(width: 27, height: 27)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Text(value)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(AppTheme.controlBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
    }

    private var recentGamesSection: some View {
        sectionCard(title: "Recent Games") {
            VStack(alignment: .leading, spacing: 12) {
                if isLoadingRecentGames && recentGames.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(AppTheme.hotPink)
                        Text("Loading recent matches...")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                } else if let recentGamesError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recentGamesError)
                            .font(.caption)
                            .foregroundStyle(AppTheme.warning)
                        Button("Retry") {
                            Task { await loadRecentGames() }
                        }
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.crownGold)
                    }
                } else if recentGames.isEmpty {
                    Text("Your latest online matches will appear here with dates and breakdowns.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(Array(recentGames.prefix(5))) { session in
                        RecentGameRow(session: session, currentUserID: user.id) {
                            selectedRecentGame = session
                        }
                    }

                    if recentGames.count > 5 {
                        Button {
                            showAllRecentGames = true
                        } label: {
                            Label("View All Recent Games", systemImage: "clock.arrow.circlepath")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.08))
                                .foregroundStyle(AppTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func loadRecentGames() async {
        let currentUserID = auth.user?.id ?? user.id
        isLoadingRecentGames = true
        recentGamesError = nil

        do {
            recentGames = try await FirestoreService.shared.fetchRecentFinishedSessions(for: currentUserID, limit: 20)
        } catch {
            #if DEBUG
            print("Recent games fetch failed for \(currentUserID): \(error)")
            #endif
            recentGamesError = "Could not load recent games right now."
        }

        do {
            onlineStatGames = try await FirestoreService.shared.fetchFinishedOnlineSessions(for: currentUserID)
        } catch {
            #if DEBUG
            print("Online stats fetch failed for \(currentUserID): \(error)")
            #endif
        }

        isLoadingRecentGames = false
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(AppTheme.accentBright)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }
}

private enum ProfileRoute: Hashable {
    case customizeProfile
    case gameCustomization
    case settings
    case earned
}


private struct AvatarEditorView: View {
    @ObservedObject var shop: ShopViewModel
    var onChanged: () async -> Void
    @State private var selectedCategory: CosmeticCategory = .avatarHead
    @State private var bodyHexInput: String
    @State private var bodyHexError: String?

    private let categories: [CosmeticCategory] = [.title, .avatarHead, .avatarOutfit, .avatarAura, .avatarFace]

    init(shop: ShopViewModel, onChanged: @escaping () async -> Void) {
        self.shop = shop
        self.onChanged = onChanged
        _bodyHexInput = State(initialValue: shop.ownedCosmetics.customAvatarBodyHex)
    }

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    StickDuelerAvatarView(style: shop.ownedCosmetics.avatarStyle, size: 150)
                        .padding(.top, 18)
                    Text("Puzzle Profile")
                        .font(.title2.bold())
                    NavigationLink(value: ProfileRoute.earned) {
                        Label("Earned Titles, Badges & Frames", systemImage: "medal.fill")
                            .font(.subheadline.bold()).foregroundStyle(AppTheme.hotPink)
                    }
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Equip owned titles, bodies, headwear, auras, and bold expressions here. Buy new cosmetics in the Shop.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                Button { selectedCategory = category } label: {
                                    Text(label(for: category))
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(selectedCategory == category ? AppTheme.hotPink : AppTheme.controlBackground)
                                        .foregroundStyle(selectedCategory == category ? AppTheme.textOnColor : AppTheme.textSecondary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(selectedCategory == category ? Color.white.opacity(0.6) : AppTheme.controlBorder, lineWidth: 1)
                                        )
                                        .shadow(color: selectedCategory == category ? AppTheme.hotPink.opacity(0.24) : .clear, radius: 7, x: 0, y: 3)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if selectedCategory == .avatarOutfit {
                        bodyColorEditor
                            .padding(.horizontal)
                    }

                    avatarItemsSection
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Customize Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Profile update failed",
            isPresented: Binding(get: { shop.errorMessage != nil }, set: { if !$0 { shop.errorMessage = nil } })
        ) {
            Button("OK") { shop.errorMessage = nil }
        } message: {
            Text(shop.errorMessage ?? "")
        }
    }

    private var bodyColorEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Solid Color")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: OwnedCosmetics.normalizedHex(bodyHexInput) ?? shop.ownedCosmetics.customAvatarBodyHex))
                    .frame(width: 42, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.65), lineWidth: 1))
            }
            Text("Used when Custom Solid is equipped. Premium body skins override this color.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                TextField("", text: $bodyHexInput, prompt: Text("FF2F78").foregroundStyle(AppTheme.textMuted))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .foregroundStyle(AppTheme.textPrimary)
                    .tint(AppTheme.accentBright)
                    .background(AppTheme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(bodyHexError == nil ? AppTheme.controlBorder : AppTheme.danger, lineWidth: 1.25))
                Button("Save") {
                    Task { await saveBodyHex() }
                }
                .font(.caption.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.hotPink)
                .foregroundStyle(AppTheme.textOnColor)
                .clipShape(Capsule())
                .disabled(shop.isSaving)
            }
            if let bodyHexError {
                Text(bodyHexError)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.danger)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(colorSwatches, id: \.self) { hex in
                    Button {
                        bodyHexInput = hex
                        Task { await saveBodyHex() }
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(hex == shop.ownedCosmetics.customAvatarBodyHex ? AppTheme.hotPink : AppTheme.cardBorder, lineWidth: hex == shop.ownedCosmetics.customAvatarBodyHex ? 2.5 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var avatarItemsSection: some View {
        let allItems = CosmeticCatalog.all.filter { $0.category == selectedCategory }
        let ownedItems = allItems.filter { shop.isOwned($0) }

        return VStack(alignment: .leading, spacing: 18) {
            if !ownedItems.isEmpty {
                avatarItemGroup(
                    title: ownedTitle(for: selectedCategory),
                    subtitle: selectedCategory == .title ? "Equip your saved name title." : "Equip the parts you already unlocked.",
                    items: ownedItems,
                    tint: AppTheme.teal
                )
            }
        }
    }

    private func avatarItemGroup(title: String, subtitle: String, items: [CosmeticItem], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(tint)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(items) { item in
                    ShopItemCard(
                        item: item,
                        isOwned: shop.isOwned(item),
                        isEquipped: shop.isEquipped(item),
                        canAfford: shop.canAfford(item),
                        isLimited: false
                    ) {
                        Task {
                            if await shop.equip(item) { await onChanged() }
                        }
                    }
                }
            }
        }
    }

    private var colorSwatches: [String] {
        [
            "FF2F78", "12C8A2", "256BFF", "FFD02E", "7B42FF", "FFFFFF",
            "FF6B1A", "8FFFE1", "11183A", "39D5FF", "FF9ED1", "050510",
            "C9D2E3", "23D18B"
        ]
    }

    private func label(for category: CosmeticCategory) -> String {
        switch category {
        case .title: return "Title"
        case .avatarHead: return "Head"
        case .avatarFace: return "Expression"
        case .avatarOutfit: return "Body"
        case .avatarAura: return "Aura"
        case .avatarPose: return "Pose"
        case .tileTheme: return "Tile"
        case .cardTheme: return "Card"
        default: return category.rawValue
        }
    }

    private func ownedTitle(for category: CosmeticCategory) -> String {
        switch category {
        case .title: return "Owned Titles"
        case .avatarHead: return "Owned Heads"
        case .avatarFace: return "Owned Expressions"
        case .avatarOutfit: return "Owned Bodies"
        case .avatarAura: return "Owned Auras"
        default: return "Owned"
        }
    }

    private func saveBodyHex() async {
        guard let normalized = OwnedCosmetics.normalizedHex(bodyHexInput) else {
            bodyHexError = "Use a 6-digit hex color like FF2F78."
            return
        }
        bodyHexError = nil
        bodyHexInput = normalized
        if await shop.setCustomAvatarBodyHex(normalized) {
            await onChanged()
        }
    }
}

private struct GameCustomizationView: View {
    @ObservedObject var shop: ShopViewModel
    var onChanged: () async -> Void
    @State private var selectedCategory: CosmeticCategory = .boardTheme
    @State private var previewItem: CosmeticItem?

    private let categories: [CosmeticCategory] = [.boardTheme, .tileTheme, .cardTheme]

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Tune board surfaces, letter and number tiles, and Solitaire cards separately.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                Button { selectedCategory = category } label: {
                                    Text(label(for: category))
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == category ? AppTheme.hotPink : AppTheme.cardBackground)
                                        .foregroundStyle(selectedCategory == category ? AppTheme.textOnColor : AppTheme.textSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Text(description(for: selectedCategory))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    ownedGameItems
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Game Customization")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Customization failed",
            isPresented: Binding(get: { shop.errorMessage != nil }, set: { if !$0 { shop.errorMessage = nil } })
        ) {
            Button("OK") { shop.errorMessage = nil }
        } message: {
            Text(shop.errorMessage ?? "")
        }
        .sheet(item: $previewItem) { item in
            CosmeticThemePreviewSheet(
                item: item,
                isEquipped: shop.isEquipped(item)
            ) {
                Task {
                    if await shop.equip(item) {
                        await onChanged()
                        previewItem = nil
                    }
                }
            }
        }
    }

    private var ownedGameItems: some View {
        let items = CosmeticCatalog.all
            .filter { $0.category == selectedCategory && shop.isOwned($0) }
            .sorted { lhs, rhs in
                if shop.isEquipped(lhs) != shop.isEquipped(rhs) { return shop.isEquipped(lhs) }
                if lhs.rarity != rhs.rarity { return lhs.rarity.rawValue < rhs.rarity.rawValue }
                return lhs.name < rhs.name
            }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Owned \(label(for: selectedCategory))")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.textPrimary)

            if items.isEmpty {
                Text("Owned game cosmetics will appear here after you unlock them in the Shop.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(items) { item in
                        VStack(spacing: 6) {
                            ShopItemCard(
                                item: item,
                                isOwned: true,
                                isEquipped: shop.isEquipped(item),
                                canAfford: true,
                                isLimited: false
                            ) {
                                Task {
                                    if await shop.equip(item) {
                                        await onChanged()
                                    }
                                }
                            }

                            Button {
                                SoundManager.shared.appButtonTap()
                                previewItem = item
                            } label: {
                                Label("Preview", systemImage: "eye")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(AppTheme.cardBackground.opacity(0.8))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func label(for category: CosmeticCategory) -> String {
        switch category {
        case .boardTheme: return "Board Themes"
        case .tileTheme: return "Letter & Number Tiles"
        case .cardTheme: return "Card Themes"
        default: return category.rawValue
        }
    }

    private func description(for category: CosmeticCategory) -> String {
        switch category {
        case .boardTheme:
            return "Changes the shared play surface, grid lines, highlights, and path accents in Sudoku, Color Link, Minesweeper, and Word Hunt."
        case .tileTheme:
            return "Changes the individual letter and number pieces in Word Guess, Anagrams, Word Hunt, and Sudoku."
        case .cardTheme:
            return "Changes Solitaire card fronts, backs, suits, borders, and table color only."
        default:
            return ""
        }
    }
}

private enum CosmeticThemePreviewGame: String, CaseIterable, Identifiable {
    case sudoku = "Sudoku"
    case colorLink = "Color Link"
    case minesweeper = "Minesweeper"
    case wordGuess = "Word Guess"
    case anagram = "Anagrams"
    case wordHunt = "Word Hunt"
    case solitaire = "Solitaire"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sudoku: return "square.grid.3x3.fill"
        case .colorLink: return "link"
        case .minesweeper: return "burst.fill"
        case .wordGuess: return "textformat.abc"
        case .anagram: return "textformat"
        case .wordHunt: return "square.grid.3x3"
        case .solitaire: return "suit.spade.fill"
        }
    }

    static func options(for category: CosmeticCategory) -> [Self] {
        switch category {
        case .boardTheme:
            return [.sudoku, .colorLink, .minesweeper, .wordHunt]
        case .tileTheme:
            return [.wordGuess, .anagram, .wordHunt, .sudoku]
        case .cardTheme:
            return [.solitaire]
        default:
            return []
        }
    }
}

struct CosmeticThemePreviewSheet: View {
    let item: CosmeticItem
    let isEquipped: Bool
    let showsEquipAction: Bool
    let onEquip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var previewGame: CosmeticThemePreviewGame

    init(
        item: CosmeticItem,
        isEquipped: Bool,
        showsEquipAction: Bool = true,
        onEquip: @escaping () -> Void
    ) {
        self.item = item
        self.isEquipped = isEquipped
        self.showsEquipAction = showsEquipAction
        self.onEquip = onEquip
        _previewGame = State(initialValue: CosmeticThemePreviewGame.options(for: item.category).first ?? .sudoku)
    }

    private var previewGames: [CosmeticThemePreviewGame] {
        CosmeticThemePreviewGame.options(for: item.category)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                    if previewGames.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview in")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(previewGames) { game in
                                        Button {
                                            SoundManager.shared.appButtonTap()
                                            previewGame = game
                                        } label: {
                                            Label(game.rawValue, systemImage: game.icon)
                                                .font(.caption.bold())
                                                .foregroundStyle(previewGame == game ? AppTheme.textOnColor : AppTheme.textSecondary)
                                                .padding(.horizontal, 12)
                                                .frame(height: 34)
                                                .background(previewGame == game ? AppTheme.hotPink : AppTheme.cardBackground)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(previewGame == game ? AppTheme.hotPink : AppTheme.cardBorder, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }

                    Text(previewScopeDescription)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    CosmeticThemeGameplayMock(item: item, previewGame: previewGame)
                        .frame(height: 260)
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)

                    VStack(spacing: 6) {
                        Text(item.name)
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(item.rarity.rawValue.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(item.rarity.badgeColor)
                        Text(item.description)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    Button {
                        SoundManager.shared.playThemePreview(for: item)
                    } label: {
                        Label("Hear Theme", systemImage: "speaker.wave.2.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.cardBackground.opacity(0.88))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    if !showsEquipAction {
                        Text("Preview only")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.vertical, 12)
                    } else if isEquipped {
                        Label("Equipped", systemImage: "checkmark.circle.fill")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.teal)
                            .padding(.vertical, 12)
                    } else {
                        Button {
                            SoundManager.shared.appButtonTap()
                            onEquip()
                        } label: {
                            Label("Equip Theme", systemImage: "checkmark.circle.fill")
                                .font(.headline.bold())
                                .foregroundStyle(AppTheme.textOnColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.hotPink)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 28)
                    }

                    Spacer()
                }
                .padding(.top, 28)
            }
            .navigationTitle("Theme Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.hotPink)
                }
            }
        }
    }

    private var previewScopeDescription: String {
        switch item.category {
        case .boardTheme:
            return "Board theme preview: shared surface, grid, highlights, and path accents. Letter and number pieces stay separate."
        case .tileTheme:
            return "Tile preview: letter and number pieces only. Board surfaces and Minesweeper cells stay separate."
        case .cardTheme:
            return "Card theme preview: Solitaire cards and table styling only."
        default:
            return ""
        }
    }

}

private struct CosmeticThemeGameplayMock: View {
    let item: CosmeticItem
    let previewGame: CosmeticThemePreviewGame

    private var board: BoardThemeStyle {
        var cosmetics = OwnedCosmetics.default
        if item.category == .boardTheme { cosmetics.equippedBoardTheme = item.id }
        return cosmetics.themeStyle
    }

    private var tile: TileThemeStyle {
        var cosmetics = OwnedCosmetics.default
        if item.category == .tileTheme { cosmetics.equippedTileTheme = item.id }
        return cosmetics.tileThemeStyle
    }

    private var cards: CardThemeStyle {
        var cosmetics = OwnedCosmetics.default
        if item.category == .cardTheme { cosmetics.equippedCardTheme = item.id }
        return cosmetics.cardThemeStyle
    }

    var body: some View {
        switch item.category {
        case .boardTheme:
            boardThemeMock(for: previewGame)
        case .tileTheme:
            tileThemeMock(for: previewGame)
        case .cardTheme:
            solitaireMock
        default:
            EmptyView()
        }
    }

    private func boardThemeMock(for game: CosmeticThemePreviewGame) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.cardBackground)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(board.tileGradient)
                .opacity(0.2)

            VStack(spacing: 10) {
                HStack {
                    Label(game.rawValue, systemImage: game.icon)
                        .font(.caption.bold())
                        .foregroundStyle(boardLabelColor)
                    Spacer()
                    Text("PREVIEW")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(boardLabelColor.opacity(0.68))
                }

                boardPreviewContent(for: game)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(14)
        }
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(board.gridLineMajor.opacity(0.82), lineWidth: 1.5))
        .padding(.horizontal, 24)
        .shadow(color: board.gridLineMajor.opacity(0.2), radius: 10, x: 0, y: 6)
    }

    private var boardLabelColor: Color {
        item.id == "theme_dark" || item.id == "theme_cosmic_crown" || item.id == "theme_prism_party"
            ? .white
            : AppTheme.textPrimary
    }

    @ViewBuilder
    private func boardPreviewContent(for game: CosmeticThemePreviewGame) -> some View {
        switch game {
        case .sudoku:
            sudokuBoardPreview
        case .colorLink:
            colorLinkBoardPreview
        case .minesweeper:
            minesweeperBoardPreview
        case .wordHunt:
            wordHuntBoardPreview(usesTileTheme: false)
        default:
            sudokuBoardPreview
        }
    }

    private var sudokuBoardPreview: some View {
        let values = [
            "6", "", "", "1", "", "4",
            "", "2", "", "", "6", "",
            "", "", "5", "", "", "3",
            "2", "", "", "5", "", "",
            "", "4", "", "", "1", "",
            "5", "", "2", "", "", "6"
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 6), spacing: 0) {
            ForEach(values.indices, id: \.self) { index in
                Rectangle()
                    .fill(index == 20 ? board.selectedCell : board.cellBackground.opacity(0.9))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(Rectangle().stroke(index % 2 == 0 ? board.gridLineMinor : board.gridLineMinor.opacity(0.72), lineWidth: 0.7))
                    .overlay {
                        Text(values[index])
                            .font(.system(size: 16, weight: values[index].isEmpty ? .regular : .bold, design: .rounded))
                            .foregroundStyle(boardLabelColor)
                    }
            }
        }
        .frame(width: 188, height: 188)
        .overlay(Rectangle().stroke(board.gridLineMajor, lineWidth: 2))
    }

    private var colorLinkBoardPreview: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 5
            ZStack(alignment: .topLeading) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 5), spacing: 2) {
                    ForEach(0..<25, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(board.cellBackground.opacity(0.88))
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(board.gridLineMinor, lineWidth: 0.8))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .frame(width: side, height: side)

                Canvas { context, _ in
                    drawLink([0, 1, 6, 11, 12], color: board.activeTraceColor, cell: cell, context: &context)
                    drawLink([4, 9, 14, 19, 18, 17], color: AppTheme.hotPink, cell: cell, context: &context)
                    for (index, color) in [(0, board.activeTraceColor), (12, board.activeTraceColor), (4, AppTheme.hotPink), (17, AppTheme.hotPink)] {
                        let center = linkPoint(index, cell: cell)
                        context.fill(Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)), with: .color(color))
                    }
                }
                .frame(width: side, height: side)
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .frame(width: 188, height: 188)
    }

    private func drawLink(_ indices: [Int], color: Color, cell: CGFloat, context: inout GraphicsContext) {
        var path = Path()
        for (offset, index) in indices.enumerated() {
            let point = linkPoint(index, cell: cell)
            if offset == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
    }

    private func linkPoint(_ index: Int, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(index % 5) + 0.5) * cell, y: (CGFloat(index / 5) + 0.5) * cell)
    }

    private func tileThemeMock(for game: CosmeticThemePreviewGame) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "11142B"))
            VStack(spacing: 10) {
                HStack {
                    Label(game.rawValue, systemImage: game.icon)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer()
                    Text("PREVIEW")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white.opacity(0.62))
                }

                tilePreviewContent(for: game)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(14)
        }
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(tile.border.opacity(0.72), lineWidth: 1.5))
        .padding(.horizontal, 24)
        .shadow(color: tile.shadow.opacity(0.42), radius: 10, x: 0, y: 6)
    }

    @ViewBuilder
    private func tilePreviewContent(for game: CosmeticThemePreviewGame) -> some View {
        switch game {
        case .wordGuess:
            wordGuessTilePreview
        case .anagram:
            anagramTilePreview
        case .wordHunt:
            wordHuntBoardPreview(usesTileTheme: true)
        case .sudoku:
            sudokuTilePreview
        default:
            anagramTilePreview
        }
    }

    private var wordGuessTilePreview: some View {
        let letters = Array("CROWNPARTYGUESS")
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 5), spacing: 5) {
            ForEach(0..<15, id: \.self) { index in
                compactTile(String(letters[index]), active: index < 10)
            }
        }
        .frame(width: 210)
    }

    private var anagramTilePreview: some View {
        HStack(spacing: 7) {
            ForEach(Array("PUZZLE").indices, id: \.self) { index in
                compactTile(String(Array("PUZZLE")[index]), active: index == 2)
                    .frame(width: 38, height: 48)
            }
        }
    }

    private var sudokuTilePreview: some View {
        let values = ["6", "", "2", "", "5", "1", "", "4", "", "3", "", "6", "2", "", "", "5"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
            ForEach(values.indices, id: \.self) { index in
                compactTile(values[index], active: index == 6 || index == 9)
            }
        }
        .frame(width: 184)
    }

    private func wordHuntBoardPreview(usesTileTheme: Bool) -> some View {
        let letters = Array("CROWNPARTYLINKSXY")
        let selected = Set([0, 1, 5, 9, 10])
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
            ForEach(0..<16, id: \.self) { index in
                if usesTileTheme {
                    compactTile(String(letters[index]), active: selected.contains(index))
                } else {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(selected.contains(index) ? board.selectedCell : board.cellBackground.opacity(0.9))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(selected.contains(index) ? board.activeTraceColor : board.gridLineMinor, lineWidth: selected.contains(index) ? 2 : 1))
                        .overlay(Text(String(letters[index])).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(boardLabelColor))
                }
            }
        }
        .frame(width: 184)
    }

    private var minesweeperBoardPreview: some View {
        let values = ["1", "1", "", "", "⚑", "", "2", "2", "1", "", "1", "2", "✦", "2", "1", "", "1", "1", "2", ""]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
            ForEach(values.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(index == 4 || index == 12 ? board.tileGradient : LinearGradient(colors: [board.cellBackground.opacity(0.9), board.cellBackground.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(index == 4 ? board.activeTraceColor : board.gridLineMinor, lineWidth: index == 4 ? 1.5 : 1))
                    .overlay(Text(values[index]).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(boardLabelColor))
            }
        }
        .frame(width: 210)
    }

    private func compactTile(_ value: String, active: Bool) -> some View {
        RoundedRectangle(cornerRadius: max(4, 14 * tile.cornerScale), style: .continuous)
            .fill(active ? tile.fill : LinearGradient(
                colors: [tile.inactiveFill, tile.inactiveFill.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .aspectRatio(1, contentMode: .fit)
            .overlay(RoundedRectangle(cornerRadius: max(4, 14 * tile.cornerScale), style: .continuous).stroke(active ? tile.accent : tile.border, lineWidth: active ? 2 : 1))
            .overlay(Text(value).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(tile.textColor))
            .shadow(color: tile.shadow.opacity(active ? 0.72 : 0.25), radius: active ? 5 : 2, y: 2)
    }

    private var solitaireMock: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(cards.tableTint)
            .overlay {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Solitaire preview", systemImage: "suit.spade.fill")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
                        Spacer()
                        Text("NOT PLAYABLE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(AppTheme.textPrimary.opacity(0.72))
                    }

                    HStack(spacing: 14) {
                        mockPlayingCard(rank: "A", suit: "♥", color: cards.redSuit)
                            .rotationEffect(.degrees(-6))
                        mockPlayingCard(rank: "K", suit: "♠", color: cards.blackSuit)
                            .offset(y: 9)
                        mockBackCard
                            .rotationEffect(.degrees(6))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(18)
            }
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(cards.border.opacity(0.82), lineWidth: 1.5))
            .padding(.horizontal, 24)
            .shadow(color: cards.shadow.opacity(0.45), radius: 14, x: 0, y: 8)
    }

    private func mockPlayingCard(rank: String, suit: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(cards.frontFill)
            .frame(width: 76, height: 108)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(cards.border, lineWidth: 1.5))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: -2) {
                    Text(rank).font(.headline.weight(.black))
                    Text(suit).font(.caption.bold())
                }
                .foregroundStyle(color)
                .padding(9)
            }
            .overlay(Text(suit).font(.system(size: 32)).foregroundStyle(color.opacity(0.9)))
            .shadow(color: cards.shadow.opacity(0.5), radius: 5, y: 3)
    }

    private var mockBackCard: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(cards.backFill)
            .frame(width: 76, height: 108)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(cards.border, lineWidth: 1.5))
            .overlay(Image(systemName: cards.backSymbol).font(.title2.bold()).foregroundStyle(cards.accent))
            .shadow(color: cards.shadow.opacity(0.5), radius: 5, y: 3)
    }
}

private struct SettingsView: View {
    let user: AppUser

    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferenceKeys.soundEffectsEnabled) private var soundEffectsEnabled = true
    @AppStorage(AppPreferenceKeys.musicEnabled) private var musicEnabled = true
    @AppStorage(AppPreferenceKeys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppPreferenceKeys.reduceExtraAnimations) private var reduceExtraAnimations = false

    @State private var notificationSettings: NotificationSettings
    @State private var statusMessage: String?
    @State private var isWorking = false
    @State private var showDeleteConfirmation = false

    init(user: AppUser) {
        self.user = user
        _notificationSettings = State(initialValue: user.notificationSettings)
    }

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    accountSection
                    notificationSection
                    audioSection
                    gameplaySection
                    supportSection
                    legalSection
                    appInfoSection
                    dangerSection
                }
                .padding()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this account?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This anonymizes your profile, removes notification tokens, cancels pending social invites where possible, and deletes your sign-in account. This cannot be undone.")
        }
    }

    private var accountSection: some View {
        settingsCard("Account", icon: "person.crop.circle.fill", color: AppTheme.hotPink) {
            SettingsInfoRow(title: user.username, detail: user.email, icon: "person.fill")
            Button {
                auth.signOut()
                dismiss()
            } label: {
                SettingsActionRow(title: "Sign Out", detail: "Leave this device signed out.", icon: "rectangle.portrait.and.arrow.right", color: AppTheme.danger)
            }
            .buttonStyle(.plain)
        }
    }

    private var notificationSection: some View {
        settingsCard("Notifications", icon: "bell.badge.fill", color: AppTheme.teal) {
            ForEach(NotificationPreferenceType.allCases) { type in
                Toggle(isOn: notificationBinding(for: type)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(type.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(type.detail)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .tint(AppTheme.hotPink)
                Divider().overlay(AppTheme.cardBorder)
            }

            Button {
                openSystemSettings()
            } label: {
                SettingsActionRow(title: "Manage iOS Notification Permission", detail: "Open Apple Settings for app-level permissions.", icon: "gearshape.fill", color: AppTheme.crownGold)
            }
            .buttonStyle(.plain)
        }
    }

    private var audioSection: some View {
        settingsCard("Audio & Haptics", icon: "speaker.wave.2.fill", color: AppTheme.crownGold) {
            Toggle("Sound Effects", isOn: $soundEffectsEnabled)
                .tint(AppTheme.hotPink)
            Toggle("Music Loops", isOn: Binding {
                musicEnabled
            } set: { isEnabled in
                musicEnabled = isEnabled
                if !isEnabled {
                    SoundManager.shared.stopAllLoops()
                }
            })
                .tint(AppTheme.hotPink)
            Toggle("Haptics", isOn: $hapticsEnabled)
                .tint(AppTheme.hotPink)
        }
    }

    private var gameplaySection: some View {
        settingsCard("Gameplay & Accessibility", icon: "accessibility.fill", color: AppTheme.royalBlue) {
            SettingsInfoRow(title: "Appearance", detail: "Puzzle Party Theme", icon: "paintpalette.fill")
            Toggle("Reduce Extra Animations", isOn: $reduceExtraAnimations)
                .tint(AppTheme.hotPink)
            Text("This calms app-only decorative motion without changing your iPhone accessibility settings.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var supportSection: some View {
        settingsCard("Support", icon: "lifepreserver.fill", color: AppTheme.teal) {
            Button {
                openMail(subject: "Puzzle Party Support")
            } label: {
                SettingsActionRow(title: "Contact Support", detail: "Send an email about your account or purchases.", icon: "envelope.fill", color: AppTheme.teal)
            }
            .buttonStyle(.plain)

            Button {
                openMail(subject: "Puzzle Party Bug Report")
            } label: {
                SettingsActionRow(title: "Report a Problem", detail: "Share bugs, screenshots, or confusing game flow.", icon: "exclamationmark.bubble.fill", color: AppTheme.hotPink)
            }
            .buttonStyle(.plain)

            Button {
                Task { await restorePurchases() }
            } label: {
                SettingsActionRow(title: "Restore Purchases", detail: "Restore ranked access purchases from your Apple account.", icon: "arrow.clockwise.circle.fill", color: AppTheme.crownGold)
            }
            .buttonStyle(.plain)
            .disabled(isWorking)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var legalSection: some View {
        settingsCard("Legal", icon: "doc.text.fill", color: AppTheme.hotPink) {
            ForEach(SettingsLegalPage.allCases) { page in
                NavigationLink {
                    LegalTextView(page: page)
                } label: {
                    SettingsActionRow(title: page.title, detail: page.subtitle, icon: page.icon, color: AppTheme.hotPink)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var appInfoSection: some View {
        settingsCard("App Info", icon: "info.circle.fill", color: AppTheme.royalBlue) {
            SettingsInfoRow(title: "Puzzle Party", detail: "Solo, Ranked, Casual", icon: "puzzlepiece.extension.fill")
            SettingsInfoRow(title: "Version", detail: appVersionText, icon: "number.circle.fill")
            SettingsInfoRow(title: "Theme", detail: "Light pastel Puzzle Party", icon: "sparkles")
        }
    }

    private var dangerSection: some View {
        settingsCard("Danger Zone", icon: "exclamationmark.triangle.fill", color: AppTheme.danger) {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                SettingsActionRow(title: "Delete Account", detail: "Anonymize your profile and delete sign-in access.", icon: "trash.fill", color: AppTheme.danger)
            }
            .buttonStyle(.plain)
            .disabled(isWorking || auth.isLoading)
        }
    }

    private func notificationBinding(for type: NotificationPreferenceType) -> Binding<Bool> {
        Binding {
            notificationSettings.enabled(for: type)
        } set: { isEnabled in
            var updated = notificationSettings
            updated.set(isEnabled, for: type)
            notificationSettings = updated
            Task { await saveNotificationSettings(updated) }
        }
    }

    private func saveNotificationSettings(_ settings: NotificationSettings) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        if await auth.updateNotificationSettings(settings) {
            statusMessage = "Notification settings saved."
        } else {
            statusMessage = auth.errorMessage ?? "Could not save notification settings."
        }
    }

    private func restorePurchases() async {
        guard !isWorking else { return }
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }
        if await auth.restorePurchases() {
            statusMessage = "Purchases restored."
        } else {
            statusMessage = auth.errorMessage ?? "No purchases were restored."
        }
    }

    private func deleteAccount() async {
        guard !isWorking else { return }
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }
        if await auth.deleteAccount() {
            dismiss()
        } else {
            statusMessage = auth.errorMessage ?? "Could not delete account."
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func openMail(subject: String) {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        guard let url = URL(string: "mailto:support@puzzleparty.app?subject=\(encodedSubject)") else { return }
        UIApplication.shared.open(url)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func settingsCard<Content: View>(_ title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline.bold())
                .foregroundStyle(color)
            content()
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
        .shadow(color: AppTheme.softShadow.opacity(0.24), radius: 8, x: 0, y: 4)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(AppTheme.accentBright)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
    }
}

private struct SettingsActionRow: View {
    let title: String
    let detail: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
        }
        .contentShape(Rectangle())
    }
}

private enum SettingsLegalPage: String, CaseIterable, Identifiable {
    case terms
    case privacy
    case community
    case coins

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return "Terms of Service"
        case .privacy: return "Privacy Policy"
        case .community: return "Community Guidelines"
        case .coins: return "Coin & Purchase Policy"
        }
    }

    var subtitle: String {
        switch self {
        case .terms: return "Prototype rules for using Puzzle Party."
        case .privacy: return "What account and gameplay data is used."
        case .community: return "Friendly play and username expectations."
        case .coins: return "Virtual coins, purchases, and ranked access."
        }
    }

    var icon: String {
        switch self {
        case .terms: return "doc.plaintext.fill"
        case .privacy: return "lock.shield.fill"
        case .community: return "person.2.fill"
        case .coins: return "crown.fill"
        }
    }

    var sections: [(String, String)] {
        switch self {
        case .terms:
            return [
                ("Prototype Notice", "Puzzle Party is an in-development game. Features, prices, rewards, modes, and availability may change while testing continues."),
                ("Accounts", "Players are responsible for keeping sign-in access secure and using usernames that are appropriate for a friendly puzzle game."),
                ("Fair Play", "Do not exploit bugs, automate games, harass other players, or interfere with matchmaking, friends, parties, daily challenges, or leaderboards."),
                ("Virtual Items", "Coins, cosmetics, ranked access, and other in-app items are for use inside Puzzle Party only and have no cash value."),
                ("Service Changes", "Online features may be adjusted, paused, or removed as the app is balanced and prepared for release.")
            ]
        case .privacy:
            return [
                ("Data We Use", "Puzzle Party stores account details, username, email, cosmetics, coins, ranks, match results, friends, invites, party rooms, notification tokens, and purchase entitlement state."),
                ("Why We Use It", "This data powers sign-in, matchmaking, fair puzzles, friends, notifications, purchases, leaderboards, recent games, and support."),
                ("Notifications", "If enabled, Firebase Cloud Messaging tokens are stored so the app can send friend, invite, party, turn, and rematch notifications."),
                ("Sharing", "Your username, avatar, ranks, and match results can be visible to opponents, friends, party members, and leaderboard viewers."),
                ("Deletion", "Deleting an account anonymizes profile data where practical and removes notification tokens. Some completed match records may remain for opponent history and game integrity.")
            ]
        case .community:
            return [
                ("Be Friendly", "Use respectful usernames and messages. Puzzle Party is meant to feel playful, social, and welcoming."),
                ("No Harassment", "Do not target, threaten, spam, impersonate, or pressure other players through friends, invites, parties, or rematches."),
                ("Fair Competition", "Play the puzzles yourself. Do not abuse exploits, external automation, or intentional disconnects to manipulate results."),
                ("Reporting", "Use Report a Problem or Contact Support if a player, match, or invite flow feels abusive or broken.")
            ]
        case .coins:
            return [
                ("Virtual Currency", "Coins are virtual only. They cannot be cashed out, transferred for money, redeemed for real prizes, or converted back into currency."),
                ("Purchases", "Coin packs and ranked access are handled through Apple in-app purchase. Cosmetic items do not affect puzzle generation, matchmaking, rank rules, or timers."),
                ("Ranked Rewards", "Ranked matches award virtual coins for eligible results. Losing does not deduct coins, and coins are not required to enter. Ranked access rules still apply."),
                ("Rewards", "Daily challenge, ranked, and multiplayer rewards are virtual only. There are no real-money prizes or cash-equivalent rewards."),
                ("Restores", "Use Restore Purchases for ranked access entitlements. Consumable coin packs are granted when processed and are not restored like permanent unlocks.")
            ]
        }
    }
}

private struct LegalTextView: View {
    let page: SettingsLegalPage

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Draft policy for testing. Final App Store legal copy should be reviewed before launch.")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.crownGold)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.crownGold.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    ForEach(page.sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.0)
                                .font(.headline.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(section.1)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }
                }
                .padding()
            }
        }
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ModeRankRow: View {
    let mode: GameMode
    let info: RankInfo

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.modeGradient(mode))
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: mode.icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white))

            Text(mode.displayName).foregroundStyle(AppTheme.textPrimary)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                RankBadgeView(tier: info.displayTier, division: info.division, iconSize: 22, labelFont: .subheadline.bold())
                RankDivisionProgressView(info: info, height: 4, spacing: 3)
                    .frame(width: 112)
                Text(info.nextRankStepText).font(.caption).foregroundStyle(AppTheme.textSecondary)
                Text("Solo \(info.soloBest?.displayText(for: mode) ?? "--") · Online \(info.onlineBest?.displayText(for: mode) ?? "--")")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.accentBright)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value).bold().foregroundStyle(AppTheme.textPrimary)
        }
        .font(.subheadline)
    }
}

private struct RecentOnlineStatsView: View {
    let sessions: [GameSession]
    let currentUserID: String
    let totalRankPoints: Int

    private var ranked: RecentTypeRecord { record(for: { $0.matchKind == .ranked }) }
    private var casual: RecentTypeRecord { record(for: { $0.matchKind == .casual }) }
    private var friends: RecentTypeRecord { record(for: { $0.isExhibition }) }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statTile("Ranked", ranked.display, "trophy.fill", AppTheme.crownGold)
            statTile("Casual", casual.display, "shuffle.circle.fill", AppTheme.teal)
            statTile("Friends", friends.display, "person.2.fill", AppTheme.hotPink)
            statTile("Best Type", bestTypeText, "star.fill", AppTheme.accentBright)
            statTile("Total Points", "\(totalRankPoints)", "sparkles", AppTheme.crownGold)
        }
        Text("Stats include all completed online matches.")
            .font(.caption2)
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statTile(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
    }

    private var bestTypeText: String {
        let values = [
            ("Ranked", ranked.wins),
            ("Casual", casual.wins),
            ("Friends", friends.wins)
        ]
        guard let best = values.max(by: { $0.1 < $1.1 }), best.1 > 0 else {
            return "No games yet"
        }
        return best.0
    }

    private func record(for predicate: (GameSession) -> Bool) -> RecentTypeRecord {
        sessions.filter(predicate).reduce(into: RecentTypeRecord()) { partial, session in
            switch session.result(for: currentUserID) ?? .draw {
            case .win:
                partial.wins += 1
            case .loss, .abandoned:
                partial.losses += 1
            case .draw:
                partial.draws += 1
            }
        }
    }
}

private struct RecentTypeRecord {
    var wins = 0
    var losses = 0
    var draws = 0

    var display: String {
        "\(wins)-\(losses)-\(draws)"
    }
}

private struct RecentGamesListView: View {
    let sessions: [GameSession]
    let currentUserID: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSession: GameSession?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sessions) { session in
                            RecentGameRow(session: session, currentUserID: currentUserID) {
                                selectedSession = session
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Recent Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accentBright)
                }
            }
            .sheet(item: $selectedSession) { session in
                MatchBreakdownView(
                    session: session,
                    currentUserID: currentUserID,
                    results: session.playerResults ?? [:]
                )
            }
        }
    }
}

private struct RecentGameRow: View {
    let session: GameSession
    let currentUserID: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.modeGradient(session.mode))
                    .frame(width: 42, height: 42)
                    .overlay(Image(systemName: session.mode.icon).font(.subheadline.bold()).foregroundStyle(.white))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(session.mode.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Text(kindLabel)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(kindColor.opacity(0.18))
                            .foregroundStyle(kindColor)
                            .clipShape(Capsule())
                    }
                    Text(opponentText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                    Text(reasonText)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(outcomeLabel)
                        .font(.caption.bold())
                        .foregroundStyle(outcomeColor)
                    Text(dateText)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.cardBorder.opacity(0.8), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(session.mode.displayName), \(kindLabel), \(outcomeLabel), \(dateText)")
    }

    private var outcomeLabel: String {
        switch session.result(for: currentUserID) ?? .draw {
        case .win: return "Win"
        case .loss: return "Loss"
        case .draw: return "Draw"
        case .abandoned: return "Left"
        }
    }

    private var outcomeColor: Color {
        switch session.result(for: currentUserID) ?? .draw {
        case .win: return AppTheme.success
        case .loss, .abandoned: return AppTheme.danger
        case .draw: return AppTheme.crownGold
        }
    }

    private var kindLabel: String {
        switch session.matchKind {
        case .ranked: return "Ranked"
        case .casual: return "Casual"
        case .exhibition, .asyncExhibition: return "Exhibition"
        case .party: return "Party"
        }
    }

    private var kindColor: Color {
        switch session.matchKind {
        case .ranked: return AppTheme.crownGold
        case .casual: return AppTheme.teal
        case .exhibition, .asyncExhibition: return AppTheme.hotPink
        case .party: return AppTheme.royalBlue
        }
    }

    private var opponentText: String {
        let names = session.players
            .filter { $0.userID != currentUserID }
            .map(\.username)
            .filter { !$0.isEmpty }
        return names.isEmpty ? "No opponent listed" : "vs \(names.joined(separator: ", "))"
    }

    private var reasonText: String {
        if let forfeiter = forfeitPlayer {
            return forfeiter.userID == currentUserID ? "You forfeited" : "\(forfeiter.username) forfeited"
        }
        return session.winnerReason ?? session.mode.winConditionText
    }

    private var forfeitPlayer: MatchPlayer? {
        if let forfeiterID = session.playerResults?.first(where: { $0.value.summary["forfeit"] == "true" })?.key {
            return session.players.first { $0.userID == forfeiterID }
        }
        guard session.winnerReason == "Opponent forfeited", let winnerID = session.winnerID else { return nil }
        return session.players.first { $0.userID != winnerID }
    }

    private var dateText: String {
        guard let date = session.finishedAt ?? session.startedAt else { return "Recent" }
        return Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
