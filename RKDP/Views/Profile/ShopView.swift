import SwiftUI


private enum ShopSection: Hashable, CaseIterable {
    case cosmetics
    case rankedPass
    case coinPacks

    var title: String {
        switch self {
        case .cosmetics: return "Cosmetics"
        case .rankedPass: return "Ranked Pass"
        case .coinPacks: return "Coin Packs"
        }
    }
}

private let cosmeticPacksEnabled = false

struct ShopView: View {
    let user: AppUser
    var onUserChanged: () -> Void = {}
    @StateObject private var vm: ShopViewModel
    @ObservedObject private var coinStore = CoinPackStoreKitService.shared
    @State private var selectedSection: ShopSection = .cosmetics
    @State private var confirmingPack: CosmeticPackKind?
    #if DEBUG
    @State private var showCosmeticCollectionDebug = false
    #endif
    @Environment(\.dismiss) var dismiss

    init(user: AppUser, onUserChanged: @escaping () -> Void = {}) {
        self.user = user
        self.onUserChanged = onUserChanged
        _vm = StateObject(wrappedValue: ShopViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Coin balance
                HStack {
                    Spacer()
                    Label("Balance:", systemImage: "circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    CoinBadgeView(amount: vm.user.coins)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)

                // Store tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ShopSection.allCases, id: \.self) { section in
                            Button {
                                guard selectedSection != section else { return }
                                SoundManager.shared.appButtonTap()
                                selectedSection = section
                            } label: {
                                Text(section.title)
                                    .font(.subheadline.weight(selectedSection == section ? .bold : .regular))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(selectedSection == section ? AppTheme.hotPink : AppTheme.cardBackground)
                                    .foregroundStyle(selectedSection == section ? AppTheme.textOnColor : AppTheme.textSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                // Rotation countdown banner
                if selectedSection == .cosmetics {
                    RotationCountdownBanner(nextDate: vm.nextRotationDate)
                }

                // Items
                ScrollView {
                    if vm.refundDebt > 0 {
                        Label("Refund adjustment: \(vm.refundDebt) coins remaining. Earned coins go toward this amount before increasing your balance.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                    }
                    switch selectedSection {
                    case .cosmetics:
                        cosmeticsSection
                            .padding(.vertical)
                    case .rankedPass:
                        rankedPassSection
                            .padding()
                    case .coinPacks:
                        coinPackSection
                            .padding()
                    }
                }
            }
            .background(AppTheme.arenaBackground.ignoresSafeArea())
            .foregroundStyle(AppTheme.textPrimary)
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: vm.user.coins) { await vm.refreshRefundStatus() }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(item: $confirmingPack) { kind in
                CosmeticPackConfirmSheet(
                    kind: kind,
                    balance: vm.user.coins,
                    canAfford: vm.canAffordPack(kind),
                    isBusy: vm.isSaving
                ) {
                    Task {
                        if await vm.openPack(kind) {
                            confirmingPack = nil
                            onUserChanged()
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(
                isPresented: Binding(
                    get: { vm.openedPackResult != nil },
                    set: { if !$0 { vm.openedPackResult = nil } }
                )
            ) {
                if let result = vm.openedPackResult {
                    CosmeticPackRevealView(result: result) {
                        vm.openedPackResult = nil
                    }
                }
            }
            #if DEBUG
            .sheet(isPresented: $showCosmeticCollectionDebug) {
                CosmeticCollectionDebugView(vm: vm)
            }
            #endif
            .tint(AppTheme.accentBright)
            .alert(
                "Shop update failed",
                isPresented: Binding(
                    get: { vm.errorMessage != nil },
                    set: { if !$0 { vm.errorMessage = nil } }
                )
            ) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }


    private var cosmeticsSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            if cosmeticPacksEnabled {
                cosmeticPackShelf
            }

            #if DEBUG
            debugCollectionButton
            #endif

            itemSection(
                title: "Avatar Shop",
                subtitle: "Daily bodies, headwear, auras, and bold expressions.",
                items: vm.todaysAvatarShopItems
            )

            itemSection(
                title: "Board Themes",
                subtitle: "Play surfaces, grid lines, highlights, and path accents.",
                items: vm.todaysBoardShopItems
            )

            itemSection(
                title: "Letter & Number Tiles",
                subtitle: "Puzzle pieces for Word Guess, Anagrams, Word Hunt, and Sudoku.",
                items: vm.todaysTileShopItems
            )

            itemSection(
                title: "Card Themes",
                subtitle: "Solitaire card fronts, backs, suits, and table styling.",
                items: vm.todaysCardShopItems
            )

            itemSection(
                title: "Name Titles",
                subtitle: "Four rotating titles for today.",
                items: vm.todaysTitleShopItems
            )

            Text("Owned cosmetics stay organized in Profile customization, where board surfaces, letter and number tiles, and Solitaire cards remain separate.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
        }
        .padding(.horizontal)
    }

    #if DEBUG
    // DEBUG-only collector browser; remove this block and its sheet before final release if needed.
    private var debugCollectionButton: some View {
        let ownedCount = CosmeticCatalog.all.filter { vm.isOwned($0) }.count
        let totalCount = CosmeticCatalog.all.count

        return Button {
            showCosmeticCollectionDebug = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.hotPink)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.hotPink.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Debug Collection Checklist")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(ownedCount) / \(totalCount) collected")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(12)
            .background(AppTheme.controlBackground.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.hotPink.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    #endif

    private var cosmeticPackShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PUZZLE PACKS")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.hotPink)
                Text("Open with coins for cosmetics. Duplicates convert into coins.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CosmeticPackKind.allCases) { kind in
                    CosmeticPackCard(
                        kind: kind,
                        canAfford: vm.canAffordPack(kind),
                        isBusy: vm.isSaving
                    ) {
                        confirmingPack = kind
                    }
                }
            }
        }
    }

    private var coinPackSection: some View {
        VStack(spacing: 14) {
            if let message = coinStore.pendingDeliveryError {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Purchase awaiting delivery", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                    Text(message).font(.subheadline)
                    Button {
                        Task { if await vm.retryPendingCoinPurchases() { onUserChanged() } }
                    } label: {
                        Label("Retry Delivery", systemImage: "arrow.clockwise")
                    }
                    .disabled(vm.isSaving)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Free Coins")
                    .font(.headline.bold())
                DailyPlayBonusBanner(user: vm.user)
                HStack(spacing: 10) {
                    freeCoinButton(
                        title: "+\(CoinWallet.dailyClaimAmount)",
                        subtitle: vm.user.coinWallet.canClaimDaily() ? "Daily claim" : "Claimed today",
                        icon: "calendar.badge.plus",
                        enabled: vm.user.coinWallet.canClaimDaily()
                    ) {
                        Task { if await vm.claimDailyCoins() { onUserChanged() } }
                    }
                    freeCoinButton(
                        title: "+\(CoinWallet.rewardedAdAmount)",
                        subtitle: "Ad \(vm.user.coinWallet.rewardedAdsRemaining())/\(CoinWallet.rewardedAdsPerDay)",
                        icon: "play.rectangle.fill",
                        enabled: vm.user.coinWallet.rewardedAdsRemaining() > 0
                    ) {
                        Task { if await vm.watchCoinAd() { onUserChanged() } }
                    }
                }
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CoinPackProduct.all) { pack in
                    CoinPackCard(
                        pack: pack,
                        price: vm.coinPackPriceText(for: pack),
                        isBusy: vm.isSaving
                    ) {
                        Task { if await vm.purchaseCoinPack(pack) { onUserChanged() } }
                    }
                }
            }

            Text("Coins unlock cosmetics. Ranked matches never cost coins. Coins cannot be cashed out or redeemed for real prizes.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var rankedPassSection: some View {
        RankedAccessStoreContent(user: vm.user) {
            onUserChanged()
        }
    }

    private func freeCoinButton(title: String, subtitle: String, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3.bold())
                Text(title)
                    .font(.headline.bold())
                Text(subtitle)
                    .font(.caption2.bold())
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(enabled ? AppTheme.crownGold.opacity(0.22) : AppTheme.cardBackground)
            .foregroundStyle(enabled ? AppTheme.crownGold : AppTheme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(enabled ? AppTheme.crownGold.opacity(0.5) : AppTheme.cardBorder, lineWidth: 1))
        }
        .disabled(!enabled || vm.isSaving)
    }

    private func handleShopAction(_ item: CosmeticItem) async {
        let changed: Bool
        if vm.isOwned(item) {
            changed = await vm.equip(item)
        } else {
            changed = await vm.purchase(item)
        }
        if changed { onUserChanged() }
    }

    private func itemGrid(items: [CosmeticItem]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(items) { item in
                ShopItemCard(
                    item: item,
                    isOwned: vm.isOwned(item),
                    isEquipped: vm.isEquipped(item),
                    canAfford: vm.canAfford(item),
                    isLimited: false,
                    allowsOwnedEquip: false
                ) {
                    Task { await handleShopAction(item) }
                }
            }
        }
    }

    private func rotationShopGrid(category: CosmeticCategory, items: [CosmeticItem]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            itemSection(
                title: todaysTitle(for: category),
                subtitle: category.isAvatarCategory ? "Four rotating avatar cosmetics for today." : "Four rotating cosmetics for today.",
                items: items
            )
        }
        .padding(.horizontal)
    }

    private func todaysTitle(for category: CosmeticCategory) -> String {
        switch category {
        case .title: return "Today's Titles"
        case .avatarHead: return "Today's Heads"
        case .avatarFace: return "Today's Faces"
        case .avatarOutfit: return "Today's Bodies"
        case .avatarAura: return "Today's Auras"
        default: return "Today's Picks"
        }
    }

    private func itemSection(title: String, subtitle: String, items: [CosmeticItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(title == "Owned" ? AppTheme.teal : AppTheme.hotPink)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            itemGrid(items: items)
        }
    }

    @ViewBuilder
    private func titleGrid(items: [CosmeticItem], ownedItems: [CosmeticItem]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if !ownedItems.isEmpty {
                itemSection(title: "Owned", subtitle: "Equip one of your saved titles.", items: ownedItems)
            }

            if !items.isEmpty {
                itemSection(title: "Today's Titles", subtitle: "Four rotating titles available today.", items: items)
            }
        }
        .padding(.vertical)
        .padding(.horizontal)
    }

    private func emptyStoreState(category: CosmeticCategory) -> some View {
        VStack(spacing: 10) {
            Image(systemName: category == .title ? "clock.arrow.circlepath" : "bag.fill")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.crownGold)
            Text("No items in today’s cycle")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text("Owned cosmetics are managed from Profile. Store tabs show today’s rotating picks only.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

#if DEBUG
private struct CosmeticCollectionDebugView: View {
    @ObservedObject var vm: ShopViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: CosmeticCategory = .title
    @State private var showOwnedOnly = false

    private let categories: [CosmeticCategory] = [.title, .avatarHead, .avatarFace, .avatarOutfit, .avatarAura, .boardTheme, .tileTheme, .cardTheme]

    private var totalItems: [CosmeticItem] {
        CosmeticCatalog.all
    }

    private var visibleItems: [CosmeticItem] {
        totalItems
            .filter { $0.category == selectedCategory }
            .filter { !showOwnedOnly || vm.isOwned($0) }
            .sorted { lhs, rhs in
                if vm.isOwned(lhs) != vm.isOwned(rhs) { return vm.isOwned(lhs) }
                if lhs.rarity != rhs.rarity { return raritySort(lhs.rarity) < raritySort(rhs.rarity) }
                if lhs.price != rhs.price { return lhs.price < rhs.price }
                return lhs.name < rhs.name
            }
    }

    private var ownedCount: Int {
        totalItems.filter { vm.isOwned($0) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.arenaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryCard
                        categoryPicker
                        Toggle("Show owned only", isOn: $showOwnedOnly)
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                            .tint(AppTheme.hotPink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppTheme.controlBackground.opacity(0.78))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))

                        categorySection
                    }
                    .padding()
                }
            }
            .navigationTitle("Cosmetic Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accentBright)
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("DEBUG ONLY", systemImage: "hammer.fill")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.crownGold)
                Spacer()
                Text("\(ownedCount) / \(totalItems.count)")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }

            ProgressView(value: Double(ownedCount), total: Double(max(1, totalItems.count)))
                .tint(AppTheme.hotPink)

            Text("Quickly checks collected vs missing cosmetics. This is intentionally isolated behind DEBUG so it can be removed before release.")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    let owned = totalItems.filter { $0.category == category && vm.isOwned($0) }.count
                    let total = totalItems.filter { $0.category == category }.count

                    Button {
                        selectedCategory = category
                    } label: {
                        VStack(spacing: 2) {
                            Text(shortLabel(for: category))
                                .font(.caption.bold())
                            Text("\(owned)/\(total)")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedCategory == category ? AppTheme.hotPink : AppTheme.controlBackground)
                        .foregroundStyle(selectedCategory == category ? AppTheme.textOnColor : AppTheme.textSecondary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selectedCategory == category ? Color.white.opacity(0.55) : AppTheme.controlBorder, lineWidth: 1))
                    }
                }
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(shortLabel(for: selectedCategory).uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.hotPink)
                Spacer()
                Text("\(visibleItems.filter { vm.isOwned($0) }.count) owned shown")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if visibleItems.isEmpty {
                Text(showOwnedOnly ? "No owned cosmetics in this category yet." : "No cosmetics in this category.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(visibleItems) { item in
                        ShopItemCard(
                            item: item,
                            isOwned: vm.isOwned(item),
                            isEquipped: vm.isEquipped(item),
                            canAfford: false,
                            isLimited: false,
                            allowsOwnedEquip: false
                        ) {}
                    }
                }
            }
        }
    }

    private func shortLabel(for category: CosmeticCategory) -> String {
        switch category {
        case .title: return "Titles"
        case .avatarHead: return "Heads"
        case .avatarFace: return "Faces"
        case .avatarOutfit: return "Bodies"
        case .avatarAura: return "Auras"
        case .boardTheme: return "Boards"
        case .tileTheme: return "Tiles"
        case .cardTheme: return "Cards"
        default: return category.rawValue
        }
    }

    private func raritySort(_ rarity: CosmeticRarity) -> Int {
        switch rarity {
        case .free: return 0
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }
}
#endif

