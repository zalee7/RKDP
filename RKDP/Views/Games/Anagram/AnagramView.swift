import SwiftUI

struct AnagramView: View {
    @StateObject private var vm: AnagramViewModel
    @Environment(\.dismiss) var dismiss

    init(difficulty: Difficulty, sessionID: String? = nil) {
        _vm = StateObject(wrappedValue: AnagramViewModel(difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 12)

                resultBanner
                    .padding(.top, 6)

                foundWordsScroll
                    .padding(.top, 10)

                Spacer(minLength: 0)

                placedRow
                    .padding(.top, 12)

                bankSection
                    .padding(.top, 14)

                controlRow
                    .padding(.top, 14)
                    .padding(.horizontal)
                    .padding(.bottom, 28)
            }

            if vm.isFinished { finishedOverlay }
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
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                    Text("\(vm.timeRemaining)s")
                        .monospacedDigit()
                }
                .font(.headline)
                .foregroundStyle(vm.timeRemaining <= 15 ? .red : AppTheme.textPrimary)
                .animation(.easeInOut, value: vm.timeRemaining)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(vm.score)")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.accentBright)
                Text("pts")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Result banner

    @ViewBuilder
    private var resultBanner: some View {
        if let result = vm.lastResult {
            Group {
                switch result {
                case .valid(let word, let pts):
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(word).bold()
                        Text("+\(pts) pts").foregroundStyle(.green)
                    }
                case .invalid:
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        Text("Not a word")
                    }
                case .alreadyFound:
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text("Already found!")
                    }
                case .tooShort:
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text("Need 3+ letters")
                    }
                }
            }
            .font(.subheadline.bold())
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 1))
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.25), value: vm.lastResult)
        }
    }

    // MARK: - Found words

    private var foundWordsScroll: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Words Found")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1)
                Spacer()
                Text("\(vm.foundWords.count) / \(vm.game.validWords.count)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal)

            if vm.foundWords.isEmpty {
                Text("Start typing to find words!")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal)
                    .frame(height: 34)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.sortedFoundWords, id: \.self) { word in
                            HStack(spacing: 4) {
                                Text(word.capitalized)
                                    .font(.caption.bold())
                                Text("+\(AnagramGame.score(for: word))")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.accentBright)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.modeAccent(.anagram).opacity(0.15))
                            .foregroundStyle(AppTheme.textPrimary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.modeAccent(.anagram).opacity(0.3), lineWidth: 1))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                    .animation(.spring(response: 0.3), value: vm.foundWords)
                }
                .frame(height: 34)
            }
        }
    }

    // MARK: - Placed (current word)

    private var placedRow: some View {
        VStack(spacing: 6) {
            Text("Current Word")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(1)

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.modeAccent(.anagram).opacity(0.4), lineWidth: 1))

                if vm.placed.isEmpty {
                    Text("Tap letters below")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.placed, id: \.id) { tile in
                                LetterTile(letter: tile.letter, gradient: AppTheme.modeGradient(.anagram), size: 44)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.25)) { vm.returnToBank(id: tile.id) }
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
            }
            .frame(height: 64)
            .padding(.horizontal)
        }
    }

    // MARK: - Bank

    private var bankSection: some View {
        VStack(spacing: 6) {
            Text("Your Letters")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(1)

            LetterWrapLayout(spacing: 8) {
                ForEach(vm.bank, id: \.id) { tile in
                    LetterTile(letter: tile.letter, gradient: AppTheme.brandGradient, size: 48)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25)) { vm.pickFromBank(id: tile.id) }
                        }
                }
            }
            .padding(.horizontal)
            .frame(minHeight: 56)
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: 10) {
            iconButton(label: "Shuffle", icon: "shuffle") {
                withAnimation(.spring(response: 0.35)) { vm.shuffleBank() }
            }
            iconButton(label: "Clear", icon: "arrow.uturn.backward") {
                withAnimation(.spring(response: 0.35)) { vm.clearPlaced() }
            }

            // Hint
            Button {
                withAnimation { vm.showHint.toggle() }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: vm.showHint ? "lightbulb.fill" : "lightbulb")
                        .font(.headline)
                    Text("Hint")
                        .font(.caption2.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(vm.showHint ? AppTheme.accentBright.opacity(0.2) : AppTheme.cardBackground)
                .foregroundStyle(vm.showHint ? AppTheme.accentBright : AppTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(vm.showHint ? AppTheme.accentBright.opacity(0.5) : AppTheme.cardBorder, lineWidth: 1))
            }

            // Submit
            Button { vm.submit() } label: {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.headline)
                    Text("Submit")
                        .font(.caption2.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(vm.placed.count >= 3 ? AppTheme.modeGradient(.anagram) : LinearGradient(colors: [AppTheme.cardBackground], startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(vm.placed.count < 3)
            .animation(.easeInOut(duration: 0.15), value: vm.placed.count)
        }
    }

    @ViewBuilder
    private func iconButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.headline)
                Text(label).font(.caption2.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.cardBackground)
            .foregroundStyle(AppTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Hint overlay

    private var hintSection: some View {
        Group {
            if vm.showHint, let hint = vm.hintWord {
                Text("Hint: \(hint.prefix(1))\(String(repeating: "·", count: hint.count - 1))")
                    .font(.subheadline.italic())
                    .foregroundStyle(AppTheme.accentBright)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Finished overlay

    private var finishedOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("⏱️ Time's Up!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.textPrimary)

                    HStack(spacing: 24) {
                        statBox(value: "\(vm.score)", label: "Points", color: AppTheme.accentBright)
                        statBox(value: "\(vm.foundWords.count)", label: "Found", color: AppTheme.modeAccent(.anagram))
                        statBox(value: "\(vm.missedWords.count)", label: "Missed", color: .orange)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))

                    if !vm.missedWords.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Words you missed:")
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.textSecondary)
                            LetterWrapLayout(spacing: 6) {
                                ForEach(vm.missedWords.prefix(30), id: \.self) { word in
                                    Text(word.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
                    }

                    Button { vm.stop(); dismiss() } label: {
                        Text("Done")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.modeGradient(.anagram))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(24)
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(AppTheme.cardBorder, lineWidth: 1))
            .padding(20)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: vm.isFinished)
    }

    @ViewBuilder
    private func statBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(AppTheme.textSecondary)
        }
    }
}

