import Foundation
import Combine

enum SolitaireSuit: String, Codable, CaseIterable, Hashable {
    case hearts
    case diamonds
    case clubs
    case spades

    var symbol: String {
        switch self {
        case .hearts: return "suit.heart.fill"
        case .diamonds: return "suit.diamond.fill"
        case .clubs: return "suit.club.fill"
        case .spades: return "suit.spade.fill"
        }
    }

    var shortName: String {
        switch self {
        case .hearts: return "H"
        case .diamonds: return "D"
        case .clubs: return "C"
        case .spades: return "S"
        }
    }

    var isRed: Bool { self == .hearts || self == .diamonds }
}

enum SolitaireRank: Int, Codable, CaseIterable, Comparable {
    case ace = 1
    case two
    case three
    case four
    case five
    case six
    case seven
    case eight
    case nine
    case ten
    case jack
    case queen
    case king

    static func < (lhs: SolitaireRank, rhs: SolitaireRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .ace: return "A"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        default: return "\(rawValue)"
        }
    }
}

struct SolitaireCard: Identifiable, Codable, Equatable, Hashable {
    let suit: SolitaireSuit
    let rank: SolitaireRank
    var isFaceUp: Bool

    var id: String { "\(suit.rawValue)-\(rank.rawValue)" }
    var isRed: Bool { suit.isRed }
    var shortLabel: String { "\(rank.label)\(suit.shortName)" }
}

enum SolitaireSelection: Equatable {
    case waste
    case tableau(column: Int, index: Int)
}

struct SolitaireRules: Equatable {
    let drawCount: Int
    let maxRedeals: Int?

    var drawLabel: String { "Draw \(drawCount)" }

    var redealLabel: String {
        guard let maxRedeals else { return "Unlimited redeals" }
        return "\(maxRedeals) redeal\(maxRedeals == 1 ? "" : "s")"
    }

    static func rules(for difficulty: Difficulty) -> SolitaireRules {
        switch difficulty {
        case .easy:
            return SolitaireRules(drawCount: 1, maxRedeals: nil)
        case .medium:
            return SolitaireRules(drawCount: 3, maxRedeals: nil)
        case .hard:
            return SolitaireRules(drawCount: 3, maxRedeals: 3)
        case .expert:
            return SolitaireRules(drawCount: 3, maxRedeals: 1)
        }
    }
}

@MainActor
final class GridlockViewModel: ObservableObject {
    @Published var stock: [SolitaireCard]
    @Published var waste: [SolitaireCard]
    @Published var foundations: [SolitaireSuit: [SolitaireCard]]
    @Published var tableau: [[SolitaireCard]]
    @Published var elapsedSeconds: Int = 0
    @Published var moveCount: Int = 0
    @Published var isComplete = false
    @Published var selected: SolitaireSelection?
    @Published var message: String?
    @Published var redealsUsed: Int = 0

    let difficulty: Difficulty
    let rules: SolitaireRules
    private var timer: AnyCancellable?
    private(set) var rewardMoves: [[Int]] = []

    var foundationCount: Int { foundations.values.reduce(0) { $0 + $1.count } }
    var progress: Double { Double(foundationCount) / 52.0 }
    var faceUpTableauCount: Int { tableau.flatMap { $0 }.filter(\.isFaceUp).count }
    var stockCount: Int { stock.count }
    var wasteCount: Int { waste.count }
    var score: Int { max(0, foundationCount * 10 + faceUpTableauCount * 2 - moveCount) }
    var canRedeal: Bool { rules.maxRedeals.map { redealsUsed < $0 } ?? true }
    var redealsRemainingText: String {
        guard let maxRedeals = rules.maxRedeals else { return "Unlimited" }
        return "\(max(0, maxRedeals - redealsUsed))"
    }

