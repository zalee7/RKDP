import Foundation

struct AnagramGame {
    let baseWord: String           // the source word whose letters are used
    let letters: [Character]       // shuffled letters given to the player
    let validWords: Set<String>    // all words formable from these letters (3+ letters)
    let difficulty: Difficulty
    let seed: Int

    // MARK: - Generation

    static func generate(difficulty: Difficulty, seed: Int? = nil) -> AnagramGame {
        let pool = wordPool(for: difficulty)
        let s = seed ?? Int.random(in: 0..<Int.max)
        let idx = abs(s) % pool.count
        let base = pool[idx]
        let shuffled = shuffleLetters(Array(base), seed: s)
        let words = findValidWords(in: Array(base))
        return AnagramGame(baseWord: base, letters: shuffled, validWords: words, difficulty: difficulty, seed: s)
    }

    // MARK: - Validation

    /// True if `word` can be spelled using only the available letters (respecting counts).
    func canForm(_ word: String) -> Bool {
        Self.canForm(word.uppercased(), from: Array(baseWord))
    }

    static func canForm(_ word: String, from letters: [Character]) -> Bool {
        var remaining = letters
        for ch in word.uppercased() {
            guard let idx = remaining.firstIndex(of: ch) else { return false }
            remaining.remove(at: idx)
        }
        return true
    }

    // MARK: - Scoring

    static func score(for word: String) -> Int {
        switch word.count {
        case 3:    return 1
        case 4:    return 2
        case 5:    return 3
        case 6:    return 4
        default:   return 5
        }
    }

    // MARK: - Timer per difficulty

    static func totalSeconds(for difficulty: Difficulty) -> Int {
        60
    }

    // MARK: - Internals

    private static func findValidWords(in letters: [Character]) -> Set<String> {
        var found = Set<String>()
        for word in WordDictionary.words where word.count >= 3 {
            if canForm(word, from: letters) { found.insert(word) }
        }
        return found
    }

    private static func shuffleLetters(_ chars: [Character], seed: Int) -> [Character] {
        var arr = chars
        var s = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        for i in stride(from: arr.count - 1, through: 1, by: -1) {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(s >> 33) % (i + 1)
            if i != j { arr.swapAt(i, j) }
        }
        return arr
    }

    // MARK: - Word pools (longer base words → more sub-words)

