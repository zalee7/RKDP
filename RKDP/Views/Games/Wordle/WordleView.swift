import SwiftUI

struct WordleView: View {
    @StateObject private var vm: WordleViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.boardCosmetics) var cosmetics
    private let userID: String?
    private let sessionID: String?
    private let onMatchResult: (MatchPlayerResult) -> Void
    private let onSoloResult: (SoloGameResult) -> Void
    private let onPlayAgain: () -> Void
    private let onChangeDifficulty: () -> Void
    private let onTryRanked: () -> Void
    private let onHome: () -> Void
    @State private var didReportMatchResult = false
    @State private var didReportSoloResult = false

    init(
        difficulty: Difficulty,
        user: AppUser? = nil,
        sessionID: String? = nil,
        seed: Int? = nil,
        onMatchResult: @escaping (MatchPlayerResult) -> Void = { _ in },
        onSoloResult: @escaping (SoloGameResult) -> Void = { _ in },
        onPlayAgain: @escaping () -> Void = {},
        onChangeDifficulty: @escaping () -> Void = {},
        onTryRanked: @escaping () -> Void = {},
        onHome: @escaping () -> Void = {}
    ) {
        let rounds = sessionID == nil ? 1 : 3
        self.userID = user?.id
        self.sessionID = sessionID
        self.onMatchResult = onMatchResult
        self.onSoloResult = onSoloResult
        self.onPlayAgain = onPlayAgain
        self.onChangeDifficulty = onChangeDifficulty
        self.onTryRanked = onTryRanked
        self.onHome = onHome
        _vm = StateObject(wrappedValue: WordleViewModel(
            difficulty: difficulty,
            seed: seed,
            totalRounds: rounds
        ))
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                messageBanner
                    .frame(height: 32)

                if vm.totalRounds > 1 {
                    roundDots
                        .padding(.bottom, 8)
                }

                wordGrid
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)

                Spacer(minLength: 0)

                keyboard
                    .padding(.horizontal, 8)
                    .padding(.bottom, 24)
            }

            if vm.isMatchOver && sessionID == nil { finishedOverlay }
        }
        .navigationBarBackButtonHidden()
        .onDisappear { vm.stop() }
        .onChange(of: vm.isMatchOver) { _, finished in
            if finished {
                if sessionID == nil { reportSoloResult() }
                reportMatchResult()
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
            Text("Wordle")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text("\(vm.maxGuesses) guesses")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Message

    @ViewBuilder
    private var messageBanner: some View {
        if let msg = vm.message {
            Text(msg)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(AppTheme.cardBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 1))
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.2), value: vm.message)
        }
    }

    // MARK: - Round dots

    private var roundDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<vm.totalRounds, id: \.self) { i in
                if i < vm.roundResults.count {
                    let r = vm.roundResults[i]
                    Circle()
                        .fill(r.solved ? Color(hex: "538D4E") : Color(hex: "3A3A3C"))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                } else if i == vm.currentRound {
                    Circle()
                        .fill(AppTheme.accentBright)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                }
            }
        }
    }

    // MARK: - Word grid

    private var wordGrid: some View {
        let fs = cosmetics.fontStyle
        return VStack(spacing: 6) {
            ForEach(0..<vm.maxGuesses, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { col in
                        WordleTileView(
                            letter: letter(row: row, col: col),
                            state: tileState(row: row, col: col),
                            revealed: vm.revealingRow == nil || row < vm.revealingRow ?? 0,
                            revealDelay: Double(col) * 0.12,
                            fontStyle: fs
                        )
                    }
                }
                .modifier(ShakeModifier(active: vm.shakeRow && row == vm.guesses.count))
            }
        }
    }

    private func letter(row: Int, col: Int) -> Character? {
        if row < vm.guesses.count {
            let word = vm.guesses[row].word
            return word.count > col ? word[word.index(word.startIndex, offsetBy: col)] : nil
        }
        if row == vm.guesses.count {
            return vm.currentInput.count > col
                ? vm.currentInput[vm.currentInput.index(vm.currentInput.startIndex, offsetBy: col)]
                : nil
        }
        return nil
    }

    private func tileState(row: Int, col: Int) -> WordleTileState {
        if row < vm.guesses.count {
            return .submitted(vm.guesses[row].result[col])
        }
        if row == vm.guesses.count {
            return vm.currentInput.count > col ? .active : .empty
        }
        return .empty
    }

    // MARK: - Keyboard

    private let keyRows: [[String]] = [
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L"],
        ["ENTER","Z","X","C","V","B","N","M","⌫"]
    ]

    private var keyboard: some View {
        VStack(spacing: 8) {
            ForEach(keyRows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { key in
                        KeyButton(
                            key: key,
                            state: keyState(for: key),
                            action: { handleKey(key) }
                        )
                    }
                }
            }
        }
    }

    private func keyState(for key: String) -> WordleKeyState {
        guard key.count == 1, let c = key.first else { return .unused }
        return vm.letterStates[c] ?? .unused
    }

    private func handleKey(_ key: String) {
        switch key {
        case "ENTER":
            SoundManager.shared.wordleTileClick()
            vm.submitGuess()
        case "⌫":
            SoundManager.shared.wordleTileClick()
            vm.deleteLetter()
        default:
            if let c = key.first {
                SoundManager.shared.wordleTileClick()
                vm.addLetter(c)
            }
        }
    }

    // MARK: - Finished overlay

    private var finishedOverlay: some View {
        Group {
            if let result = makeSoloResult() {
                SoloResultOverlay(result: result, onPlayAgain: onPlayAgain, onChangeDifficulty: onChangeDifficulty, onTryRanked: onTryRanked, onHome: onHome)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: vm.isMatchOver)
    }

    private func makeSoloResult() -> SoloGameResult? {
        guard let round = vm.roundResults.first else { return nil }
        return SoloGameResult(
            mode: .wordle,
            difficulty: vm.difficulty,
            completed: round.solved,
            title: round.solved ? "Word Solved" : "Word Missed",
            message: "The word was \(round.targetWord).",
            elapsedSeconds: vm.elapsedSeconds,
            score: round.solved ? 1 : 0,
            progress: round.solved ? 1 : 0,
            guesses: round.guessCount,
            stats: [
                SoloResultStat(label: "Guesses", value: "\(round.guessCount)/\(vm.maxGuesses)"),
                SoloResultStat(label: "Time", value: formattedTime(vm.elapsedSeconds)),
                SoloResultStat(label: "Word", value: round.targetWord),
                SoloResultStat(label: "Result", value: round.solved ? "Solved" : "Failed")
            ]
        )
    }

    private func reportSoloResult() {
        guard !didReportSoloResult, let result = makeSoloResult() else { return }
        didReportSoloResult = true
        onSoloResult(result)
    }

    private func reportMatchResult() {
        guard !didReportMatchResult, sessionID != nil, let userID else { return }
        didReportMatchResult = true
        let solved = vm.roundResults.filter(\.solved)
        let totalGuesses = solved.reduce(0) { $0 + $1.guessCount }
        onMatchResult(MatchPlayerResult(
            userID: userID,
            mode: .wordle,
            completed: solved.count >= 2,
            elapsedSeconds: vm.elapsedSeconds,
            score: solved.count,
            progress: Double(solved.count) / Double(max(1, vm.totalRounds)),
            status: "\(solved.count)/\(vm.totalRounds) solved",
            summary: [
                "solvedRounds": "\(solved.count)",
                "totalGuesses": "\(totalGuesses)",
                "failedRounds": "\(vm.roundResults.filter { !$0.solved }.count)"
            ],
            details: vm.roundResults.enumerated().map { idx, result in
                if result.solved {
                    return "Round \(idx + 1): \(result.targetWord) in \(result.guessCount)"
                }
                return "Round \(idx + 1): \(result.targetWord) failed"
            }
        ))
    }

    @ViewBuilder
    private func statBox(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(AppTheme.textSecondary)
        }
    }
}

