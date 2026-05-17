import SwiftUI

struct RankedAccessStoreView: View {
    let user: AppUser
    let focusedMode: GameMode?
    var onUserChanged: () -> Void = {}

    @StateObject private var vm: RankedAccessViewModel
    @Environment(\.dismiss) private var dismiss

    init(user: AppUser, focusedMode: GameMode? = nil, onUserChanged: @escaping () -> Void = {}) {
        self.user = user
        self.focusedMode = focusedMode
        self.onUserChanged = onUserChanged
        _vm = StateObject(wrappedValue: RankedAccessViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    allAccessCard
                    if let focusedMode {
                        modeUnlockCard(mode: focusedMode)
                        rewardedAdCard(mode: focusedMode)
                    } else {
                        modeUnlockGrid
                    }
                    restoreButton
                    policyNote
                }
                .padding()
            }
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Ranked Pass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .tint(AppTheme.accentBright)
            .alert(
                "Ranked access update failed",
                isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
            ) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(AppTheme.crownGold)
            Text("Play ranked your way")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text("You get one free ranked match per mode each day. Watch an ad for extra entries, or unlock ranked forever.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var allAccessCard: some View {
        let productID = RankedAccessProduct.allAccessProductID
        return rankedPurchaseCard(
            title: "All Ranked Access",
            subtitle: "Unlock ranked forever for every mode.",
            productID: productID,
            isOwned: vm.user.rankedAccess.allModesUnlocked,
            accent: AppTheme.crownGold,
            action: { await vm.purchase(productID: productID) }
        )
    }

    private func modeUnlockCard(mode: GameMode) -> some View {
        let productID = RankedAccessProduct.productID(for: mode)
        return rankedPurchaseCard(
            title: "Unlock \(mode.displayName)",
            subtitle: "Permanent ranked access for this mode.",
            productID: productID,
            isOwned: vm.user.rankedAccess.hasPermanentAccess(to: mode),
            accent: mode.accentColor,
            action: { await vm.purchase(productID: productID) }
        )
    }

    private var modeUnlockGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mode Unlocks")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(GameMode.allCases) { mode in
                    modeUnlockCard(mode: mode)
                }
            }
        }
    }

    private func rewardedAdCard(mode: GameMode) -> some View {
        let remaining = vm.user.rankedAccess.rewardedAdsRemaining(for: mode)
        let tickets = vm.user.rankedAccess.rewardedTicketsRemaining(for: mode)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Watch Ad", systemImage: "play.rectangle.fill")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(remaining) left today")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accentBright)
            }
            Text("Earn one extra \(mode.displayName) ranked entry. Tickets ready: \(tickets).")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Button {
                Task {
                    if await vm.watchAdForRankedTicket(mode: mode) { onUserChanged() }
                }
            } label: {
                Text(vm.isWorking ? "Working..." : "Watch for 1 Entry")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(remaining > 0 ? AppTheme.teal : AppTheme.cardBorder)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(vm.isWorking || remaining <= 0)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func rankedPurchaseCard(
        title: String,
        subtitle: String,
        productID: String,
        isOwned: Bool,
        accent: Color,
        action: @escaping () async -> Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Text(isOwned ? "Owned" : vm.priceText(for: productID))
                    .font(.subheadline.bold())
                    .foregroundStyle(isOwned ? AppTheme.teal : accent)
            }
            Button {
                Task {
                    if await action() { onUserChanged() }
                }
            } label: {
                Text(isOwned ? "Unlocked" : "Unlock")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isOwned ? AppTheme.cardBorder : accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(isOwned || vm.isWorking)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(accent.opacity(0.45), lineWidth: 1))
    }

    private var restoreButton: some View {
        Button {
            Task {
                if await vm.restorePurchases() { onUserChanged() }
            }
        } label: {
            Label("Restore Purchases", systemImage: "arrow.clockwise.circle.fill")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.10))
                .foregroundStyle(AppTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(vm.isWorking)
    }

    private var policyNote: some View {
        Text("Ranked passes unlock entry only. Coins, ranks, puzzles, wagers, and match rules stay fair for everyone.")
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
}
