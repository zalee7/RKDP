import Foundation

struct WordHuntGame {
    let grid: [[Character]]   // 4×4
    let seed: Int
    private(set) var validWords: Set<String> = []

    static let gridSize = 4

    init(grid: [[Character]], seed: Int) {
        self.grid = grid
        self.seed = seed
        self.validWords = Self.findAllWords(in: grid)
    }

    // MARK: - Path validation

    /// Returns true if `word` can be traced as a valid adjacency path in the grid.
    func canForm(_ word: String) -> Bool {
        let chars = Array(word.uppercased())
        guard chars.count >= 3 else { return false }
        for r in 0..<Self.gridSize {
            for c in 0..<Self.gridSize {
                if grid[r][c] == chars[0] {
                    var visited = [[Bool]](repeating: [Bool](repeating: false, count: Self.gridSize), count: Self.gridSize)
                    visited[r][c] = true
                    if dfs(chars: chars, index: 1, row: r, col: c, visited: &visited) { return true }
                }
            }
        }
        return false
    }

    private func dfs(chars: [Character], index: Int, row: Int, col: Int, visited: inout [[Bool]]) -> Bool {
        if index == chars.count { return true }
        for (nr, nc) in Self.neighbors(row: row, col: col) {
            guard !visited[nr][nc], grid[nr][nc] == chars[index] else { continue }
            visited[nr][nc] = true
            if dfs(chars: chars, index: index + 1, row: nr, col: nc, visited: &visited) { return true }
            visited[nr][nc] = false
        }
        return false
    }

    static func neighbors(row: Int, col: Int) -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        for dr in -1...1 {
            for dc in -1...1 {
                guard dr != 0 || dc != 0 else { continue }
                let nr = row + dr, nc = col + dc
                if nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize {
                    result.append((nr, nc))
                }
            }
        }
        return result
    }

    // MARK: - Score

    static func score(for word: String) -> Int {
        switch word.count {
        case 3:      return 1
        case 4:      return 2
        case 5:      return 3
        case 6:      return 4
        default:     return 5
        }
    }

    // MARK: - Grid generation

    static func generate(seed: Int) -> WordHuntGame {
        // Weighted letter bag — roughly English Scrabble frequencies
        let bag: [Character] = Array(
            "AAAAAAAAABBCCDDDDEEEEEEEEEEEEFFGGGHHIIIIIIIIJKLLLLMMNNNNNNOOOOOOOOPPQRRRRRRSSSSTTTTTTTUUUUVVWWXYYZ"
        )
        var s = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        var flat: [Character] = []
        for _ in 0..<(gridSize * gridSize) {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            flat.append(bag[Int(s >> 33) % bag.count])
        }
        let grid = (0..<gridSize).map { r in Array(flat[(r * gridSize)..<(r * gridSize + gridSize)]) }
        return WordHuntGame(grid: grid, seed: seed)
    }

    // MARK: - Pre-compute all valid words in this grid

    private static func findAllWords(in grid: [[Character]]) -> Set<String> {
        var found = Set<String>()
        let game = WordHuntGame(grid: grid, seed: 0, validWords: Set())   // temp without recursion
        for word in WordDictionary.words {
            if game.canForm(word) { found.insert(word) }
        }
        return found
    }

    // Private init used during pre-computation
    private init(grid: [[Character]], seed: Int, validWords: Set<String>) {
        self.grid = grid
        self.seed = seed
        self.validWords = validWords
    }
}

// MARK: - Embedded dictionary

