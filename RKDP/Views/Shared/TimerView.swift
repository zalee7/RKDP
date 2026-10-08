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
            .foregroundStyle(AppTheme.textPrimary)
    }
}

struct RankIconView: View {
    let tier: RankTier
    var division: RankDivision? = nil
    var size: CGFloat = 18

    var body: some View {
        Image(tier.iconAssetName(division: division))
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: tier.color.opacity(0.35), radius: size * 0.12, x: 0, y: size * 0.06)
            .accessibilityHidden(true)
    }
}

struct RankBadgeView: View {
    let tier: RankTier
    var division: RankDivision? = nil
    var showLabel = true
    var iconSize: CGFloat? = nil
    var labelFont: Font = .caption.bold()

    var body: some View {
        HStack(spacing: 5) {
            RankIconView(tier: tier, division: division, size: iconSize ?? (showLabel ? 18 : 22))
            if showLabel {
                if let div = division {
                    Text("\(tier.displayName) \(div.label)")
                        .font(labelFont)
                        .foregroundStyle(tier.color)
                } else {
                    Text(tier.displayName)
                        .font(labelFont)
                        .foregroundStyle(tier.color)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
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
                .foregroundStyle(AppTheme.textPrimary)
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

struct RankDivisionProgressView: View {
    let info: RankInfo
    var height: CGFloat = 4
    var spacing: CGFloat = 3
    var showLabels = false
    var progressOverride: Double? = nil

    private var tint: Color { info.displayTier.color }

    var body: some View {
        VStack(spacing: showLabels ? 5 : 0) {
            HStack(spacing: spacing) {
                ForEach(RankDivision.progression, id: \.self) { division in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                                .fill(AppTheme.progressTrack)
                            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                                .fill(tint)
                                .frame(width: geo.size.width * segmentProgress(for: division))
                        }
                    }
                    .frame(height: height)
                }
            }
            if showLabels {
                HStack(spacing: spacing) {
                    ForEach(RankDivision.progression, id: \.self) { division in
                        Text(division.label)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(division == info.division ? tint : AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityLabel("Rank division progress")
        .accessibilityValue(info.nextRankStepText)
    }

    private func segmentProgress(for division: RankDivision) -> Double {
        if division.rawValue < info.division.rawValue { return 1 }
        if division.rawValue > info.division.rawValue { return 0 }
        return max(0, min(1, progressOverride ?? info.divisionProgress))
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
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(AppTheme.controlBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AppTheme.controlBorder, lineWidth: 1)
                            )
                            .shadow(color: AppTheme.softShadow.opacity(0.7), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 16) {
                Button { onNote() } label: {
                    Label("Notes", systemImage: "pencil")
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(isNoteMode ? AppTheme.royalBlue : AppTheme.controlBackground)
                        .foregroundStyle(isNoteMode ? AppTheme.textOnColor : AppTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isNoteMode ? AppTheme.royalBlue : AppTheme.controlBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                Button { onErase() } label: {
                    Label("Erase", systemImage: "delete.left")
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(AppTheme.controlBackground)
                        .foregroundStyle(AppTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppTheme.controlBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}
