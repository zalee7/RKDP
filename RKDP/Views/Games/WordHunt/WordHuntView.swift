import SwiftUI

struct WordHuntView: View {
    @StateObject private var vm: WordHuntViewModel
    @Environment(\.dismiss) var dismiss
    @State private var lastDragLocation: CGPoint?

    init(difficulty: Difficulty, user: AppUser? = nil, sessionID: String? = nil) {
        _vm = StateObject(wrappedValue: WordHuntViewModel(
            difficulty: difficulty,
            userID: user?.id,
            priorBest: user?.rank(for: .wordHunt).bestScore
        ))
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                wordFeedbackBanner

                letterGrid
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                currentWordDisplay
                    .padding(.top, 12)

                foundWordsList
                    .padding(.top, 8)
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
                    .foregroundStyle(AppTheme.modeAccent(.wordHunt))
                HStack(spacing: 6) {
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

    // MARK: - Word feedback banner

    @ViewBuilder
    private var wordFeedbackBanner: some View {
        if let result = vm.lastWordResult {
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
                        Text(vm.currentWord.isEmpty ? "Not a word" : "Not a word")
                    }
                case .alreadyFound:
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text("Already found!")
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
            .animation(.easeInOut(duration: 0.3), value: vm.lastWordResult)
        }
    }

    // MARK: - Letter grid

    private var letterGrid: some View {
        GeometryReader { geo in
            // Each cell owns exactly cellSize × cellSize of the drag coordinate space.
            // Zero spacing means cell[r][c] center = ((c+0.5)*cellSize, (r+0.5)*cellSize).
            let cellSize = geo.size.width / CGFloat(WordHuntGame.gridSize)
            let gridView = VStack(spacing: 0) {
                ForEach(0..<WordHuntGame.gridSize, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<WordHuntGame.gridSize, id: \.self) { col in
                            GridCell(
                                letter: vm.game.grid[row][col],
                                isActive: vm.isInPath(row: row, col: col),
                                pathIndex: vm.pathIndex(row: row, col: col),
                                cellSize: cellSize
                            )
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .contentShape(Rectangle())
            .gesture(dragGesture(cellSize: cellSize))

            gridView
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dragGesture(cellSize: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let loc = value.location
                if vm.currentPath.isEmpty {
                    lastDragLocation = loc
                    let (r, c) = floorCell(loc, cellSize: cellSize)
                    vm.startPath(row: r, col: c)
                } else if let prev = lastDragLocation {
                    interpolatePath(from: prev, to: loc, cellSize: cellSize)
                    lastDragLocation = loc
                }
            }
            .onEnded { _ in
                vm.submitPath()
                lastDragLocation = nil
            }
    }

    /// Floor-division mapping: point → (row, col). Correct for every position in the cell.
    private func floorCell(_ p: CGPoint, cellSize: CGFloat) -> (Int, Int) {
        let col = max(0, min(WordHuntGame.gridSize - 1, Int(p.x / cellSize)))
        let row = max(0, min(WordHuntGame.gridSize - 1, Int(p.y / cellSize)))
        return (row, col)
    }

    /// Walk the straight line prev→current and feed every new cell to extendPath.
    private func interpolatePath(from prev: CGPoint, to current: CGPoint, cellSize: CGFloat) {
        let dx = current.x - prev.x
        let dy = current.y - prev.y
        let steps = max(1, Int((max(abs(dx), abs(dy)) / (cellSize * 0.4)).rounded(.up)))
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let pt = CGPoint(x: prev.x + dx * t, y: prev.y + dy * t)
            let (r, c) = floorCell(pt, cellSize: cellSize)
            vm.extendPath(row: r, col: c)
        }
    }

    // MARK: - Current word display

    private var currentWordDisplay: some View {
        HStack(spacing: 6) {
            if vm.currentWord.isEmpty {
                Text("Drag to trace a word")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(Array(vm.currentWord.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .frame(height: 36)
        .padding(.horizontal, 20)
    }

    // MARK: - Found words list

    private var foundWordsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Found Words")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1)
                Spacer()
                Text("\(vm.foundWords.count) / \(vm.game.validWords.count)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.sortedFoundWords, id: \.self) { word in
                        HStack(spacing: 4) {
                            Text(word)
                                .font(.caption.bold())
                            Text("+\(WordHuntGame.score(for: word))")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.accentBright)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.modeAccent(.wordHunt).opacity(0.15))
                        .foregroundStyle(AppTheme.textPrimary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.modeAccent(.wordHunt).opacity(0.3), lineWidth: 1))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .animation(.spring(response: 0.3), value: vm.foundWords)
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
                        VStack {
                            Text("\(vm.score)")
                                .font(.title.bold())
                                .foregroundStyle(AppTheme.accentBright)
                            Text("Points")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        VStack {
                            Text("\(vm.foundWords.count)")
                                .font(.title.bold())
                                .foregroundStyle(AppTheme.modeAccent(.wordHunt))
                            Text("Words")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        VStack {
                            Text("\(vm.game.validWords.count - vm.foundWords.count)")
                                .font(.title.bold())
                                .foregroundStyle(.orange)
                            Text("Missed")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
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
                            FlowLayout(spacing: 6) {
                                ForEach(vm.missedWords.prefix(30), id: \.self) { word in
                                    Text(word)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
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

                    Button {
                        vm.stop()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.modeGradient(.wordHunt))
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
}

// MARK: - Grid cell

private struct GridCell: View {
    let letter: Character
    let isActive: Bool
    let pathIndex: Int?
    let cellSize: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? AppTheme.modeGradient(.wordHunt) : LinearGradient(colors: [AppTheme.cardBackground], startPoint: .leading, endPoint: .trailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? AppTheme.modeAccent(.wordHunt) : AppTheme.cardBorder, lineWidth: isActive ? 2 : 1)
                )
                .shadow(color: isActive ? AppTheme.modeAccent(.wordHunt).opacity(0.5) : .clear, radius: 6)

            VStack(spacing: 1) {
                Text(String(letter))
                    .font(.system(size: cellSize * 0.38, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let idx = pathIndex {
                    Text("\(idx + 1)")
                        .font(.system(size: cellSize * 0.18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.7))
                }
            }
        }
        // Frame is the full cellSize so drag coordinates align exactly.
        // Visual gap comes from padding, not a reduced frame.
        .frame(width: cellSize, height: cellSize)
        .padding(3)
        .animation(.spring(response: 0.2), value: isActive)
    }
}

// MARK: - Flow layout for missed words

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? UIScreen.main.bounds.width
        var y: CGFloat = 0, rowH: CGFloat = 0, x: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var y = bounds.minY, rowH: CGFloat = 0, x = bounds.minX
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }
    }
}
