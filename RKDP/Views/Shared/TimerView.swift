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
            Image(systemName: "circle.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
            Text("\(amount)")
                .font(.subheadline.bold())
        }
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