    init(difficulty: Difficulty, seed: Int? = nil) {
        self.difficulty = difficulty
        self.rules = SolitaireRules.rules(for: difficulty)
        let deal = Self.makeDeal(seed: seed ?? Int.random(in: 0..<Int.max))
        self.stock = deal.stock
        self.waste = []
        self.foundations = Dictionary(uniqueKeysWithValues: SolitaireSuit.allCases.map { ($0, []) })
        self.tableau = deal.tableau
        startTimer()
    }

    func drawFromStock() {
        guard !isComplete else { return }
        selected = nil
        if stock.isEmpty {
            redealWaste()
            return
        }

        let drawTotal = min(rules.drawCount, stock.count)
        rewardMoves.append([0])
        for _ in 0..<drawTotal {
            guard var card = stock.popLast() else { break }
            card.isFaceUp = true
            waste.append(card)
        }
        registerMove()
    }

    func tapWaste() {
        guard !isComplete, !waste.isEmpty else { return }
        selected = selected == .waste ? nil : .waste
    }

    func tapFoundation(_ suit: SolitaireSuit) {
        guard !isComplete else { return }
        guard let selected else {
            message = "Select a card first."
            return
        }
        if moveSelectedToFoundation(suit) {
            registerMove()
            clearAfterMove()
        } else {
            message = "That card can't go there yet."
        }
    }

    func tapTableau(column: Int, index: Int?) {
        guard !isComplete, tableau.indices.contains(column) else { return }

        if let selected {
            if moveSelectedToTableau(column) {
                registerMove()
                clearAfterMove()
                return
            }
            if case let .tableau(sourceColumn, sourceIndex) = selected,
               sourceColumn == column,
               sourceIndex == index {
                self.selected = nil
                return
            }
            message = "That move is blocked."
            return
        }

        guard let index else {
            message = "Only a King can start an empty lane."
            return
        }
        guard tableau[column].indices.contains(index) else { return }
        if tableau[column][index].isFaceUp {
            selected = .tableau(column: column, index: index)
        } else if index == tableau[column].count - 1 {
            tableau[column][index].isFaceUp = true
            registerMove()
            selected = nil
        }
    }

    func autoMoveToFoundations() {
        guard !isComplete else { return }
        var didMove = false
        var movedThisPass = true

        while movedThisPass {
            movedThisPass = false
            if let wasteCard = waste.last, canPlaceOnFoundation(wasteCard, suit: wasteCard.suit) {
                rewardMoves.append([1, -1, waste.count - 1, -1])
                _ = waste.popLast()
                foundations[wasteCard.suit, default: []].append(wasteCard)
                movedThisPass = true
                didMove = true
            }

            for column in tableau.indices {
                guard let card = tableau[column].last, card.isFaceUp else { continue }
                if canPlaceOnFoundation(card, suit: card.suit) {
                    rewardMoves.append([1, column, tableau[column].count - 1, -1])
                    _ = tableau[column].popLast()
                    foundations[card.suit, default: []].append(card)
                    flipTopCardIfNeeded(column: column)
                    movedThisPass = true
                    didMove = true
                }
            }
        }

        if didMove {
            registerMove()
            clearAfterMove()
        } else {
            message = "No foundation moves available."
        }
    }

    func stop() { timer?.cancel() }

    private static func makeDeal(seed: Int) -> (stock: [SolitaireCard], tableau: [[SolitaireCard]]) {
        var rng = SeededRNG(seed: seed)
        let deck = rng.shuffled(SolitaireSuit.allCases.flatMap { suit in
            SolitaireRank.allCases.map { rank in
                SolitaireCard(suit: suit, rank: rank, isFaceUp: false)
            }
        })

        var cursor = 0
        var columns: [[SolitaireCard]] = []
        for column in 0..<7 {
            var cards: [SolitaireCard] = []
            for row in 0...column {
                var card = deck[cursor]
                card.isFaceUp = row == column
                cards.append(card)
                cursor += 1
            }
            columns.append(cards)
        }

        return (Array(deck[cursor...]), columns)
    }

