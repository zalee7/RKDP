import Foundation

// MARK: - Result types

enum WordleLetterResult: Equatable {
    case correct   // green  — right letter, right position
    case present   // yellow — right letter, wrong position
    case absent    // gray   — letter not in word
}

struct WordleGuess: Identifiable {
    let id = UUID()
    let word: String          // 5 uppercase chars
    let result: [WordleLetterResult]
    var isSolved: Bool { result.allSatisfy { $0 == .correct } }
}

// MARK: - Game

struct WordleGame {
    let targetWord: String    // 5 uppercase letters
    let seed: Int
    let round: Int

    init(seed: Int, round: Int) {
        self.seed = seed
        self.round = round
        var rng = SeededRNG(seed: seed &+ round &* 1_000_003)
        self.targetWord = rng.shuffled(WordleGame.wordBank)[0]
    }

    func evaluate(guess raw: String) -> [WordleLetterResult] {
        let guess  = Array(raw.uppercased())
        let target = Array(targetWord)
        var result     = Array(repeating: WordleLetterResult.absent, count: 5)
        var targetUsed = Array(repeating: false, count: 5)
        var guessUsed  = Array(repeating: false, count: 5)

        // Pass 1: correct positions
        for i in 0..<5 {
            if guess[i] == target[i] {
                result[i]     = .correct
                targetUsed[i] = true
                guessUsed[i]  = true
            }
        }
        // Pass 2: present (wrong position)
        for i in 0..<5 {
            guard !guessUsed[i] else { continue }
            for j in 0..<5 {
                if !targetUsed[j] && guess[i] == target[j] {
                    result[i]    = .present
                    targetUsed[j] = true
                    break
                }
            }
        }
        return result
    }

    static func isValidGuess(_ word: String) -> Bool {
        let w = word.uppercased()
        return w.count == 5 && (wordBank.contains(w) || WordDictionary.words.contains(w))
    }

    // MARK: - Word bank (~250 common 5-letter answer words)

