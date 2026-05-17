import SwiftUI

struct ShopView: View {
    let user: AppUser
    var onUserChanged: () -> Void = {}
    @StateObject private var vm: ShopViewModel
    @State private var selectedCategory: CosmeticCategory = .title
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

                RankedPassShopBanner(user: vm.user) {
                    showRankedPassStore = true
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CosmeticCategory.allCases, id: \.self) { cat in
                            Button { selectedCategory = cat } label: {
                                Text(cat.rawValue)
                                    .font(.subheadline.weight(selectedCategory == cat ? .bold : .regular))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(selectedCategory == cat ? AppTheme.royalBlue : AppTheme.cardBackground)
                                    .foregroundStyle(selectedCategory == cat ? .white : AppTheme.textSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                // Rotation countdown banner (titles only)
                if selectedCategory == .title {
                    RotationCountdownBanner(nextDate: vm.nextRotationDate)
                }

                // Items
                let items = vm.items(for: selectedCategory)
                ScrollView {
                    if selectedCategory == .title {
                        titleGrid(items: items)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(items) { item in
                                ShopItemCard(
                                    item: item,
                                    isOwned: vm.isOwned(item),
                                    isEquipped: vm.isEquipped(item),
                                    canAfford: vm.canAfford(item),
                                    isLimited: false
                                ) {
                                    Task { await handleShopAction(item) }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
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

    private func handleShopAction(_ item: CosmeticItem) async {
        let changed: Bool
        if vm.isOwned(item) {
            changed = await vm.equip(item)
        } else {
            changed = await vm.purchase(item)
        }
        if changed { onUserChanged() }
    }

    @ViewBuilder
    private func titleGrid(items: [CosmeticItem]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Today's rotation
            let todayItems = items.filter { vm.isInTodaysRotation($0) || $0.price == 0 }
            let ownedOther = items.filter { !vm.isInTodaysRotation($0) && $0.price > 0 && vm.isOwned($0) }

            if !todayItems.isEmpty {
                Text("Today's Titles")
                    .font(.headline)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(todayItems) { item in
                        ShopItemCard(
                            item: item,
                            isOwned: vm.isOwned(item),
                            isEquipped: vm.isEquipped(item),
                            canAfford: vm.canAfford(item),
                            isLimited: item.price > 0
                        ) {
                            Task { await handleShopAction(item) }
                        }
                    }
                }
                .padding(.horizontal)
            }

            if !ownedOther.isEmpty {
                Divider().padding(.horizontal)
                Text("Owned")
                    .font(.headline)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(ownedOther) { item in
                        ShopItemCard(
                            item: item,
                            isOwned: true,
                            isEquipped: vm.isEquipped(item),
                            canAfford: true,
                            isLimited: false
                        ) { Task { await handleShopAction(item) } }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
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
        if isEquipped { return AppTheme.cardBorder }
        if isOwned    { return AppTheme.royalBlue }
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
                    if isOwned {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.teal)
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
