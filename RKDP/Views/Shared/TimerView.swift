import SwiftUI

struct TimerView: View {
    let seconds: Int

    private var formatted: String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        Label(formatted, systemImage: "timer")
            .font(.headline.monospacedDigit())
            .foregroundStyle(.primary)
    }
}

struct RankBadgeView: View {
    let tier: RankTier
    var division: RankDivision? = nil
    var showLabel = true

    var body: some View {
        HStack(spacing: 4) {
            Text(tier.icon).font(.subheadline)
            if showLabel {
                if let div = division {
                    Text("\(tier.displayName) \(div.label)")
                        .font(.caption.bold())
                        .foregroundStyle(tier.color)
                } else {
                    Text(tier.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(tier.color)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tier.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

struct CoinBadgeView: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 4) {
            CoinIconView(size: 16)
            Text("\(amount)")
                .font(.subheadline.bold())
        }
    }
}

struct CoinIconView: View {
    var size: CGFloat = 18

    var body: some View {
        Image("CoinAsset")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: max(1, size * 0.06)))
            .shadow(color: AppTheme.crownGold.opacity(0.45), radius: size * 0.18, x: 0, y: size * 0.08)
    }
}

struct RecordTextView: View {
    let wins: Int?
    let losses: Int?
    var prefix: String = ""
    var font: Font = .caption.bold()

    var body: some View {
        HStack(spacing: 2) {
            if !prefix.isEmpty {
                Text(prefix)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let wins, let losses {
                Text("\(wins)")
                    .foregroundStyle(AppTheme.success)
                Text("-")
                    .foregroundStyle(AppTheme.textSecondary)
                Text("\(losses)")
                    .foregroundStyle(AppTheme.danger)
            } else {
                Text("--")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .font(font)
        .monospacedDigit()
    }
}

struct NumberPadView: View {
    let size: Int        // max digit or board size for number-pad games
    let onDigit: (Int) -> Void
    let onErase: () -> Void
    let onNote: () -> Void
    var isNoteMode: Bool = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...size, id: \.self) { digit in
                    Button { onDigit(digit) } label: {
                        Text("\(digit)")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .foregroundStyle(.primary)
                }
            }
            HStack(spacing: 16) {
                Button { onNote() } label: {
                    Label("Notes", systemImage: "pencil")
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(isNoteMode ? Color.blue : Color(.secondarySystemBackground))
                        .foregroundStyle(isNoteMode ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button { onErase() } label: {
                    Label("Erase", systemImage: "delete.left")
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal)
    }
}
