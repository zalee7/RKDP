import Foundation

struct AnagramPuzzle {
    let word: String          // answer
    let scrambled: [Character] // shuffled letters shown to player
    let hint: String          // short clue
    let difficulty: Difficulty

    // Shared seed so both players in a match get identical scrambles
    static func generate(difficulty: Difficulty, seed: Int? = nil) -> AnagramPuzzle {
        let pool = wordPool(for: difficulty)
        let idx: Int
        if let seed {
            idx = abs(seed) % pool.count
        } else {
            idx = Int.random(in: 0..<pool.count)
        }
        let entry = pool[idx]
        let scrambled = scramble(entry.word, seed: seed ?? Int.random(in: 0..<Int.max))
        return AnagramPuzzle(word: entry.word, scrambled: scrambled, hint: entry.hint, difficulty: difficulty)
    }

    private static func scramble(_ word: String, seed: Int) -> [Character] {
        var chars = Array(word)
        // Seeded Fisher-Yates
        var s = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        for i in stride(from: chars.count - 1, through: 1, by: -1) {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(s >> 33) % (i + 1)
            if i != j { chars.swapAt(i, j) }
        }
        // Make sure it's never identical to the original
        if String(chars) == word && chars.count > 1 { chars.swapAt(0, 1) }
        return chars
    }

    private struct Entry { let word: String; let hint: String }

    private static func wordPool(for difficulty: Difficulty) -> [Entry] {
        switch difficulty {
        case .easy:
            return [
                Entry(word: "ANGEL", hint: "Heavenly being"),
                Entry(word: "BRAVE", hint: "Courageous"),
                Entry(word: "CLAIM", hint: "To assert"),
                Entry(word: "DANCE", hint: "Move to music"),
                Entry(word: "EARTH", hint: "Our planet"),
                Entry(word: "FAULT", hint: "A mistake"),
                Entry(word: "GRACE", hint: "Elegance"),
                Entry(word: "HEART", hint: "Vital organ"),
                Entry(word: "IMAGE", hint: "A picture"),
                Entry(word: "JEWEL", hint: "A gem"),
                Entry(word: "KNIFE", hint: "Cutting tool"),
                Entry(word: "LEMON", hint: "Sour fruit"),
                Entry(word: "MAGIC", hint: "Illusion or spell"),
                Entry(word: "NERVE", hint: "Courage or body signal"),
                Entry(word: "OCEAN", hint: "Vast body of water"),
                Entry(word: "PANIC", hint: "Sudden fear"),
                Entry(word: "QUEEN", hint: "Royal female"),
                Entry(word: "RIVER", hint: "Flowing water"),
                Entry(word: "SMILE", hint: "Happy expression"),
                Entry(word: "TIGER", hint: "Striped big cat"),
            ]
        case .medium:
            return [
                Entry(word: "BRIDGE", hint: "Connects two sides"),
                Entry(word: "CANDLE", hint: "Wax light source"),
                Entry(word: "CASTLE", hint: "Royal fortress"),
                Entry(word: "DANGER", hint: "Risk or threat"),
                Entry(word: "ENGINE", hint: "Powers a machine"),
                Entry(word: "FINGER", hint: "Part of a hand"),
                Entry(word: "GARDEN", hint: "Where plants grow"),
                Entry(word: "HUNTER", hint: "Pursues prey"),
                Entry(word: "ISLAND", hint: "Land surrounded by water"),
                Entry(word: "JUNGLE", hint: "Dense tropical forest"),
                Entry(word: "LANCER", hint: "Knight with a spear"),
                Entry(word: "MIRROR", hint: "Reflection surface"),
                Entry(word: "NEEDLE", hint: "Used for sewing"),
                Entry(word: "ORANGE", hint: "Citrus fruit"),
                Entry(word: "PLANET", hint: "Orbits a star"),
                Entry(word: "ROCKET", hint: "Launches into space"),
                Entry(word: "SILVER", hint: "Precious metal"),
                Entry(word: "TIMBER", hint: "Wood for building"),
                Entry(word: "UNFAIR", hint: "Not just"),
                Entry(word: "WALRUS", hint: "Arctic sea mammal"),
            ]
        case .hard:
            return [
                Entry(word: "BALANCE", hint: "Equilibrium"),
                Entry(word: "CAPTAIN", hint: "Leader of a ship or team"),
                Entry(word: "DIAMOND", hint: "Precious gem"),
                Entry(word: "ELEMENT", hint: "Basic substance"),
                Entry(word: "FANTASY", hint: "Imaginative fiction"),
                Entry(word: "GARBAGE", hint: "Rubbish or waste"),
                Entry(word: "HISTORY", hint: "Study of the past"),
                Entry(word: "INSULTS", hint: "Offensive remarks"),
                Entry(word: "JUSTICE", hint: "Fairness under law"),
                Entry(word: "KITCHEN", hint: "Room for cooking"),
                Entry(word: "LANTERN", hint: "Portable light"),
                Entry(word: "MACHINE", hint: "Mechanical device"),
                Entry(word: "NETWORK", hint: "Interconnected system"),
                Entry(word: "OPINION", hint: "Personal viewpoint"),
                Entry(word: "PIONEER", hint: "First to explore"),
                Entry(word: "QUANTUM", hint: "Smallest discrete unit"),
                Entry(word: "RAMPANT", hint: "Widespread and uncontrolled"),
                Entry(word: "SHELTER", hint: "Protection from weather"),
                Entry(word: "THUNDER", hint: "Sound after lightning"),
                Entry(word: "WHISPER", hint: "Speak very softly"),
            ]
        case .expert:
            return [
                Entry(word: "ABSOLUTE", hint: "Complete and total"),
                Entry(word: "BACKBONE", hint: "Spine or core strength"),
                Entry(word: "CALCULUS", hint: "Branch of mathematics"),
                Entry(word: "DILEMMAS", hint: "Difficult choices"),
                Entry(word: "ELECTRON", hint: "Negatively charged particle"),
                Entry(word: "FEMININE", hint: "Relating to women"),
                Entry(word: "GRANDEUR", hint: "Splendour and magnificence"),
                Entry(word: "HAUNTING", hint: "Persistently memorable"),
                Entry(word: "ILLUSION", hint: "False perception"),
                Entry(word: "JUDGMENT", hint: "Decision or assessment"),
                Entry(word: "KINDNESS", hint: "Friendly and generous quality"),
                Entry(word: "LABYRINTH", hint: "Complex maze"),
                Entry(word: "MADRIGAL", hint: "Renaissance vocal composition"),
                Entry(word: "NARCOTIC", hint: "Numbing drug"),
                Entry(word: "OBSTACLE", hint: "Something in the way"),
                Entry(word: "PARALLEL", hint: "Side by side, never meeting"),
                Entry(word: "QUANTIFY", hint: "Measure precisely"),
                Entry(word: "ROMANTIC", hint: "Relating to love or adventure"),
                Entry(word: "SCULPTOR", hint: "Creates three-dimensional art"),
                Entry(word: "TWILIGHT", hint: "Dusk — between day and night"),
            ]
        }
    }
}