enum WordDictionary {
    static let words: Set<String> = [
        // 3-letter words
        "ACE","ACT","ADD","AGE","AGO","AID","AIM","AIR","ALL","AND","ANT","APE","APT","ARC","ARE","ARK","ARM","ART",
        "ASH","ASK","ATE","AWE","AXE","BAD","BAG","BAN","BAR","BAT","BAY","BED","BIG","BIT","BOW","BOX","BOY",
        "BUD","BUG","BUN","BUS","BUT","BUY","CAB","CAN","CAP","CAR","CAT","COB","COD","COP","COT","COW","CRY",
        "CUB","CUP","CUT","DAD","DAM","DAY","DEN","DID","DIG","DIM","DIP","DOC","DOE","DOG","DOT","DRY","DUB",
        "DUD","DUE","DUG","DUN","DUO","DYE","EAR","EAT","EEL","EGG","ELF","ELK","ELM","EMU","END","ERA","EWE",
        "EYE","FAD","FAN","FAR","FAT","FAX","FED","FEW","FIG","FIN","FIT","FLY","FOB","FOE","FOG","FOR","FOX",
        "FRY","FUN","FUR","GAP","GAS","GEL","GEM","GET","GIG","GNU","GOD","GOT","GUM","GUN","GUT","GUY","GYM",
        "HAD","HAM","HAS","HAT","HAY","HEN","HER","HIM","HIT","HOB","HOG","HOP","HOT","HOW","HUB","HUE","HUG",
        "HUM","HUT","ICE","ICY","ILL","INN","ION","IRE","IVY","JAB","JAM","JAR","JAW","JET","JOB","JOG","JOT",
        "JOY","JUG","JUT","KEG","KIT","LAB","LAD","LAP","LAW","LAX","LAY","LEA","LED","LEG","LET","LID","LIP",
        "LIT","LOG","LOT","LOW","MAD","MAP","MAR","MAT","MAW","MAY","MEN","MET","MID","MIX","MOB","MOD","MOM",
        "MOP","MOW","MUD","MUG","NAB","NAG","NAP","NET","NEW","NIP","NOB","NOD","NOR","NOT","NOW","NUB","NUN",
        "NUT","OAK","OAR","OAT","ODD","ODE","OPT","ORB","ORE","OUR","OUT","OWE","OWL","OWN","PAD","PAN","PAP",
        "PAR","PAT","PAW","PAY","PEA","PEG","PEN","PEP","PET","PIE","PIG","PIN","PIT","PLY","POD","POP","POT",
        "POW","PRY","PUB","PUG","PUN","PUP","PUS","PUT","RAG","RAM","RAN","RAP","RAT","RAW","RAY","RED","RIB",
        "RID","RIG","RIM","RIP","ROB","ROD","ROT","ROW","RUB","RUG","RUN","RUT","SAC","SAD","SAP","SAT","SAW",
        "SAY","SEA","SET","SEW","SHY","SIP","SIR","SIT","SIX","SKI","SKY","SLY","SOB","SOD","SON","SOP","SOT",
        "SOW","SOY","SPA","SPY","STY","SUB","SUM","SUN","TAB","TAD","TAG","TAN","TAP","TAR","TAT","TAX","TEA",
        "TEN","THE","TIE","TIN","TIP","TOE","TON","TOO","TOP","TOT","TOW","TOY","TUB","TUG","TUN","TWO","URN",
        "USE","VAT","VIA","VIE","VOW","WAD","WAR","WAS","WAX","WEB","WED","WET","WHO","WHY","WIG","WIN","WIT",
        "WOE","WOK","WON","WOO","WOW","YAK","YAM","YAP","YAW","YEA","YEW","YOU","ZAP","ZEN","ZIP","ZIT","ZOO",
        // 4-letter words
        "ABLE","ACHE","ACID","AGED","ALSO","ARCH","AREA","ARMY","ACHE","ATOM","AUNT","AURA","AWAY","BAKE","BALE",
        "BALL","BAND","BANE","BANG","BARE","BARK","BARN","BASE","BASH","BASK","BATH","BEAD","BEAM","BEAN","BEAR",
        "BEAT","BEEN","BELL","BELT","BEND","BEST","BIAS","BILE","BILL","BIND","BITE","BLADE","BLOT","BLOW","BLUE",
        "BLUR","BOAR","BOAT","BOLD","BOLT","BOND","BONE","BOOK","BOOM","BOOT","BORE","BORN","BOTH","BOUT","BRAG",
        "BRAN","BRAT","BREW","BRIM","BULL","BUMP","BURN","BURP","CAGE","CAKE","CALL","CALM","CAME","CAMP","CANE",
        "CAPE","CARD","CARE","CART","CASE","CASH","CAST","CAVE","CELL","CHAD","CHAT","CHIP","CLAM","CLAP","CLAY",
        "CLIP","CLOD","CLOG","CLOP","CLOT","CLUB","CLUE","COAL","COAT","COIL","COIN","COLA","COLD","COME","COOK",
        "COOL","COPE","CORD","CORE","CORK","CORN","COST","COSY","COUP","CRAM","CRIB","CROP","CROW","CUBE","CURL",
        "DAMP","DARE","DARK","DART","DATA","DAWN","DAYS","DEAD","DEAL","DEAN","DEAR","DEBT","DECK","DEED","DEEM",
        "DEEP","DENY","DESK","DIET","DIRE","DIRT","DISK","DOCK","DOME","DONE","DOOM","DOOR","DOSE","DOVE","DOWN",
        "DRAB","DRAG","DRAW","DRIP","DROP","DRUG","DRUM","DUAL","DUNE","DUSK","DUST","DUTY","EACH","EARL","EARN",
        "EASE","EAST","EDGE","EMIT","ENVY","EPIC","EXAM","FACE","FACT","FADE","FAIL","FAIR","FAKE","FALL","FAME",
        "FANG","FARE","FARM","FAST","FATE","FAWN","FEAT","FEED","FEEL","FEET","FELL","FELT","FEND","FERN","FETE",
        "FILE","FILL","FILM","FIND","FIRE","FIRM","FISH","FIST","FIZZ","FLAG","FLAP","FLAT","FLAW","FLEA","FLED",
        "FLEW","FLEX","FLIP","FLOG","FLOW","FOAM","FOLD","FOLK","FOND","FONT","FOOD","FOOL","FORD","FORE","FORK",
        "FORM","FORT","FOUL","FOUR","FOWL","FREE","FROG","FROM","FUME","FUND","FUSE","FUZZ","GALE","GANG","GASH",
        "GATE","GAVE","GAZE","GEAR","GERM","GIFT","GILL","GIRD","GIRL","GIST","GIVE","GLAD","GLEE","GLEN","GLOW",
        "GLUE","GNAT","GNAW","GOAL","GOLF","GOOD","GOOF","GORE","GOWN","GRAB","GRAM","GRAY","GREW","GRIN","GRIP",
        "GRIT","GUST","HACK","HAIL","HAIR","HALE","HALF","HALL","HALT","HAND","HANG","HARD","HARE","HARM","HARP",
        "HASH","HATE","HAVE","HAWK","HAZE","HEAD","HEAL","HEAP","HEAR","HEAT","HEEL","HELM","HELP","HEMP","HERB",
        "HERD","HERO","HIDE","HIGH","HILL","HIRE","HISS","HOLD","HOLE","HOME","HOOD","HOOK","HORN","HOSE","HOST",
        "HOUR","HULK","HULL","HUNT","HYMN","IDEA","IDLE","INCH","INTO","JACK","JADE","JAIL","JERK","JOIN","JOKE",
        "JOLT","JUNK","JUST","KEEN","KEEP","KERN","KIND","KING","KNOB","KNOT","KNOW","LACK","LAKE","LAMB","LAMP",
        "LAND","LANE","LARK","LASH","LAST","LATE","LAUD","LAVA","LAWN","LEAD","LEAF","LEAN","LEAP","LEFT","LEND",
        "LESS","LIFE","LIFT","LIKE","LIME","LINE","LINK","LION","LIST","LIVE","LOAD","LOAF","LOAN","LOCK","LODE",
        "LONE","LONG","LOOK","LOOM","LOOP","LORD","LORE","LOSE","LOSS","LOST","LOUD","LOVE","LUCK","LULL","LUMP",
        "LUNG","LURK","LUST","MADE","MAIL","MAIN","MAKE","MALE","MALL","MANE","MAST","MATE","MAZE","MEAL","MEAN",
        "MEAT","MEET","MELT","MEMO","MENU","MESS","MILD","MILE","MILK","MILL","MINE","MINT","MISS","MIST","MOAN",
        "MOAT","MOCK","MOLD","MOLE","MORE","MOST","MOTH","MOVE","MUCK","MULE","MUTT","MYTH","NAIL","NAME","NAVY",
        "NEAR","NEAT","NECK","NEED","NEWS","NEXT","NICE","NINE","NODE","NONE","NOON","NOPE","NORM","NOSE","NOSH",
        "NOTE","NUDE","NUMB","OATH","OBEY","ODDS","OMEN","ONCE","ONLY","OPEN","OVAL","OVEN","OVER","OXEN","PACE",
        "PACK","PAGE","PAID","PAIN","PALE","PALM","PANT","PATH","PAVE","PEAK","PEAL","PEAR","PEAT","PEEK","PEEL",
        "PEER","PEST","PICK","PILE","PILL","PINE","PINK","PIPE","PLAN","PLAY","PLEA","PLOD","PLOT","PLOW","PLUG",
        "PLUM","PLUS","POEM","POET","POLE","POLL","POOL","POOR","POPE","PORE","PORK","PORT","POSE","POUR","PRAY",
        "PREP","PREY","PRIM","PROD","PROP","PROW","PULL","PULP","PUMP","PURE","PUSH","QUAD","QUAY","QUIZ","RACE",
        "RACK","RAGE","RAIL","RAIN","RAKE","RAMP","RANG","RANK","RANT","RASH","RATE","READ","REAL","REAP","REED",
        "REEF","REEK","REEL","RELY","REND","RENT","RICH","RIDE","RING","RIOT","RISE","RISK","ROAD","ROAM","ROAR",
        "RODE","ROLL","ROOF","ROOM","ROOT","ROPE","ROSE","ROUT","RUDE","RULE","RUSH","RUST","SAFE","SAGE","SAID",
        "SAIL","SALT","SAME","SAND","SANE","SANG","SANK","SAP","SASH","SAVE","SCAN","SCAR","SEAL","SEAM","SEEM",
        "SEEN","SELF","SELL","SEND","SENT","SHED","SHIN","SHIP","SHOE","SHOT","SHOW","SHUT","SICK","SIGN","SILK",
        "SILL","SING","SINK","SIZE","SKIN","SKIP","SLAM","SLAP","SLID","SLIM","SLIP","SLOB","SLOE","SLOT","SLOW",
        "SLUG","SLUM","SMUG","SNAP","SNOB","SNOW","SOAP","SOCK","SOIL","SOLE","SOME","SONG","SORE","SORT","SOUL",
        "SOUP","SOUR","SPIN","SPIT","SPOT","SPUR","STAB","STAG","STAR","STAY","STEM","STEP","STEW","STIR","STOP",
        "STUB","STUD","SUED","SULK","SUNG","SUNK","SURF","SWAP","SWAT","SWIM","TAIL","TALE","TALK","TALL","TAME",
        "TAUT","TEAM","TEAR","TEEM","TELL","TEND","TERM","TEST","THAN","THAT","THEM","THEN","THEY","THIN","THIS",
        "THORN","THOU","THUD","TICK","TIDE","TILL","TILT","TIME","TINY","TIRE","TOAD","TOLD","TOLL","TOMB","TOME",
        "TONG","TORE","TORN","TORT","TOUR","TRAM","TRAP","TRIM","TRIO","TRIP","TROD","TROT","TRUE","TUBE","TUFT",
        "TUNE","TURF","TUSK","TWIN","TYPE","UGLY","UNDO","UNIT","UPON","URGE","USED","VALE","VANE","VASE","VAST",
        "VEIL","VEIN","VERY","VEST","VETO","VIBE","VINE","VISA","VOID","VOLT","VOTE","WADE","WAGE","WAKE","WALK",
        "WALL","WANE","WANT","WARD","WARM","WARN","WARP","WART","WASP","WAVE","WEAK","WEAL","WEAN","WEAR","WEED",
        "WEEK","WELL","WEND","WENT","WERE","WEST","WHAM","WHAT","WHEN","WHET","WHIP","WHIR","WIDE","WIFE","WILD",
        "WILL","WILT","WIND","WINE","WING","WIRE","WISE","WISH","WITH","WOLF","WOOD","WOOL","WORD","WORE","WORM",
        "WORN","WREN","WRIT","YARD","YARN","YEAR","YELL","YOGA","YOLK","YORK","YOUR","ZERO","ZEST","ZINC","ZONE",
        // 5-letter words
        "ABOUT","ABOVE","ABUSE","ACTOR","ACUTE","ADMIT","ADOPT","ADULT","AFTER","AGAIN","AGENT","AGREE","AHEAD",
        "ALARM","ALBUM","ALERT","ALIKE","ALIGN","ALIVE","ALOFT","ALONE","ALONG","ALOUD","ALTER","AMBER","AMBLE",
        "AMEND","ANGEL","ANGER","ANGLE","ANGRY","ANIME","ANNEX","ANTIC","APART","APPLE","APPLY","ARENA","ARGUE",
        "ARISE","ARMOR","AROMA","ARRAY","ASIDE","ASSET","AUDIO","AUDIT","AVOID","AWAKE","AWARD","AWARE","AWFUL",
        "BADGE","BARGE","BASIC","BASIN","BASIS","BATCH","BEACH","BEARD","BEAST","BEGAN","BEGIN","BEING","BELOW",
        "BENCH","BILLY","BINGO","BIRCH","BIRTH","BISON","BITES","BLAND","BLANK","BLAST","BLAZE","BLEAK","BLEED",
        "BLEND","BLESS","BLIND","BLOCK","BLOOD","BLOOM","BLOWN","BLUNT","BOARD","BOAST","BOGGY","BOUND","BRACE",
        "BRAIN","BRAND","BRAVE","BREAK","BREED","BREVE","BRICK","BRIDE","BRIEF","BRINE","BRINK","BROKE","BROOD",
        "BROTH","BROWN","BULLY","BURLY","BURNS","BUYER","CABIN","CAMEL","CANDY","CARRY","CATCH","CAUSE","CEDAR",
        "CHAIN","CHALK","CHAMP","CHAOS","CHARM","CHEAT","CHEEK","CHEEP","CHEER","CHESS","CHEST","CHIEF","CHILD",
        "CHILI","CHIME","CHIMP","CHINA","CHORD","CHUNK","CIVIC","CIVIL","CLAIM","CLAMP","CLANK","CLASH","CLASP",
        "CLASS","CLEAT","CLERK","CLICK","CLIMB","CLING","CLOAK","CLOCK","CLONE","CLOSE","CLOTH","CLOUD","CLOWN",
        "COACH","COBRA","COCOA","COLOR","COMET","CORAL","COUNT","COURT","COVER","CRACK","CRAFT","CRAMP","CRANE",
        "CRASH","CRAWL","CREAK","CREAM","CREEK","CREEP","CREST","CRIME","CRISP","CROSS","CROWD","CROWN","CRUEL",
        "CRUSH","CRUST","CRYPT","CURES","CURRY","CURSE","CURVE","CUTIE","CYCLE","DAILY","DAISY","DANCE","DEPOT",
        "DEPTH","DERBY","DIRTY","DITCH","DIVER","DIZZY","DODGE","DOING","DONOR","DOUBT","DOUGH","DOWRY","DRAIN",
        "DRAPE","DREAD","DREAM","DRESS","DRIED","DRIFT","DRILL","DRINK","DRIVE","DRONE","DROOL","DROVE","DRUNK",
        "DRYER","DYING","EAGLE","EARLY","EARTH","EATEN","EIGHT","ELITE","EMPTY","ENEMY","ENJOY","ENTER","ENTRY",
        "EQUAL","EVENT","EVERY","EXACT","EXIST","EXTRA","FABLE","FACET","FAIRY","FAITH","FANCY","FATAL","FEAST",
        "FEVER","FIBER","FIELD","FIEND","FIFTH","FIFTY","FIGHT","FINAL","FIXED","FLAIR","FLAME","FLARE","FLASH",
        "FLASK","FLESH","FLICK","FLIES","FLING","FLOAT","FLOCK","FLOOD","FLOOR","FLOSS","FLUFF","FLUNK","FLUSH",
        "FOCAL","FOGGY","FORAY","FORCE","FORGE","FORTE","FORUM","FOUND","FRAME","FRANK","FREED","FRESH","FRONT",
        "FROST","FROZE","FULLY","FUNNY","GAMES","GHOST","GIRTH","GIVEN","GLAND","GLARE","GLASS","GLEAM","GLOBE",
        "GLORY","GLOSS","GLOVE","GOING","GRACE","GRADE","GRAIN","GRAND","GRANT","GRAPE","GRASP","GRASS","GRATE",
        "GRAVE","GRAVY","GRAZE","GREED","GREET","GRIEF","GRIND","GROAN","GROIN","GROPE","GROSS","GROUT","GROVE",
        "GROWL","GRUFF","GUARD","GUILD","GUILE","GUILT","GUSTO","HABIT","HAPPY","HARSH","HAVEN","HEDGE","HEIST",
        "HENCE","HOARD","HOARY","HOLLY","HOMER","HONEY","HONOR","HORSE","HOTEL","HOUSE","HUMAN","HUMOR","HURRY",
        "HUSKY","IMAGE","IMPLY","INDEX","INNER","INPUT","INTER","INTRO","ISSUE","IVORY","JELLY","JEWEL","JUMBO",
        "JUICE","JUICY","KARMA","KAYAK","KNEEL","KNIFE","KNIVE","KNOCK","LABEL","LANCE","LANKY","LAPSE","LARGE",
        "LASER","LATER","LAUGH","LAYER","LEARN","LEASE","LEAST","LEAVE","LEGAL","LEMON","LIGHT","LIMIT","LINER",
        "LIVER","LOCAL","LODGE","LOGIC","LOOSE","LOVER","LOWER","LOYAL","LUNAR","LUSTY","LYRIC","MAGIC","MAJOR",
        "MANOR","MAPLE","MARCH","MARSH","MATCH","MAYOR","MEDIA","MERCY","MERIT","METAL","MIGHT","MINOR","MINUS",
        "MIRTH","MOIST","MONEY","MONTH","MORAL","MOUTH","MOVIE","MUDDY","MUSIC","NAIVE","NERVE","NEVER","NIGHT",
        "NOBLE","NOISE","NORTH","NOTCH","NOVEL","NURSE","NYMPH","OCEAN","OFFER","OLIVE","ONSET","ORDER","OTHER",
        "OUTER","OWNER","OXIDE","OZONE","PAINT","PAPER","PARTY","PASTA","PATCH","PEARL","PENAL","PERCH","PHOTO",
        "PIANO","PIECE","PILOT","PINCH","PITCH","PIXEL","PIXEL","PIXEL","PIXIE","PLACE","PLAIN","PLANE","PLANK",
        "PLANT","PLATE","PLAZA","PLEAD","PLEAT","PLUCK","PLUMB","PLUME","PLUMP","PLUNK","POINT","POLAR","POPPY",
        "POWER","PRESS","PRICE","PRIDE","PRIME","PRINT","PRIOR","PRIZE","PROBE","PROOF","PROSE","PROUD","PROVE",
        "PROWL","PULSE","PUNCH","PUPIL","PURSE","QUEEN","QUERY","QUEST","QUICK","QUIET","QUOTA","QUOTE","RADAR",
        "RADIO","RAISE","RANCH","RANGE","RAPID","RATIO","REACH","REACT","READY","REALM","REBUT","REIGN","RELAX",
        "REPAY","REPLY","RIGHT","RIGID","RISKY","RIVAL","RIVER","RIVET","ROBOT","ROCKY","ROUGE","ROUGH","ROUND",
        "ROUTE","ROWDY","RULER","RURAL","RUSTY","SADLY","SAINT","SAUCE","SCALE","SCALP","SCAMP","SCANT","SCARF",
        "SCENE","SCENT","SCONE","SCOOP","SCOPE","SCORE","SCOUT","SCOWL","SCRAM","SCRAP","SCRUB","SEIZE","SENSE",
        "SEVEN","SHADE","SHAKE","SHALL","SHAME","SHAPE","SHARE","SHARP","SHEER","SHONE","SHORE","SHOUT","SHOVE",
        "SHRUB","SIEGE","SINCE","SIXTH","SIXTY","SKILL","SKIRT","SKULL","SLACK","SLAIN","SLANT","SLASH","SLATE",
        "SLAVE","SLEEK","SLEEP","SLEET","SLICK","SLIDE","SLING","SLOPE","SMART","SMASH","SMELL","SMELT","SMILE",
        "SMITE","SMOKE","SNACK","SNAIL","SNAKE","SNARE","SNIFF","SNORE","SOLAR","SOLID","SOUTH","SPACE","SPARK",
        "SPAWN","SPEAK","SPEAR","SPEED","SPEND","SPICE","SPINE","SPIRAL","SPLAT","SPOKE","SPOON","SPRAY","SQUAD",
        "STACK","STAFF","STAGE","STAIN","STAIR","STAKE","STALE","STALL","STAMP","STAND","STARK","START","STASH",
        "STATE","STEAM","STEEL","STEEP","STEER","STERN","STICK","STIFF","STILL","STOCK","STONE","STOOD","STORM",
        "STORY","STOUT","STOVE","STRAP","STRAY","STRUM","STUCK","STUDY","STUFF","STUMP","STUNG","STYLE","SUGAR",
        "SUITE","SUNNY","SUPER","SURGE","SWEAR","SWEEP","SWEET","SWEPT","SWIFT","SWING","SWIPE","SWOOP","SWORD",
        "TABLE","TASTE","TAUNT","THORN","THREE","TIGER","TIMER","TIRED","TITLE","TOAST","TOKEN","TORCH","TOTAL",
        "TOUCH","TOUGH","TOWER","TOXIC","TRACE","TRACK","TRADE","TRAIL","TRAIN","TRAMP","TREAD","TREND","TRIBE",
        "TRICK","TRIED","TROOP","TROTH","TRUCK","TRULY","TRUMP","TRUNK","TRUST","TRUTH","TULIP","TUMOR","TUNIC",
        "UNION","UNITY","UNTIL","UPPER","USAGE","UTTER","VAGUE","VALID","VAULT","VIGOR","VIRAL","VISIT","VISTA",
        "VITAL","VIVID","VOCAL","VOICE","VOUCH","WALTZ","WASTE","WATCH","WATER","WEARY","WEAVE","WEDGE","WEEDY",
        "WEIGH","WEIRD","WHALE","WHEAT","WHEEL","WHERE","WHICH","WHILE","WHITE","WHOLE","WHOSE","WIDER","WIELD",
        "WINDY","WITCH","WOMAN","WOMEN","WOOZY","WORLD","WORRY","WORSE","WORST","WORTH","WOULD","WRACK","WRATH",
        "WREAK","WRECK","WROTE","YOUNG","YOUTH","ZIPPY",
        // 6-letter words
        "ABSENT","ACCENT","ACCEPT","ACCESS","ANIMAL","ANNUAL","ANSWER","ANYONE","ATTACK","BATTLE","BEAUTY","BEHIND",
        "BELONG","BETTER","BEYOND","BITTER","BRIDGE","BROKEN","BUDGET","BUTTER","CANDLE","CARBON","CASTLE","CATTLE",
        "CAUGHT","CHANCE","CHANGE","CHARGE","CHEEKY","CHERRY","CHOICE","CHOOSE","CIRCLE","CLEVER","CLOSER","COFFEE",
        "COMBAT","COMMIT","CORNER","COTTON","COUPLE","CREATE","CUSTOM","DAMAGE","DANGER","DEBATE","DECIDE","DEFEAT",
        "DEFEND","DESIGN","DETAIL","DINNER","DIRECT","DIVIDE","DOUBLE","ENOUGH","ENTITY","ENTIRE","ESCAPE","EVENTS",
        "EXPERT","EXTEND","FACTOR","FALLEN","FAMILY","FAMOUS","FASTER","FATHER","FIGURE","FINGER","FOLLOW","FOREST",
        "FORMAL","FROZEN","FUTURE","GARDEN","GATHER","GENTLE","GLOBAL","GOVERN","GRAVEL","GROUND","GROWTH","HAPPEN",
        "HARBOR","HUNGRY","HUNTER","IMPACT","INCOME","INSULT","ISLAND","ITSELF","JACKET","JUNGLE","JUNIOR","KEEPER",
        "KERNEL","KNIGHT","LADDER","LANCER","LAUNCH","LEADER","LESSEN","LETTER","LISTEN","LITTLE","LOVING","LUXURY",
        "MAGNET","MANNER","MARBLE","MARKET","MATTER","MEMBER","MIGHTY","MIRROR","MODERN","MOMENT","MORTAL","MOTHER",
        "MOTION","MUSCLE","MUTUAL","MYSELF","NARROW","NATION","NATURE","NEARLY","NEEDLE","OBJECT","OLDEST","ONLINE",
        "ORANGE","ORIGIN","OUTPUT","PARENT","PATROL","PEOPLE","PLANET","PLAYER","PLENTY","POCKET","PONDER","PORTAL",
        "PRETTY","PRISON","PROPER","PUBLIC","PURPLE","PUZZLE","RABBIT","RADIAL","RANDOM","REASON","RECORD","REFUSE",
        "REMAIN","REMOTE","RENTAL","REPAIR","REPEAT","RESCUE","RESULT","RETURN","REVIEW","RISING","ROCKET","ROTATE",
        "RUSTIC","SAMPLE","SCHEME","SCHOOL","SEARCH","SECURE","SELECT","SERIES","SIGNAL","SILVER","SIMPLE","SINGLE",
        "SISTER","SLIGHT","SMOOTH","SNATCH","SOCIAL","SOCKET","SOLACE","SOLVER","SORROW","SORTED","SOURCE","SIMPLE",
        "SPREAD","SQUARE","STABLE","STATUE","STEADY","STRIDE","STRIKE","STRING","STRONG","SUMMER","SUPPLY","SWITCH",
        "SYSTEM","TARGET","THEORY","THIRTY","THOUGH","THREAD","THREAT","THROAT","TIMBER","TONGUE","TRAVEL","TRIPLE",
        "TUNNEL","TURTLE","TWELVE","TWENTY","UPWARD","USEFUL","WISDOM","WITHIN","WONDER","WOODEN","WRITER","YELLOW"
    ]
}
