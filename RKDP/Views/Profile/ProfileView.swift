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

                            Button { showAvatarEditor = true } label: {
                                Label("Customize Avatar", systemImage: "sparkles")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.hotPink.opacity(0.18))
                                    .foregroundStyle(AppTheme.hotPink)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(AppTheme.hotPink.opacity(0.45), lineWidth: 1))
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


                        // Owned cosmetics
                        sectionCard(title: "Owned Cosmetics") {
                            let ownedItems = shop.ownedItems
                            let categoryItems = ownedItems.filter { $0.category == selectedOwnedCategory }
                            if ownedItems.isEmpty {
                                Text("Bought cosmetics will appear here for quick equipping.")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            } else {
                                VStack(alignment: .leading, spacing: 14) {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(nonAvatarCosmeticCategories, id: \.self) { category in
                                                let count = ownedItems.filter { $0.category == category }.count
                                                Button { selectedOwnedCategory = category } label: {
                                                    HStack(spacing: 5) {
                                                        Text(category.rawValue)
                                                        Text("\(count)")
                                                            .font(.caption2.bold())
                                                            .padding(.horizontal, 5)
                                                            .padding(.vertical, 2)
                                                            .background(Color.white.opacity(selectedOwnedCategory == category ? 0.22 : 0.10))
                                                            .clipShape(Capsule())
                                                    }
                                                    .font(.caption.bold())
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 8)
                                                    .background(selectedOwnedCategory == category ? AppTheme.crownGold : Color.white.opacity(0.08))
                                                    .foregroundStyle(selectedOwnedCategory == category ? .white : AppTheme.textSecondary)
                                                    .clipShape(Capsule())
                                                    .overlay(Capsule().stroke(selectedOwnedCategory == category ? AppTheme.crownGold.opacity(0.75) : AppTheme.cardBorder, lineWidth: 1))
                                                }
                                                .disabled(count == 0)
                                                .opacity(count == 0 ? 0.45 : 1)
                                            }
                                        }
                                    }

                                    if categoryItems.isEmpty {
                                        Text("No owned \(selectedOwnedCategory.rawValue.lowercased()) yet.")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 8)
                                    } else {
                                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                            ForEach(categoryItems) { item in
                                                ShopItemCard(
                                                    item: item,
                                                    isOwned: true,
                                                    isEquipped: shop.isEquipped(item),
                                                    canAfford: true,
                                                    isLimited: false
                                                ) {
                                                    Task {
                                                        if await shop.equip(item) {
                                                            await auth.refreshUser()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Career stats
                        sectionCard(title: "Career Stats") {
                            let totalWins   = user.ranks.values.reduce(0) { $0 + $1.wins }
                            let totalLosses = user.ranks.values.reduce(0) { $0 + $1.losses }
                            VStack(spacing: 8) {
                                StatRow(label: "Total Wins",   value: "\(totalWins)")
                                StatRow(label: "Total Losses", value: "\(totalLosses)")
                                StatRow(label: "Total Points", value: "\(user.totalRankPoints)")
                            }
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
        }
    }

    private var nonAvatarCosmeticCategories: [CosmeticCategory] {
        CosmeticCategory.allCases.filter { !$0.isAvatarCategory }
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

    private let categories: [CosmeticCategory] = [.avatarHead, .avatarFace, .avatarOutfit, .avatarAura, .avatarPose]

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
                        Text("Puzzle Pal")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Avatar parts are cosmetic only and never affect ranked play.")
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
                                            .background(selectedCategory == category ? AppTheme.crownGold : Color.white.opacity(0.08))
                                            .foregroundStyle(selectedCategory == category ? .white : AppTheme.textSecondary)
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

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(CosmeticCatalog.all.filter { $0.category == selectedCategory }) { item in
                                ShopItemCard(
                                    item: item,
                                    isOwned: shop.isOwned(item),
                                    isEquipped: shop.isEquipped(item),
                                    canAfford: shop.canAfford(item),
                                    isLimited: false
                                ) {
                                    Task {
                                        let changed = shop.isOwned(item) ? await shop.equip(item) : await shop.purchase(item)
                                        if changed { await onChanged() }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Customize Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert(
                "Avatar update failed",
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
                TextField("FF2F78", text: $bodyHexInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(bodyHexError == nil ? AppTheme.cardBorder : AppTheme.danger, lineWidth: 1))
                Button("Save") {
                    Task { await saveBodyHex() }
                }
                .font(.caption.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.crownGold)
                .foregroundStyle(.white)
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
                            .overlay(Circle().stroke(hex == shop.ownedCosmetics.customAvatarBodyHex ? AppTheme.crownGold : Color.white.opacity(0.55), lineWidth: hex == shop.ownedCosmetics.customAvatarBodyHex ? 2.5 : 1))
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

    private var colorSwatches: [String] {
        [
            "FF2F78", "12C8A2", "256BFF", "FFD02E", "7B42FF", "FFFFFF",
            "FF6B1A", "8FFFE1", "11183A", "39D5FF", "FF9ED1", "050510",
            "C9D2E3", "23D18B"
        ]
    }

    private func label(for category: CosmeticCategory) -> String {
        switch category {
        case .avatarHead: return "Head"
        case .avatarFace: return "Face"
        case .avatarOutfit: return "Body"
        case .avatarAura: return "Aura"
        case .avatarPose: return "Pose"
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
                if let best = info.bestScore {
                    Text("Best \(best) pts").font(.system(size: 10)).foregroundStyle(AppTheme.accentBright)
                } else if let best = info.bestTime {
                    Text("Best \(best / 60):\(String(format: "%02d", best % 60))")
                        .font(.system(size: 10)).foregroundStyle(AppTheme.accentBright)
                }
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
