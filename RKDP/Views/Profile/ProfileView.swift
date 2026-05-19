import SwiftUI

struct ProfileView: View {
    let user: AppUser
    let onDone: (() -> Void)?
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var shop: ShopViewModel
    @State private var isGrantingTesterAccess = false
    @State private var selectedOwnedCategory: CosmeticCategory = .title

    init(user: AppUser, onDone: (() -> Void)? = nil) {
        self.user = user
        self.onDone = onDone
        _shop = StateObject(wrappedValue: ShopViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Avatar header card
                        VStack(spacing: 12) {
                            Circle()
                                .fill(AppTheme.brandGradient)
                                .frame(width: 72, height: 72)
                                .overlay(Text(String(user.username.prefix(1))).font(.largeTitle.bold()).foregroundStyle(.white))
                                .shadow(color: AppTheme.accent.opacity(0.6), radius: 12)

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
                                            ForEach(CosmeticCategory.allCases, id: \.self) { category in
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
        }
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
