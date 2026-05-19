import SwiftUI


private enum ShopSection: Hashable, CaseIterable {
    case coinPacks
    case rankedPass
    case category(CosmeticCategory)

    static var allCases: [ShopSection] {
        [.coinPacks, .rankedPass] + CosmeticCategory.allCases.map { .category($0) }
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
                        if items.isEmpty {
                            emptyStoreState(category: category)
                                .padding()
                        } else if category == .title {
                            titleGrid(items: items)
                        } else {
                            itemGrid(items: items)
                                .padding()
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
    private func titleGrid(items: [CosmeticItem]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Titles")
                .font(.headline.bold())
                .padding(.horizontal)

            itemGrid(items: items)
                .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private func emptyStoreState(category: CosmeticCategory) -> some View {
        VStack(spacing: 10) {
            Image(systemName: category == .title ? "clock.arrow.circlepath" : "bag.fill")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.crownGold)
            Text(category == .title ? "No new titles today" : "Everything here is owned")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text("Owned cosmetics now live on your Profile for faster equipping.")
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
        case .title:       return "text.badge.star"
        case .boardTheme:  return "paintpalette.fill"
        case .numberFont:  return "textformat"
        case .cellBorder:  return "rectangle.inset.filled"
        }
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