    private static func wordPool(for difficulty: Difficulty) -> [String] {
        switch difficulty {
        case .easy:      // 6-letter words
            return [
                "CASTLE", "PLANET", "SILVER", "GARDEN", "BRIDGE", "ORANGE", "FINGER", "CANDLE",
                "HUNTER", "ISLAND", "LANCER", "MIRROR", "ROCKET", "TIMBER", "NEEDLE", "DANGER",
                "GENTLE", "FLOWER", "SINGLE", "MOTHER", "STREAM", "MASTER", "WINTER", "LINGER",
                "SPRING", "SIMPLE", "TEMPLE", "CHANGE", "CHARGE", "CLEVER", "CORNER", "CRAFTS",
                "CUSTOM", "DANCER", "DESERT", "DONKEY", "DRAGON", "EMPIRE", "ENGINE", "FACTOR",
                "FAMINE", "FENDER", "FILTER", "FOREST", "FROZEN", "GENDER", "GOLDEN", "GRAVEL",
                "GROWER", "HAMLET", "HANDLE", "HANGAR", "HARBOR", "HARDEN", "HELPER", "HONEST",
                "HUMBLE", "HUNGER", "INSECT", "INTENT", "INVENT", "JINGLE", "JOGGER", "JUNGLE",
                "KERNEL", "LANKER", "LATHER", "LAUNCH", "LEADER", "LENDER", "LESSEN", "LETTER",
                "LINEAR", "LISTEN", "LOCKET", "LOOSEN", "MANGLE", "MANTLE", "MARTEN", "MARVEL",
                "MENTAL", "MENTOR", "MERLIN", "METEOR", "MINGLE", "MODERN", "MORTAL", "MORTAR",
                "NESTER", "NETTLE", "NIMBLE", "NOODLE", "NORMAL", "NOSTLE", "NOUGAT", "NOUNCE",
                "PARLOR", "PARROT", "PENCIL", "PEBBLE", "PEDDLE", "PELLET", "PENCIL", "PENNANT",
                "PERMIT", "PERSON", "PILLAR", "PIRATE", "PLANER", "PLIANT", "PLUNGE", "PONDER",
                "PORTAL", "POSTER", "POTTER", "POUNCE", "POWDER", "PRINCE", "PRISON", "PUNTER",
                "RACKET", "RAMBLE", "RANCOR", "RANDOM", "RANTER", "RASCAL", "RATTLE", "RENDER",
                "RENOWN", "REPAIR", "RESCUE", "RETAIN", "RETURN", "REVEAL", "RIDDLE", "RIOTER",
                "RIPPLE", "ROBUST", "ROSTER", "ROTTEN", "RUFFLE", "RUNNER", "RUSTLE", "SADDLE",
                "SAMPLE", "SANDER", "SAUCER", "SAVAGE", "SCALAR", "SCALER", "SCARLET", "SCORER",
                "SCREAM", "SCREEN", "SCRIBE", "SENDER", "SERENE", "SETTLE", "SHAKEN", "SHAPER",
                "SILENT", "SIMMER", "SISTER", "SKATER", "SLATED", "SLENDER", "SLIDER", "SLIPPER",
                "SLOGAN", "SMELTER", "SMOKER", "SNIPER", "SOCKET", "SOFTEN", "SOLVER", "SORTER",
                "SPOKEN", "SPONGE", "STABLE", "STATIC", "STONER", "STORED", "STREWN", "STRIKE",
                "STROKE", "SULTAN", "SUMMER", "SUPPER", "SURFER", "SWIVEL", "SYMBOL", "TANGLE",
                "TANKER", "TASTER", "TENDER", "TENNIS", "TENTER", "TERSER", "TINGLE", "TINKER",
                "TOPPER", "TOPPLE", "TORMENT", "TRACER", "TRADER", "TRAVEL", "TRESTLE", "TRIPLE",
                "TROWEL", "TUNNEL", "TURMOIL", "TWINKLE", "UNPACK", "UPLIFT", "URCHIN", "USURP",
                "VANTAGE", "VARNISH", "VENDOR", "VERBAL", "VESSEL", "VIRGIN", "VISUAL", "WANDER",
                "WARBLE", "WARDEN", "WARMER", "WASHER", "WATTLE", "WELDER", "WINNER", "WISDOM",
                "WITHER", "WONDER", "WORKER", "WRANGLER", "ZINGER"
            ]
        case .medium:    // 7-letter words
            return [
                "PAINTER", "CAPTAIN", "LANTERN", "MONSTER", "STRANGE", "SHELTER", "THUNDER",
                "KITCHEN", "MACHINE", "HISTORY", "BALANCE", "NETWORK", "SOLDIER", "PARTNER",
                "CENTRAL", "CHAPTER", "SILENCE", "PLANTER", "BLANKET", "CABINET", "CERTAIN",
                "CHANNEL", "CHICKEN", "COMFORT", "COMPANY", "COMPLEX", "CONCERN", "CONTROL",
                "CONVERT", "COUNCIL", "COUNTRY", "COURAGE", "CRICKET", "CULTURE", "CURRENT",
                "CUSTARD", "DEFENSE", "DELIVER", "DENTIST", "DESKTOP", "DESPAIR", "DEVIANT",
                "DIGITAL", "DISABLE", "DISMISS", "DISTANT", "DISTURB", "DIVIDED", "DORMANT",
                "DYNASTY", "EDITION", "ELECTED", "ELEMENT", "ENCHANT", "ENFORCE", "ENHANCE",
                "ENLARGE", "EPISODE", "EVIDENT", "EXAMINE", "EXECUTE", "EXHAUST", "EXPLORE",
                "EXPRESS", "EXTRACT", "FANTASY", "FASHION", "FERTILE", "FLUTTER", "FOCUSED",
                "FOREIGN", "FORTUNE", "FOUNDED", "GENUINE", "GRAMMAR", "GRANTED", "GRAVITY",
                "GREATER", "HARMONY", "HARVEST", "HEALTHY", "HOLIDAY", "HONORED", "HOSTILE",
                "HUNDRED", "IMAGINE", "IMMENSE", "IMPULSE", "INCLUDE", "INSPIRE", "INTENSE",
                "ISOLATE", "JOURNEY", "JUSTICE", "KINGDOM", "LANDING", "LEARNED", "LEISURE",
                "LIBERAL", "LIMITED", "LITERAL", "LOYALTY", "MENTION", "MIGRATE", "MIRACLE",
                "MISSING", "MIXTURE", "MONITOR", "MONTHLY", "MYSTERY", "NEUTRAL", "NOTABLE",
                "NOURISH", "OBSCURE", "OBVIOUS", "OFFENSE", "OPERATE", "OPINION", "ORGANIC",
                "OUTLINE", "OUTSIDE", "PATIENT", "PERFECT", "PERFORM", "PERSIST", "PHANTOM",
                "PLASTIC", "POPULAR", "PORTION", "POSTURE", "PRESENT", "PREVENT", "PRIVATE",
                "PROCESS", "PRODUCE", "PROGRAM", "PROJECT", "PROMOTE", "PROTECT", "PROVIDE",
                "PURPOSE", "QUALITY", "REALITY", "RECEIVE", "RECOVER", "REFLECT", "REGULAR",
                "RELEASE", "REPLACE", "REQUIRE", "RESOLVE", "RESPECT", "RESPOND", "RESTORE",
                "RETREAT", "REVENUE", "REVERSE", "ROYALTY", "SATISFY", "SCATTER", "SECTION",
                "SIMILAR", "SKILLED", "SOCIETY", "SOMEHOW", "SOMEONE", "SPECIAL", "STADIUM",
                "STATION", "STUDENT", "SUBJECT", "SUGGEST", "SUPPORT", "SUPPOSE", "SURVIVE",
                "TACTICS", "TENSION", "THOUGHT", "TONIGHT", "TOURISM", "TRIUMPH", "TRUSTED",
                "UNIFORM", "UNKNOWN", "URGENCY", "VENTURE", "VERSION", "VETERAN", "VIBRANT",
                "VILLAGE", "VISIBLE", "VOLCANO", "WARRIOR", "WEDDING", "WELCOME", "WHISPER",
                "WITNESS", "WORKOUT", "YOUNGER", "CRUMBLE", "CLUSTER", "COMPETE", "CAPTURE"
            ]
        case .hard:      // 8-letter words
            return [
                "ABSOLUTE", "BRANCHES", "STRANGER", "TROUBLES", "ELECTRON", "PRESENTS",
                "CHILDREN", "TOGETHER", "COMPLETE", "PERSONAL", "SMALLEST", "DAUGHTER",
                "STANDARD", "STRAIGHT", "STRENGTH", "RELATIVE", "CONSIDER", "POINTING",
                "SCRAMBLE", "CRIMINAL", "ABSTRACT", "ACCURATE", "ACHIEVED", "ACQUIRED",
                "ADJUSTED", "ADMITTED", "AFFECTED", "ALPHABET", "ALTHOUGH", "AMBITION",
                "ANALYSIS", "ANSWERED", "ANYWHERE", "APPEARED", "APPROACH", "ARRANGED",
                "BACKYARD", "BALANCED", "BECOMING", "BELIEVER", "BELONGED", "BETRAYAL",
                "BOOKCASE", "BORROWED", "BREAKING", "BREATHED", "BROTHERS", "BUILDING",
                "CALENDAR", "CARRYING", "CATCHING", "CENTERED", "CHAIRMAN", "CHANGING",
                "CHAPTERS", "CHEMICAL", "CLIMBING", "CLOTHING", "COLLAPSE", "COLONIES",
                "COLORFUL", "COMBINED", "COMMERCE", "COMPARED", "COMPILED", "CONCEALED",
                "CONCLUDE", "CONFLICT", "CONFUSED", "CONQUEST", "CONTAINS", "CONTRACT",
                "CONTRAST", "CONVINCE", "CRASHING", "CREATING", "CREATIVE", "CROSSING",
                "CULTURAL", "DARKNESS", "DEADLOCK", "DEADLINE", "DEARBORN", "DECREASE",
                "DEFEATED", "DEFIANCE", "DELICATE", "DELIGHTS", "DESERVED", "DESIGNED",
                "DETECTED", "DISASTER", "DISCOVER", "DISTANCE", "DISTINCT", "DOCTRINE",
                "DOMESTIC", "DOMINANT", "DRAMATIC", "DURATION", "EARNINGS", "EDUCATED",
                "ELEMENTS", "ELEVATED", "EMERGED", "ENFORCED", "ENGINEER", "ENORMOUS",
                "ENTERING", "ENVELOPE", "EQUATION", "ESCALATE", "ESTIMATE", "EVALUATE",
                "EVERYONE", "EXCHANGE", "EXPANDED", "EXPECTED", "EXPORTED", "EXTENDED",
                "EXTERNAL", "FAILURES", "FAITHFUL", "FAMILIAR", "FEATURED", "FEELINGS",
                "FIGHTING", "FINISHED", "FOCUSED", "FOLLOWED", "FORMALLY", "FRACTURE",
                "FRACTION", "FRAGMENT", "FREQUENT", "FRONTIER", "FUNCTION", "GENERATE",
                "GRATEFUL", "GREATEST", "GUARDIAN", "GUIDANCE", "HARDSHIP", "HERITAGE",
                "HORRIBLE", "HUMANITY", "HUMOROUS", "IDENTIFY", "IMAGINED", "IMPROVED",
                "INCLUDED", "INCREASE", "INDICATE", "INFORMED", "INNOCENT", "INSPIRED",
                "INTERVAL", "INVOLVED", "ISOLATED", "LAUNCHED", "LEARNING", "LIFETIME",
                "LISTENED", "LOCATION", "LONGTERM", "MEASURED", "MOVEMENT", "NEGATIVE",
                "ORIGINAL", "OUTDOORS", "OVERLOOK", "PEACEFUL", "PLATFORM", "PLEASURE",
                "POSITION", "POSSIBLE", "POWERFUL", "PRACTICE", "PREPARED", "PRESSURE",
                "PREVIOUS", "PRINCESS", "PROBABLE", "PROBLEMS", "PROGRESS", "PROMISED",
                "PROMOTED", "PROVIDED", "QUARTERS", "QUESTION", "REALIZED", "RECORDED",
                "REFERRED", "REMAINED", "REPORTED", "REQUIRED", "RESEARCH", "RESERVED",
                "RESOLVED", "RESPONSE", "RESULTED", "REVEALED", "REVERSED", "REWARDED",
                "SCHEDULE", "SELECTED", "SEQUENCE", "SERVICES", "SHORTAGE", "STRUGGLE",
                "SUPPLIED", "SUPPORTS", "SURVIVED", "SWIMMING", "TAXATION", "TARGETED",
                "TOGETHER", "TRAVELED", "TROUBLED", "ULTIMATE", "CAPTURED", "TREASURE"
            ]
        case .expert:    // 9-letter words
            return [
                "CARPENTER", "TRANSLATE", "IMPORTANT", "LANDSCAPE", "CHALLENGE", "STRANGEST",
                "REMAINDER", "PASSENGER", "YESTERDAY", "UNCERTAIN", "WONDERFUL", "CELEBRATE",
                "DETECTIVE", "CALCULATE", "BEAUTIFUL", "LISTENING", "NIGHTMARE", "SOMEWHERE",
                "COMPLAINS", "ALERTNESS", "ABANDONED", "ABUNDANCE", "ACCIDENTS", "ADDRESSED",
                "ADMISSION", "ADVENTURE", "AFTERMATH", "AGREEMENT", "ALONGSIDE", "AMBITIONS",
                "AMPLITUDE", "ANCESTORS", "ATTENTION", "ATTITUDES", "AUTHENTIC", "BEGINNING",
                "BRILLIANT", "BYSTANDER", "CAREFULLY", "CATHEDRAL", "CHARACTER", "CHILDHOOD",
                "CLOCKWISE", "COALITION", "COMBINING", "COMMUNITY", "COMPARING", "COMPLETED",
                "COMPONENT", "CONCERNED", "CONCLUDES", "CONFIDENT", "CONFIRMED", "CONNECTED",
                "CONSCIOUS", "CONSIDERS", "CONSTRUCT", "CONTINUED", "CONVERTED", "CONVINCED",
                "CORRECTLY", "COUNTLESS", "CREATURES", "DANGEROUS", "DECISIONS", "DEDICATED",
                "DELIVERED", "DEPENDING", "DESCRIBED", "DEVELOPED", "DIFFERENT", "DIRECTION",
                "DISCOVERY", "DISCUSSED", "DISPLAYED", "DISTANCES", "DOMINATED", "EMERGENCY",
                "EMPLOYEES", "ENCOUNTER", "ENGINEERS", "ENJOYMENT", "ESTIMATED", "EVALUATED",
                "EXCELLENT", "EXCLUSIVE", "EXPLAINED", "EXPRESSED", "EXTENSIVE", "EXTREMELY",
                "FOLLOWERS", "FORMATION", "FRANCHISE", "FREQUENCY", "GATHERING", "GRADUATED",
                "GREATNESS", "HAPPENING", "HONORABLE", "HOUSEHOLD", "IMAGINING", "IMMEDIATE",
                "IMPRESSED", "INCREASED", "INDICATED", "INHERITED", "INSTANTLY", "INTENTION",
                "KNOWLEDGE", "LEADERSHIP", "MOUNTAINS", "NARRATIVE", "OBSERVERS", "OCCURRING",
                "OTHERWISE", "OWNERSHIP", "PAINTINGS", "PERFORMED", "PERMANENT", "PLACEMENT",
                "POSITIONS", "POTENTIAL", "PRACTICED", "PREPARING", "PRESENTED", "PRINCIPLE",
                "PRISONERS", "PROLONGED", "PROVIDING", "PURCHASES", "QUESTIONS", "RECOVERED",
                "REFLECTED", "REMAINING", "REPRESENT", "RESOURCES", "SATISFIED", "SEPARATED",
                "SHOULDERS", "SIGNATURE", "SITUATIONS", "STANDARDS", "STATEMENT", "STRETCHED",
                "STRUCTURE", "SUCCEEDED", "SUPPORTED", "TERRITORY", "THOUSANDS", "THROUGHOUT",
                "TRANSPORT", "TRAVELERS", "TREATMENT", "UNIVERSAL", "UNLIMITED", "WITNESSES"
            ]
        }
    }
}
