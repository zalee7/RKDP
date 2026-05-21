import SwiftUI

struct HangmanView: View {
    @StateObject private var vm: HangmanViewModel
    @Environment(\.dismiss) var dismiss
    private let userID: String?
    private let sessionID: String?
    private let onMatchResult: (MatchPlayerResult) -> Void
    private let onSoloResult: (SoloGameResult) -> Void
    private let onPlayAgain: () -> Void
    private let onChangeDifficulty: () -> Void
    private let onTryRanked: () -> Void
    private let onHome: () -> Void
    @State private var didReportFinalMatchResult = false
    @State private var didReportSoloResult = false

    init(
        difficulty: Difficulty,
        user: AppUser? = nil,
        sessionID: String? = nil,
        seed: Int? = nil,
        puzzleData: String? = nil,
        onMatchResult: @escaping (MatchPlayerResult) -> Void = { _ in },
        onSoloResult: @escaping (SoloGameResult) -> Void = { _ in },
        onPlayAgain: @escaping () -> Void = {},
        onChangeDifficulty: @escaping () -> Void = {},
        onTryRanked: @escaping () -> Void = {},
        onHome: @escaping () -> Void = {}
    ) {
        self.userID = user?.id
        self.sessionID = sessionID
        self.onMatchResult = onMatchResult
        self.onSoloResult = onSoloResult
        self.onPlayAgain = onPlayAgain
        self.onChangeDifficulty = onChangeDifficulty
        self.onTryRanked = onTryRanked
        self.onHome = onHome
        _vm = StateObject(wrappedValue: HangmanViewModel(
            difficulty: difficulty,
            userID: user?.id,
            priorBest: user?.rank(for: .hangman).bestTime,
            seed: seed,
            puzzleData: MultiplayerPuzzleDataFactory.decodeHangman(puzzleData),
            timed: sessionID != nil
        ))
    }

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()
            VStack(spacing: 12) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 12)

                messageBanner
                    .frame(height: 30)

                categoryCard
                    .padding(.horizontal)

                lavaCard
                    .padding(.horizontal)

                wordSlots
                    .padding(.horizontal)

                wrongLetters
                    .padding(.horizontal)

                Spacer(minLength: 0)

                keyboard
                    .padding(.horizontal, 10)
                    .padding(.bottom, 18)
            }

            if vm.isFinished && sessionID == nil {
                SoloResultOverlay(result: soloResult, onPlayAgain: onPlayAgain, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            }
        }
        .navigationBarBackButtonHidden(sessionID != nil)
        .onDisappear { vm.stop() }
        .onChange(of: vm.isFinished) { _, finished in
            guard finished else { return }
            if sessionID == nil { reportSoloResult() }
            reportMatchResult(final: true)
        }
    }

    private var topBar: some View {
        HStack {
            if sessionID == nil {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                }
            } else {
                Color.clear.frame(width: 28, height: 28)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Lava Rescue")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(GameMode.hangman.difficultyLabel(vm.difficulty))
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.modeAccent(.hangman))
            }
            Spacer()
            if let remaining = vm.timeRemaining {
                Text(timeString(remaining))
                    .font(.caption.bold())
                    .foregroundStyle(remaining <= 15 ? AppTheme.danger : AppTheme.textSecondary)
                    .frame(width: 48, alignment: .trailing)
            } else {
                Image(systemName: "infinity")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var messageBanner: some View {
        if let message = vm.message {
            Text(message)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(AppTheme.cardBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 1))
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var categoryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.fill")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.crownGold)
                .frame(width: 28, height: 28)
                .background(AppTheme.crownGold.opacity(0.18))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Category")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Text(vm.game.category)
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Starter")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                Text(String(vm.game.starterLetter))
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.crownGold)
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var lavaCard: some View {
        VStack(spacing: 12) {
            LavaRescueScene(misses: vm.game.wrongGuessCount, maxMisses: vm.game.maxWrongGuesses, isSolved: vm.game.isSolved)
                .frame(height: 178)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1.2))
                .shadow(color: AppTheme.danger.opacity(0.22), radius: 18)

            VStack(spacing: 8) {
                HStack {
                    Text("Lava Meter")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text("\(vm.game.wrongGuessCount)/\(vm.game.maxWrongGuesses) wrong")
                        .font(.caption.bold())
                        .foregroundStyle(vm.game.wrongGuessCount >= vm.game.maxWrongGuesses ? AppTheme.danger : AppTheme.textPrimary)
                }
                ProgressView(value: Double(vm.game.wrongGuessCount), total: Double(vm.game.maxWrongGuesses))
                    .tint(AppTheme.danger)
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var wordSlots: some View {
        HangmanWrapLayout(spacing: 8) {
            ForEach(Array(vm.game.targetWord.enumerated()), id: \.offset) { _, letter in
                Text(vm.game.correctLetters.contains(letter) ? String(letter) : "")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 36, height: 46)
                    .background(Color.black.opacity(0.24))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(slotBorderColor(letter), lineWidth: 1.4))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(vm.game.correctLetters.contains(letter) ? AppTheme.crownGold : Color.white.opacity(0.22))
                            .frame(height: 3)
                            .padding(.horizontal, 7)
                            .padding(.bottom, 5)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func slotBorderColor(_ letter: Character) -> Color {
        vm.game.correctLetters.contains(letter) ? AppTheme.crownGold.opacity(0.58) : AppTheme.modeAccent(.hangman).opacity(0.35)
    }

    private var wrongLetters: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Wrong Letters")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
            Text(sortedLetters(vm.game.wrongLetters).joined(separator: " ").ifEmpty("None"))
                .font(.subheadline.bold())
                .foregroundStyle(vm.game.wrongLetters.isEmpty ? AppTheme.textSecondary : AppTheme.danger)
            Spacer()
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private var keyboard: some View {
        VStack(spacing: 8) {
            ForEach(vm.alphabetRows.indices, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(vm.alphabetRows[row], id: \.self) { letter in
                        Button {
                            let accepted = vm.guess(letter)
                            if accepted { reportMatchResult(final: vm.isFinished) }
                        } label: {
                            Text(String(letter))
                                .font(.subheadline.bold())
                                .foregroundStyle(keyTextColor(letter))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(keyColor(letter))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
                        }
                        .disabled(vm.game.guessedLetters.contains(letter) || vm.isFinished)
                    }
                }
            }
        }
    }

    private func keyColor(_ letter: Character) -> Color {
        if vm.game.correctLetters.contains(letter) { return AppTheme.success.opacity(0.8) }
        if vm.game.wrongLetters.contains(letter) { return AppTheme.danger.opacity(0.8) }
        return Color.white.opacity(0.16)
    }

    private func keyTextColor(_ letter: Character) -> Color {
        vm.game.guessedLetters.contains(letter) ? .white : AppTheme.textPrimary
    }

    private var soloResult: SoloGameResult {
        SoloGameResult(
            mode: .hangman,
            difficulty: vm.difficulty,
            completed: vm.game.isSolved,
            title: vm.game.isSolved ? "Puzzle Rescued" : "Lava Reached The Puzzle",
            message: vm.game.isSolved ? "Solved \(vm.game.targetWord) with \(vm.game.wrongGuessCount) wrong letters." : "The word was \(vm.game.targetWord).",
            elapsedSeconds: vm.elapsedSeconds,
            score: vm.game.revealedUniqueCount,
            progress: vm.game.progress,
            stats: [
                SoloResultStat(label: "Category", value: vm.game.category),
                SoloResultStat(label: "Word", value: vm.game.targetWord.capitalized),
                SoloResultStat(label: "Wrong", value: "\(vm.game.wrongGuessCount)/\(vm.game.maxWrongGuesses)"),
                SoloResultStat(label: "Pattern", value: displayPattern(vm.game.revealedPattern)),
                SoloResultStat(label: "Mode", value: "Untimed")
            ]
        )
    }

    private func reportSoloResult() {
        guard !didReportSoloResult else { return }
        didReportSoloResult = true
        onSoloResult(soloResult)
    }

    private func reportMatchResult(final: Bool) {
        guard sessionID != nil, let userID else { return }
        if final {
            guard !didReportFinalMatchResult else { return }
            didReportFinalMatchResult = true
            vm.stop()
        }
        onMatchResult(MatchPlayerResult(
            userID: userID,
            mode: .hangman,
            completed: vm.game.isSolved,
            elapsedSeconds: vm.elapsedSeconds,
            score: vm.game.revealedUniqueCount,
            progress: vm.game.progress,
            status: final ? finalStatus : "In progress",
            summary: [
                "targetWord": vm.game.targetWord,
                "category": vm.game.category,
                "starterLetter": String(vm.game.starterLetter),
                "correctLetters": sortedLetters(vm.game.correctLetters).joined(),
                "wrongLetters": sortedLetters(vm.game.wrongLetters).joined(),
                "wrongGuessCount": "\(vm.game.wrongGuessCount)",
                "revealedPattern": vm.game.revealedPattern,
                "revealedLetterCount": "\(vm.game.revealedUniqueCount)",
                "maxWrongGuesses": "\(vm.game.maxWrongGuesses)",
                "lavaLevel": "\(vm.game.wrongGuessCount)",
                "solved": vm.game.isSolved ? "true" : "false",
                "final": final ? "true" : "false"
            ],
            details: [
                "Category: \(vm.game.category)",
                "Word: \(vm.game.targetWord)",
                "Pattern: \(displayPattern(vm.game.revealedPattern))",
                "Starter: \(vm.game.starterLetter)",
                "Correct: \(sortedLetters(vm.game.correctLetters).joined(separator: ", ").ifEmpty("None"))",
                "Wrong: \(sortedLetters(vm.game.wrongLetters).joined(separator: ", ").ifEmpty("None"))"
            ]
        ))
    }

    private var finalStatus: String {
        if vm.game.isSolved { return "Puzzle rescued" }
        if vm.game.isLost { return "Lava reached the puzzle" }
        return "Time expired"
    }

    private func displayPattern(_ pattern: String) -> String {
        pattern.map { $0 == "_" ? "_" : String($0) }.joined(separator: " ")
    }

    private func sortedLetters(_ letters: Set<Character>) -> [String] {
        letters.map(String.init).sorted()
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct HangmanWrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct LavaRescueScene: View {
    let misses: Int
    let maxMisses: Int
    let isSolved: Bool

    private var lavaProgress: Double {
        Double(misses) / Double(max(1, maxMisses))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [Color.black.opacity(0.65), Color(red: 0.16, green: 0.08, blue: 0.22)], startPoint: .top, endPoint: .bottom)

                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: geo.size.width * 0.86, height: 1)
                        .offset(y: -CGFloat(index) * geo.size.height / 7)
                }

                LavaWave()
                    .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.26, blue: 0.16), Color(red: 1.0, green: 0.64, blue: 0.12)], startPoint: .bottom, endPoint: .top))
                    .frame(height: max(18, geo.size.height * CGFloat(lavaProgress)))
                    .shadow(color: AppTheme.danger.opacity(0.45), radius: 18)

                PuzzleRescueMascot(misses: misses, maxMisses: maxMisses, isSolved: isSolved)
                    .frame(width: 112, height: 112)
                    .offset(y: -geo.size.height * CGFloat(lavaProgress) * 0.16)

                VStack {
                    Spacer()
                    Text(sceneText)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 6)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    private var sceneText: String {
        if isSolved { return "Puzzle rescued" }
        if misses >= maxMisses { return "Lava reached the puzzle" }
        return "Keep the puzzle above lava"
    }
}