    static let wordBank: [String] = [
        "ABUSE","ACUTE","ADMIT","ADOPT","ADULT","AFTER","AGAIN","AGENT","AGREE","AHEAD",
        "ALARM","ALERT","ALIKE","ALIVE","ALONE","ALTER","AMBER","AMEND","ANGEL","ANGER",
        "ANGLE","APPLE","ARISE","ARMOR","AROMA","ARRAY","ASIDE","ASSET","AVOID","AWAKE",
        "AWARD","AWARE","AWFUL","BADGE","BASIC","BASIN","BEACH","BEARD","BEAST","BEGIN",
        "BENCH","BLAND","BLANK","BLAST","BLAZE","BLEAK","BLEND","BLESS","BLIND","BLOCK",
        "BLOOD","BLOOM","BLOWN","BLUNT","BOARD","BOAST","BOUND","BRACE","BRAIN","BRAND",
        "BRAVE","BREAK","BREED","BRICK","BRIDE","BRIEF","BROKE","BROOD","BROTH","BROWN",
        "CABIN","CANDY","CARRY","CATCH","CAUSE","CHAIN","CHALK","CHAOS","CHARM","CHEAT",
        "CHEEK","CHEER","CHESS","CHEST","CHIEF","CHILD","CHORD","CHUNK","CIVIL","CLAIM",
        "CLASH","CLASP","CLASS","CLERK","CLICK","CLIMB","CLING","CLOAK","CLOCK","CLONE",
        "CLOSE","CLOTH","CLOUD","CLOWN","COBRA","COLOR","CORAL","COUNT","COURT","COVER",
        "CRACK","CRAFT","CRANE","CRASH","CRAWL","CREAM","CREEK","CREEP","CREST","CRIME",
        "CRISP","CROSS","CROWD","CROWN","CRUEL","CRUSH","CRUST","CURRY","CURSE","CURVE",
        "CYCLE","DAILY","DANCE","DEPOT","DEPTH","DIRTY","DODGE","DOUBT","DOUGH","DRAIN",
        "DRAPE","DREAD","DREAM","DRESS","DRIFT","DRINK","DRIVE","DRONE","DROVE","DRUNK",
        "EAGER","EARLY","EARTH","EIGHT","ELITE","EMPTY","ENEMY","ENJOY","ENTER","EQUAL",
        "EVENT","EVERY","EXACT","EXIST","EXTRA","FABLE","FAIRY","FAITH","FANCY","FATAL",
        "FEAST","FEVER","FIBER","FIELD","FIFTH","FIGHT","FINAL","FLAIR","FLAME","FLARE",
        "FLASH","FLASK","FLESH","FLING","FLOAT","FLOCK","FLOOD","FLOOR","FLUSH","FORCE",
        "FORGE","FORTE","FOUND","FRAME","FRANK","FREED","FRESH","FRONT","FROST","FULLY",
        "GHOST","GIVEN","GLARE","GLASS","GLEAM","GLOBE","GLORY","GLOSS","GLOVE","GRACE",
        "GRADE","GRAIN","GRAND","GRANT","GRAPE","GRASP","GRASS","GRATE","GRAVE","GRAVY",
        "GRAZE","GREED","GREET","GRIEF","GRIND","GROAN","GROVE","GROWL","GUARD","GUILD",
        "GUILE","GUILT","GUSTO","HABIT","HAPPY","HARSH","HAVEN","HENCE","HOARD","HONEY",
        "HONOR","HORSE","HOTEL","HOUSE","HUMAN","HUMOR","HURRY","IMAGE","IMPLY","INNER",
        "INPUT","ISSUE","JELLY","JEWEL","JUICE","JUICY","KARMA","KNIFE","KNOCK","LANCE",
        "LARGE","LASER","LATER","LAUGH","LAYER","LEARN","LEASE","LEAST","LEAVE","LEGAL",
        "LEMON","LIGHT","LIMIT","LIVER","LOCAL","LODGE","LOGIC","LOOSE","LOWER","LOYAL",
        "LUNAR","LYRIC","MAGIC","MAJOR","MANOR","MAPLE","MARCH","MARSH","MATCH","MAYOR",
        "MEDIA","MERCY","MERIT","METAL","MIGHT","MINOR","MIRTH","MONEY","MONTH","MORAL",
        "MOUTH","MUSIC","NAIVE","NERVE","NEVER","NIGHT","NOBLE","NOISE","NORTH","NOTCH",
        "NOVEL","NURSE","OCEAN","OFFER","OLIVE","ORDER","OTHER","OUTER","OWNER","PAINT",
        "PAPER","PARTY","PASTA","PATCH","PEARL","PERCH","PHOTO","PIANO","PIECE","PILOT",
        "PITCH","PLACE","PLAIN","PLANE","PLANK","PLANT","PLATE","PLAZA","PLUCK","POINT",
        "POLAR","POWER","PRESS","PRICE","PRIDE","PRIME","PRINT","PRIOR","PRIZE","PROOF",
        "PROSE","PROUD","PROVE","PROWL","PULSE","PUNCH","PURSE","QUEEN","QUEST","QUICK",
        "QUIET","RADAR","RADIO","RAISE","RANCH","RANGE","RAPID","RATIO","REACH","REACT",
        "READY","REALM","REIGN","RELAX","REPAY","REPLY","RIGHT","RIGID","RIVAL","ROBOT",
        "ROCKY","ROUGH","ROUND","ROUTE","ROWDY","RULER","RURAL","RUSTY","SAINT","SAUCE",
        "SCALE","SCENE","SCENT","SCONE","SCOOP","SCOPE","SCORE","SCOUT","SEIZE","SENSE",
        "SEVEN","SHADE","SHAKE","SHALL","SHAME","SHAPE","SHARE","SHARP","SHEER","SHONE",
        "SHORE","SHOUT","SHOVE","SHRUB","SIEGE","SINCE","SIXTH","SIXTY","SKILL","SKIRT",
        "SKULL","SLACK","SLATE","SLAVE","SLEEK","SLEEP","SLEET","SLIDE","SLING","SLOPE",
        "SMART","SMASH","SMELL","SMILE","SMOKE","SNACK","SNAIL","SNAKE","SNARE","SNIFF",
        "SOLAR","SOUTH","SPACE","SPARK","SPAWN","SPEAK","SPEAR","SPEED","SPEND","SPICE",
        "SPINE","SPOKE","SPOON","SPRAY","STACK","STAFF","STAGE","STAIN","STAIR","STAKE",
        "STALE","STALL","STAMP","STAND","STARK","START","STATE","STEAM","STEEL","STEEP",
        "STEER","STERN","STICK","STIFF","STILL","STOCK","STONE","STOOD","STORM","STORY",
        "STOUT","STOVE","STRAP","STRAY","STUCK","STUDY","STUFF","STUMP","STUNG","STYLE",
        "SUGAR","SUITE","SUPER","SURGE","SWEAR","SWEEP","SWEET","SWEPT","SWIFT","SWING",
        "SWORD","TABLE","TASTE","TAUNT","THORN","THREE","TIGER","TIRED","TITLE","TOAST",
        "TOKEN","TORCH","TOTAL","TOUCH","TOUGH","TOWER","TOXIC","TRACE","TRACK","TRADE",
        "TRAIL","TRAIN","TRAMP","TREAD","TREND","TRIBE","TRICK","TRUCK","TRULY","TRUNK",
        "TRUST","TRUTH","TULIP","TUNIC","UNION","UNITY","UNTIL","UPPER","USAGE","UTTER",
        "VAGUE","VALID","VAULT","VIGOR","VIRAL","VISIT","VISTA","VITAL","VIVID","VOCAL",
        "VOICE","WALTZ","WASTE","WATCH","WATER","WEARY","WEAVE","WEDGE","WEIGH","WEIRD",
        "WHALE","WHEAT","WHEEL","WHITE","WHOLE","WITCH","WOMAN","WORLD","WORRY","WORSE",
        "WORST","WORTH","WOULD","WRATH","WRECK","WROTE","YOUNG","YOUTH",
    ]
}
