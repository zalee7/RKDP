import SwiftUI


private enum ShopSection: Hashable, CaseIterable {
    case coinPacks
    case rankedPass
    case category(CosmeticCategory)

    static var allCases: [ShopSection] {
        let shopCategories = CosmeticCategory.allCases.filter { !$0.isAvatarCategory }
        return [.coinPacks, .rankedPass] + shopCategories.map { .category($0) }
    }

    var title: String {
        switch self {
        case .coinPacks: return "Coin Packs"
        case .rankedPass: return "Ranked Pass"
        case .category(let category): return category.rawValue
        }
    }
}

struct ShopView: View {
    let user: AppUser
    var onUserChanged: () -> Void = {}
    @StateObject private var vm: ShopViewModel
    @State private var selectedSection: ShopSection = .coinPacks
    @State private var showRankedPassStore = false
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
                            Button { selectedSection = section } label: {
                                Text(section.title)
                                    .font(.subheadline.weight(selectedSection == section ? .bold : .regular))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(selectedSection == section ? AppTheme.crownGold : AppTheme.cardBackground)
                                    .foregroundStyle(selectedSection == section ? .white : AppTheme.textSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                // Rotation countdown banner (titles only)
                if selectedSection == .category(.title) {
                    RotationCountdownBanner(nextDate: vm.nextRotationDate)
                }

                // Items
                ScrollView {
                    switch selectedSection {
                    case .coinPacks:
                        coinPackSection
                            .padding()
                    case .rankedPass:
                        rankedPassSection
                            .padding()
                    case .category(let category):
                        let items = vm.items(for: category)
                        let ownedItems = vm.ownedItems.filter { $0.category == category }
                        if items.isEmpty && ownedItems.isEmpty {
                            emptyStoreState(category: category)
                                .padding()
                        } else if category == .title {
                            titleGrid(items: items, ownedItems: ownedItems)
                        } else {
                            categorizedShopGrid(availableItems: items, ownedItems: ownedItems)
                                .padding(.vertical)
                        }
                    }
                }
            }
            .background(AppTheme.arenaBackground.ignoresSafeArea())
            .foregroundStyle(AppTheme.textPrimary)
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showRankedPassStore) {
                RankedAccessStoreView(user: vm.user) {
                    onUserChanged()
                }
            }
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


    private var coinPackSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Free Coins")
                    .font(.headline.bold())
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

            Text("Coins are virtual currency for cosmetics, ranked wagers, and tournament entries only. They cannot be cashed out or redeemed for real prizes.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var rankedPassSection: some View {
        VStack(spacing: 14) {
            RankedPassShopBanner(user: vm.user) {
                showRankedPassStore = true
            }
            Text("Ranked passes unlock entry access only. They do not change wagers, rank points, puzzles, or match outcomes.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
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
                    isLimited: item.category == .title && item.price > 0 && vm.isInTodaysRotation(item)
                ) {
                    Task { await handleShopAction(item) }
                }
            }
        }
    }

    @ViewBuilder
    private func categorizedShopGrid(availableItems: [CosmeticItem], ownedItems: [CosmeticItem]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if !ownedItems.isEmpty {
                itemSection(title: "Owned", subtitle: "Equip anything you already have.", items: ownedItems)
            }
            if !availableItems.isEmpty {
                itemSection(title: "Available", subtitle: "Unlock new cosmetics with coins.", items: availableItems)
            }
        }
        .padding(.horizontal)
    }

    private func itemSection(title: String, subtitle: String, items: [CosmeticItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(title == "Owned" ? AppTheme.teal : AppTheme.crownGold)
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
                itemSection(title: "Today's Titles", subtitle: "Limited rotation titles available today.", items: items)
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
            Text(category == .title ? "No new titles today" : "Everything here is owned")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text("Owned cosmetics live on your Profile for faster equipping. Avatar parts live in Customize Avatar.")
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
                    .background(AppTheme.crownGold)
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

private struct RankedPassShopBanner: View {
    let user: AppUser
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.brandGradient)
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: "crown.fill").font(.title3.bold()).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ranked Pass")
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(user.rankedAccess.allModesUnlocked ? "All ranked modes unlocked" : "Daily entries, ad tickets, and permanent unlocks")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accentBright)
            }
            .padding(12)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
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
    let onAction: () -> Void

    var actionLabel: String {
        if isEquipped { return "Equipped" }
        if isOwned    { return "Equip" }
        return "\(item.price) 🪙"
    }

    var actionColor: Color {
        if isEquipped { return AppTheme.teal.opacity(0.72) }
        if isOwned    { return AppTheme.crownGold }
        return canAfford ? AppTheme.crownGold : AppTheme.cardBorder
    }

    var body: some View {
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
                } else if item.category.isAvatarCategory {
                    AvatarPartPreview(item: item)
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

                // Badges
                VStack(alignment: .trailing, spacing: 4) {
                    RarityBadgeView(rarity: item.rarity)
                    HStack(spacing: 4) {
                        if isLimited && !isOwned {
                        Text("LIMITED")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(AppTheme.crownGold)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                        if isEquipped {
                            Text("EQUIPPED")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(AppTheme.teal)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        } else if isOwned {
                            Text("OWNED")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(AppTheme.royalBlue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(6)
            }

            Text(item.name).font(.subheadline.bold()).lineLimit(1)
            Text(item.description).font(.caption).foregroundStyle(AppTheme.textSecondary).lineLimit(2).multilineTextAlignment(.center)

            Button(action: onAction) {
                Text(actionLabel)
                    .font(.caption.bold())
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(actionColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .disabled(isEquipped || (!isOwned && !canAfford))
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isLimited && !isOwned ? AppTheme.crownGold.opacity(0.65) : AppTheme.cardBorder, lineWidth: 1.5)
        )
    }

    private func iconForCategory(_ cat: CosmeticCategory) -> String {
        switch cat {
        case .title:        return "text.badge.star"
        case .boardTheme:   return "paintpalette.fill"
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
        case .avatarHead:
            headPreview
        case .avatarFace:
            facePreview
        case .avatarOutfit:
            bodySkinPreview
        case .avatarAura:
            auraPreview
        case .avatarPose:
            posePreview
        default:
            Image(systemName: "sparkles")
                .font(.title.bold())
                .foregroundStyle(AppTheme.crownGold)
        }
    }

    private var headPreview: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 48, height: 48)
            switch item.id {
            case "avatar_head_crown", "avatar_head_puzzle_crown":
                Image(systemName: "crown.fill")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(item.id == "avatar_head_puzzle_crown" ? AppTheme.hotPink : AppTheme.crownGold)
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
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(AppTheme.royalBlue)
            case "avatar_head_mini_crown":
                Image(systemName: "crown.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(AppTheme.crownGold)
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
                .overlay(PreviewPuzzlePieceShape().stroke(Color.white, lineWidth: 3))
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
            return LinearGradient(colors: [AppTheme.hotPink, Color(hex: "7B42FF"), AppTheme.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
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
        path.addLine(to: CGPoint(x: x + w * 0.42, y: y + h * 0.10))
        path.addCurve(
            to: CGPoint(x: x + w * 0.58, y: y + h * 0.10),
            control1: CGPoint(x: x + w * 0.43, y: y - h * 0.08),
            control2: CGPoint(x: x + w * 0.57, y: y - h * 0.08)
        )
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

private struct ShopThemePreview: View {
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