private struct LavaWave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.18))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.10), control: CGPoint(x: rect.width * 0.25, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18), control: CGPoint(x: rect.width * 0.75, y: rect.minY + rect.height * 0.30))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PuzzleRescueMascot: View {
    let misses: Int
    let maxMisses: Int
    let isSolved: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSolved ? AppTheme.success.opacity(0.55) : AppTheme.crownGold.opacity(0.4), lineWidth: 6)
                .scaleEffect(isSolved ? 1.12 : 1 + CGFloat(misses) * 0.025)
                .opacity(max(0.2, 1 - Double(misses) * 0.1))

            PuzzlePieceShape()
                .fill(LinearGradient(colors: [AppTheme.hotPink, AppTheme.teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(PuzzlePieceShape().stroke(Color.white, lineWidth: 4))
                .shadow(color: AppTheme.hotPink.opacity(0.35), radius: 12)
                .opacity(max(0.35, 1 - Double(misses) / Double(max(1, maxMisses)) * 0.45))
                .overlay(face)

            if misses > 0, !isSolved {
                ForEach(0..<min(misses, maxMisses), id: \.self) { index in
                    CrackMark(index: index)
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                }
            }
        }
    }

    private var face: some View {
        VStack(spacing: 8) {
            HStack(spacing: 24) {
                Circle().fill(Color.white).frame(width: 9, height: 9)
                Circle().fill(Color.white).frame(width: 9, height: 9)
            }
            if isSolved {
                SmileShape()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 34, height: 16)
            } else {
                Capsule()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 32, height: misses >= maxMisses ? 6 : 14)
            }
        }
    }
}

