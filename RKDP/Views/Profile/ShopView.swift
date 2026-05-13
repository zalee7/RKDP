import SwiftUI

struct ShopView: View {
    let user: AppUser
    @StateObject private var vm: ShopViewModel
    @State private var selectedCategory: CosmeticCategory = .title
    @Environment(\.dismiss) var dismiss

    init(user: AppUser) {
        self.user = user
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
                        .foregroundStyle(.secondary)
                    CoinBadgeView(amount: user.coins)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))

                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CosmeticCategory.allCases, id: \.self) { cat in
                            Button { selectedCategory = cat } label: {
                                Text(cat.rawValue)
                                    .font(.subheadline.weight(selectedCategory == cat ? .bold : .regular))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(selectedCategory == cat ? Color.blue : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedCategory == cat ? .white : .primary)
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
                                    Task {
                                        if vm.isOwned(item) { vm.equip(item) }
                                        else { await vm.purchase(item) }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
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
                            Task {
                                if vm.isOwned(item) { vm.equip(item) }
                                else { await vm.purchase(item) }
                            }
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
                        ) { vm.equip(item) }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
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
        .foregroundStyle(.orange)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
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
        if isEquipped { return .gray }
        if isOwned    { return .blue }
        return canAfford ? .orange : .gray
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Preview area
                if item.category == .title {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(height: 72)
                        .overlay(
                            Text("\"\(item.name)\"")
                                .font(.subheadline.bold().italic())
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .padding(8)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(height: 72)
                        .overlay(
                            Image(systemName: iconForCategory(item.category))
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                        )
                }

                // Badges
                HStack(spacing: 4) {
                    if isLimited && !isOwned {
                        Text("LIMITED")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    if isOwned {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(6)
            }

            Text(item.name).font(.subheadline.bold()).lineLimit(1)
            Text(item.description).font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.center)

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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isLimited && !isOwned ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }

    private func iconForCategory(_ cat: CosmeticCategory) -> String {
        switch cat {
        case .title:       return "text.badge.star"
        case .boardTheme:  return "square.grid.3x3.fill"
        case .numberFont:  return "textformat"
        case .cellBorder:  return "rectangle.inset.filled"
        }
    }
}
