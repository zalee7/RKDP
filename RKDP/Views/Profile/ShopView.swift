import SwiftUI

struct ShopView: View {
    let user: AppUser
    @StateObject private var vm: ShopViewModel
    @State private var selectedCategory: CosmeticCategory = .boardTheme
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

                // Items grid
                let items = vm.items(for: selectedCategory)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(items) { item in
                            ShopItemCard(
                                item: item,
                                isOwned: vm.isOwned(item),
                                isEquipped: vm.isEquipped(item),
                                canAfford: vm.canAfford(item)
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
}

struct ShopItemCard: View {
    let item: CosmeticItem
    let isOwned: Bool
    let isEquipped: Bool
    let canAfford: Bool
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
            // Preview placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
                .frame(height: 90)
                .overlay(
                    Image(systemName: iconForCategory(item.category))
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                )
                .overlay(alignment: .topTrailing) {
                    if isOwned {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .padding(6)
                    }
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
    }

    private func iconForCategory(_ cat: CosmeticCategory) -> String {
        switch cat {
        case .boardTheme:  return "square.grid.3x3.fill"
        case .avatar:      return "person.crop.circle.fill"
        case .numberFont:  return "textformat"
        case .cellBorder:  return "rectangle.inset.filled"
        }
    }
}