private struct PuzzlePieceShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.18, y: h * 0.10))
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.10))
        path.addQuadCurve(to: CGPoint(x: w * 0.58, y: h * 0.10), control: CGPoint(x: w * 0.50, y: h * -0.08))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.10))
        path.addQuadCurve(to: CGPoint(x: w * 0.90, y: h * 0.18), control: CGPoint(x: w * 0.90, y: h * 0.10))
        path.addLine(to: CGPoint(x: w * 0.90, y: h * 0.42))
        path.addQuadCurve(to: CGPoint(x: w * 0.90, y: h * 0.58), control: CGPoint(x: w * 1.08, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.90, y: h * 0.82))
        path.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.90), control: CGPoint(x: w * 0.90, y: h * 0.90))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.90))
        path.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.90), control: CGPoint(x: w * 0.50, y: h * 1.08))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.90))
        path.addQuadCurve(to: CGPoint(x: w * 0.10, y: h * 0.82), control: CGPoint(x: w * 0.10, y: h * 0.90))
        path.addLine(to: CGPoint(x: w * 0.10, y: h * 0.58))
        path.addQuadCurve(to: CGPoint(x: w * 0.10, y: h * 0.42), control: CGPoint(x: w * -0.08, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.10, y: h * 0.18))
        path.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.10), control: CGPoint(x: w * 0.10, y: h * 0.10))
        return path
    }
}

private struct CrackMark: Shape {
    let index: Int
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let starts: [(CGFloat, CGFloat)] = [(0.35, 0.18), (0.62, 0.25), (0.28, 0.55), (0.70, 0.58), (0.48, 0.72), (0.52, 0.38)]
        let start = starts[index % starts.count]
        let x = rect.width * start.0
        let y = rect.height * start.1
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + 14, y: y + 12))
        path.addLine(to: CGPoint(x: x + 6, y: y + 24))
        return path
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2), control: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