// MARK: - Shared subviews

private struct LetterTile: View {
    let letter: Character
    let gradient: LinearGradient
    var size: CGFloat = 44

    var body: some View {
        Text(String(letter))
            .font(.system(size: size * 0.42, weight: .bold))
            .frame(width: size, height: size)
            .background(gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
    }
}

// MARK: - Wrapping layout for letter bank

private struct LetterWrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? UIScreen.main.bounds.width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (subview, origin) in zip(subviews, result.origins) {
            let size = subview.sizeThatFits(.unspecified)
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                          proposal: ProposedViewSize(size))
        }
    }

    private struct LayoutResult { var size: CGSize; var origins: [CGPoint] }

    private func layout(subviews: Subviews, width: CGFloat) -> LayoutResult {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowH + spacing; x = 0; rowH = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }

        // Centre each row
        var centred: [CGPoint] = []
        var rowStart = 0
        var ry: CGFloat = 0
        while rowStart < origins.count {
            var rowEnd = rowStart
            while rowEnd + 1 < origins.count && origins[rowEnd + 1].y == origins[rowStart].y {
                rowEnd += 1
            }
            let lastOrigin = origins[rowEnd]
            let lastSize = subviews[rowEnd].sizeThatFits(.unspecified)
            let rowWidth = lastOrigin.x + lastSize.width
            let offset = (width - rowWidth) / 2
            let rh = subviews[rowStart...rowEnd].map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for i in rowStart...rowEnd {
                centred.append(CGPoint(x: origins[i].x + offset, y: ry))
            }
            ry += rh + spacing
            rowStart = rowEnd + 1
        }

        let totalH = ry > spacing ? ry - spacing : 0
        return LayoutResult(size: CGSize(width: width, height: totalH), origins: centred)
    }
}