// MARK: - Tile

enum WordleTileState {
    case empty
    case active
    case submitted(WordleLetterResult)
}

struct WordleTileView: View {
    let letter: Character?
    let state: WordleTileState
    let revealed: Bool
    var revealDelay: Double = 0
    var fontStyle: NumberFontStyle = NumberFontStyle(design: .default, weight: .regular)

    @State private var flipDegrees: Double = 0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                tileBackground(size: size)
                if let c = letter {
                    Text(String(c))
                        .font(.system(size: size * 0.52, weight: .bold, design: fontStyle.design))
                        .foregroundStyle(textColor)
                }
            }
            .rotation3DEffect(.degrees(flipDegrees), axis: (1, 0, 0))
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: revealed) { _, newVal in
            if newVal { triggerFlip() }
        }
    }

    @ViewBuilder
    private func tileBackground(size: CGFloat) -> some View {
        switch state {
        case .empty:
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
        case .active:
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
        case .submitted(let result):
            RoundedRectangle(cornerRadius: 6)
                .fill(submittedColor(result))
        }
    }

    private var textColor: Color {
        switch state {
        case .empty, .active:     return AppTheme.textPrimary
        case .submitted:          return .white
        }
    }

    private func submittedColor(_ r: WordleLetterResult) -> Color {
        switch r {
        case .correct: return Color(hex: "538D4E")
        case .present: return Color(hex: "B59F3B")
        case .absent:  return Color(hex: "3A3A3C")
        }
    }

    private func triggerFlip() {
        DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
            withAnimation(.easeInOut(duration: 0.3)) { flipDegrees = 90 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) { flipDegrees = 0 }
            }
        }
    }
}

// MARK: - Keyboard key

private struct KeyButton: View {
    let key: String
    let state: WordleKeyState
    let action: () -> Void

    private var isWide: Bool { key == "ENTER" || key == "⌫" }

    var body: some View {
        Button(action: action) {
            Text(key)
                .font(.system(size: key == "ENTER" ? 11 : 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(state.color)
                .foregroundStyle(key == "ENTER" || key == "⌫" ? AppTheme.textPrimary : letterTextColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(width: isWide ? 60 : nil)
        .buttonStyle(.plain)
    }

    private var letterTextColor: Color {
        switch state {
        case .unused:  return AppTheme.textPrimary
        default:       return .white
        }
    }
}

// MARK: - Shake modifier

private struct ShakeModifier: ViewModifier {
    let active: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: active) { _, isActive in
                guard isActive else { return }
                let sequence: [CGFloat] = [-8, 8, -6, 6, -4, 4, 0]
                for (i, x) in sequence.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                        withAnimation(.easeInOut(duration: 0.06)) { offset = x }
                    }
                }
            }
    }
}
