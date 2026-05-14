import SwiftUI

struct AnagramView: View {
    @StateObject private var vm: AnagramViewModel
    @Environment(\.dismiss) var dismiss

    init(difficulty: Difficulty, sessionID: String? = nil) {
        _vm = StateObject(wrappedValue: AnagramViewModel(difficulty: difficulty))
    }

    private let tileSize: CGFloat = 44
    private let tileSpacing: CGFloat = 8

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                hintSection
                    .padding(.horizontal)
                    .padding(.top, 16)

                placedRow
                    .padding(.top, 24)

                bankSection
                    .padding(.top, 20)

                controlButtons
                    .padding(.top, 20)
                    .padding(.horizontal)

                submitButton
                    .padding(.top, 12)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }

            if vm.isCorrect { winOverlay }
        }
        .navigationBarBackButtonHidden()
        .onDisappear { vm.stop() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { vm.stop(); dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(vm.difficulty.displayName.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.modeAccent(.anagram))
                TimerView(seconds: vm.effectiveTime)
                    .foregroundStyle(vm.penaltySeconds > 0 ? .orange : AppTheme.textPrimary)
            }

            Spacer()

            Button {
                withAnimation { vm.showHint.toggle() }
            } label: {
                Image(systemName: vm.showHint ? "lightbulb.fill" : "lightbulb")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accentBright)
            }
        }
    }

    // MARK: - Hint

    private var hintSection: some View {
        VStack(spacing: 6) {
            if vm.showHint {
                Text(vm.puzzle.hint)
                    .font(.subheadline.italic())
                    .foregroundStyle(AppTheme.accentBright)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Text("ANAGRAM")
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(2)
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showHint)
    }

    // MARK: - Placed row (answer)

    private var placedRow: some View {
        VStack(spacing: 8) {
            Text("Your Answer")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(1)

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(vm.isWrong ? Color.red : AppTheme.modeAccent(.anagram).opacity(0.4), lineWidth: vm.isWrong ? 2 : 1)
                    )
                    .animation(.easeInOut(duration: 0.2), value: vm.isWrong)

                if vm.placed.isEmpty {
                    Text("Tap letters below")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.vertical, 14)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: tileSpacing) {
                            ForEach(vm.placed, id: \.id) { tile in
                                LetterTile(letter: tile.letter, gradient: AppTheme.modeGradient(.anagram), isPlaced: true)
                                    .onTapGesture { withAnimation(.spring(response: 0.3)) { vm.returnToBank(id: tile.id) } }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
            }
            .frame(height: tileSize + 28)
            .padding(.horizontal)
        }
    }

    // MARK: - Bank

    private var bankSection: some View {
        VStack(spacing: 8) {
            Text("Letters")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(1)

            WrappingHStack(spacing: tileSpacing) {
                ForEach(vm.bank, id: \.id) { tile in
                    LetterTile(letter: tile.letter, gradient: AppTheme.brandGradient, isPlaced: false)
                        .onTapGesture { withAnimation(.spring(response: 0.3)) { vm.pickFromBank(id: tile.id) } }
                }
            }
            .padding(.horizontal)
            .frame(minHeight: tileSize * 2 + tileSpacing)
        }
    }

    // MARK: - Control buttons

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35)) { vm.shuffleBank() }
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.cardBackground)
                    .foregroundStyle(AppTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
            }

            Button {
                withAnimation(.spring(response: 0.35)) { vm.clearPlaced() }
            } label: {
                Label("Clear", systemImage: "arrow.uturn.backward")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.cardBackground)
                    .foregroundStyle(AppTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            vm.submit()
        } label: {
            Text("Submit")
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(vm.placed.count == vm.puzzle.word.count ? AppTheme.modeGradient(.anagram) : LinearGradient(colors: [AppTheme.cardBackground], startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: AppTheme.modeAccent(.anagram).opacity(vm.placed.count == vm.puzzle.word.count ? 0.5 : 0), radius: 10)
        }
        .disabled(vm.placed.count != vm.puzzle.word.count || vm.isCorrect)
        .animation(.easeInOut(duration: 0.2), value: vm.placed.count)
    }

    // MARK: - Win overlay

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 72))

                Text("You got it!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.textPrimary)

                Text(vm.puzzle.word)
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.modeAccent(.anagram))

                VStack(spacing: 6) {
                    Text("Time: \(vm.elapsedSeconds)s")
                        .foregroundStyle(AppTheme.textSecondary)
                    if vm.penaltySeconds > 0 {
                        Text("+\(vm.penaltySeconds)s penalty")
                            .foregroundStyle(.orange)
                    }
                    Text("Effective: \(vm.effectiveTime)s")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .font(.subheadline)

                Button {
                    vm.stop()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.modeGradient(.anagram))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
            }
            .padding(32)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(AppTheme.cardBorder, lineWidth: 1))
            .padding(32)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.4), value: vm.isCorrect)
    }
}

// MARK: - Letter tile

private struct LetterTile: View {
    let letter: Character
    let gradient: LinearGradient
    let isPlaced: Bool

    var body: some View {
        Text(String(letter))
            .font(.title2.bold())
            .frame(width: 44, height: 44)
            .background(gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            .scaleEffect(isPlaced ? 1.05 : 1.0)
    }
}

// MARK: - Wrapping HStack for bank

private struct WrappingHStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? UIScreen.main.bounds.width
        var rows: [[LayoutSubviews.Element]] = [[]]
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + (rows.last!.isEmpty ? 0 : spacing) > width {
                rows.append([subview])
                rowWidth = size.width
            } else {
                rows[rows.count - 1].append(subview)
                rowWidth += size.width + (rows.last!.count == 1 ? 0 : spacing)
            }
        }

        let height = rows.reduce(0.0) { acc, row in
            let rowH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            return acc + rowH + (acc > 0 ? spacing : 0)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var rows: [[LayoutSubviews.Element]] = [[]]
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + (rows.last!.isEmpty ? 0 : spacing) > width {
                rows.append([subview])
                rowWidth = size.width
            } else {
                rows[rows.count - 1].append(subview)
                rowWidth += size.width + (rows.last!.count == 1 ? 0 : spacing)
            }
        }

        var y = bounds.minY
        for row in rows {
            let rowH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            let totalW = row.reduce(0.0) { $0 + $1.sizeThatFits(.unspecified).width } + CGFloat(row.count - 1) * spacing
            var x = bounds.minX + (width - totalW) / 2
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowH + spacing
        }
    }
}
