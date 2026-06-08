import SwiftUI

struct ProfileView: View {
    let user: AppUser
    let onDone: (() -> Void)?
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var shop: ShopViewModel
    @State private var isGrantingTesterAccess = false
    @State private var selectedOwnedCategory: CosmeticCategory = .title
    @State private var showAvatarEditor = false
    @State private var showGameCustomizer = false
    @State private var recentGames: [GameSession] = []
    @State private var onlineStatGames: [GameSession] = []
    @State private var isLoadingRecentGames = false
    @State private var recentGamesError: String?
    @State private var selectedRecentGame: GameSession?
    @State private var showAllRecentGames = false

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
                            StickDuelerAvatarView(style: shop.ownedCosmetics.avatarStyle, size: 96)

                            HStack(spacing: 10) {
                                Button { showAvatarEditor = true } label: {
                                    Label("Customize Profile", systemImage: "sparkles")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.hotPink.opacity(0.18))
                                        .foregroundStyle(AppTheme.hotPink)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(AppTheme.hotPink.opacity(0.45), lineWidth: 1))
                                }

                                Button { showGameCustomizer = true } label: {
                                    Label("Game Customization", systemImage: "paintpalette.fill")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.teal.opacity(0.18))
                                        .foregroundStyle(AppTheme.teal)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(AppTheme.teal.opacity(0.45), lineWidth: 1))
                                }
                            }

                            Text(user.username).font(.title2.bold()).foregroundStyle(AppTheme.textPrimary)
                            Text(shop.equippedTitleName)
                                .font(.subheadline.italic())
                                .foregroundStyle(AppTheme.accentBright)
                            Text(user.email).font(.caption).foregroundStyle(AppTheme.textSecondary)
                            CoinBadgeView(amount: user.coins)

                            #if DEBUG
                            Button {
                                Task {
                                    isGrantingTesterAccess = true
                                    await auth.grantTesterRankedAccess()
                                    isGrantingTesterAccess = false
                                }
                            } label: {
                                Label(
                                    auth.user?.rankedAccess.allModesUnlocked == true ? "Tester Ranked Access On" : "Enable Tester Ranked Access",
                                    systemImage: auth.user?.rankedAccess.allModesUnlocked == true ? "checkmark.seal.fill" : "hammer.fill"
                                )
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.crownGold.opacity(0.2))
                                .foregroundStyle(AppTheme.crownGold)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppTheme.crownGold.opacity(0.45), lineWidth: 1))
                            }
                            .disabled(isGrantingTesterAccess || auth.user?.rankedAccess.allModesUnlocked == true)
                            #endif
                        }
                        .padding(.top, 24)

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
            .sheet(isPresented: $showAvatarEditor) {
                AvatarEditorView(shop: shop) {
                    await auth.refreshUser()
                }
            }
            .sheet(isPresented: $showGameCustomizer) {
                GameCustomizationView(shop: shop) {
                    await auth.refreshUser()
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
            }
        }
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
        isLoadingRecentGames = true
        recentGamesError = nil
        do {
            async let recent = FirestoreService.shared.fetchRecentFinishedSessions(for: user.id, limit: 20)
            async let cumulative = FirestoreService.shared.fetchFinishedOnlineSessions(for: user.id)
            recentGames = try await recent
            onlineStatGames = try await cumulative
        } catch {
            recentGamesError = "Could not load recent games right now."
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


private struct AvatarEditorView: View {
    @ObservedObject var shop: ShopViewModel
    var onChanged: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: CosmeticCategory = .avatarHead
    @State private var bodyHexInput: String
    @State private var bodyHexError: String?

    private let categories: [CosmeticCategory] = [.title, .avatarHead, .avatarFace, .avatarOutfit, .avatarAura]

    init(shop: ShopViewModel, onChanged: @escaping () async -> Void) {
        self.shop = shop
        self.onChanged = onChanged
        _bodyHexInput = State(initialValue: shop.ownedCosmetics.customAvatarBodyHex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        StickDuelerAvatarView(style: shop.ownedCosmetics.avatarStyle, size: 150)
                            .padding(.top, 18)
                        Text("Puzzle Profile")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Equip owned avatar parts and name titles here. Buy new cosmetics in the Shop.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
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
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert(
                "Profile update failed",
                isPresented: Binding(get: { shop.errorMessage != nil }, set: { if !$0 { shop.errorMessage = nil } })
            ) {
                Button("OK") { shop.errorMessage = nil }
            } message: {
                Text(shop.errorMessage ?? "")
            }
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
                    title: "Owned",
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
        case .avatarFace: return "Face"
        case .avatarOutfit: return "Body"
        case .avatarAura: return "Aura"
        case .avatarPose: return "Pose"
        case .tileTheme: return "Tile"
        default: return category.rawValue
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
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: CosmeticCategory = .boardTheme

    private let categories: [CosmeticCategory] = [.boardTheme, .tileTheme]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Tune how boards and tiles look across your games.")
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

                        ownedGameItems
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Game Customization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert(
                "Customization failed",
                isPresented: Binding(get: { shop.errorMessage != nil }, set: { if !$0 { shop.errorMessage = nil } })
            ) {
                Button("OK") { shop.errorMessage = nil }
            } message: {
                Text(shop.errorMessage ?? "")
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
                    }
                }
            }
        }
    }

    private func label(for category: CosmeticCategory) -> String {
        switch category {
        case .boardTheme: return "Board / Background Themes"
        case .tileTheme: return "Tile Themes"
        default: return category.rawValue
        }
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