    private func redealWaste() {
        guard !waste.isEmpty else {
            message = "No cards left to draw."
            return
        }
        guard canRedeal else {
            message = "No redeals left."
            return
        }
        stock = waste.reversed().map {
            var card = $0
            card.isFaceUp = false
            return card
        }
        rewardMoves.append([0])
        waste.removeAll()
        redealsUsed += 1
        registerMove()
    }

    private func moveSelectedToFoundation(_ suit: SolitaireSuit) -> Bool {
        switch selected {
        case .waste:
            guard let card = waste.last, canPlaceOnFoundation(card, suit: suit) else { return false }
            rewardMoves.append([1, -1, waste.count - 1, -1])
            _ = waste.popLast()
            foundations[suit, default: []].append(card)
            return true
        case let .tableau(column, index):
            guard tableau.indices.contains(column),
                  tableau[column].indices.contains(index),
                  index == tableau[column].count - 1 else { return false }
            let card = tableau[column][index]
            guard canPlaceOnFoundation(card, suit: suit) else { return false }
            rewardMoves.append([1, column, index, -1])
            _ = tableau[column].popLast()
            foundations[suit, default: []].append(card)
            flipTopCardIfNeeded(column: column)
            return true
        case .none:
            return false
        }
    }

    private func moveSelectedToTableau(_ destinationColumn: Int) -> Bool {
        guard tableau.indices.contains(destinationColumn) else { return false }
        switch selected {
        case .waste:
            guard let card = waste.last, canPlaceOnTableau(card, column: destinationColumn) else { return false }
            rewardMoves.append([1, -1, waste.count - 1, destinationColumn])
            _ = waste.popLast()
            tableau[destinationColumn].append(card)
            return true
        case let .tableau(sourceColumn, index):
            guard tableau.indices.contains(sourceColumn),
                  sourceColumn != destinationColumn,
                  tableau[sourceColumn].indices.contains(index) else { return false }
            let movingCards = Array(tableau[sourceColumn][index...])
            guard movingCards.allSatisfy(\.isFaceUp),
                  let first = movingCards.first,
                  canPlaceOnTableau(first, column: destinationColumn) else { return false }
            rewardMoves.append([1, sourceColumn, index, destinationColumn])
            tableau[sourceColumn].removeSubrange(index...)
            tableau[destinationColumn].append(contentsOf: movingCards)
            flipTopCardIfNeeded(column: sourceColumn)
            return true
        case .none:
            return false
        }
    }

    private func canPlaceOnFoundation(_ card: SolitaireCard, suit: SolitaireSuit) -> Bool {
        guard card.suit == suit else { return false }
        let stack = foundations[suit] ?? []
        if stack.isEmpty { return card.rank == .ace }
        guard let top = stack.last else { return false }
        return card.rank.rawValue == top.rank.rawValue + 1
    }

    private func canPlaceOnTableau(_ card: SolitaireCard, column: Int) -> Bool {
        guard tableau.indices.contains(column) else { return false }
        guard let target = tableau[column].last else { return card.rank == .king }
        return target.isFaceUp
            && target.isRed != card.isRed
            && target.rank.rawValue == card.rank.rawValue + 1
    }

    private func flipTopCardIfNeeded(column: Int) {
        guard tableau.indices.contains(column),
              let lastIndex = tableau[column].indices.last,
              !tableau[column][lastIndex].isFaceUp else { return }
        tableau[column][lastIndex].isFaceUp = true
    }

    private func registerMove() {
        moveCount += 1
        SoundManager.shared.keyboardPress()
        if foundationCount == 52 {
            isComplete = true
            selected = nil
            message = nil
            timer?.cancel()
            SoundManager.shared.gameOver()
        }
    }

    private func clearAfterMove() {
        selected = nil
        message = nil
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }
}