private struct DailyPlayBonusBanner: View {
    let user: AppUser

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: user.playProgress.hasPlayedToday ? "flame.fill" : "calendar.badge.plus")
                .font(.headline.bold())
                .foregroundStyle(user.playProgress.hasPlayedToday ? AppTheme.hotPink : AppTheme.crownGold)
                .frame(width: 30, height: 30)
                .background((user.playProgress.hasPlayedToday ? AppTheme.hotPink : AppTheme.crownGold).opacity(0.16))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(user.playProgress.hasPlayedToday ? "\(max(1, user.playProgress.currentStreak)) day play streak" : "Play any game today")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(user.playProgress.canEarnDailyBonusToday ? "Play any game today to claim +\(CoinWallet.dailyPlayReward) coins." : "Today's daily play bonus is claimed.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(AppTheme.controlBackground.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))
    }
}



private struct CoinPackCard: View {
    let pack: CoinPackProduct
    let price: String
    let isBusy: Bool
    let onBuy: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.brandGradient)
                .frame(height: 82)
                .overlay(
                    VStack(spacing: 4) {
                        CoinIconView(size: 26)
                        Text("\(pack.coins.formatted())")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                )
                .shadow(color: AppTheme.crownGold.opacity(0.24), radius: 10, x: 0, y: 5)

            Text(pack.title)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(pack.subtitle)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Button(action: onBuy) {
                Text(price)
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(AppTheme.hotPink)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(isBusy)
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}

private struct CosmeticPackCard: View {
    let kind: CosmeticPackKind
    let canAfford: Bool
    let isBusy: Bool
    let onOpen: () -> Void

    private var enabled: Bool { canAfford && !isBusy }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                CosmeticPackThumbnailView(kind: kind, isEnabled: enabled)

                Text(kind.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(kind.subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    CoinIconView(size: 15)
                    Text("\(kind.price)")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(enabled ? AppTheme.hotPink : AppTheme.controlBackground)
                .foregroundStyle(enabled ? AppTheme.textOnColor : AppTheme.textSecondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(enabled ? Color.clear : AppTheme.controlBorder, lineWidth: 1))
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("\(kind.title), \(kind.price) coins")
    }
}

private struct CosmeticPackThumbnailView: View {
    let kind: CosmeticPackKind
    let isEnabled: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(backgroundGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.66), lineWidth: 1)
                )
                .shadow(color: glowColor.opacity(isEnabled ? 0.28 : 0.08), radius: 12, x: 0, y: 6)

            if kind == .avatar {
                avatarHints
                    .offset(x: -36, y: -2)
            } else {
                themeHints
                    .offset(x: -37, y: 0)
            }

            toyBox
                .offset(x: 27, y: 3)

            sparkleLayer
        }
        .frame(height: 92)
        .opacity(isEnabled ? 1 : 0.58)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var toyBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(packGradient)
                .frame(width: 78, height: 72)
                .rotationEffect(.degrees(-4))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.78), lineWidth: 1.4)
                        .rotationEffect(.degrees(-4))
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.24))
                        .frame(width: 58, height: 12)
                        .offset(y: 7)
                        .rotationEffect(.degrees(-4))
                }
                .shadow(color: glowColor.opacity(0.38), radius: 10, x: 0, y: 5)

            VStack(spacing: 4) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)

                Text(kind == .avatar ? "AVATAR" : "THEME")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                    .tracking(0)
            }
            .rotationEffect(.degrees(-4))
        }
    }

    private var avatarHints: some View {
        ZStack {
            PreviewPuzzlePieceShape()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.96), AppTheme.hotPink.opacity(0.42), AppTheme.teal.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .overlay(PreviewPuzzlePieceShape().stroke(Color.white.opacity(0.86), lineWidth: 1.2))
                .shadow(color: AppTheme.hotPink.opacity(0.2), radius: 6, x: 0, y: 4)

            Image(systemName: "face.smiling.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.royalBlue.opacity(0.86))
        }
    }

    private var themeHints: some View {
        ZStack {
            miniBoard
                .rotationEffect(.degrees(-5))
                .offset(x: -6, y: -2)

            miniTiles
                .rotationEffect(.degrees(6))
                .offset(x: 23, y: 11)
        }
    }

    private var miniBoard: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(colors: [AppTheme.royalBlue, AppTheme.teal, AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 48, height: 50)
            .overlay(
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { column in
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                    .fill((row + column).isMultiple(of: 2) ? Color.white.opacity(0.78) : Color.white.opacity(0.32))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.78), lineWidth: 1))
            .shadow(color: AppTheme.royalBlue.opacity(0.22), radius: 6, x: 0, y: 4)
    }

    private var miniTiles: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(12), spacing: 3), count: 2), spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(index.isMultiple(of: 2) ? AppTheme.crownGold : AppTheme.hotPink)
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Color.white.opacity(0.76), lineWidth: 0.8))
                    .frame(width: 12, height: 12)
            }
        }
        .padding(7)
        .background(AppTheme.textOnColor.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.white.opacity(0.84), lineWidth: 1))
        .shadow(color: AppTheme.hotPink.opacity(0.2), radius: 6, x: 0, y: 4)
    }

    private var sparkleLayer: some View {
        ZStack {
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(Color.white.opacity(0.92))
                .offset(x: -9, y: -31)

            Circle()
                .fill(AppTheme.crownGold.opacity(0.9))
                .frame(width: 6, height: 6)
                .offset(x: -60, y: 28)
        }
    }

    private var backgroundGradient: LinearGradient {
        switch kind {
        case .avatar:
            return LinearGradient(colors: [Color(hex: "FFF0FA"), AppTheme.hotPink.opacity(0.32), AppTheme.teal.opacity(0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .theme:
            return LinearGradient(colors: [Color(hex: "FFF7D6"), AppTheme.crownGold.opacity(0.34), AppTheme.royalBlue.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var glowColor: Color {
        switch kind {
        case .avatar: return AppTheme.hotPink
        case .theme: return AppTheme.crownGold
        }
    }

    private var packGradient: LinearGradient {
        switch kind {
        case .avatar:
            return LinearGradient(colors: [AppTheme.hotPink, Color(hex: "7B42FF"), AppTheme.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .theme:
            return LinearGradient(colors: [AppTheme.crownGold, AppTheme.hotPink, AppTheme.royalBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct CosmeticPackConfirmSheet: View {
    let kind: CosmeticPackKind
    let balance: Int
    let canAfford: Bool
    let isBusy: Bool
    let onOpen: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var actionTitle: String {
        if !canAfford { return "Not Enough Coins" }
        return "Open for \(kind.price) coins"
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(AppTheme.cardBorder)
                .frame(width: 44, height: 5)
                .padding(.top, 8)

            VStack(spacing: 8) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(AppTheme.hotPink)
                    .frame(width: 66, height: 66)
                    .background(AppTheme.hotPink.opacity(0.14))
                    .clipShape(Circle())

                Text(kind.title)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Duplicates convert into coins.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Drop odds")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(kind.odds, id: \.rarity) { odds in
                    HStack {
                        RarityBadgeView(rarity: odds.rarity)
                        Spacer()
                        Text("\(odds.percent)%")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }
            .padding(14)
            .background(AppTheme.controlBackground.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.controlBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 10) {
                Text("Duplicate refunds")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach([CosmeticRarity.common, .rare, .epic, .legendary], id: \.self) { rarity in
                    HStack {
                        RarityBadgeView(rarity: rarity)
                        Spacer()
                        HStack(spacing: 5) {
                            CoinIconView(size: 14)
                            Text("+\(rarity.duplicateRefund)")
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }
            }
            .padding(14)
            .background(AppTheme.controlBackground.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.controlBorder.opacity(0.8), lineWidth: 1))

            HStack {
                Text("Balance")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                CoinBadgeView(amount: balance)
            }

            Button(action: onOpen) {
                Text(actionTitle)
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canAfford ? AppTheme.hotPink : AppTheme.controlBackground)
                    .foregroundStyle(canAfford ? AppTheme.textOnColor : AppTheme.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!canAfford || isBusy)

            Button("Cancel") { dismiss() }
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(20)
        .background(AppTheme.arenaBackground.ignoresSafeArea())
    }
}

private enum CosmeticPackRevealPhase {
    case sealed
    case charging
    case burst
    case reveal
}

private struct CosmeticPackRevealView: View {
    let result: CosmeticPackOpenResult
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppPreferenceKeys.reduceExtraAnimations) private var reduceExtraAnimations = false
    @State private var phase: CosmeticPackRevealPhase = .sealed
    @State private var packWobble = false
    @State private var pulse = false
    @State private var burstOut = false
    @State private var cardVisible = false
    @State private var hasStarted = false

    private var motionDisabled: Bool { reduceMotion || reduceExtraAnimations }
    private var rarity: CosmeticRarity { result.item.rarity }

    var body: some View {
        ZStack {
            RarityRevealBackdrop(
                rarity: rarity,
                phase: phase,
                pulse: pulse,
                burstOut: burstOut,
                motionDisabled: motionDisabled
            )

            if !motionDisabled {
                PackBurstParticlesView(rarity: rarity, phase: phase, burstOut: burstOut)
            }

            VStack(spacing: 18) {
                Spacer(minLength: 16)

                VStack(spacing: 8) {
                    Text(headlineText)
                        .font(.system(size: phase == .reveal ? 30 : 26, weight: .black, design: .rounded))
                        .foregroundStyle(rarity.tileGlowColor)
                        .multilineTextAlignment(.center)

                    Text(subtitleText)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .scaleEffect(phase == .burst ? 1.06 : 1)
                .animation(.spring(response: 0.42, dampingFraction: 0.74), value: phase)

                ZStack {
                    if phase != .reveal {
                        Button(action: startOpening) {
                            SealedCosmeticPackView(
                                kind: result.kind,
                                rarity: rarity,
                                phase: phase,
                                wobble: packWobble,
                                pulse: pulse,
                                motionDisabled: motionDisabled
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(phase != .sealed)
                        .transition(.scale.combined(with: .opacity))
                    }

                    if phase == .reveal {
                        ZStack {
                            ShopItemCard(
                                item: result.item,
                                isOwned: true,
                                isEquipped: false,
                                canAfford: true,
                                isLimited: false,
                                allowsOwnedEquip: false
                            ) {}
                            .frame(maxWidth: 260)
                            .scaleEffect(cardVisible ? 1 : 0.52)
                            .rotation3DEffect(.degrees(cardVisible ? 0 : 88), axis: (x: 0, y: 1, z: 0))
                            .shadow(color: rarity.tileGlowColor.opacity(rarity.glowOpacity), radius: rarity.shadowRadius * 2.4, x: 0, y: 12)

                            if result.isDuplicate {
                                DuplicateRefundBurstView(amount: result.duplicateRefund, rarity: rarity, isVisible: cardVisible)
                                    .offset(y: 118)
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 286)

                VStack(spacing: 4) {
                    if phase == .sealed {
                        Text("Tap to open")
                            .font(.headline.bold())
                            .foregroundStyle(rarity.tileGlowColor)
                    } else if phase == .charging {
                        Text("Charging...")
                            .font(.headline.bold())
                            .foregroundStyle(rarity.tileGlowColor)
                    } else if phase == .burst {
                        Text("Revealing...")
                            .font(.headline.bold())
                            .foregroundStyle(rarity.tileGlowColor)
                    } else {
                        Text(result.item.name)
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(revealDetailText)
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .frame(minHeight: 46)
                .opacity(phase == .reveal ? (cardVisible ? 1 : 0) : 1)
                .animation(.easeOut(duration: 0.24), value: cardVisible)

                Spacer()

                if phase == .reveal {
                    Button(action: onDone) {
                        Text("Done")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(AppTheme.hotPink)
                            .foregroundStyle(AppTheme.textOnColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Color.clear
                        .frame(height: 69)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            guard !motionDisabled else { return }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var headlineText: String {
        switch phase {
        case .sealed: return result.kind.title
        case .charging: return "Powering Up"
        case .burst: return "Revealing..."
        case .reveal:
            if result.isDuplicate { return "Duplicate!" }
            return rarity == .legendary ? "Legendary Unlock!" : "New Unlock!"
        }
    }

    private var subtitleText: String {
        switch phase {
        case .sealed: return "Duplicates convert into coins."
        case .charging: return "Rarity energy is building..."
        case .burst: return "Card forming"
        case .reveal: return result.kind.title
        }
    }

    private var revealDetailText: String {
        if result.isDuplicate {
            return "\(result.item.category.avatarDisplayLabel) • \(rarity.rawValue) • +\(result.duplicateRefund) coins"
        }
        return "\(result.item.category.avatarDisplayLabel) • \(rarity.rawValue)"
    }

    private func startOpening() {
        guard !hasStarted else { return }
        hasStarted = true

        if motionDisabled {
            phase = .reveal
            cardVisible = true
            playRevealFeedback()
            return
        }

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.38, dampingFraction: 0.5)) {
            phase = .charging
        }
        withAnimation(.easeInOut(duration: 0.09).repeatForever(autoreverses: true)) {
            packWobble = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 780_000_000)
            withAnimation(.easeOut(duration: 0.18)) {
                phase = .burst
                burstOut = true
            }
            playRevealFeedback()

            try? await Task.sleep(nanoseconds: 430_000_000)
            withAnimation(.spring(response: 0.72, dampingFraction: 0.72)) {
                phase = .reveal
                cardVisible = true
                packWobble = false
            }
        }
    }

    private func playRevealFeedback() {
        #if os(iOS)
        switch result.item.rarity {
        case .legendary:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .epic:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .rare:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        default:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}

private struct SealedCosmeticPackView: View {
    let kind: CosmeticPackKind
    let rarity: CosmeticRarity
    let phase: CosmeticPackRevealPhase
    let wobble: Bool
    let pulse: Bool
    let motionDisabled: Bool

    var body: some View {
        ZStack {
            if phase == .charging && !motionDisabled {
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 2) ? rarity.tileGlowColor : AppTheme.crownGold)
                        .frame(width: 8, height: 8)
                        .offset(y: pulse ? -128 : -102)
                        .rotationEffect(.degrees(Double(index) * 45 + (pulse ? 28 : -18)))
                        .opacity(0.75)
                }
            }

            if phase == .burst {
                RevealCardBackView(kind: kind, rarity: rarity, pulse: pulse)
                    .transition(.scale.combined(with: .opacity))
            } else {
                packBody
                    .scaleEffect(phase == .charging && pulse ? 1.04 : 1)
                    .rotationEffect(.degrees(phase == .charging ? (wobble ? 3.4 : -3.4) : 0))
                    .shadow(color: rarity.tileGlowColor.opacity(phase == .charging ? 0.58 : 0.32), radius: phase == .charging ? 28 : 16, x: 0, y: 14)
            }
        }
        .frame(width: 218, height: 246)
        .accessibilityLabel("\(kind.title), tap to open")
    }

    private var packBody: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(packGradient)
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 2)
            )
            .overlay(
                VStack(spacing: 14) {
                    Image(systemName: kind.iconName)
                        .font(.system(size: 54, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)

                    VStack(spacing: 3) {
                        Text(kind == .avatar ? "AVATAR" : "THEME")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                        Text("PACK")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)

                    if phase == .charging {
                        rarityChase
                    } else {
                        RarityBadgeView(rarity: rarity)
                            .scaleEffect(1.18)
                    }
                }
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: rarity == .legendary ? "crown.fill" : "sparkles")
                    .font(.title2.bold())
                    .foregroundStyle(rarity == .legendary ? AppTheme.crownGold : .white)
                    .padding(18)
                    .opacity(0.92)
            }
            .frame(width: 176, height: 214)
    }

    private var rarityChase: some View {
        HStack(spacing: 7) {
            ForEach([CosmeticRarity.common, .rare, .epic, .legendary], id: \.self) { chaseRarity in
                Circle()
                    .fill(chaseRarity.tileGlowColor)
                    .frame(width: chaseRarity == rarity ? 13 : 9, height: chaseRarity == rarity ? 13 : 9)
                    .overlay(Circle().stroke(Color.white.opacity(chaseRarity == rarity ? 0.9 : 0.35), lineWidth: 1))
                    .shadow(color: chaseRarity.tileGlowColor.opacity(chaseRarity == rarity ? 0.65 : 0.2), radius: chaseRarity == rarity ? 8 : 2)
                    .opacity(chaseRarity == rarity ? 1 : 0.66)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.18))
        .clipShape(Capsule())
    }

    private var packGradient: LinearGradient {
        switch kind {
        case .avatar:
            return LinearGradient(colors: [AppTheme.hotPink, Color(hex: "7B42FF"), rarity.tileGlowColor], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .theme:
            return LinearGradient(colors: [AppTheme.crownGold, AppTheme.hotPink, rarity.tileGlowColor], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

}

private struct RevealCardBackView: View {
    let kind: CosmeticPackKind
    let rarity: CosmeticRarity
    let pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(rarity.tileGlowColor.opacity(0.16))
                .frame(width: pulse ? 214 : 176, height: pulse ? 214 : 176)
                .blur(radius: 8)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.96),
                            rarity.tileGlowColor.opacity(0.24),
                            AppTheme.hotPink.opacity(rarity == .legendary ? 0.18 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 150, height: 196)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(rarity.tileGlowColor.opacity(0.78), lineWidth: 2)
                )
                .shadow(color: rarity.tileGlowColor.opacity(0.42), radius: 22, x: 0, y: 12)

            VStack(spacing: 12) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(rarity.tileGlowColor)

                RarityBadgeView(rarity: rarity)
                    .scaleEffect(1.16)

                Text("REVEAL")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.72))
            }
        }
        .scaleEffect(pulse ? 1.04 : 0.98)
        .animation(.easeInOut(duration: 0.42), value: pulse)
        .accessibilityLabel("\(rarity.rawValue) card reveal")
    }
}

private struct RarityRevealBackdrop: View {
    let rarity: CosmeticRarity
    let phase: CosmeticPackRevealPhase
    let pulse: Bool
    let burstOut: Bool
    let motionDisabled: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    rarity.tileGlowColor.opacity(0.28),
                    Color.white.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if phase == .charging || phase == .burst || phase == .reveal {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(rarity.tileGlowColor.opacity(0.16 - Double(index) * 0.03), lineWidth: 2)
                        .scaleEffect(ringScale(index))
                        .opacity(motionDisabled ? 0.12 : ringOpacity)
                }
            }

            if (rarity == .epic || rarity == .legendary), phase != .sealed {
                ForEach(0..<6, id: \.self) { index in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, rarity.tileGlowColor.opacity(rarity == .legendary ? 0.2 : 0.13), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: rarity == .legendary ? 18 : 12, height: 460)
                        .rotationEffect(.degrees(Double(index) * 60))
                        .opacity(phase == .burst ? 0.84 : 0.34)
                }
            }

            if phase == .burst {
                Circle()
                    .fill((rarity == .legendary ? AppTheme.crownGold : rarity.tileGlowColor).opacity(burstOut ? 0 : 0.78))
                    .scaleEffect(burstOut ? 4.8 : 0.2)
                    .blur(radius: burstOut ? 18 : 0)
            }
        }
        .ignoresSafeArea()
    }

    private var ringOpacity: Double {
        switch phase {
        case .sealed: return 0
        case .charging: return pulse ? 0.9 : 0.34
        case .burst: return 0.72
        case .reveal: return 0.22
        }
    }

    private func ringScale(_ index: Int) -> CGFloat {
        guard !motionDisabled else { return CGFloat(1.2 + Double(index) * 0.32) }
        let base = 0.72 + Double(index) * 0.26
        switch phase {
        case .sealed: return CGFloat(base)
        case .charging: return CGFloat(base + (pulse ? 0.34 : 0))
        case .burst: return CGFloat(base + 0.72)
        case .reveal: return CGFloat(base + 0.48)
        }
    }
}

private struct PackBurstParticlesView: View {
    let rarity: CosmeticRarity
    let phase: CosmeticPackRevealPhase
    let burstOut: Bool

    private var particleCount: Int {
        switch rarity {
        case .free, .common: return 10
        case .rare: return 14
        case .epic: return 18
        case .legendary: return 24
        }
    }

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                particle(index)
            }
        }
        .opacity(phase == .sealed ? 0 : 1)
    }

    private func particle(_ index: Int) -> some View {
        let angle = Double(index) / Double(max(1, particleCount)) * 360
        let distance = burstOut ? CGFloat(112 + (index % 5) * 28) : CGFloat(26 + (index % 4) * 8)
        let size = CGFloat(5 + (index % 4) * 2)

        return Group {
            if rarity == .legendary && index.isMultiple(of: 5) {
                Image(systemName: "crown.fill")
                    .font(.system(size: size + 5, weight: .black))
                    .foregroundStyle(AppTheme.crownGold)
            } else if rarity == .epic && index.isMultiple(of: 4) {
                Image(systemName: "sparkle")
                    .font(.system(size: size + 4, weight: .black))
                    .foregroundStyle(AppTheme.hotPink)
            } else {
                Circle()
                    .fill(index.isMultiple(of: 3) ? AppTheme.crownGold : rarity.tileGlowColor)
                    .frame(width: size, height: size)
            }
        }
        .offset(
            x: CGFloat(cos(angle * .pi / 180)) * distance,
            y: CGFloat(sin(angle * .pi / 180)) * distance
        )
        .rotationEffect(.degrees(burstOut ? angle + 90 : angle))
        .opacity(phase == .burst ? (burstOut ? 0 : 0.95) : 0.28)
        .animation(.easeOut(duration: 0.9), value: burstOut)
    }
}

private struct DuplicateRefundBurstView: View {
    let amount: Int
    let rarity: CosmeticRarity
    let isVisible: Bool

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                CoinIconView(size: index.isMultiple(of: 2) ? 14 : 10)
                    .offset(
                        x: isVisible ? CGFloat(cos(Double(index) * .pi / 4)) * 68 : 0,
                        y: isVisible ? CGFloat(sin(Double(index) * .pi / 4)) * 26 : 0
                    )
                    .opacity(isVisible ? 0.0 : 0.9)
                    .animation(.easeOut(duration: 0.9).delay(0.1), value: isVisible)
            }

            HStack(spacing: 7) {
                CoinIconView(size: 18)
                Text("+\(amount)")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.94))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(rarity.tileGlowColor.opacity(0.75), lineWidth: 1.4))
            .shadow(color: rarity.tileGlowColor.opacity(0.35), radius: 12, x: 0, y: 5)
            .scaleEffect(isVisible ? 1 : 0.7)
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.46, dampingFraction: 0.7).delay(0.08), value: isVisible)
        }
        .accessibilityLabel("Duplicate refund, \(amount) coins")
    }
}

// MARK: - Rotation countdown

struct RotationCountdownBanner: View {
    let nextDate: Date
    @State private var timeLeft: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
            Text("Rotates in \(timeLeft)")
                .font(.caption.bold())
        }
        .foregroundStyle(AppTheme.crownGold)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(AppTheme.crownGold.opacity(0.16))
        .onAppear { updateCountdown() }
        .onReceive(timer) { _ in updateCountdown() }
    }

    private func updateCountdown() {
        let remaining = max(0, nextDate.timeIntervalSinceNow)
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        let s = Int(remaining) % 60
        timeLeft = String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Item card

struct ShopItemCard: View {
    let item: CosmeticItem
    let isOwned: Bool
    let isEquipped: Bool
    let canAfford: Bool
    let isLimited: Bool
    var allowsOwnedEquip = true
    let onAction: () -> Void

    var actionLabel: String {
        if isEquipped { return "Equipped" }
        if isOwned    { return allowsOwnedEquip ? "Equip" : "Owned" }
        return "\(item.price)"
    }

    var actionColor: Color {
        if isEquipped { return AppTheme.teal.opacity(0.72) }
        if isOwned    { return allowsOwnedEquip ? AppTheme.hotPink : AppTheme.royalBlue.opacity(0.72) }
        return canAfford ? AppTheme.hotPink : AppTheme.cardBorder
    }

    var body: some View {
        if item.category.isAvatarCategory {
            AvatarItemTile(
                item: item,
                isOwned: isOwned,
                isEquipped: isEquipped,
                canAfford: canAfford,
                isLimited: isLimited,
                allowsOwnedEquip: allowsOwnedEquip,
                actionLabel: actionLabel,
                onAction: onAction
            )
        } else {
            standardCard
        }
    }

    private var standardCard: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Preview area
                if item.category == .title {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.cardBackground)
                        .frame(height: 72)
                        .overlay(
                            Text("\"\(item.name)\"")
                                .font(.subheadline.bold().italic())
                                .foregroundStyle(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(8)
                        )
                } else if item.category == .boardTheme {
                    ShopThemePreview(themeID: item.id)
                        .frame(height: 72)
                } else if item.category == .tileTheme {
                    ShopTileThemePreview(tileThemeID: item.id)
                        .frame(height: 72)
                } else if item.category == .cardTheme {
                    ShopCardThemePreview(cardThemeID: item.id)
                        .frame(height: 72)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.cardBackground)
                        .frame(height: 72)
                        .overlay(
                            Image(systemName: iconForCategory(item.category))
                                .font(.system(size: 30))
                                .foregroundStyle(AppTheme.textSecondary)
                        )
                }

                // Ownership badges
                HStack(spacing: 4) {
                    if isEquipped {
                            Text("EQUIPPED")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(AppTheme.teal)
                                .foregroundStyle(AppTheme.textOnColor)
                                .clipShape(Capsule())
                        } else if isOwned {
                            Text("OWNED")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(AppTheme.royalBlue)
                                .foregroundStyle(AppTheme.textOnColor)
                                .clipShape(Capsule())
                        }
                }
                .padding(6)

                if item.rarity == .epic || item.rarity == .legendary {
                    standardRaritySparkles
                }
            }

            Text(item.name)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            Text(item.description)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Button(action: onAction) {
                if isOwned || isEquipped {
                    Text(actionLabel)
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(minWidth: 76)
                        .background(actionColor)
                        .foregroundStyle(AppTheme.textOnColor)
                        .clipShape(Capsule())
                } else {
                    HStack(spacing: 5) {
                        CoinIconView(size: 15)
                        Text(actionLabel)
                            .font(.caption.bold())
                            .foregroundStyle(canAfford ? AppTheme.textOnColor : AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .frame(minWidth: 76)
                    .background(actionColor)
                    .clipShape(Capsule())
                }
            }
            .disabled(isEquipped || (isOwned && !allowsOwnedEquip) || (!isOwned && !canAfford))
        }
        .padding()
        .background(standardCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(item.rarity.tileBorderColor.opacity(item.rarity == .free ? 0.55 : 0.78), lineWidth: item.rarity == .legendary ? 2.1 : 1.5)
        )
        .shadow(color: item.rarity.tileGlowColor.opacity(item.rarity.glowOpacity), radius: item.rarity.shadowRadius, x: 0, y: 6)
        .overlay(alignment: .bottomLeading) {
            RarityBadgeView(rarity: item.rarity)
                .padding(8)
        }
    }

    private var standardCardBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(0.95),
                item.rarity.tileGlowColor.opacity(item.rarity == .free ? 0.04 : 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var standardRaritySparkles: some View {
        ZStack {
            Image(systemName: item.rarity == .legendary ? "crown.fill" : "sparkle")
                .font(.system(size: item.rarity == .legendary ? 13 : 11, weight: .black))
                .foregroundStyle(item.rarity == .legendary ? AppTheme.crownGold : AppTheme.hotPink)
                .offset(x: -42, y: -24)
            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(Color.white.opacity(0.88))
                .offset(x: 39, y: -18)
        }
    }

    private func iconForCategory(_ cat: CosmeticCategory) -> String {
        switch cat {
        case .title:        return "text.badge.star"
        case .boardTheme:   return "paintpalette.fill"
        case .tileTheme:    return "square.grid.3x3.fill"
        case .cardTheme:    return "suit.spade.fill"
        case .numberFont:   return "textformat"
        case .cellBorder:   return "rectangle.inset.filled"
        case .avatarHead:   return "crown.fill"
        case .avatarFace:   return "face.smiling.fill"
        case .avatarOutfit: return "tshirt.fill"
        case .avatarAura:   return "sparkles"
        case .avatarPose:   return "figure.wave"
        }
    }
}

private struct AvatarItemTile: View {
    let item: CosmeticItem
    let isOwned: Bool
    let isEquipped: Bool
    let canAfford: Bool
    let isLimited: Bool
    let allowsOwnedEquip: Bool
    let actionLabel: String
    let onAction: () -> Void

    private var actionDisabled: Bool {
        isEquipped || (isOwned && !allowsOwnedEquip) || (!isOwned && !canAfford)
    }

    var body: some View {
        Button(action: onAction) {
            VStack(spacing: 10) {
                previewStage

                VStack(spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(item.category.avatarDisplayLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    RarityBadgeView(rarity: item.rarity)
                    Spacer(minLength: 4)
                    actionPill
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 192)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(item.rarity.tileBorderColor.opacity(isEquipped ? 0.95 : 0.68), lineWidth: isEquipped ? 2.2 : 1.45)
            )
            .shadow(color: item.rarity.tileGlowColor.opacity(item.rarity.glowOpacity), radius: item.rarity.shadowRadius, x: 0, y: 6)
            .overlay(alignment: .topTrailing) {
                statusBadges
                    .padding(8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
        }
        .buttonStyle(AvatarCatalogButtonStyle())
        .disabled(actionDisabled)
    }

    private var previewStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: item.rarity.previewColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
                )

            if item.rarity == .epic || item.rarity == .legendary {
                sparkleLayer
            }

            StickDuelerAvatarView(style: previewStyle, size: 92)
                .padding(.top, 2)
        }
        .frame(height: 106)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var cardBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(0.94),
                item.rarity.tileGlowColor.opacity(item.rarity == .free ? 0.06 : 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var actionPill: some View {
        Group {
            if isOwned || isEquipped {
                Text(actionLabel)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textOnColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isEquipped ? AppTheme.teal : AppTheme.hotPink)
                    .clipShape(Capsule())
            } else {
                HStack(spacing: 4) {
                    CoinIconView(size: 13)
                    Text(actionLabel)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(canAfford ? AppTheme.textOnColor : AppTheme.textSecondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(canAfford ? AppTheme.hotPink : AppTheme.controlBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(canAfford ? Color.clear : AppTheme.controlBorder, lineWidth: 1)
                )
            }
        }
    }

    @ViewBuilder
    private var statusBadges: some View {
        HStack(spacing: 4) {
            if isEquipped {
                statusBadge("EQUIPPED", color: AppTheme.teal)
            } else if isOwned {
                statusBadge("OWNED", color: AppTheme.royalBlue)
            }
        }
    }

    private func statusBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.textOnColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: color.opacity(0.25), radius: 4, x: 0, y: 2)
    }

    private var sparkleLayer: some View {
        ZStack {
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(item.rarity == .legendary ? AppTheme.crownGold : AppTheme.hotPink)
                .offset(x: -34, y: -30)
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(Color.white.opacity(0.9))
                .offset(x: 35, y: -18)
            Image(systemName: "sparkle")
                .font(.system(size: 7, weight: .black))
                .foregroundStyle(item.rarity.tileGlowColor.opacity(0.75))
                .offset(x: -22, y: 32)
        }
    }

    private var previewStyle: AvatarStyle {
        var style = AvatarStyle.default
        switch item.category {
        case .avatarHead:
            style.head = item.id
        case .avatarFace:
            style.face = item.id
        case .avatarOutfit:
            style.outfit = item.id
        case .avatarAura:
            style.aura = item.id
        default:
            break
        }
        return style
    }

    private var accessibilityLabel: String {
        let state: String
        if isEquipped {
            state = "equipped"
        } else if isOwned {
            state = "owned"
        } else {
            state = canAfford ? "\(item.price) coins" : "\(item.price) coins, not enough coins"
        }
        return "\(item.name), \(item.category.avatarDisplayLabel), \(item.rarity.rawValue), \(state)"
    }
}

// A disabled purchase should disable the action, not wash out the item artwork.
private struct AvatarCatalogButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct RarityBadgeView: View {
    let rarity: CosmeticRarity

    var body: some View {
        Text(rarity.rawValue.uppercased())
            .font(.system(size: 8, weight: .black, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(rarity.badgeColor.opacity(rarity == .free ? 0.28 : 0.94))
            .foregroundStyle(rarity.textColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
            .shadow(color: rarity.badgeColor.opacity(0.25), radius: 5, x: 0, y: 2)
    }
}

private extension CosmeticRarity {
    var previewColors: [Color] {
        switch self {
        case .free:
            return [Color.white.opacity(0.94), AppTheme.controlBackground]
        case .common:
            return [Color(hex: "E7FFF9"), AppTheme.teal.opacity(0.20)]
        case .rare:
            return [Color(hex: "EAF8FF"), AppTheme.royalBlue.opacity(0.22)]
        case .epic:
            return [Color(hex: "FFF0FA"), AppTheme.hotPink.opacity(0.26), Color(hex: "7B42FF").opacity(0.16)]
        case .legendary:
            return [Color(hex: "FFF7D6"), AppTheme.crownGold.opacity(0.38), AppTheme.hotPink.opacity(0.12)]
        }
    }

    var tileBorderColor: Color {
        switch self {
        case .free: return AppTheme.cardBorder
        case .common: return AppTheme.teal
        case .rare: return AppTheme.royalBlue
        case .epic: return AppTheme.hotPink
        case .legendary: return AppTheme.crownGold
        }
    }

    var tileGlowColor: Color {
        switch self {
        case .free: return AppTheme.textSecondary
        case .common: return AppTheme.teal
        case .rare: return AppTheme.royalBlue
        case .epic: return AppTheme.hotPink
        case .legendary: return AppTheme.crownGold
        }
    }

    var glowOpacity: Double {
        switch self {
        case .free: return 0.08
        case .common: return 0.16
        case .rare: return 0.22
        case .epic: return 0.30
        case .legendary: return 0.38
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .free: return 5
        case .common: return 7
        case .rare: return 8
        case .epic: return 10
        case .legendary: return 12
        }
    }

    var supportsShine: Bool {
        self == .epic || self == .legendary
    }
}

private extension CosmeticCategory {
    var avatarDisplayLabel: String {
        switch self {
        case .avatarHead: return "Head"
        case .avatarFace: return "Expression"
        case .avatarOutfit: return "Body"
        case .avatarAura: return "Aura"
        case .avatarPose: return "Pose"
        default: return rawValue
        }
    }
}

private struct AvatarPartPreview: View {
    let item: CosmeticItem

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(AppTheme.cardBackground)
            .overlay(previewContent)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.category {
        case .avatarHead, .avatarFace, .avatarOutfit, .avatarAura:
            liveAvatarPreview
        case .avatarPose:
            posePreview
        default:
            Image(systemName: "sparkles")
                .font(.title.bold())
                .foregroundStyle(AppTheme.crownGold)
        }
    }

    private var liveAvatarPreview: some View {
        StickDuelerAvatarView(style: previewStyle, size: 64, allowsMotion: false)
            .frame(width: 72, height: 72)
    }

    private var previewStyle: AvatarStyle {
        var style = AvatarStyle.default
        switch item.category {
        case .avatarHead:
            style.head = item.id
        case .avatarFace:
            style.face = item.id
        case .avatarOutfit:
            style.outfit = item.id
        case .avatarAura:
            style.aura = item.id
        default:
            break
        }
        return style
    }

    private var headPreview: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 48, height: 48)
            switch item.id {
            case "avatar_head_crown":
                Image(systemName: "crown.fill")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(AppTheme.crownGold)
            case "avatar_head_puzzle_crown":
                ZStack {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [AppTheme.crownGold, Color(hex: "FF6B1A"), AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    HStack(spacing: -1) {
                        Image(systemName: "flame.fill")
                        Image(systemName: "flame.fill")
                        Image(systemName: "flame.fill")
                    }
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(AppTheme.hotPink)
                    .offset(y: -11)
                }
            case "avatar_head_headphones":
                Image(systemName: "headphones")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.teal)
            case "avatar_head_wizard":
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.royalBlue)
            case "avatar_head_lightning":
                Image(systemName: "bolt.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(AppTheme.crownGold)
            case "avatar_head_halo":
                Ellipse()
                    .stroke(AppTheme.crownGold, lineWidth: 4)
                    .frame(width: 44, height: 18)
            case "avatar_head_neon_visor":
                Capsule()
                    .fill(LinearGradient(colors: [AppTheme.hotPink, AppTheme.royalBlue], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 46, height: 15)
                    .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1.5))
            case "avatar_head_star_clip":
                Image(systemName: "star.fill")
                    .font(.system(size: 31, weight: .black))
                    .foregroundStyle(AppTheme.crownGold)
            case "avatar_head_lava_helmet":
                Image(systemName: "flame.fill")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(Color(hex: "FF6B1A"))
            case "avatar_head_pixel_cap":
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "39D5FF"), AppTheme.royalBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 42, height: 17)
                    Capsule()
                        .fill(Color(hex: "0B1435"))
                        .frame(width: 24, height: 7)
                        .offset(x: 20, y: 6)
                    HStack(spacing: 2) {
                        Rectangle().fill(Color.white.opacity(0.58)).frame(width: 6, height: 9)
                        Rectangle().fill(Color(hex: "0B1435").opacity(0.28)).frame(width: 6, height: 9)
                        Rectangle().fill(Color.white.opacity(0.58)).frame(width: 6, height: 9)
                    }
                }
            case "avatar_head_mini_crown":
                Image(systemName: "crown.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(AppTheme.crownGold)
            case "avatar_head_party_hat":
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 31, weight: .black))
                    .foregroundStyle(AppTheme.hotPink)
            case "avatar_head_bubble_crown":
                ZStack {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(AppTheme.hotPink)
                    Circle()
                        .stroke(Color(hex: "39D5FF"), lineWidth: 2)
                        .frame(width: 42, height: 42)
                }
            case "avatar_head_arcade_antenna":
                VStack(spacing: 2) {
                    Circle()
                        .fill(AppTheme.crownGold)
                        .frame(width: 10, height: 10)
                    Capsule()
                        .fill(AppTheme.royalBlue)
                        .frame(width: 8, height: 32)
                }
            case "avatar_head_prize_ribbon":
                ZStack {
                    Capsule()
                        .fill(Color(hex: "11183A"))
                        .frame(width: 52, height: 10)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "252B5A"), Color(hex: "050510")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 35, height: 34)
                        .overlay(
                            Rectangle()
                                .fill(LinearGradient(colors: [AppTheme.crownGold, AppTheme.hotPink], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 7),
                            alignment: .bottom
                        )
                    Circle()
                        .fill(AppTheme.crownGold)
                        .frame(width: 6, height: 6)
                        .offset(x: 10, y: 10)
                }
            case "avatar_head_royal_headband":
                Capsule()
                    .fill(LinearGradient(colors: [AppTheme.hotPink, AppTheme.crownGold], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 48, height: 12)
                    .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1.5))
            case "avatar_head_crystal_spikes":
                HStack(spacing: -2) {
                    ForEach(0..<3, id: \.self) { index in
                        PreviewDiamondShape()
                            .fill(index == 1 ? Color(hex: "E8F7FF") : Color(hex: "78D7FF"))
                            .frame(width: 22, height: index == 1 ? 42 : 32)
                    }
                }
            case "avatar_head_gem_crown":
                Image(systemName: "crown.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [AppTheme.crownGold, AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing))
            case "avatar_head_cosmic_halo":
                ZStack {
                    Ellipse()
                        .stroke(AppTheme.crownGold, lineWidth: 4)
                        .frame(width: 50, height: 20)
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "78D7FF"))
                }
            default:
                Image(systemName: "circle.dashed")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var facePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.hotPink.opacity(0.24))
                .frame(width: 54, height: 46)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.55), lineWidth: 1.5))
            switch item.id {
            case "avatar_face_focused":
                VStack(spacing: 7) {
                    Text("•   •")
                    Capsule().frame(width: 18, height: 3)
                }
            case "avatar_face_wink":
                Text("•  -")
                    .offset(y: -2)
                Text("⌣")
                    .offset(y: 12)
            case "avatar_face_shades":
                Image(systemName: "eyeglasses")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.black)
            case "avatar_face_gem":
                HStack(spacing: 8) {
                    Image(systemName: "diamond.fill")
                    Image(systemName: "diamond.fill")
                }
                .foregroundStyle(AppTheme.hotPink)
            case "avatar_face_laugh":
                Text("^  ^")
                    .offset(y: -3)
                Text("⌣")
                    .offset(y: 12)
            case "avatar_face_determined":
                VStack(spacing: 8) { Text("•   •"); Capsule().frame(width: 24, height: 3) }
            case "avatar_face_sleepy":
                Text("-  -")
                    .offset(y: -4)
                Text(".")
                    .offset(y: 12)
            case "avatar_face_star":
                HStack(spacing: 8) { Image(systemName: "star.fill"); Image(systemName: "star.fill") }
                    .foregroundStyle(AppTheme.crownGold)
            case "avatar_face_oops":
                Text("•  •")
                    .offset(y: -4)
                Text("o")
                    .offset(y: 12)
            case "avatar_face_smirk":
                Text("•  •")
                    .offset(y: -4)
                Text("⌒")
                    .offset(y: 12)
            case "avatar_face_blush":
                Text("•  •")
                    .offset(y: -4)
                HStack(spacing: 24) {
                    Circle().frame(width: 6, height: 6)
                    Circle().frame(width: 6, height: 6)
                }
                .foregroundStyle(AppTheme.hotPink)
                .offset(y: 5)
                Text("⌣")
                    .offset(y: 13)
            case "avatar_face_pixel":
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 1).frame(width: 7, height: 7)
                    RoundedRectangle(cornerRadius: 1).frame(width: 7, height: 7)
                }
                .offset(y: -5)
                Capsule().frame(width: 16, height: 3).offset(y: 13)
            case "avatar_face_party":
                Text("^  ^")
                    .offset(y: -4)
                Image(systemName: "party.popper.fill")
                    .foregroundStyle(AppTheme.crownGold)
                    .offset(x: 18, y: -12)
                Text("⌣")
                    .offset(y: 13)
            case "avatar_face_robot":
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppTheme.teal, lineWidth: 2)
                    .frame(width: 34, height: 14)
                    .overlay(HStack(spacing: 10) {
                        Circle().fill(AppTheme.teal).frame(width: 4, height: 4)
                        Circle().fill(AppTheme.teal).frame(width: 4, height: 4)
                    })
                    .offset(y: -5)
                Capsule().frame(width: 14, height: 3).offset(y: 14)
            case "avatar_face_lava":
                HStack(spacing: 8) { Image(systemName: "flame.fill"); Image(systemName: "flame.fill") }
                    .foregroundStyle(Color(hex: "FF6B1A"))
                    .offset(y: -5)
                Text("⌣")
                    .offset(y: 13)
            case "avatar_face_crown":
                HStack(spacing: 8) { Image(systemName: "crown.fill"); Image(systemName: "crown.fill") }
                    .foregroundStyle(AppTheme.crownGold)
                    .offset(y: -5)
                Text("⌣")
                    .offset(y: 13)
            case "avatar_face_masked":
                Capsule()
                    .fill(Color.black.opacity(0.82))
                    .frame(width: 36, height: 14)
                    .overlay(HStack(spacing: 12) {
                        Circle().fill(.white).frame(width: 4, height: 4)
                        Circle().fill(.white).frame(width: 4, height: 4)
                    })
                    .offset(y: -5)
                Text("⌣")
                    .offset(y: 13)
            case "avatar_face_heart":
                HStack(spacing: 8) { Image(systemName: "heart.fill"); Image(systemName: "heart.fill") }
                    .foregroundStyle(AppTheme.hotPink)
                    .offset(y: -5)
                Text("⌣")
                    .offset(y: 13)
            case "avatar_face_chill":
                Text("-  -")
                    .offset(y: -5)
                Text("⌣")
                    .offset(y: 13)
            case "avatar_face_prize":
                HStack(spacing: 8) { Image(systemName: "seal.fill"); Image(systemName: "seal.fill") }
                    .foregroundStyle(AppTheme.crownGold)
                    .offset(y: -5)
                Text("⌣")
                    .offset(y: 13)
            case "avatar_face_glitter":
                HStack(spacing: 8) { Image(systemName: "sparkles"); Image(systemName: "sparkles") }
                    .foregroundStyle(AppTheme.hotPink)
                    .offset(y: -5)
                Text("⌣")
                    .offset(y: 13)
            case "avatar_face_focus_laser":
                HStack(spacing: 7) {
                    Capsule().frame(width: 18, height: 4)
                    Capsule().frame(width: 18, height: 4)
                }
                .foregroundStyle(AppTheme.teal)
                .offset(y: -5)
                Capsule().frame(width: 20, height: 3).offset(y: 14)
            case "avatar_face_rainbow":
                HStack(spacing: 8) { Circle().frame(width: 9, height: 9); Circle().frame(width: 9, height: 9) }
                    .foregroundStyle(LinearGradient(colors: [AppTheme.hotPink, AppTheme.teal, AppTheme.crownGold], startPoint: .leading, endPoint: .trailing))
                    .offset(y: -5)
                Text("⌣")
                    .offset(y: 13)
            case "avatar_face_gold_smile":
                HStack(spacing: 8) { Image(systemName: "crown.fill"); Image(systemName: "crown.fill") }
                    .foregroundStyle(AppTheme.crownGold)
                    .offset(y: -5)
                Text("⌣")
                    .foregroundStyle(AppTheme.crownGold)
                    .offset(y: 13)
            case "avatar_face_cosmic":
                HStack(spacing: 8) { Image(systemName: "star.fill"); Image(systemName: "star.fill") }
                    .foregroundStyle(Color(hex: "78D7FF"))
                    .offset(y: -5)
                Text("⌣")
                    .offset(y: 13)
            default:
                Image(systemName: "face.smiling.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .font(.system(size: 18, weight: .black, design: .rounded))
        .foregroundStyle(.white)
    }

    private var bodySkinPreview: some View {
        ZStack {
            PreviewPuzzlePieceShape()
                .fill(bodyFill)
                .frame(width: 52, height: 52)
                .overlay(PreviewPuzzlePieceShape().stroke(Color(hex: "F8EFFF").opacity(0.84), lineWidth: 1.5))
            if item.id == "avatar_outfit_basic" {
                Text("HEX")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
            } else if item.id == "avatar_outfit_royal" {
                Image(systemName: "crown.fill")
                    .foregroundStyle(AppTheme.hotPink)
                    .font(.caption.bold())
            } else if item.id == "avatar_outfit_neon" {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.teal)
                    .font(.caption.bold())
            }
        }
        .shadow(color: bodyGlow.opacity(0.28), radius: 8, x: 0, y: 4)
    }

    private var auraPreview: some View {
        ZStack {
            Circle()
                .stroke(auraColor.opacity(0.9), lineWidth: 4)
                .frame(width: 50, height: 50)
                .blur(radius: item.id == "avatar_aura_none" ? 0 : 1)
            Circle()
                .fill(auraColor.opacity(item.id == "avatar_aura_none" ? 0.08 : 0.22))
                .frame(width: 36, height: 36)
            Image(systemName: item.id == "avatar_aura_none" ? "circle" : "sparkles")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(auraColor)
        }
    }

    private var posePreview: some View {
        Image(systemName: poseIcon)
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(AppTheme.crownGold)
            .frame(width: 58, height: 58)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.24), lineWidth: 1))
    }

    private var bodyFill: LinearGradient {
        switch item.id {
        case "avatar_outfit_hoodie":
            return LinearGradient(colors: [Color(hex: "7FFFE3"), AppTheme.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_cape":
            return LinearGradient(colors: [Color(hex: "FFB3D7"), AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_armor":
            return LinearGradient(colors: [Color(hex: "71C8FF"), AppTheme.royalBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_neon":
            return LinearGradient(colors: [Color(hex: "39D5FF"), Color(hex: "0B1435"), AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_royal":
            return LinearGradient(colors: [Color(hex: "FFE887"), AppTheme.crownGold], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_lava":
            return LinearGradient(colors: [Color(hex: "FFD36B"), Color(hex: "FF6B1A"), AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_frost":
            return LinearGradient(colors: [Color(hex: "E9FFFF"), Color(hex: "71C8FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_galaxy":
            return LinearGradient(colors: [Color(hex: "10142F"), Color(hex: "7B42FF"), AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_mint":
            return LinearGradient(colors: [Color(hex: "CFFFF1"), Color(hex: "23D18B")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_candy":
            return LinearGradient(colors: [Color(hex: "FF9ED1"), Color(hex: "39D5FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_obsidian":
            return LinearGradient(colors: [Color(hex: "626A85"), Color(hex: "050510")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_sunset":
            return LinearGradient(colors: [Color(hex: "FFD36B"), Color(hex: "FF6B1A"), AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_bubblegum":
            return LinearGradient(colors: [Color(hex: "FF9ED1"), Color(hex: "39D5FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_arcade_jacket":
            return LinearGradient(colors: [Color(hex: "2D2A7F"), Color(hex: "39D5FF"), AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_teal_gold":
            return LinearGradient(colors: [Color(hex: "12C8A2"), AppTheme.crownGold], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_prism":
            return LinearGradient(colors: [AppTheme.hotPink, Color(hex: "7B42FF"), AppTheme.teal, AppTheme.crownGold], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_crystal":
            return LinearGradient(colors: [Color(hex: "E8F7FF"), Color(hex: "78D7FF"), Color(hex: "12C8A2")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_royal_velvet":
            return LinearGradient(colors: [Color(hex: "5B1440"), AppTheme.hotPink, AppTheme.crownGold], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "avatar_outfit_starlight":
            return LinearGradient(colors: [Color(hex: "050510"), Color(hex: "256BFF"), Color(hex: "78D7FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Color(hex: "FF7FB7"), AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var bodyGlow: Color {
        switch item.id {
        case "avatar_outfit_hoodie": return AppTheme.teal
        case "avatar_outfit_armor": return AppTheme.royalBlue
        case "avatar_outfit_royal": return AppTheme.crownGold
        case "avatar_outfit_lava": return Color(hex: "FF6B1A")
        case "avatar_outfit_frost": return Color(hex: "71C8FF")
        case "avatar_outfit_galaxy": return Color(hex: "7B42FF")
        case "avatar_outfit_mint": return Color(hex: "23D18B")
        case "avatar_outfit_obsidian": return Color(hex: "050510")
        case "avatar_outfit_sunset": return Color(hex: "FF6B1A")
        case "avatar_outfit_bubblegum": return Color(hex: "FF9ED1")
        case "avatar_outfit_arcade_jacket": return Color(hex: "39D5FF")
        case "avatar_outfit_teal_gold": return AppTheme.crownGold
        case "avatar_outfit_prism": return AppTheme.hotPink
        case "avatar_outfit_crystal": return Color(hex: "78D7FF")
        case "avatar_outfit_royal_velvet": return AppTheme.crownGold
        case "avatar_outfit_starlight": return Color(hex: "78D7FF")
        default: return AppTheme.hotPink
        }
    }

    private var auraColor: Color {
        switch item.id {
        case "avatar_aura_teal": return AppTheme.teal
        case "avatar_aura_pink": return AppTheme.hotPink
        case "avatar_aura_crown": return AppTheme.crownGold
        case "avatar_aura_storm": return AppTheme.royalBlue
        case "avatar_aura_lava": return Color(hex: "FF6B1A")
        case "avatar_aura_star": return AppTheme.crownGold
        case "avatar_aura_pixel": return Color(hex: "7B42FF")
        case "avatar_aura_mint": return Color(hex: "23D18B")
        case "avatar_aura_royal": return AppTheme.crownGold
        case "avatar_aura_confetti": return AppTheme.hotPink
        case "avatar_aura_bubblegum": return Color(hex: "FF9ED1")
        case "avatar_aura_stage_light": return Color(hex: "39D5FF")
        case "avatar_aura_teal_orbit": return AppTheme.teal
        case "avatar_aura_prism": return Color(hex: "7B42FF")
        case "avatar_aura_crystal": return Color(hex: "78D7FF")
        case "avatar_aura_gold_crown": return AppTheme.crownGold
        case "avatar_aura_cosmic": return Color(hex: "78D7FF")
        default: return AppTheme.textSecondary
        }
    }

    private var poseIcon: String {
        switch item.id {
        case "avatar_pose_victory": return "figure.wave"
        case "avatar_pose_thinking": return "lightbulb.fill"
        case "avatar_pose_ready": return "bolt.fill"
        case "avatar_pose_flex": return "figure.strengthtraining.traditional"
        case "avatar_pose_point": return "hand.point.up.left.fill"
        case "avatar_pose_jump": return "figure.run"
        case "avatar_pose_celebrate": return "party.popper.fill"
        case "avatar_pose_sneaky": return "eye.fill"
        case "avatar_pose_power": return "bolt.circle.fill"
        default: return "figure.stand"
        }
    }
}

private struct PreviewPuzzlePieceShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        var path = Path()
        path.move(to: CGPoint(x: x + w * 0.18, y: y + h * 0.10))
        path.addLine(to: CGPoint(x: x + w * 0.82, y: y + h * 0.10))
        path.addLine(to: CGPoint(x: x + w * 0.82, y: y + h * 0.42))
        path.addCurve(
            to: CGPoint(x: x + w * 0.82, y: y + h * 0.58),
            control1: CGPoint(x: x + w * 1.02, y: y + h * 0.43),
            control2: CGPoint(x: x + w * 1.02, y: y + h * 0.57)
        )
        path.addLine(to: CGPoint(x: x + w * 0.82, y: y + h * 0.90))
        path.addLine(to: CGPoint(x: x + w * 0.18, y: y + h * 0.90))
        path.addLine(to: CGPoint(x: x + w * 0.18, y: y + h * 0.62))
        path.addCurve(
            to: CGPoint(x: x + w * 0.18, y: y + h * 0.38),
            control1: CGPoint(x: x - w * 0.04, y: y + h * 0.60),
            control2: CGPoint(x: x - w * 0.04, y: y + h * 0.40)
        )
        path.closeSubpath()
        return path
    }
}

private struct PreviewDiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct ShopThemePreview: View {
    let themeID: String

    private var style: BoardThemeStyle {
        var cosmetics = OwnedCosmetics.default
        cosmetics.equippedBoardTheme = themeID
        return cosmetics.themeStyle
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(style.tileGradient)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1.5)
            )
            .overlay(
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        previewCell(opacity: 0.95)
                        previewCell(opacity: 0.72)
                        previewCell(opacity: 0.95)
                    }
                    HStack(spacing: 5) {
                        previewCell(opacity: 0.72)
                        Circle()
                            .fill(style.activeTraceColor)
                            .frame(width: 13, height: 13)
                            .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.2))
                        previewCell(opacity: 0.72)
                    }
                    HStack(spacing: 5) {
                        previewCell(opacity: 0.95)
                        previewCell(opacity: 0.72)
                        previewCell(opacity: 0.95)
                    }
                }
                .padding(10)
            )
            .shadow(color: style.activeTraceColor.opacity(0.28), radius: 8, x: 0, y: 4)
    }

    private func previewCell(opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(style.cellBackground.opacity(opacity))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(style.gridLineMinor, lineWidth: 1)
            )
            .frame(width: 16, height: 16)
    }
}

struct ShopTileThemePreview: View {
    let tileThemeID: String

    private var style: TileThemeStyle {
        var cosmetics = OwnedCosmetics.default
        cosmetics.equippedTileTheme = tileThemeID
        return cosmetics.tileThemeStyle
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                LinearGradient(
                    colors: [
                        style.inactiveFill.opacity(0.88),
                        style.shadow.opacity(0.20),
                        Color.white.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                ZStack {
                    previewTile("A", size: 42, rotation: -8)
                        .offset(x: -24, y: 4)
                        .opacity(0.88)
                    previewTile("7", size: 48, rotation: 7)
                        .offset(x: 20, y: -2)
                    previewTile("", size: 24, rotation: 0)
                        .offset(x: -2, y: 27)
                        .opacity(0.68)
                }
                .padding(8)
            )
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(style.border.opacity(0.8), lineWidth: 1.3))
            .shadow(color: style.shadow.opacity(0.9), radius: 8, x: 0, y: 4)
    }

    private func previewTile(_ text: String, size: CGFloat, rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: size * style.cornerScale, style: .continuous)
            .fill(style.fill)
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: size * style.cornerScale, style: .continuous)
                    .stroke(style.border, lineWidth: 1.6)
            )
            .overlay(
                Text(text)
                    .font(.system(size: size * 0.43, weight: .black, design: .rounded))
                    .foregroundStyle(style.textColor)
                    .shadow(color: style.shadow.opacity(0.55), radius: 2, x: 0, y: 1)
            )
            .shadow(color: style.shadow, radius: 5, x: 0, y: 3)
            .rotationEffect(.degrees(rotation))
    }
}

struct ShopCardThemePreview: View {
    let cardThemeID: String

    private var style: CardThemeStyle {
        var cosmetics = OwnedCosmetics.default
        cosmetics.equippedCardTheme = cardThemeID
        return cosmetics.cardThemeStyle
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                LinearGradient(
                    colors: [
                        style.tableTint.opacity(0.88),
                        style.shadow.opacity(0.35),
                        Color.white.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                ZStack {
                    previewBackCard
                        .offset(x: -25, y: 4)
                        .rotationEffect(.degrees(-9))
                    previewFaceCard(rank: "A", suit: "suit.heart.fill", color: style.redSuit)
                        .offset(x: 1, y: -1)
                        .rotationEffect(.degrees(3))
                    previewFaceCard(rank: "K", suit: "suit.spade.fill", color: style.blackSuit)
                        .offset(x: 27, y: 7)
                        .rotationEffect(.degrees(10))
                }
                .padding(8)
            )
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(style.border.opacity(0.82), lineWidth: 1.4))
            .shadow(color: style.shadow.opacity(0.9), radius: 8, x: 0, y: 4)
    }

    private var previewBackCard: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(style.backFill)
            .frame(width: 36, height: 50)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1.3)
            )
            .overlay(
                Image(systemName: style.backSymbol)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.9))
            )
            .shadow(color: style.shadow, radius: 4, x: 0, y: 2)
    }

    private func previewFaceCard(rank: String, suit: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(style.frontFill)
            .frame(width: 36, height: 50)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(style.border.opacity(0.72), lineWidth: 1.2)
            )
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(rank)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                    Image(systemName: suit)
                        .font(.system(size: 9, weight: .black))
                }
                .foregroundStyle(color)
                .padding(5)
            }
            .overlay(
                Image(systemName: suit)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(color.opacity(0.22))
            )
            .shadow(color: style.shadow.opacity(0.75), radius: 4, x: 0, y: 2)
    }
}
