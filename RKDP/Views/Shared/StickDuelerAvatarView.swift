import SwiftUI

struct StickDuelerAvatarView: View {
    var style: AvatarStyle
    var size: CGFloat = 56
    var initials: String? = nil
    var allowsMotion: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppPreferenceKeys.reduceExtraAnimations) private var reduceExtraAnimations = false
    @State private var isVisible = false
    @State private var auraSpin = false
    @State private var softPulse = false
    @State private var bodyShimmer = false
    @State private var isInViewport = true
    @State private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var lineWidth: CGFloat { max(1.1, size * 0.032) }
    private var bodyOutlineColor: Color { Color(hex: "F8EFFF").opacity(0.84) }
    private var scale: CGFloat { size / 100 }
    private var motionDisabled: Bool {
        !allowsMotion || reduceMotion || reduceExtraAnimations || lowPowerMode
    }
    private var shouldAnimate: Bool {
        isVisible && isInViewport && scenePhase == .active && !motionDisabled
    }
    private var auraContainmentScale: CGFloat {
        guard style.aura != "avatar_aura_none" else { return 1 }
        if style.aura == "avatar_aura_storm" || style.aura == "avatar_aura_cosmic" { return 1 }
        return auraShouldSpin ? 0.74 : 0.86
    }
    private var auraPulseScale: CGFloat {
        guard shouldAnimate && style.aura != "avatar_aura_none" else { return auraContainmentScale }
        if style.aura == "avatar_aura_storm" || style.aura == "avatar_aura_cosmic" { return 1 }
        return auraContainmentScale * (softPulse ? 1.04 : 0.97)
    }
    private var auraSpinDuration: Double {
        style.aura == "avatar_aura_cosmic" ? 12.0 : 7.5
    }
    private var isSceneAura: Bool {
        style.aura == "avatar_aura_storm" || style.aura == "avatar_aura_cosmic"
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "F24793"), Color(hex: "F76378")], startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.72))
                .overlay(Circle().stroke(Color.white.opacity(0.30), lineWidth: max(1, size * 0.024)))
            auraView
                .frame(width: size, height: size, alignment: .center)
                .scaleEffect(auraPulseScale)
                .rotationEffect(.degrees(shouldAnimate && auraShouldSpin ? (auraSpin ? 360 : 0) : 0))
                .animation(shouldAnimate ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : nil, value: softPulse)
                .animation(shouldAnimate && auraShouldSpin ? .linear(duration: auraSpinDuration).repeatForever(autoreverses: false) : nil, value: auraSpin)
            mascot
        }
        .frame(width: size, height: size)
        .shadow(color: auraColor.opacity(style.aura == "avatar_aura_none" ? 0.18 : (isSceneAura ? 0.24 : 0.52)), radius: size * (isSceneAura ? 0.07 : 0.15))
        .accessibilityLabel("Puzzle piece avatar")
        .modifier(AvatarScrollVisibility(isVisible: $isInViewport))
        .onAppear {
            isVisible = true
            guard !motionDisabled else { return }
            startMotionOnNextRunLoop()
        }
        .onDisappear {
            isVisible = false
            auraSpin = false
            softPulse = false
            bodyShimmer = false
        }
        .onChange(of: reduceMotion) { _, _ in
            updateMotionState()
        }
        .onChange(of: reduceExtraAnimations) { _, _ in
            updateMotionState()
        }
        .onChange(of: shouldAnimate) { _, _ in
            updateMotionState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private var mascot: some View {
        ZStack {
            limbsBack
            puzzleBody
            face
                .shadow(color: Color(hex: "241D38").opacity(0.40), radius: 0.5 * scale, y: 0.7 * scale)
            headwear
            limbsFront
            if !usesMaterialSkin {
                outfitAccent
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var auraView: some View {
        switch style.aura {
        case "avatar_aura_teal":
            Circle().fill(Color(hex: "12C8A2").opacity(0.25)).blur(radius: size * 0.12)
        case "avatar_aura_pink":
            Circle().fill(Color(hex: "FF2F78").opacity(0.28)).blur(radius: size * 0.12)
        case "avatar_aura_crown":
            Circle().fill(Color(hex: "FFD36B").opacity(0.26)).blur(radius: size * 0.14)
        case "avatar_aura_storm":
            stormCloudAura
        case "avatar_aura_lava":
            Circle().fill(Color(hex: "FF6B1A").opacity(0.25)).blur(radius: size * 0.10)
                .overlay(Circle().stroke(Color(hex: "FF2F78").opacity(0.38), lineWidth: max(1, size * 0.03)).scaleEffect(0.86))
        case "avatar_aura_star":
            Circle().fill(Color(hex: "FFD36B").opacity(0.18)).blur(radius: size * 0.10)
                .overlay(Image(systemName: "sparkles").font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(Color(hex: "FFD36B").opacity(0.55)))
        case "avatar_aura_pixel":
            pixelAura
        case "avatar_aura_mint":
            Circle().fill(Color(hex: "23D18B").opacity(0.24)).blur(radius: size * 0.13)
        case "avatar_aura_royal":
            Circle().stroke(Color(hex: "FFD36B").opacity(0.78), lineWidth: max(2, size * 0.045))
                .overlay(Circle().stroke(Color(hex: "FF2F78").opacity(0.54), lineWidth: max(1, size * 0.025)).scaleEffect(0.76))
        case "avatar_aura_confetti":
            Circle().fill(Color(hex: "FF2F78").opacity(0.18)).blur(radius: size * 0.10)
                .overlay(confettiAura)
        case "avatar_aura_bubblegum":
            Circle().fill(Color(hex: "FF9ED1").opacity(0.22)).blur(radius: size * 0.13)
                .overlay(Circle().stroke(Color(hex: "39D5FF").opacity(0.58), lineWidth: max(1, size * 0.025)).scaleEffect(0.82))
                .overlay(bubbleAuraDetails)
        case "avatar_aura_stage_light":
            Circle().fill(Color(hex: "39D5FF").opacity(0.18)).blur(radius: size * 0.12)
                .overlay(Triangle().fill(Color.white.opacity(0.28)).frame(width: 72 * scale, height: 72 * scale).rotationEffect(.degrees(180)).offset(y: 18 * scale))
                .overlay(stageLightAuraDetails)
        case "avatar_aura_teal_orbit":
            Circle().stroke(Color(hex: "12C8A2").opacity(0.84), lineWidth: max(2, size * 0.04)).rotationEffect(.degrees(-18))
                .overlay(Circle().stroke(Color(hex: "8FFFE1").opacity(0.54), lineWidth: max(1, size * 0.025)).scaleEffect(0.72).rotationEffect(.degrees(18)))
                .overlay(orbitAuraDetails)
        case "avatar_aura_prism":
            Circle().fill(Color(hex: "7B42FF").opacity(0.18)).blur(radius: size * 0.10)
                .overlay(Circle().stroke(LinearGradient(colors: [Color(hex: "FF2F78"), Color(hex: "12C8A2"), Color(hex: "FFD36B")], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: max(2, size * 0.045)).scaleEffect(0.88))
                .overlay(prismAuraDetails)
        case "avatar_aura_crystal":
            Circle().fill(Color(hex: "78D7FF").opacity(0.20)).blur(radius: size * 0.12)
                .overlay(crystalAura)
        case "avatar_aura_gold_crown":
            Circle().stroke(Color(hex: "FFD36B").opacity(0.82), lineWidth: max(2, size * 0.046))
                .overlay(Image(systemName: "crown.fill").font(.system(size: max(10, 19 * scale), weight: .black)).foregroundStyle(Color(hex: "FFD36B")).offset(y: -40 * scale))
                .overlay(goldCrownAuraDetails)
        case "avatar_aura_cosmic":
            cosmicAura
        default:
            Circle().fill(Color.white.opacity(0.04))
        }
    }

    private var pixelAura: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18)
                .stroke(Color(hex: "7B42FF").opacity(0.78), lineWidth: max(2, size * 0.04))
                .frame(width: 70 * scale, height: 70 * scale)
                .rotationEffect(.degrees(8))
            RoundedRectangle(cornerRadius: size * 0.13)
                .stroke(Color(hex: "39D5FF").opacity(0.38), lineWidth: max(1, size * 0.022))
                .frame(width: 54 * scale, height: 54 * scale)
                .scaleEffect(0.76)
                .rotationEffect(.degrees(-8))
            pixelBlock(Color(hex: "FFD36B"), x: -27, y: -25)
            pixelBlock(Color(hex: "39D5FF"), x: 27, y: -19)
            pixelBlock(Color(hex: "FF2F78"), x: -26, y: 25)
            pixelBlock(Color(hex: "12C8A2"), x: 26, y: 25)
        }
        .frame(width: size, height: size, alignment: .center)
    }

    private var stormCloudAura: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "45698A"), Color(hex: "91B6CE")], startPoint: .top, endPoint: .bottom))
                .opacity(0.85)
                .frame(width: 94 * scale, height: 94 * scale)
            cloudPuff(width: 24, height: 17, x: -33, y: 1, opacity: 0.90)
            cloudPuff(width: 17, height: 19, x: -37, y: -6, opacity: 0.95)
            cloudPuff(width: 23, height: 16, x: 33, y: 8, opacity: 0.90)
            cloudPuff(width: 18, height: 21, x: 36, y: 0, opacity: 0.95)
            cloudPuff(width: 53, height: 13, x: 0, y: 35, opacity: 0.62)
            LightningShape()
                .fill(LinearGradient(colors: [Color.white, Color(hex: "FFD36B")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 8 * scale, height: 15 * scale)
                .offset(x: -36 * scale, y: 17 * scale)
                .opacity(shouldAnimate ? (softPulse ? 1 : 0.45) : 0.82)
            raindrop(x: 37, y: 26, opacity: shouldAnimate && softPulse ? 0.95 : 0.5)
            raindrop(x: -28, y: 30, opacity: 0.65)
        }
        .frame(width: size, height: size, alignment: .center)
    }

    private func cloudPuff(width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) -> some View {
        Ellipse()
            .fill(Color(hex: "D7F2FF").opacity(opacity))
            .frame(width: width * scale, height: height * scale)
            .overlay(Ellipse().stroke(Color.white.opacity(0.42), lineWidth: max(0.6, lineWidth * 0.18)))
            .offset(x: x * scale, y: y * scale)
            .shadow(color: Color(hex: "4D8DFF").opacity(0.18), radius: 4 * scale)
    }

    private func raindrop(x: CGFloat, y: CGFloat, opacity: Double) -> some View {
        Capsule()
            .fill(Color(hex: "78D7FF").opacity(opacity))
            .frame(width: 3.5 * scale, height: 11 * scale)
            .rotationEffect(.degrees(15))
            .offset(x: x * scale, y: y * scale)
    }

    private var cosmicAura: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "455498"), Color(hex: "171C40"), Color(hex: "30365D")], center: .center, startRadius: 7 * scale, endRadius: 48 * scale))
                .frame(width: 94 * scale, height: 94 * scale)
            Ellipse()
                .stroke(Color(hex: "78D7FF").opacity(0.7), lineWidth: max(0.7, size * 0.014))
                .frame(width: 87 * scale, height: 54 * scale)
                .rotationEffect(.degrees(-18))
                .offset(y: 8 * scale)
            Ellipse()
                .stroke(Color(hex: "FFD36B").opacity(0.4), lineWidth: max(0.6, size * 0.01))
                .frame(width: 84 * scale, height: 46 * scale)
                .rotationEffect(.degrees(20))
                .offset(y: 8 * scale)
            planetDot(Color(hex: "FFD36B"), size: 7, x: -39, y: 20)
            planetDot(Color(hex: "78D7FF"), size: 5, x: 39, y: -3)
            starDot(size: 5, x: -30, y: -24, opacity: shouldAnimate && softPulse ? 1 : 0.55)
            starDot(size: 4, x: 29, y: 30, opacity: shouldAnimate && softPulse ? 0.55 : 1)
            starDot(size: 3, x: -10, y: 41, opacity: 0.85)
        }
        .frame(width: size, height: size, alignment: .center)
    }

    private func planetDot(_ color: Color, size dotSize: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.86))
            .frame(width: dotSize * scale, height: dotSize * scale)
            .overlay(Circle().stroke(Color.white.opacity(0.38), lineWidth: max(0.5, scale * 0.7)))
            .offset(x: x * scale, y: y * scale)
    }

    private func starDot(size dotSize: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) -> some View {
        Diamond()
            .fill(Color.white.opacity(opacity))
            .frame(width: dotSize * scale, height: dotSize * scale)
            .offset(x: x * scale, y: y * scale)
    }

    private func pixelBlock(_ color: Color, x: CGFloat, y: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: max(1, 1.5 * scale))
            .fill(color.opacity(0.92))
            .frame(width: 7 * scale, height: 7 * scale)
            .overlay(RoundedRectangle(cornerRadius: max(1, 1.5 * scale)).stroke(Color.white.opacity(0.48), lineWidth: max(0.5, scale)))
            .offset(x: x * scale, y: y * scale)
    }

    private func bubbleGem(size gemSize: CGFloat, color: Color, y: CGFloat) -> some View {
        Circle()
            .fill(LinearGradient(colors: [Color.white.opacity(0.55), color.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: gemSize * scale, height: gemSize * scale)
            .overlay(Circle().stroke(Color.white.opacity(0.62), lineWidth: max(0.7, lineWidth * 0.16)))
            .shadow(color: color.opacity(0.22), radius: 3 * scale)
            .offset(y: y * scale)
    }

    private var bubbleAuraDetails: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.55), lineWidth: max(1, scale)).frame(width: 13 * scale, height: 13 * scale).offset(x: -33 * scale, y: -21 * scale)
            Circle().stroke(Color(hex: "39D5FF").opacity(0.65), lineWidth: max(1, scale)).frame(width: 10 * scale, height: 10 * scale).offset(x: 33 * scale, y: 22 * scale)
            Circle().fill(Color.white.opacity(0.38)).frame(width: 4 * scale, height: 4 * scale).offset(x: -21 * scale, y: 32 * scale)
        }
    }

    private var stageLightAuraDetails: some View {
        ZStack {
            Capsule().fill(Color.white.opacity(0.34)).frame(width: 7 * scale, height: 16 * scale).rotationEffect(.degrees(-22)).offset(x: -28 * scale, y: -23 * scale)
            Capsule().fill(Color(hex: "FFD36B").opacity(0.46)).frame(width: 7 * scale, height: 16 * scale).rotationEffect(.degrees(22)).offset(x: 28 * scale, y: -23 * scale)
            Circle().fill(Color.white.opacity(0.42)).frame(width: 8 * scale, height: 8 * scale).offset(y: 36 * scale)
        }
    }

    private var orbitAuraDetails: some View {
        ZStack {
            Circle().fill(Color(hex: "8FFFE1")).frame(width: 7 * scale, height: 7 * scale).offset(x: -32 * scale, y: -12 * scale)
            Circle().fill(Color(hex: "FFD36B")).frame(width: 6 * scale, height: 6 * scale).offset(x: 32 * scale, y: 14 * scale)
            Circle().fill(Color.white.opacity(0.64)).frame(width: 4 * scale, height: 4 * scale).offset(x: 8 * scale, y: -35 * scale)
        }
    }

    private var prismAuraDetails: some View {
        ZStack {
            Diamond().fill(Color(hex: "FF2F78").opacity(0.72)).frame(width: 8 * scale, height: 12 * scale).offset(x: -32 * scale, y: -18 * scale)
            Diamond().fill(Color(hex: "FFD36B").opacity(0.72)).frame(width: 8 * scale, height: 12 * scale).offset(x: 32 * scale, y: 19 * scale)
            Circle().fill(Color(hex: "12C8A2").opacity(0.82)).frame(width: 5 * scale, height: 5 * scale).offset(x: 28 * scale, y: -27 * scale)
        }
    }

    private var goldCrownAuraDetails: some View {
        ZStack {
            Capsule().fill(Color(hex: "FFD36B").opacity(0.56)).frame(width: 5 * scale, height: 15 * scale).offset(x: -29 * scale, y: -25 * scale).rotationEffect(.degrees(-18))
            Capsule().fill(Color(hex: "FFD36B").opacity(0.56)).frame(width: 5 * scale, height: 15 * scale).offset(x: 29 * scale, y: -25 * scale).rotationEffect(.degrees(18))
            Circle().fill(Color.white.opacity(0.58)).frame(width: 5 * scale, height: 5 * scale).offset(y: -37 * scale)
        }
    }

    private var cosmicAuraDetails: some View {
        ZStack {
            Circle().fill(Color(hex: "FFD36B").opacity(0.8)).frame(width: 5 * scale, height: 5 * scale).offset(x: -33 * scale, y: -18 * scale)
            Circle().fill(Color(hex: "FF2F78").opacity(0.76)).frame(width: 5 * scale, height: 5 * scale).offset(x: 31 * scale, y: 23 * scale)
            Image(systemName: "star.fill").font(.system(size: max(5, 8 * scale), weight: .black)).foregroundStyle(Color.white.opacity(0.72)).offset(x: 26 * scale, y: -28 * scale)
        }
    }

    private var confettiAura: some View {
        ZStack {
            Circle().fill(Color(hex: "FFD36B")).frame(width: 6 * scale, height: 6 * scale).offset(x: -34 * scale, y: -19 * scale)
            Circle().fill(Color(hex: "39D5FF")).frame(width: 5 * scale, height: 5 * scale).offset(x: 34 * scale, y: -15 * scale)
            Capsule().fill(Color(hex: "FF2F78")).frame(width: 4 * scale, height: 10 * scale).rotationEffect(.degrees(28)).offset(x: -27 * scale, y: 29 * scale)
            Capsule().fill(Color(hex: "12C8A2")).frame(width: 4 * scale, height: 10 * scale).rotationEffect(.degrees(-24)).offset(x: 28 * scale, y: 28 * scale)
        }
    }

    private var crystalAura: some View {
        ZStack {
            Diamond().fill(Color(hex: "E8F7FF").opacity(0.82)).frame(width: 10 * scale, height: 15 * scale).offset(x: -34 * scale, y: -24 * scale)
            Diamond().fill(Color(hex: "78D7FF").opacity(0.78)).frame(width: 9 * scale, height: 13 * scale).offset(x: 34 * scale, y: -17 * scale)
            Diamond().fill(Color(hex: "12C8A2").opacity(0.62)).frame(width: 8 * scale, height: 12 * scale).offset(x: 30 * scale, y: 30 * scale)
        }
    }

    private var puzzleBody: some View {
        let bodySize = 56 * scale
        return ZStack {
            PuzzlePieceShape()
                .fill(bodyFill)
                .frame(width: bodySize, height: bodySize)
            if usesMaterialSkin {
                AvatarBodyMaterial(outfit: style.outfit, animates: shouldAnimate)
                    .frame(width: bodySize, height: bodySize)
                    .clipShape(PuzzlePieceShape())
            } else {
                bodyMotif
                    .frame(width: bodySize, height: bodySize)
                    .clipShape(PuzzlePieceShape())
                animatedBodyOverlay
                    .frame(width: bodySize, height: bodySize)
                    .clipShape(PuzzlePieceShape())
            }
            PuzzlePieceShape()
                .stroke(bodyOutlineColor, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                .frame(width: bodySize, height: bodySize)
        }
        .shadow(color: bodyColor.opacity(0.28), radius: size * 0.08, x: 0, y: size * 0.04)
        .offset(y: 4 * scale)
    }

    private var usesMaterialSkin: Bool {
        ["avatar_outfit_frost", "avatar_outfit_lava", "avatar_outfit_obsidian",
         "avatar_outfit_prism", "avatar_outfit_starlight", "avatar_outfit_hoodie",
         "avatar_outfit_candy", "avatar_outfit_armor", "avatar_outfit_royal_velvet"].contains(style.outfit)
    }

    @ViewBuilder
    private var animatedBodyOverlay: some View {
        if shouldAnimate && bodyShouldAnimate {
            switch style.outfit {
            case "avatar_outfit_hoodie":
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color(hex: "8FFFE1").opacity(0.30), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 12 * scale, height: 72 * scale)
                    .rotationEffect(.degrees(18))
                    .offset(x: bodyShimmer ? 37 * scale : -37 * scale)
                    .animation(.easeInOut(duration: 3.1).repeatForever(autoreverses: false), value: bodyShimmer)
            case "avatar_outfit_armor":
                ShieldShape()
                    .stroke(Color.white.opacity(bodyShimmer ? 0.60 : 0.18), lineWidth: max(1, lineWidth * 0.22))
                    .frame(width: 35 * scale, height: 41 * scale)
                    .offset(y: 4 * scale)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: bodyShimmer)
            case "avatar_outfit_neon":
                ZStack {
                    RoundedRectangle(cornerRadius: 5 * scale)
                        .stroke(Color(hex: "39D5FF").opacity(bodyShimmer ? 0.86 : 0.24), lineWidth: max(1, lineWidth * 0.25))
                        .frame(width: 41 * scale, height: 41 * scale)
                    RoundedRectangle(cornerRadius: 3 * scale)
                        .stroke(Color(hex: "FF2F78").opacity(bodyShimmer ? 0.24 : 0.82), lineWidth: max(1, lineWidth * 0.20))
                        .frame(width: 27 * scale, height: 27 * scale)
                        .rotationEffect(.degrees(45))
                }
                .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: bodyShimmer)
            case "avatar_outfit_prism":
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.36),
                                Color(hex: "12C8A2").opacity(0.22),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 18 * scale, height: 76 * scale)
                    .rotationEffect(.degrees(24))
                    .offset(x: bodyShimmer ? 43 * scale : -43 * scale)
                    .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: false), value: bodyShimmer)
            case "avatar_outfit_lava":
                ZStack {
                    lavaBubble(x: -15, y: bodyShimmer ? -21 : 17, size: 7)
                    lavaBubble(x: 13, y: bodyShimmer ? 16 : -18, size: 5)
                    lavaBubble(x: 3, y: bodyShimmer ? -3 : 24, size: 4)
                }
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: bodyShimmer)
            case "avatar_outfit_frost":
                ZStack {
                    frostWisp(x: -17, y: bodyShimmer ? -20 : 10, width: 17, opacity: bodyShimmer ? 0.54 : 0.18)
                    frostWisp(x: 5, y: bodyShimmer ? -12 : 16, width: 22, opacity: bodyShimmer ? 0.22 : 0.50)
                    frostWisp(x: 20, y: bodyShimmer ? -24 : 4, width: 14, opacity: bodyShimmer ? 0.46 : 0.16)
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.34), .clear], startPoint: .top, endPoint: .bottom))
                        .frame(width: 10 * scale, height: 70 * scale)
                        .rotationEffect(.degrees(-30))
                        .offset(x: bodyShimmer ? 37 * scale : -37 * scale)
                }
                .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: bodyShimmer)
            case "avatar_outfit_crystal":
                ZStack {
                    Diamond().fill(Color.white.opacity(0.36)).frame(width: 9 * scale, height: 16 * scale).offset(x: -12 * scale, y: bodyShimmer ? -13 * scale : -8 * scale)
                    Diamond().fill(Color(hex: "E8F7FF").opacity(0.28)).frame(width: 7 * scale, height: 13 * scale).offset(x: 13 * scale, y: bodyShimmer ? 10 * scale : 15 * scale)
                }
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: bodyShimmer)
            case "avatar_outfit_obsidian":
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color(hex: "78D7FF").opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 14 * scale, height: 74 * scale)
                    .rotationEffect(.degrees(-28))
                    .offset(x: bodyShimmer ? 40 * scale : -40 * scale)
                    .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: false), value: bodyShimmer)
            case "avatar_outfit_galaxy", "avatar_outfit_starlight":
                ZStack {
                    starDot(size: 5, x: bodyShimmer ? -18 : -12, y: -12, opacity: bodyShimmer ? 0.92 : 0.42)
                    starDot(size: 4, x: bodyShimmer ? 18 : 13, y: 9, opacity: bodyShimmer ? 0.42 : 0.86)
                    planetDot(Color(hex: "FFD36B"), size: 4, x: bodyShimmer ? 5 : 11, y: 18)
                }
                .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: bodyShimmer)
            case "avatar_outfit_candy":
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.42), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 16 * scale, height: 78 * scale)
                    .rotationEffect(.degrees(28))
                    .offset(x: bodyShimmer ? 42 * scale : -42 * scale)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: false), value: bodyShimmer)
            case "avatar_outfit_bubblegum":
                ZStack {
                    bubbleDot(x: -16, y: bodyShimmer ? -16 : -10, size: 7, color: Color.white.opacity(0.32))
                    bubbleDot(x: 13, y: bodyShimmer ? 7 : 14, size: 9, color: Color(hex: "39D5FF").opacity(0.28))
                }
                .animation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true), value: bodyShimmer)
            case "avatar_outfit_mint":
                ZStack {
                    leafShape(Color.white.opacity(0.26), x: bodyShimmer ? -17 : -11, y: bodyShimmer ? -8 : 4, angle: -24)
                    leafShape(Color(hex: "8FFFE1").opacity(0.24), x: bodyShimmer ? 15 : 9, y: bodyShimmer ? 7 : 15, angle: 28)
                }
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: bodyShimmer)
            case "avatar_outfit_sunset":
                ZStack {
                    Circle()
                        .fill(Color(hex: "FFD36B").opacity(bodyShimmer ? 0.32 : 0.12))
                        .frame(width: 30 * scale, height: 30 * scale)
                        .offset(y: bodyShimmer ? -8 * scale : -2 * scale)
                    Capsule()
                        .fill(Color.white.opacity(bodyShimmer ? 0.36 : 0.14))
                        .frame(width: 38 * scale, height: 3 * scale)
                        .offset(y: 17 * scale)
                }
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: bodyShimmer)
            case "avatar_outfit_arcade_jacket":
                HStack(spacing: 10 * scale) {
                    Circle().fill(Color(hex: "FFD36B").opacity(bodyShimmer ? 0.95 : 0.28)).frame(width: 5 * scale, height: 5 * scale)
                    Circle().fill(Color.white.opacity(bodyShimmer ? 0.28 : 0.86)).frame(width: 5 * scale, height: 5 * scale)
                }
                .offset(y: 14 * scale)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: bodyShimmer)
            case "avatar_outfit_teal_gold":
                ZStack {
                    Diamond()
                        .fill(Color(hex: "FFD36B").opacity(bodyShimmer ? 0.42 : 0.16))
                        .frame(width: 25 * scale, height: 33 * scale)
                    starDot(size: 5, x: bodyShimmer ? -14 : 14, y: bodyShimmer ? -12 : 11, opacity: bodyShimmer ? 0.82 : 0.34)
                }
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: bodyShimmer)
            case "avatar_outfit_royal", "avatar_outfit_royal_velvet":
                ZStack {
                    Circle().fill(Color.white.opacity(0.32)).frame(width: 5 * scale, height: 5 * scale).offset(x: -14 * scale, y: bodyShimmer ? -16 * scale : -11 * scale)
                    Image(systemName: "sparkle").font(.system(size: max(5, 8 * scale), weight: .black)).foregroundStyle(Color(hex: "FFD36B").opacity(0.64)).offset(x: 15 * scale, y: bodyShimmer ? 13 * scale : 8 * scale)
                }
                .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: bodyShimmer)
            default:
                EmptyView()
            }
        }
    }

    private func lavaBubble(x: CGFloat, y: CGFloat, size bubbleSize: CGFloat) -> some View {
        Circle()
            .fill(Color(hex: "FFD36B").opacity(0.38))
            .frame(width: bubbleSize * scale, height: bubbleSize * scale)
            .overlay(Circle().stroke(Color.white.opacity(0.26), lineWidth: max(0.5, scale)))
            .offset(x: x * scale, y: y * scale)
    }

    private func frostWisp(x: CGFloat, y: CGFloat, width: CGFloat, opacity: Double) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(opacity), Color(hex: "78D7FF").opacity(opacity * 0.42), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width * scale, height: 4 * scale)
            .blur(radius: 1.1 * scale)
            .offset(x: x * scale, y: y * scale)
    }

    private var bodyFill: LinearGradient {
        LinearGradient(
            colors: [bodyHighlight, bodyColor, bodyShadow],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var bodyMotif: some View {
        switch style.outfit {
        case "avatar_outfit_hoodie":
            ZStack {
                Capsule().fill(Color.white.opacity(0.46)).frame(width: 30 * scale, height: 4 * scale).offset(y: -10 * scale)
                HStack(spacing: 15 * scale) {
                    Capsule().fill(Color(hex: "078A76").opacity(0.52)).frame(width: 4 * scale, height: 21 * scale)
                    Capsule().fill(Color.white.opacity(0.50)).frame(width: 4 * scale, height: 21 * scale)
                }
                .offset(y: 7 * scale)
            }
        case "avatar_outfit_cape":
            ZStack {
                Diamond().fill(Color.white.opacity(0.28)).frame(width: 42 * scale, height: 28 * scale).offset(y: 2 * scale)
                Capsule().fill(Color(hex: "FFD36B").opacity(0.76)).frame(width: 26 * scale, height: 4 * scale).offset(y: -14 * scale)
                Diamond().fill(Color(hex: "FF2F78").opacity(0.85)).frame(width: 10 * scale, height: 14 * scale).offset(y: 6 * scale)
            }
        case "avatar_outfit_armor":
            ZStack {
                ShieldShape().fill(Color.white.opacity(0.24)).frame(width: 32 * scale, height: 38 * scale).offset(y: 4 * scale)
                ShieldShape().stroke(Color.white.opacity(0.58), lineWidth: max(1, lineWidth * 0.24)).frame(width: 29 * scale, height: 34 * scale).offset(y: 4 * scale)
                Capsule().fill(Color(hex: "1668D9").opacity(0.56)).frame(width: 5 * scale, height: 33 * scale).offset(y: 4 * scale)
            }
        case "avatar_outfit_neon":
            ZStack {
                RoundedRectangle(cornerRadius: 4 * scale).stroke(Color(hex: "39D5FF").opacity(0.82), lineWidth: max(1, lineWidth * 0.34)).frame(width: 35 * scale, height: 35 * scale)
                RoundedRectangle(cornerRadius: 2 * scale).stroke(Color(hex: "FF2F78").opacity(0.82), lineWidth: max(1, lineWidth * 0.26)).frame(width: 23 * scale, height: 23 * scale).rotationEffect(.degrees(45))
                Capsule().fill(Color.white.opacity(0.58)).frame(width: 5 * scale, height: 30 * scale)
            }
        case "avatar_outfit_royal":
            ZStack {
                Image(systemName: "crown.fill").font(.system(size: max(9, 16 * scale), weight: .black)).foregroundStyle(Color(hex: "D99500").opacity(0.82)).offset(y: -6 * scale)
                Capsule().fill(Color.white.opacity(0.42)).frame(width: 31 * scale, height: 4 * scale).offset(y: 16 * scale)
                HStack(spacing: 14 * scale) {
                    Diamond().fill(Color(hex: "FF2F78").opacity(0.82)).frame(width: 6 * scale, height: 9 * scale)
                    Diamond().fill(Color(hex: "FF2F78").opacity(0.82)).frame(width: 6 * scale, height: 9 * scale)
                }
                .offset(y: 7 * scale)
            }
        case "avatar_outfit_lava":
            ZStack {
                lavaVein(x: -14, y: 4, height: 44, angle: -18)
                lavaVein(x: 6, y: -3, height: 48, angle: 16)
                lavaVein(x: 19, y: 10, height: 31, angle: -9)
                Circle().fill(Color(hex: "FFD36B").opacity(0.46)).frame(width: 9 * scale, height: 9 * scale).offset(x: -7 * scale, y: 15 * scale)
            }
        case "avatar_outfit_frost":
            ZStack {
                frostFacet(width: 13, height: 32, x: -14, y: -4)
                frostFacet(width: 16, height: 38, x: 4, y: 4)
                frostFacet(width: 10, height: 24, x: 18, y: -9)
                Capsule().fill(Color.white.opacity(0.58)).frame(width: 34 * scale, height: 3 * scale).offset(y: 17 * scale)
            }
        case "avatar_outfit_galaxy":
            ZStack {
                Ellipse().stroke(Color(hex: "78D7FF").opacity(0.52), lineWidth: max(1, lineWidth * 0.22)).frame(width: 45 * scale, height: 18 * scale).rotationEffect(.degrees(-24))
                starDot(size: 6, x: -11, y: -11, opacity: 0.82)
                starDot(size: 4, x: 15, y: 8, opacity: 0.72)
                planetDot(Color(hex: "FFD36B"), size: 5, x: 17, y: -15)
            }
        case "avatar_outfit_mint":
            ZStack {
                Capsule().fill(Color.white.opacity(0.42)).frame(width: 29 * scale, height: 5 * scale).offset(y: -12 * scale)
                leafShape(Color(hex: "CFFFF1").opacity(0.72), x: -10, y: 8, angle: -28)
                leafShape(Color(hex: "078A76").opacity(0.52), x: 10, y: 8, angle: 28)
            }
        case "avatar_outfit_candy":
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? Color.white.opacity(0.64) : Color(hex: "FF2F78").opacity(0.58))
                        .frame(width: 5 * scale, height: 76 * scale)
                        .rotationEffect(.degrees(28))
                        .offset(x: CGFloat(index - 2) * 10 * scale)
                }
            }
        case "avatar_outfit_obsidian":
            ZStack {
                PolygonShard(points: [CGPoint(x: 0.25, y: 0.10), CGPoint(x: 0.62, y: 0.28), CGPoint(x: 0.48, y: 0.75), CGPoint(x: 0.14, y: 0.54)])
                    .fill(Color.white.opacity(0.13))
                PolygonShard(points: [CGPoint(x: 0.55, y: 0.18), CGPoint(x: 0.84, y: 0.36), CGPoint(x: 0.70, y: 0.78), CGPoint(x: 0.44, y: 0.48)])
                    .stroke(Color(hex: "78D7FF").opacity(0.35), lineWidth: max(1, lineWidth * 0.18))
                Capsule().fill(Color.white.opacity(0.28)).frame(width: 5 * scale, height: 42 * scale).rotationEffect(.degrees(35)).offset(x: 10 * scale, y: -4 * scale)
            }
        case "avatar_outfit_sunset":
            ZStack {
                Circle().fill(Color(hex: "FFD36B").opacity(0.86)).frame(width: 18 * scale, height: 18 * scale).offset(y: -5 * scale)
                ForEach(0..<4, id: \.self) { index in
                    Capsule().fill((index == 0 ? Color.white : Color(hex: "FF2F78")).opacity(0.36)).frame(width: (36 - CGFloat(index) * 6) * scale, height: 3 * scale).offset(y: (8 + CGFloat(index) * 6) * scale)
                }
            }
        case "avatar_outfit_bubblegum":
            ZStack {
                bubbleDot(x: -16, y: -11, size: 9, color: Color.white.opacity(0.55))
                bubbleDot(x: 12, y: -8, size: 13, color: Color(hex: "39D5FF").opacity(0.54))
                bubbleDot(x: -3, y: 14, size: 17, color: Color(hex: "FF2F78").opacity(0.38))
            }
        case "avatar_outfit_arcade_jacket":
            ZStack {
                HStack(spacing: 10 * scale) {
                    Capsule().fill(Color(hex: "39D5FF").opacity(0.92)).frame(width: 4 * scale, height: 52 * scale)
                    Capsule().fill(Color(hex: "FF2F78").opacity(0.92)).frame(width: 4 * scale, height: 52 * scale)
                }
                RoundedRectangle(cornerRadius: 3 * scale).stroke(Color.white.opacity(0.42), lineWidth: max(1, lineWidth * 0.20)).frame(width: 35 * scale, height: 39 * scale)
                HStack(spacing: 4 * scale) {
                    Circle().fill(Color(hex: "FFD36B")).frame(width: 4 * scale, height: 4 * scale)
                    RoundedRectangle(cornerRadius: 1 * scale).fill(Color.white.opacity(0.72)).frame(width: 9 * scale, height: 4 * scale)
                }
                .offset(y: 14 * scale)
            }
        case "avatar_outfit_teal_gold":
            ZStack {
                Diamond().fill(Color(hex: "FFD36B").opacity(0.92)).frame(width: 15 * scale, height: 20 * scale).offset(y: 1 * scale)
                Diamond().stroke(Color.white.opacity(0.58), lineWidth: max(1, lineWidth * 0.24)).frame(width: 34 * scale, height: 42 * scale)
                Capsule().fill(Color(hex: "D99500").opacity(0.72)).frame(width: 30 * scale, height: 4 * scale).offset(y: 18 * scale)
            }
        case "avatar_outfit_prism":
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(prismBandColor(index).opacity(0.72))
                        .frame(width: 7 * scale, height: 76 * scale)
                        .rotationEffect(.degrees(-30))
                        .offset(x: CGFloat(index - 2) * 9 * scale)
                }
                Diamond().stroke(Color.white.opacity(0.50), lineWidth: max(1, lineWidth * 0.18)).frame(width: 24 * scale, height: 32 * scale)
            }
        case "avatar_outfit_crystal":
            ZStack {
                frostFacet(width: 15, height: 40, x: -11, y: -1)
                frostFacet(width: 17, height: 45, x: 7, y: 4)
                Diamond().stroke(Color.white.opacity(0.64), lineWidth: max(1, lineWidth * 0.22)).frame(width: 30 * scale, height: 42 * scale)
            }
        case "avatar_outfit_royal_velvet":
            ZStack {
                Capsule().fill(Color(hex: "FFD36B").opacity(0.84)).frame(width: 36 * scale, height: 5 * scale).offset(y: -13 * scale)
                Image(systemName: "crown.fill").font(.system(size: max(8, 15 * scale), weight: .black)).foregroundStyle(Color(hex: "FFD36B").opacity(0.90)).offset(y: 2 * scale)
                HStack(spacing: 17 * scale) {
                    Circle().fill(Color.white.opacity(0.36)).frame(width: 5 * scale, height: 5 * scale)
                    Circle().fill(Color.white.opacity(0.36)).frame(width: 5 * scale, height: 5 * scale)
                }
                .offset(y: 18 * scale)
            }
        case "avatar_outfit_starlight":
            ZStack {
                Ellipse().stroke(Color(hex: "78D7FF").opacity(0.45), lineWidth: max(1, lineWidth * 0.18)).frame(width: 44 * scale, height: 18 * scale).rotationEffect(.degrees(18))
                starDot(size: 6, x: -14, y: -13, opacity: 0.84)
                starDot(size: 5, x: 15, y: -3, opacity: 0.78)
                starDot(size: 4, x: 1, y: 17, opacity: 0.68)
                planetDot(Color(hex: "FFD36B"), size: 4, x: 19, y: 15)
            }
        default:
            EmptyView()
        }
    }

    private var auraShouldSpin: Bool {
        switch style.aura {
        case "avatar_aura_pixel", "avatar_aura_teal_orbit", "avatar_aura_prism":
            return true
        default:
            return false
        }
    }

    private var bodyShouldAnimate: Bool {
        switch style.outfit {
        case "avatar_outfit_lava",
             "avatar_outfit_obsidian",
             "avatar_outfit_galaxy",
             "avatar_outfit_hoodie",
             "avatar_outfit_armor",
             "avatar_outfit_neon",
             "avatar_outfit_frost",
             "avatar_outfit_mint",
             "avatar_outfit_candy",
             "avatar_outfit_bubblegum",
             "avatar_outfit_sunset",
             "avatar_outfit_arcade_jacket",
             "avatar_outfit_teal_gold",
             "avatar_outfit_prism",
             "avatar_outfit_crystal",
             "avatar_outfit_royal",
             "avatar_outfit_royal_velvet",
             "avatar_outfit_starlight":
            return true
        default:
            return false
        }
    }

    private func updateMotionState() {
        guard shouldAnimate else {
            auraSpin = false
            softPulse = false
            bodyShimmer = false
            return
        }
        startMotionOnNextRunLoop()
    }

    private func startMotionOnNextRunLoop() {
        auraSpin = false
        softPulse = false
        bodyShimmer = false
        DispatchQueue.main.async {
            guard shouldAnimate else { return }
            auraSpin = true
            softPulse = true
            bodyShimmer = true
        }
    }

    @ViewBuilder
    private var face: some View {
        switch style.face {
        case "avatar_face_focused":
            faceEyes(left: "•", right: "•")
            mouthLine(width: 13, y: 55)
        case "avatar_face_wink":
            expressionEyes(.wink)
            expressionSmile
        case "avatar_face_shades":
            RoundedRectangle(cornerRadius: 3 * scale)
                .fill(Color.black.opacity(0.86))
                .frame(width: 33 * scale, height: 11 * scale)
                .overlay(Rectangle().fill(Color.white.opacity(0.55)).frame(width: 2 * scale, height: 11 * scale))
                .offset(y: -5 * scale)
            faceText("⌣", y: 56, size: 13)
        case "avatar_face_gem":
            HStack(spacing: 8 * scale) {
                Diamond().fill(Color(hex: "FF2F78")).frame(width: 7 * scale, height: 10 * scale)
                Diamond().fill(Color(hex: "FF2F78")).frame(width: 7 * scale, height: 10 * scale)
            }
            .offset(y: -5 * scale)
            faceText("⌣", y: 56, size: 13)
        case "avatar_face_laugh":
            expressionEyes(.laugh)
            Ellipse().fill(Color(hex: "382342"))
                .frame(width: 15 * scale, height: 10 * scale)
                .overlay(alignment: .top) {
                    Capsule().fill(.white).frame(width: 11 * scale, height: 3 * scale)
                }
                .offset(y: 8 * scale)
        case "avatar_face_determined":
            expressionEyes(.determined)
            mouthLine(width: 18, y: 56)
        case "avatar_face_sleepy":
            faceEyes(left: "-", right: "-", y: 45)
            faceText(".", y: 56, size: 13)
        case "avatar_face_star":
            HStack(spacing: 8 * scale) {
                Image(systemName: "star.fill").font(.system(size: max(8, 12 * scale), weight: .black))
                Image(systemName: "star.fill").font(.system(size: max(8, 12 * scale), weight: .black))
            }
            .foregroundStyle(Color(hex: "FFD36B"))
            .offset(y: -5 * scale)
            faceText("⌣", y: 56, size: 13)
        case "avatar_face_oops":
            faceEyes(left: "•", right: "•", y: 44)
            faceText("o", y: 56, size: 12)
        case "avatar_face_smirk":
            faceEyes(left: "•", right: "•", y: 44)
            faceText("⌒", y: 56, size: 13)
        case "avatar_face_blush":
            faceEyes(left: "•", right: "•", y: 44)
            HStack(spacing: 18 * scale) {
                Circle().fill(Color(hex: "FF2F78").opacity(0.72)).frame(width: 5 * scale, height: 5 * scale)
                Circle().fill(Color(hex: "FF2F78").opacity(0.72)).frame(width: 5 * scale, height: 5 * scale)
            }
            .offset(y: 4 * scale)
            faceText("⌣", y: 57, size: 13)
        case "avatar_face_pixel":
            HStack(spacing: 8 * scale) {
                RoundedRectangle(cornerRadius: 1 * scale).fill(.white).frame(width: 6 * scale, height: 6 * scale)
                RoundedRectangle(cornerRadius: 1 * scale).fill(.white).frame(width: 6 * scale, height: 6 * scale)
            }
            .offset(y: -6 * scale)
            mouthLine(width: 12, y: 56)
        case "avatar_face_party":
            faceEyes(left: "^", right: "^", y: 44)
            Image(systemName: "party.popper.fill")
                .font(.system(size: max(8, 12 * scale), weight: .bold))
                .foregroundStyle(Color(hex: "FFD36B"))
                .offset(x: 17 * scale, y: -11 * scale)
            faceText("⌣", y: 57, size: 13)
        case "avatar_face_robot":
            RoundedRectangle(cornerRadius: 3 * scale)
                .stroke(Color(hex: "12C8A2"), lineWidth: max(1, lineWidth * 0.45))
                .frame(width: 31 * scale, height: 12 * scale)
                .overlay(
                    HStack(spacing: 9 * scale) {
                        Circle().fill(Color(hex: "12C8A2")).frame(width: 4 * scale, height: 4 * scale)
                        Circle().fill(Color(hex: "12C8A2")).frame(width: 4 * scale, height: 4 * scale)
                    }
                )
                .offset(y: -5 * scale)
            mouthLine(width: 10, y: 57)
        case "avatar_face_lava":
            HStack(spacing: 8 * scale) {
                Image(systemName: "flame.fill").font(.system(size: max(8, 12 * scale), weight: .black))
                Image(systemName: "flame.fill").font(.system(size: max(8, 12 * scale), weight: .black))
            }
            .foregroundStyle(Color(hex: "FF6B1A"))
            .offset(y: -5 * scale)
            faceText("⌣", y: 57, size: 13)
        case "avatar_face_crown":
            HStack(spacing: 8 * scale) {
                Image(systemName: "crown.fill").font(.system(size: max(8, 12 * scale), weight: .black))
                Image(systemName: "crown.fill").font(.system(size: max(8, 12 * scale), weight: .black))
            }
            .foregroundStyle(Color(hex: "FFD36B"))
            .offset(y: -5 * scale)
            faceText("⌣", y: 57, size: 13)
        case "avatar_face_masked":
            Capsule()
                .fill(Color.black.opacity(0.78))
                .frame(width: 32 * scale, height: 12 * scale)
                .overlay(
                    HStack(spacing: 10 * scale) {
                        Circle().fill(.white).frame(width: 3 * scale, height: 3 * scale)
                        Circle().fill(.white).frame(width: 3 * scale, height: 3 * scale)
                    }
                )
                .offset(y: -5 * scale)
            faceText("⌣", y: 57, size: 13)
        case "avatar_face_heart":
            HStack(spacing: 7 * scale) {
                Image(systemName: "heart.fill").font(.system(size: max(8, 12 * scale), weight: .black))
                Image(systemName: "heart.fill").font(.system(size: max(8, 12 * scale), weight: .black))
            }
            .foregroundStyle(Color(hex: "FF2F78"))
            .offset(y: -5 * scale)
            faceText("⌣", y: 57, size: 13)
        case "avatar_face_chill":
            faceEyes(left: "-", right: "-", y: 45)
            faceText("⌣", y: 56, size: 13)
        case "avatar_face_prize":
            HStack(spacing: 7 * scale) {
                Image(systemName: "seal.fill").font(.system(size: max(8, 12 * scale), weight: .black))
                Image(systemName: "seal.fill").font(.system(size: max(8, 12 * scale), weight: .black))
            }
            .foregroundStyle(Color(hex: "FFD36B"))
            .offset(y: -5 * scale)
            faceText("⌣", y: 57, size: 13)
        case "avatar_face_glitter":
            HStack(spacing: 7 * scale) {
                Image(systemName: "sparkles").font(.system(size: max(8, 12 * scale), weight: .black))
                Image(systemName: "sparkles").font(.system(size: max(8, 12 * scale), weight: .black))
            }
            .foregroundStyle(Color(hex: "FF2F78"))
            .offset(y: -5 * scale)
            faceText("⌣", y: 57, size: 13)
        case "avatar_face_focus_laser":
            HStack(spacing: 7 * scale) {
                Capsule().fill(Color(hex: "12C8A2")).frame(width: 14 * scale, height: 3 * scale)
                Capsule().fill(Color(hex: "12C8A2")).frame(width: 14 * scale, height: 3 * scale)
            }
            .offset(y: -5 * scale)
            mouthLine(width: 17, y: 57)
        case "avatar_face_rainbow":
            rainbowEyes
            faceText("⌣", y: 57, size: 13)
        case "avatar_face_gold_smile":
            HStack(spacing: 7 * scale) {
                Image(systemName: "crown.fill").font(.system(size: max(8, 12 * scale), weight: .black))
                Image(systemName: "crown.fill").font(.system(size: max(8, 12 * scale), weight: .black))
            }
            .foregroundStyle(Color(hex: "FFD36B"))
            .offset(y: -5 * scale)
            faceText("⌣", y: 57, size: 13)
        case "avatar_face_cosmic":
            HStack(spacing: 7 * scale) {
                Image(systemName: "star.fill").font(.system(size: max(8, 12 * scale), weight: .black))
                Image(systemName: "star.fill").font(.system(size: max(8, 12 * scale), weight: .black))
            }
            .foregroundStyle(Color(hex: "78D7FF"))
            .offset(y: -5 * scale)
            faceText("⌣", y: 57, size: 13)
        default:
            expressionEyes(.smile)
            expressionSmile
        }
    }

    private enum Expression { case smile, wink, laugh, determined }

    private func expressionEyes(_ expression: Expression) -> some View {
        HStack(spacing: 12 * scale) {
            ForEach(0..<2) { index in
                ZStack {
                    if expression == .laugh || (expression == .wink && index == 1) {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 5 * scale))
                            path.addQuadCurve(to: CGPoint(x: 8 * scale, y: 5 * scale), control: CGPoint(x: 4 * scale, y: -2 * scale))
                        }
                        .stroke(.white, style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round))
                    } else {
                        Capsule().fill(.white).frame(width: 6.5 * scale, height: 8 * scale)
                        if expression == .determined {
                            Capsule().fill(Color(hex: "372A3C"))
                                .frame(width: 10 * scale, height: 2.4 * scale)
                                .rotationEffect(.degrees(index == 0 ? 18 : -18))
                                .offset(y: -5 * scale)
                        }
                    }
                }
                .frame(width: 8 * scale, height: 8 * scale)
            }
        }
        .offset(y: -6 * scale)
    }

    private var expressionSmile: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(to: CGPoint(x: 16 * scale, y: 0), control: CGPoint(x: 8 * scale, y: 10 * scale))
        }
        .stroke(.white, style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round))
        .frame(width: 16 * scale, height: 6 * scale)
        .offset(y: 8 * scale)
    }

    @ViewBuilder
    private var headwear: some View {
        switch style.head {
        case "avatar_head_crown":
            ZStack {
                CrownShape()
                    .fill(LinearGradient(colors: [Color(hex: "FFE887"), Color(hex: "FFD36B"), Color(hex: "D99500")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 34 * scale, height: 22 * scale)
                    .overlay(CrownShape().stroke(Color.white.opacity(0.52), lineWidth: max(1, lineWidth * 0.18)).frame(width: 34 * scale, height: 22 * scale))
                Diamond()
                    .fill(Color(hex: "FF2F78"))
                    .frame(width: 7 * scale, height: 10 * scale)
                    .offset(y: 1 * scale)
                Capsule()
                    .fill(Color(hex: "8A5A00").opacity(0.28))
                    .frame(width: 27 * scale, height: 4 * scale)
                    .offset(y: 10 * scale)
            }
            .offset(y: -33 * scale)
        case "avatar_head_headphones":
            Circle()
                .trim(from: 0.54, to: 0.96)
                .stroke(Color(hex: "12C8A2"), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: 48 * scale, height: 48 * scale)
                .offset(y: -3 * scale)
            HStack(spacing: 37 * scale) {
                Capsule().fill(Color(hex: "12C8A2")).frame(width: 7 * scale, height: 18 * scale)
                Capsule().fill(Color(hex: "12C8A2")).frame(width: 7 * scale, height: 18 * scale)
            }
            .offset(y: 3 * scale)
        case "avatar_head_wizard":
            wizardHat
        case "avatar_head_lightning":
            lightningHair
        case "avatar_head_halo":
            ZStack {
                Ellipse()
                    .stroke(Color(hex: "FFD36B").opacity(0.32), lineWidth: max(3, lineWidth * 1.8))
                    .frame(width: 45 * scale, height: 16 * scale)
                    .blur(radius: 1.4 * scale)
                Ellipse()
                    .stroke(LinearGradient(colors: [Color.white, Color(hex: "FFD36B"), Color(hex: "FFB72E")], startPoint: .leading, endPoint: .trailing), lineWidth: max(1.2, lineWidth * 0.76))
                    .frame(width: 43 * scale, height: 14 * scale)
                Diamond()
                    .fill(Color.white.opacity(0.82))
                    .frame(width: 5 * scale, height: 7 * scale)
                    .offset(x: 16 * scale, y: -3 * scale)
            }
            .offset(y: -39 * scale)
        case "avatar_head_puzzle_crown":
            flameCrown
        case "avatar_head_neon_visor":
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: "FF2F78"), Color(hex: "4D8DFF")], startPoint: .leading, endPoint: .trailing))
                .frame(width: 41 * scale, height: 11 * scale)
                .overlay(Capsule().stroke(Color.white.opacity(0.72), lineWidth: max(1, lineWidth * 0.35)))
                .offset(y: -19 * scale)
        case "avatar_head_star_clip":
            ZStack {
                Image(systemName: "sparkle")
                    .font(.system(size: max(7, 12 * scale), weight: .black))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .offset(x: shouldAnimate ? (softPulse ? 6 * scale : 10 * scale) : 8 * scale, y: shouldAnimate ? (softPulse ? -10 * scale : -15 * scale) : -12 * scale)
                    .opacity(shouldAnimate ? (softPulse ? 0.35 : 0.95) : 0.75)
                Image(systemName: "star.fill")
                    .font(.system(size: max(9, 20 * scale), weight: .black))
                    .foregroundStyle(LinearGradient(colors: [Color.white, Color(hex: "FFD36B"), Color(hex: "FF2F78")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .scaleEffect(shouldAnimate ? (softPulse ? 1.12 : 0.96) : 1)
                    .rotationEffect(.degrees(shouldAnimate ? (softPulse ? 7 : -4) : 0))
            }
            .offset(x: 19 * scale, y: -25 * scale)
            .animation(shouldAnimate ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : nil, value: softPulse)
        case "avatar_head_lava_helmet":
            SemiCircleShape()
                .fill(LinearGradient(colors: [Color(hex: "FFD36B"), Color(hex: "FF6B1A")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 43 * scale, height: 25 * scale)
                .offset(y: -25 * scale)
                .overlay(SemiCircleShape().stroke(Color.white.opacity(0.75), lineWidth: max(1, lineWidth * 0.35)).frame(width: 43 * scale, height: 25 * scale).offset(y: -25 * scale))
        case "avatar_head_pixel_cap":
            ZStack {
                RoundedRectangle(cornerRadius: 7 * scale, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "39D5FF"), Color(hex: "256BFF"), Color(hex: "7B42FF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 39 * scale, height: 16 * scale)
                    .overlay(RoundedRectangle(cornerRadius: 7 * scale, style: .continuous).stroke(Color.white.opacity(0.46), lineWidth: max(1, lineWidth * 0.16)))
                    .overlay(
                        HStack(spacing: 2 * scale) {
                            Rectangle().fill(Color.white.opacity(0.55)).frame(width: 5 * scale, height: 7 * scale)
                            Rectangle().fill(Color(hex: "0B1435").opacity(0.32)).frame(width: 5 * scale, height: 7 * scale)
                            Rectangle().fill(Color(hex: "FF2F78").opacity(0.64)).frame(width: 5 * scale, height: 7 * scale)
                        }
                        .offset(x: -3 * scale)
                    )
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "0B1435"), Color(hex: "256BFF")], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 27 * scale, height: 7 * scale)
                    .offset(x: 11 * scale, y: 7 * scale)
                    .overlay(Capsule().stroke(Color.white.opacity(0.34), lineWidth: max(1, lineWidth * 0.14)).offset(x: 11 * scale, y: 7 * scale))
            }
            .rotationEffect(.degrees(-2))
            .offset(x: -2 * scale, y: -29 * scale)
        case "avatar_head_mini_crown":
            ZStack {
                Circle()
                    .fill(Color(hex: "FFD36B").opacity(0.90))
                    .frame(width: 18 * scale, height: 18 * scale)
                    .overlay(Circle().stroke(Color.white.opacity(0.56), lineWidth: max(1, lineWidth * 0.18)))
                CrownShape()
                    .fill(Color(hex: "FF2F78"))
                    .frame(width: 13 * scale, height: 9 * scale)
                    .offset(y: 1 * scale)
                Diamond()
                    .fill(Color.white.opacity(0.74))
                    .frame(width: 4 * scale, height: 5 * scale)
                    .offset(y: -2 * scale)
            }
            .rotationEffect(.degrees(8))
            .offset(x: 21 * scale, y: -25 * scale)
        case "avatar_head_party_hat":
            ZStack {
                Triangle()
                    .fill(LinearGradient(colors: [Color(hex: "FF2F78"), Color(hex: "FFD36B")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 33 * scale, height: 29 * scale)
                    .overlay(Triangle().stroke(Color.white.opacity(0.62), lineWidth: max(1, lineWidth * 0.30)))
                    .offset(y: -33 * scale)
                Capsule()
                    .fill(Color.white.opacity(0.82))
                    .frame(width: 35 * scale, height: 5 * scale)
                    .offset(y: -20 * scale)
                Capsule()
                    .fill(Color(hex: "39D5FF").opacity(0.88))
                    .frame(width: 6 * scale, height: 18 * scale)
                    .rotationEffect(.degrees(26))
                    .offset(x: -5 * scale, y: -32 * scale)
                Capsule()
                    .fill(Color(hex: "FFD36B").opacity(0.92))
                    .frame(width: 5 * scale, height: 16 * scale)
                    .rotationEffect(.degrees(26))
                    .offset(x: 6 * scale, y: -30 * scale)
                Circle()
                    .fill(Color(hex: "39D5FF"))
                    .frame(width: 6 * scale, height: 6 * scale)
                    .overlay(Circle().stroke(Color.white.opacity(0.68), lineWidth: max(1, lineWidth * 0.22)))
                    .offset(y: -46 * scale)
            }
        case "avatar_head_bubble_crown":
            ZStack {
                Capsule()
                    .fill(Color(hex: "FF9ED1").opacity(0.65))
                    .frame(width: 39 * scale, height: 6 * scale)
                    .offset(y: -23 * scale)
                HStack(spacing: -2 * scale) {
                    bubbleGem(size: 15, color: Color(hex: "FF9ED1"), y: -4)
                    bubbleGem(size: 20, color: Color(hex: "39D5FF"), y: -8)
                    bubbleGem(size: 15, color: Color(hex: "FFD36B"), y: -4)
                }
                .offset(y: -31 * scale)
            }
        case "avatar_head_arcade_antenna":
            ZStack {
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "39D5FF"), Color(hex: "256BFF")], startPoint: .top, endPoint: .bottom))
                    .frame(width: 5 * scale, height: 27 * scale)
                    .offset(y: -39 * scale)
                Circle()
                    .fill(Color(hex: "FFD36B"))
                    .frame(width: 11 * scale, height: 11 * scale)
                    .overlay(Circle().stroke(Color.white.opacity(0.52), lineWidth: max(1, lineWidth * 0.16)))
                    .offset(y: -55 * scale)
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .trim(from: 0.08, to: 0.42)
                        .stroke(index == 0 ? Color(hex: "39D5FF").opacity(0.72) : Color.white.opacity(0.36), style: StrokeStyle(lineWidth: max(1, lineWidth * 0.18), lineCap: .round))
                        .frame(width: CGFloat(24 + index * 12) * scale, height: CGFloat(24 + index * 12) * scale)
                        .rotationEffect(.degrees(40))
                        .offset(y: -55 * scale)
                }
                Capsule()
                    .fill(Color(hex: "0B1435").opacity(0.42))
                    .frame(width: 24 * scale, height: 6 * scale)
                    .offset(y: -24 * scale)
            }
        case "avatar_head_prize_ribbon":
            ZStack {
                Capsule()
                    .fill(Color(hex: "11183A"))
                    .frame(width: 43 * scale, height: 8 * scale)
                    .overlay(Capsule().stroke(Color.white.opacity(0.36), lineWidth: max(1, lineWidth * 0.18)))
                    .offset(y: 7 * scale)
                RoundedRectangle(cornerRadius: 4 * scale, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "252B5A"), Color(hex: "050510")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 29 * scale, height: 27 * scale)
                    .overlay(
                        Rectangle()
                            .fill(LinearGradient(colors: [Color(hex: "FFD36B"), Color(hex: "FF2F78")], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 6 * scale)
                            .padding(.bottom, 3 * scale),
                        alignment: .bottom
                    )
                    .overlay(RoundedRectangle(cornerRadius: 4 * scale, style: .continuous).stroke(Color.white.opacity(0.32), lineWidth: max(1, lineWidth * 0.18)))
                Circle()
                    .fill(Color(hex: "FFD36B"))
                    .frame(width: 5 * scale, height: 5 * scale)
                    .offset(x: 8 * scale, y: 7 * scale)
            }
            .offset(y: -31 * scale)
        case "avatar_head_royal_headband":
            ZStack {
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "FF2F78"), Color(hex: "FFD36B")], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 47 * scale, height: 10 * scale)
                    .overlay(Capsule().stroke(Color.white.opacity(0.58), lineWidth: max(1, lineWidth * 0.20)))
                Diamond()
                    .fill(Color(hex: "78D7FF"))
                    .frame(width: 8 * scale, height: 11 * scale)
                    .overlay(Diamond().stroke(Color.white.opacity(0.42), lineWidth: max(0.6, lineWidth * 0.12)))
                HStack(spacing: 29 * scale) {
                    Circle().fill(Color(hex: "FFD36B")).frame(width: 4 * scale, height: 4 * scale)
                    Circle().fill(Color.white.opacity(0.68)).frame(width: 4 * scale, height: 4 * scale)
                }
            }
            .offset(y: -20 * scale)
        case "avatar_head_crystal_spikes":
            HStack(spacing: -3 * scale) {
                Diamond().fill(Color(hex: "78D7FF")).frame(width: 14 * scale, height: 24 * scale).overlay(Diamond().stroke(Color.white.opacity(0.44), lineWidth: max(1, lineWidth * 0.20)).frame(width: 14 * scale, height: 24 * scale))
                Diamond().fill(Color(hex: "E8F7FF")).frame(width: 16 * scale, height: 30 * scale).overlay(Diamond().stroke(Color.white.opacity(0.66), lineWidth: max(1, lineWidth * 0.20)).frame(width: 16 * scale, height: 30 * scale))
                Diamond().fill(Color(hex: "12C8A2")).frame(width: 14 * scale, height: 24 * scale).overlay(Diamond().stroke(Color.white.opacity(0.44), lineWidth: max(1, lineWidth * 0.20)).frame(width: 14 * scale, height: 24 * scale))
            }
            .offset(y: -35 * scale)
        case "avatar_head_gem_crown":
            ZStack {
                CrownShape()
                    .fill(LinearGradient(colors: [Color(hex: "FFD36B"), Color(hex: "FF2F78")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 39 * scale, height: 23 * scale)
                    .overlay(CrownShape().stroke(Color.white.opacity(0.48), lineWidth: max(1, lineWidth * 0.20)).frame(width: 39 * scale, height: 23 * scale))
                HStack(spacing: 4 * scale) {
                    Diamond().fill(Color(hex: "78D7FF")).frame(width: 6 * scale, height: 9 * scale).offset(y: 2 * scale)
                    Diamond().fill(Color(hex: "E8F7FF")).frame(width: 8 * scale, height: 12 * scale).offset(y: -1 * scale)
                    Diamond().fill(Color(hex: "12C8A2")).frame(width: 6 * scale, height: 9 * scale).offset(y: 2 * scale)
                }
            }
            .offset(y: -33 * scale)
        case "avatar_head_cosmic_halo":
            ZStack {
                Ellipse()
                    .stroke(Color(hex: "17224E").opacity(0.52), lineWidth: max(3, lineWidth * 1.55))
                    .frame(width: 48 * scale, height: 17 * scale)
                    .blur(radius: 1.2 * scale)
                Ellipse()
                    .stroke(Color(hex: "78D7FF"), lineWidth: max(1.2, lineWidth * 0.72))
                    .frame(width: 46 * scale, height: 15 * scale)
                Ellipse()
                    .stroke(Color(hex: "FFD36B").opacity(0.54), lineWidth: max(1, lineWidth * 0.30))
                    .frame(width: 34 * scale, height: 10 * scale)
                    .rotationEffect(.degrees(-8))
                planetDot(Color(hex: "FFD36B"), size: 4.8, x: 20, y: -2)
                starDot(size: 5, x: -17, y: 4, opacity: 0.82)
                Image(systemName: "sparkles").font(.system(size: max(7, 11 * scale), weight: .bold)).foregroundStyle(Color.white.opacity(0.82)).offset(x: 4 * scale, y: -7 * scale)
            }
            .offset(y: -39 * scale)
        default:
            EmptyView()
        }
    }

    private var wizardHat: some View {
        ZStack {
            Triangle()
                .fill(LinearGradient(colors: [Color(hex: "7471CE"), Color(hex: "34306D")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34 * scale, height: 28 * scale)
                .overlay(Triangle().stroke(Color(hex: "C3C8FF").opacity(0.65), lineWidth: 0.8 * scale))
                .offset(y: -33 * scale)
            Capsule().fill(Color(hex: "272453"))
                .frame(width: 43 * scale, height: 5 * scale)
                .overlay(Capsule().stroke(Color(hex: "B4AEF5"), lineWidth: 0.8 * scale))
                .offset(y: -19 * scale)
            Capsule().fill(Color(hex: "E9BC61"))
                .frame(width: 27 * scale, height: 3 * scale).offset(y: -23 * scale)
            Image(systemName: "moon.fill")
                .font(.system(size: 9 * scale, weight: .bold))
                .foregroundStyle(Color(hex: "FFE7A3"))
                .offset(x: -2 * scale, y: -32 * scale)
            starDot(size: 3, x: 4, y: -40, opacity: 0.9)
        }
    }

    private var lightningHair: some View {
        ZStack {
            ForEach(0..<3) { index in
                LightningShape()
                    .fill(LinearGradient(colors: [Color(hex: "FFF5BA"), Color(hex: "FFD257"), Color(hex: "EF982F")], startPoint: .top, endPoint: .bottom))
                    .frame(width: CGFloat(index == 1 ? 19 : 15) * scale, height: CGFloat(index == 1 ? 28 : 21) * scale)
                    .rotationEffect(.degrees(Double(index - 1) * 13))
                    .offset(x: CGFloat(index - 1) * 12 * scale, y: CGFloat(index == 1 ? -33 : -29) * scale)
            }
            Capsule().fill(Color(hex: "FFD257"))
                .frame(width: 33 * scale, height: 4 * scale).offset(y: -20 * scale)
        }
        .shadow(color: Color(hex: "FFE37A").opacity(shouldAnimate && softPulse ? 0.65 : 0.15), radius: 3 * scale)
        .animation(shouldAnimate ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true) : nil, value: softPulse)
    }

    private var flameCrown: some View {
        ZStack {
            ForEach(0..<3) { index in
                FlameTongue()
                    .fill(LinearGradient(colors: [Color(hex: "FF6B3D"), Color(hex: "FFD365")], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .bottom) {
                        FlameTongue().fill(Color(hex: "FFF1B0"))
                            .frame(width: 6 * scale, height: CGFloat(index == 1 ? 16 : 12) * scale)
                    }
                    .frame(width: 15 * scale, height: CGFloat(index == 1 ? 27 : 21) * scale)
                    .scaleEffect(x: 1, y: shouldAnimate && softPulse ? 0.91 : 1, anchor: .bottom)
                    .offset(x: CGFloat(index - 1) * 12 * scale, y: CGFloat(index == 1 ? -33 : -30) * scale)
            }
            Capsule().fill(LinearGradient(colors: [Color(hex: "FFE5A0"), Color(hex: "DB8525")], startPoint: .top, endPoint: .bottom))
                .frame(width: 38 * scale, height: 5 * scale).offset(y: -20 * scale)
        }
        .shadow(color: Color(hex: "FF963D").opacity(0.4), radius: 3 * scale)
        .animation(shouldAnimate ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : nil, value: softPulse)
    }

    @ViewBuilder
    private var limbsBack: some View {
        Canvas { context, _ in
            var path = Path()
            let leftHand = point(x: leftArmEnd.x, y: leftArmEnd.y)
            let rightHand = point(x: rightArmEnd.x, y: rightArmEnd.y)
            let leftFoot = point(x: leftLegEnd.x, y: leftLegEnd.y)
            let rightFoot = point(x: rightLegEnd.x, y: rightLegEnd.y)
            path.move(to: point(x: 30, y: 53))
            path.addLine(to: leftHand)
            path.move(to: point(x: 70, y: 53))
            path.addLine(to: rightHand)
            path.move(to: point(x: 40, y: 74))
            path.addLine(to: leftFoot)
            path.move(to: point(x: 60, y: 74))
            path.addLine(to: rightFoot)
            context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    @ViewBuilder
    private var limbsFront: some View {
        Capsule().fill(bodyOutlineColor).frame(width: 13 * scale, height: 5 * scale).rotationEffect(.degrees(-8)).offset(x: (leftLegEnd.x - 50) * scale, y: (leftLegEnd.y - 50) * scale)
        Capsule().fill(bodyOutlineColor).frame(width: 13 * scale, height: 5 * scale).rotationEffect(.degrees(8)).offset(x: (rightLegEnd.x - 50) * scale, y: (rightLegEnd.y - 50) * scale)
    }

    @ViewBuilder
    private var outfitAccent: some View {
        switch style.outfit {
        case "avatar_outfit_cape":
            Triangle()
                .fill(Color(hex: "FF2F78").opacity(0.72))
                .frame(width: 56 * scale, height: 38 * scale)
                .offset(y: 23 * scale)
                .zIndex(-1)
        case "avatar_outfit_armor":
            ShieldShape()
                .fill(Color(hex: "4D8DFF").opacity(0.88))
                .frame(width: 19 * scale, height: 23 * scale)
                .offset(y: 17 * scale)
                .overlay(ShieldShape().stroke(Color.white.opacity(0.82), lineWidth: max(1, lineWidth * 0.45)).frame(width: 19 * scale, height: 23 * scale).offset(y: 17 * scale))
        case "avatar_outfit_neon":
            ZStack {
                RoundedRectangle(cornerRadius: 4 * scale)
                    .stroke(LinearGradient(colors: [Color(hex: "39D5FF"), Color(hex: "FF2F78")], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: max(1, lineWidth * 0.55))
                    .frame(width: 28 * scale, height: 27 * scale)
                HStack(spacing: 10 * scale) {
                    Capsule().fill(Color(hex: "39D5FF").opacity(0.82)).frame(width: 4 * scale, height: 18 * scale)
                    Capsule().fill(Color(hex: "FF2F78").opacity(0.82)).frame(width: 4 * scale, height: 18 * scale)
                }
                Diamond().fill(Color.white.opacity(0.55)).frame(width: 6 * scale, height: 8 * scale)
            }
            .offset(y: 8 * scale)
        case "avatar_outfit_royal":
            Diamond()
                .fill(Color(hex: "FF2F78"))
                .frame(width: 11 * scale, height: 15 * scale)
                .offset(y: 12 * scale)
        case "avatar_outfit_lava":
            Capsule().fill(Color(hex: "FFD36B").opacity(0.8)).frame(width: 23 * scale, height: 6 * scale).offset(y: 17 * scale)
        case "avatar_outfit_galaxy":
            Image(systemName: "sparkles").font(.system(size: max(7, 12 * scale), weight: .bold)).foregroundStyle(Color(hex: "FFD36B")).offset(y: 12 * scale)
        case "avatar_outfit_candy":
            HStack(spacing: 4 * scale) {
                Capsule().fill(Color.white.opacity(0.75)).frame(width: 5 * scale, height: 22 * scale)
                Capsule().fill(Color(hex: "FF2F78").opacity(0.75)).frame(width: 5 * scale, height: 22 * scale)
            }.rotationEffect(.degrees(28)).offset(y: 10 * scale)
        case "avatar_outfit_obsidian":
            Diamond().stroke(Color.white.opacity(0.62), lineWidth: max(1, lineWidth * 0.35)).frame(width: 12 * scale, height: 16 * scale).offset(y: 12 * scale)
        case "avatar_outfit_sunset":
            ZStack {
                Circle().fill(Color(hex: "FFD36B").opacity(0.86)).frame(width: 14 * scale, height: 14 * scale).offset(y: 9 * scale)
                Capsule().fill(Color.white.opacity(0.42)).frame(width: 25 * scale, height: 3 * scale).offset(y: 16 * scale)
                Capsule().fill(Color(hex: "FF2F78").opacity(0.55)).frame(width: 20 * scale, height: 3 * scale).offset(y: 21 * scale)
            }
        case "avatar_outfit_bubblegum":
            ZStack {
                HStack(spacing: 12 * scale) {
                    Circle().fill(Color(hex: "FF9ED1").opacity(0.80)).frame(width: 8 * scale, height: 8 * scale)
                    Circle().fill(Color(hex: "39D5FF").opacity(0.80)).frame(width: 8 * scale, height: 8 * scale)
                }
                .offset(y: 11 * scale)
                Circle().stroke(Color.white.opacity(0.54), lineWidth: max(1, lineWidth * 0.22)).frame(width: 23 * scale, height: 23 * scale).offset(y: 11 * scale)
            }
        case "avatar_outfit_arcade_jacket":
            ZStack {
                HStack(spacing: 13 * scale) {
                    Capsule().fill(Color(hex: "39D5FF")).frame(width: 4 * scale, height: 25 * scale)
                    Capsule().fill(Color(hex: "FF2F78")).frame(width: 4 * scale, height: 25 * scale)
                }
                RoundedRectangle(cornerRadius: 2 * scale)
                    .stroke(Color.white.opacity(0.46), lineWidth: max(1, lineWidth * 0.22))
                    .frame(width: 28 * scale, height: 24 * scale)
            }
            .offset(y: 8 * scale)
        case "avatar_outfit_teal_gold":
            ZStack {
                Diamond().fill(Color(hex: "FFD36B")).frame(width: 11 * scale, height: 15 * scale).offset(y: 11 * scale)
                Capsule().fill(Color.white.opacity(0.48)).frame(width: 25 * scale, height: 3 * scale).offset(y: 22 * scale)
            }
        case "avatar_outfit_prism":
            ZStack {
                RoundedRectangle(cornerRadius: 3 * scale)
                    .stroke(LinearGradient(colors: [Color(hex: "FF2F78"), Color(hex: "12C8A2"), Color(hex: "FFD36B")], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: max(1, lineWidth * 0.65))
                    .frame(width: 30 * scale, height: 30 * scale)
                Diamond().fill(Color.white.opacity(0.62)).frame(width: 8 * scale, height: 11 * scale)
                Circle().fill(Color(hex: "FFD36B").opacity(0.82)).frame(width: 4 * scale, height: 4 * scale).offset(x: 10 * scale, y: -10 * scale)
            }
            .offset(y: 4 * scale)
        case "avatar_outfit_crystal":
            ZStack {
                Diamond().fill(Color(hex: "E8F7FF").opacity(0.90)).frame(width: 13 * scale, height: 18 * scale).offset(y: 11 * scale)
                Diamond().stroke(Color(hex: "78D7FF").opacity(0.74), lineWidth: max(1, lineWidth * 0.22)).frame(width: 24 * scale, height: 28 * scale).offset(y: 11 * scale)
            }
        case "avatar_outfit_royal_velvet":
            ZStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: max(7, 12 * scale), weight: .black))
                    .foregroundStyle(Color(hex: "FFD36B"))
                    .offset(y: 10 * scale)
                Capsule().fill(Color(hex: "FFD36B").opacity(0.54)).frame(width: 26 * scale, height: 4 * scale).offset(y: 22 * scale)
            }
        case "avatar_outfit_starlight":
            ZStack {
                Image(systemName: "sparkles")
                    .font(.system(size: max(7, 13 * scale), weight: .bold))
                    .foregroundStyle(Color(hex: "78D7FF"))
                    .offset(y: 10 * scale)
                HStack(spacing: 15 * scale) {
                    Circle().fill(Color(hex: "FFD36B").opacity(0.78)).frame(width: 4 * scale, height: 4 * scale)
                    Circle().fill(Color.white.opacity(0.70)).frame(width: 4 * scale, height: 4 * scale)
                }
                .offset(y: 21 * scale)
            }
        default:
            EmptyView()
        }
    }

    private var leftArmEnd: (x: CGFloat, y: CGFloat) {
        (27, 34)
    }

    private var rightArmEnd: (x: CGFloat, y: CGFloat) {
        (73, 34)
    }

    private var leftLegEnd: (x: CGFloat, y: CGFloat) {
        (35, 82)
    }
    private var rightLegEnd: (x: CGFloat, y: CGFloat) {
        (65, 82)
    }

    private var bodyColor: Color {
        switch style.outfit {
        case "avatar_outfit_hoodie": return Color(hex: "12C8A2")
        case "avatar_outfit_cape": return Color(hex: "FF2F78")
        case "avatar_outfit_armor": return Color(hex: "4D8DFF")
        case "avatar_outfit_neon": return Color(hex: "0B1435")
        case "avatar_outfit_royal": return Color(hex: "FFD36B")
        case "avatar_outfit_lava": return Color(hex: "FF6B1A")
        case "avatar_outfit_frost": return Color(hex: "71C8FF")
        case "avatar_outfit_galaxy": return Color(hex: "7B42FF")
        case "avatar_outfit_mint": return Color(hex: "23D18B")
        case "avatar_outfit_candy": return Color(hex: "FF9ED1")
        case "avatar_outfit_obsidian": return Color(hex: "101423")
        case "avatar_outfit_sunset": return Color(hex: "FF6B1A")
        case "avatar_outfit_bubblegum": return Color(hex: "FF9ED1")
        case "avatar_outfit_arcade_jacket": return Color(hex: "2D2A7F")
        case "avatar_outfit_teal_gold": return Color(hex: "12C8A2")
        case "avatar_outfit_prism": return Color(hex: "7B42FF")
        case "avatar_outfit_crystal": return Color(hex: "78D7FF")
        case "avatar_outfit_royal_velvet": return Color(hex: "5B1440")
        case "avatar_outfit_starlight": return Color(hex: "256BFF")
        default: return Color(hex: style.bodyHex)
        }
    }

    private var bodyHighlight: Color {
        switch style.outfit {
        case "avatar_outfit_hoodie": return Color(hex: "7FFFE3")
        case "avatar_outfit_cape": return Color(hex: "FF8AC5")
        case "avatar_outfit_armor": return Color(hex: "71C8FF")
        case "avatar_outfit_neon": return Color(hex: "39D5FF")
        case "avatar_outfit_royal": return Color(hex: "FFE887")
        case "avatar_outfit_lava": return Color(hex: "FFD36B")
        case "avatar_outfit_frost": return Color(hex: "E9FFFF")
        case "avatar_outfit_galaxy": return Color(hex: "3E48B7")
        case "avatar_outfit_mint": return Color(hex: "CFFFF1")
        case "avatar_outfit_candy": return Color(hex: "39D5FF")
        case "avatar_outfit_obsidian": return Color(hex: "626A85")
        case "avatar_outfit_sunset": return Color(hex: "FFD36B")
        case "avatar_outfit_bubblegum": return Color(hex: "39D5FF")
        case "avatar_outfit_arcade_jacket": return Color(hex: "39D5FF")
        case "avatar_outfit_teal_gold": return Color(hex: "8FFFE1")
        case "avatar_outfit_prism": return Color(hex: "FF2F78")
        case "avatar_outfit_crystal": return Color(hex: "E8F7FF")
        case "avatar_outfit_royal_velvet": return Color(hex: "FF2F78")
        case "avatar_outfit_starlight": return Color(hex: "78D7FF")
        default: return Color(hex: style.bodyHex).opacity(0.78)
        }
    }

    private var bodyShadow: Color {
        switch style.outfit {
        case "avatar_outfit_hoodie": return Color(hex: "078A76")
        case "avatar_outfit_cape": return Color(hex: "C21864")
        case "avatar_outfit_armor": return Color(hex: "1668D9")
        case "avatar_outfit_neon": return Color(hex: "050510")
        case "avatar_outfit_royal": return Color(hex: "D99500")
        case "avatar_outfit_lava": return Color(hex: "B52813")
        case "avatar_outfit_frost": return Color(hex: "2D8EDB")
        case "avatar_outfit_galaxy": return Color(hex: "050510")
        case "avatar_outfit_mint": return Color(hex: "0C8C68")
        case "avatar_outfit_candy": return Color(hex: "FF2F78")
        case "avatar_outfit_obsidian": return Color(hex: "050510")
        case "avatar_outfit_sunset": return Color(hex: "B52813")
        case "avatar_outfit_bubblegum": return Color(hex: "FF2F78")
        case "avatar_outfit_arcade_jacket": return Color(hex: "171B43")
        case "avatar_outfit_teal_gold": return Color(hex: "D99500")
        case "avatar_outfit_prism": return Color(hex: "12C8A2")
        case "avatar_outfit_crystal": return Color(hex: "12C8A2")
        case "avatar_outfit_royal_velvet": return Color(hex: "D99500")
        case "avatar_outfit_starlight": return Color(hex: "050510")
        default: return Color(hex: style.bodyHex).opacity(0.58)
        }
    }

    private var auraColor: Color {
        switch style.aura {
        case "avatar_aura_teal": return Color(hex: "12C8A2")
        case "avatar_aura_pink": return Color(hex: "FF2F78")
        case "avatar_aura_crown": return Color(hex: "FFD36B")
        case "avatar_aura_storm": return Color(hex: "4D8DFF")
        case "avatar_aura_lava": return Color(hex: "FF6B1A")
        case "avatar_aura_star": return Color(hex: "FFD36B")
        case "avatar_aura_pixel": return Color(hex: "7B42FF")
        case "avatar_aura_mint": return Color(hex: "23D18B")
        case "avatar_aura_royal": return Color(hex: "FFD36B")
        case "avatar_aura_confetti": return Color(hex: "FF2F78")
        case "avatar_aura_bubblegum": return Color(hex: "FF9ED1")
        case "avatar_aura_stage_light": return Color(hex: "39D5FF")
        case "avatar_aura_teal_orbit": return Color(hex: "12C8A2")
        case "avatar_aura_prism": return Color(hex: "7B42FF")
        case "avatar_aura_crystal": return Color(hex: "78D7FF")
        case "avatar_aura_gold_crown": return Color(hex: "FFD36B")
        case "avatar_aura_cosmic": return Color(hex: "78D7FF")
        default: return Color(hex: "FF2F78")
        }
    }

    private var rainbowEyes: some View {
        HStack(spacing: 8 * scale) {
            rainbowEye
            rainbowEye
        }
        .offset(y: -5 * scale)
    }

    private var rainbowEye: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle().fill(prismBandColor(index))
                }
            }
            .frame(width: 13 * scale, height: 13 * scale)
            .clipShape(Circle())
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: max(0.6, lineWidth * 0.16))
                .frame(width: 13 * scale, height: 13 * scale)
            Circle().fill(.white.opacity(0.9))
                .frame(width: 3 * scale, height: 3 * scale)
                .offset(x: -2.5 * scale, y: -3 * scale)
        }
    }

    private func lavaVein(x: CGFloat, y: CGFloat, height: CGFloat, angle: Double) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(hex: "FFD36B").opacity(0.90), Color(hex: "FF2F78").opacity(0.72)], startPoint: .top, endPoint: .bottom))
            .frame(width: 4 * scale, height: height * scale)
            .rotationEffect(.degrees(angle))
            .offset(x: x * scale, y: y * scale)
    }

    private func frostFacet(width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Diamond()
            .fill(LinearGradient(colors: [Color.white.opacity(0.58), Color(hex: "78D7FF").opacity(0.30)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: width * scale, height: height * scale)
            .overlay(Diamond().stroke(Color.white.opacity(0.34), lineWidth: max(0.5, lineWidth * 0.12)).frame(width: width * scale, height: height * scale))
            .offset(x: x * scale, y: y * scale)
    }

    private func leafShape(_ color: Color, x: CGFloat, y: CGFloat, angle: Double) -> some View {
        Ellipse()
            .fill(color)
            .frame(width: 12 * scale, height: 22 * scale)
            .rotationEffect(.degrees(angle))
            .offset(x: x * scale, y: y * scale)
    }

    private func bubbleDot(x: CGFloat, y: CGFloat, size dotSize: CGFloat, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: dotSize * scale, height: dotSize * scale)
            .overlay(Circle().stroke(Color.white.opacity(0.36), lineWidth: max(0.5, lineWidth * 0.12)))
            .offset(x: x * scale, y: y * scale)
    }

    private func prismBandColor(_ index: Int) -> Color {
        switch index % 5 {
        case 0: return Color(hex: "FF2F78")
        case 1: return Color(hex: "FFD36B")
        case 2: return Color(hex: "12C8A2")
        case 3: return Color(hex: "39D5FF")
        default: return Color(hex: "7B42FF")
        }
    }

    private func point(x: CGFloat, y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }

    private func faceEyes(left: String, right: String, y: CGFloat = 44) -> some View {
        HStack(spacing: 12.5 * scale) {
            Text(left)
            Text(right)
        }
        .font(.system(size: max(8, 15 * scale), weight: .black, design: .rounded))
        .foregroundStyle(.white)
        .offset(y: (y - 50) * scale)
    }

    @ViewBuilder
    private func faceText(_ text: String, y: CGFloat, size fontSize: CGFloat) -> some View {
        if text == "⌣" {
            expressionSmile
        } else {
            Text(text)
                .font(.system(size: max(7, (fontSize + 1) * scale), weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: (y - 50) * scale)
        }
    }

    private func mouthLine(width: CGFloat, y: CGFloat) -> some View {
        Capsule().fill(.white).frame(width: width * scale, height: max(1.2, 2.4 * scale)).offset(y: (y - 50) * scale)
    }
}

private struct AvatarScrollVisibility: ViewModifier {
    @Binding var isVisible: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollVisibilityChange(threshold: 0.15) { isVisible = $0 }
        } else {
            content
                .onGeometryChange(for: Bool.self) { geometry in
                    guard let viewport = geometry.bounds(of: .scrollView) else { return true }
                    return viewport.intersects(CGRect(origin: .zero, size: geometry.size))
                } action: { isVisible = $0 }
                .onDisappear { isVisible = false }
        }
    }
}

// Time-driven materials avoid repeatForever starting in its final state when a
// lazy grid inserts an avatar. Only this small layer redraws, at most 24 fps.
private struct AvatarBodyMaterial: View {
    let outfit: String
    let animates: Bool

    var body: some View {
        if animates {
            TimelineView(.animation(minimumInterval: 1.0 / 24)) { timeline in
                surface(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            surface(time: 1.2)
        }
    }

    private func surface(time: Double) -> some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 100, y: size.height / 100)
            switch outfit {
            case "avatar_outfit_frost": frost(&context, time: time)
            case "avatar_outfit_lava": lava(&context, time: time)
            case "avatar_outfit_obsidian": obsidian(&context, time: time)
            case "avatar_outfit_prism": prism(&context, time: time)
            case "avatar_outfit_hoodie": tealEnamel(&context, time: time)
            case "avatar_outfit_candy": candy(&context, time: time)
            case "avatar_outfit_armor": royalBlue(&context, time: time)
            case "avatar_outfit_royal_velvet": velvet(&context, time: time)
            default: starlight(&context, time: time)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        Path { path in
            path.addLines(points)
            path.closeSubpath()
        }
    }

    private func fill(_ context: inout GraphicsContext, _ points: [(Double, Double)], color: Color) {
        context.fill(polygon(points.map { CGPoint(x: $0.0, y: $0.1) }), with: .color(color))
    }

    private func sheen(_ context: inout GraphicsContext, time: Double, period: Double, color: Color) {
        let x = (time / period).truncatingRemainder(dividingBy: 1) * 200 - 65
        let band = polygon([CGPoint(x: x - 26, y: 0), CGPoint(x: x + 4, y: 0),
                            CGPoint(x: x + 55, y: 100), CGPoint(x: x + 25, y: 100)])
        context.fill(band, with: .linearGradient(
            Gradient(colors: [.clear, color, .clear]),
            startPoint: CGPoint(x: x - 25, y: 30), endPoint: CGPoint(x: x + 30, y: 30)))
    }

    private func frost(_ context: inout GraphicsContext, time: Double) {
        fill(&context, [(8, 10), (38, 10), (22, 78), (8, 88)], color: Color(hex: "C6FAFF").opacity(0.75))
        fill(&context, [(38, 10), (83, 10), (92, 28), (66, 23)], color: .white.opacity(0.6))
        fill(&context, [(76, 34), (92, 19), (92, 89), (62, 89)], color: Color(hex: "287CC5").opacity(0.5))
        fill(&context, [(13, 74), (38, 65), (73, 89), (13, 89)], color: Color(hex: "C6FAFF").opacity(0.65))
        var cracks = Path()
        cracks.addLines([CGPoint(x: 15, y: 22), CGPoint(x: 29, y: 33), CGPoint(x: 23, y: 55)])
        cracks.addLines([CGPoint(x: 69, y: 76), CGPoint(x: 79, y: 62), CGPoint(x: 91, y: 65)])
        context.stroke(cracks, with: .color(.white.opacity(0.65)), lineWidth: 1.5)
        sheen(&context, time: time, period: 3.6, color: .white.opacity(0.85))
    }

    private func lava(_ context: inout GraphicsContext, time: Double) {
        let glow = 0.7 + sin(time * 1.8) * 0.25
        context.fill(Path(CGRect(x: 0, y: 0, width: 100, height: 100)), with: .color(Color(hex: "39252F")))
        let channels: [[CGPoint]] = [
            [CGPoint(x: 18, y: 8), CGPoint(x: 28, y: 24), CGPoint(x: 18, y: 47), CGPoint(x: 28, y: 67), CGPoint(x: 15, y: 95)],
            [CGPoint(x: 77, y: 6), CGPoint(x: 66, y: 23), CGPoint(x: 82, y: 44), CGPoint(x: 72, y: 65), CGPoint(x: 88, y: 96)],
            [CGPoint(x: 28, y: 67), CGPoint(x: 47, y: 76), CGPoint(x: 72, y: 65)]
        ]
        for points in channels {
            let path = Path { $0.addLines(points) }
            context.stroke(path, with: .color(Color(hex: "F25236").opacity(glow)), style: StrokeStyle(lineWidth: 9, lineJoin: .round))
            context.stroke(path, with: .color(Color(hex: "FFB344")), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }
        for index in 0..<4 {
            let phase = (time / 3 + Double(index) * 0.27).truncatingRemainder(dividingBy: 1)
            let x = index.isMultiple(of: 2) ? 20.0 : 79.0
            let rect = CGRect(x: x + sin(phase * 6) * 3, y: 90 - phase * 75, width: 2.5, height: 4)
            context.fill(Path(ellipseIn: rect), with: .color(Color(hex: "FFF1A8").opacity(sin(phase * .pi))))
        }
    }

    private func obsidian(_ context: inout GraphicsContext, time: Double) {
        fill(&context, [(8, 12), (34, 12), (21, 88), (8, 88)], color: Color(hex: "667695").opacity(0.7))
        fill(&context, [(34, 12), (89, 12), (68, 26), (29, 36)], color: Color(hex: "8996B6").opacity(0.42))
        fill(&context, [(79, 45), (94, 22), (94, 90), (58, 90)], color: Color(hex: "818DB4").opacity(0.38))
        var edge = Path()
        edge.addLines([CGPoint(x: 14, y: 65), CGPoint(x: 23, y: 30), CGPoint(x: 36, y: 16)])
        context.stroke(edge, with: .color(Color(hex: "C7DEFF").opacity(0.65)), lineWidth: 1.4)
        sheen(&context, time: time, period: 4.4, color: Color(hex: "C1D8FF").opacity(0.75))
    }

    private func prism(_ context: inout GraphicsContext, time: Double) {
        let colors = ["EE5BA6", "AA70EA", "528BE8", "36C8BB", "F4CB65"]
        for index in 0..<5 {
            let x = Double(index) * 27 - 45
            fill(&context, [(x, 0), (x + 28, 0), (x + 90, 100), (x + 62, 100)], color: Color(hex: colors[index]).opacity(0.85))
        }
        sheen(&context, time: time, period: 3.2, color: .white.opacity(0.72))
    }

    private func starlight(_ context: inout GraphicsContext, time: Double) {
        context.fill(Path(CGRect(x: 0, y: 0, width: 100, height: 100)), with: .linearGradient(
            Gradient(colors: [Color(hex: "233870"), Color(hex: "11172E")]),
            startPoint: .zero, endPoint: CGPoint(x: 100, y: 100)))
        let stars: [(Double, Double)] = [(18, 24), (71, 19), (83, 51), (25, 70), (64, 76), (82, 84), (44, 18)]
        for (index, star) in stars.enumerated() {
            let pulse = 0.5 + 0.5 * sin(time * 1.7 + Double(index) * 1.6)
            let radius = index.isMultiple(of: 3) ? 3.0 : 1.5
            let color = index.isMultiple(of: 2) ? Color(hex: "B5E7FF") : Color(hex: "FFE199")
            context.fill(Path(ellipseIn: CGRect(x: star.0 - radius / 2, y: star.1 - radius / 2, width: radius, height: radius)), with: .color(color.opacity(0.4 + pulse * 0.6)))
            if index.isMultiple(of: 3) {
                var glint = Path()
                let reach = 2 + pulse * 2.5
                glint.move(to: CGPoint(x: star.0 - reach, y: star.1))
                glint.addLine(to: CGPoint(x: star.0 + reach, y: star.1))
                glint.move(to: CGPoint(x: star.0, y: star.1 - reach))
                glint.addLine(to: CGPoint(x: star.0, y: star.1 + reach))
                context.stroke(glint, with: .color(color.opacity(pulse * 0.8)), lineWidth: 1)
            }
        }
    }

    private func tealEnamel(_ context: inout GraphicsContext, time: Double) {
        fill(&context, [(8, 11), (25, 11), (18, 89), (8, 89)], color: Color(hex: "007A78").opacity(0.65))
        fill(&context, [(77, 11), (91, 11), (91, 89), (84, 76)], color: Color(hex: "B4FFF0").opacity(0.5))
        var piping = Path()
        piping.addLines([CGPoint(x: 18, y: 20), CGPoint(x: 18, y: 65), CGPoint(x: 31, y: 77)])
        piping.addLines([CGPoint(x: 80, y: 20), CGPoint(x: 80, y: 65), CGPoint(x: 69, y: 77)])
        context.stroke(piping, with: .color(Color(hex: "C2FFF0").opacity(0.65)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        sheen(&context, time: time, period: 4.2, color: Color(hex: "D7FFF8").opacity(0.4))
    }

    private func candy(_ context: inout GraphicsContext, time: Double) {
        context.fill(Path(CGRect(x: 0, y: 0, width: 100, height: 100)), with: .color(Color(hex: "D93378")))
        for index in -2..<6 {
            let x = Double(index) * 28
            fill(&context, [(x, 0), (x + 9, 0), (x + 69, 100), (x + 60, 100)], color: Color(hex: "FFCADF"))
            fill(&context, [(x + 10, 0), (x + 13, 0), (x + 73, 100), (x + 70, 100)], color: Color(hex: "9AF0E4"))
        }
        context.fill(Path(CGRect(x: 0, y: 0, width: 100, height: 100)), with: .radialGradient(
            Gradient(colors: [Color(hex: "D93378").opacity(0.92), .clear]),
            center: CGPoint(x: 50, y: 44), startRadius: 14, endRadius: 38))
        sheen(&context, time: time, period: 4.8, color: .white.opacity(0.4))
    }

    private func royalBlue(_ context: inout GraphicsContext, time: Double) {
        fill(&context, [(8, 10), (26, 10), (22, 67), (35, 89), (8, 89)], color: Color(hex: "193C81").opacity(0.85))
        fill(&context, [(74, 10), (92, 10), (92, 89), (65, 89), (78, 67)], color: Color(hex: "193C81").opacity(0.85))
        var trim = Path()
        trim.addLines([CGPoint(x: 25, y: 17), CGPoint(x: 22, y: 65), CGPoint(x: 34, y: 83)])
        trim.addLines([CGPoint(x: 75, y: 17), CGPoint(x: 78, y: 65), CGPoint(x: 66, y: 83)])
        context.stroke(trim, with: .color(Color(hex: "BEDCFF")), lineWidth: 2)
        let shield = polygon([CGPoint(x: 44, y: 70), CGPoint(x: 56, y: 70), CGPoint(x: 55, y: 77), CGPoint(x: 50, y: 81), CGPoint(x: 45, y: 77)])
        context.fill(shield, with: .color(Color(hex: "D9E8FF")))
        sheen(&context, time: time, period: 5.2, color: Color(hex: "AFCEFF").opacity(0.3))
    }

    private func velvet(_ context: inout GraphicsContext, time: Double) {
        context.fill(Path(CGRect(x: 0, y: 0, width: 100, height: 100)), with: .linearGradient(
            Gradient(colors: [Color(hex: "962754"), Color(hex: "481C41")]),
            startPoint: CGPoint(x: 10, y: 10), endPoint: CGPoint(x: 80, y: 90)))
        var trim = Path()
        trim.addLines([CGPoint(x: 17, y: 15), CGPoint(x: 22, y: 50), CGPoint(x: 17, y: 84), CGPoint(x: 34, y: 84)])
        trim.addLines([CGPoint(x: 83, y: 15), CGPoint(x: 78, y: 50), CGPoint(x: 83, y: 84), CGPoint(x: 66, y: 84)])
        context.stroke(trim, with: .color(Color(hex: "E2BD75")), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        let pin = polygon([CGPoint(x: 50, y: 69), CGPoint(x: 55, y: 75), CGPoint(x: 50, y: 80), CGPoint(x: 45, y: 75)])
        context.fill(pin, with: .color(Color(hex: "FFE3A0").opacity(0.75 + sin(time * 1.5) * 0.2)))
        sheen(&context, time: time, period: 6.4, color: Color(hex: "FF99BD").opacity(0.15))
    }
}

private struct FlameTongue: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.55, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.width * 0.90, y: rect.height * 0.70), control1: CGPoint(x: rect.width * 0.34, y: rect.height * 0.30), control2: CGPoint(x: rect.width, y: rect.height * 0.37))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.90), control: CGPoint(x: rect.width * 0.75, y: rect.height * 1.10))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.20, y: rect.height * 0.36), control: CGPoint(x: 0, y: rect.height * 0.69))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.55, y: rect.minY), control: CGPoint(x: rect.width * 0.48, y: rect.height * 0.24))
        path.closeSubpath()
        return path
    }
}

private struct PuzzlePieceShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        var path = Path()
        path.move(to: CGPoint(x: x + w * 0.18, y: y + h * 0.10))
        path.addLine(to: CGPoint(x: x + w * 0.82, y: y + h * 0.10))
        path.addCurve(to: CGPoint(x: x + w * 0.92, y: y + h * 0.20), control1: CGPoint(x: x + w * 0.88, y: y + h * 0.10), control2: CGPoint(x: x + w * 0.92, y: y + h * 0.14))
        path.addLine(to: CGPoint(x: x + w * 0.92, y: y + h * 0.40))
        path.addCurve(
            to: CGPoint(x: x + w * 0.92, y: y + h * 0.60),
            control1: CGPoint(x: x + w * 1.10, y: y + h * 0.40),
            control2: CGPoint(x: x + w * 1.10, y: y + h * 0.60)
        )
        path.addLine(to: CGPoint(x: x + w * 0.92, y: y + h * 0.80))
        path.addCurve(to: CGPoint(x: x + w * 0.82, y: y + h * 0.90), control1: CGPoint(x: x + w * 0.92, y: y + h * 0.86), control2: CGPoint(x: x + w * 0.88, y: y + h * 0.90))
        path.addLine(to: CGPoint(x: x + w * 0.58, y: y + h * 0.90))
        path.addCurve(
            to: CGPoint(x: x + w * 0.42, y: y + h * 0.90),
            control1: CGPoint(x: x + w * 0.58, y: y + h * 0.72),
            control2: CGPoint(x: x + w * 0.42, y: y + h * 0.72)
        )
        path.addLine(to: CGPoint(x: x + w * 0.18, y: y + h * 0.90))
        path.addCurve(to: CGPoint(x: x + w * 0.08, y: y + h * 0.80), control1: CGPoint(x: x + w * 0.12, y: y + h * 0.90), control2: CGPoint(x: x + w * 0.08, y: y + h * 0.86))
        path.addLine(to: CGPoint(x: x + w * 0.08, y: y + h * 0.62))
        path.addCurve(
            to: CGPoint(x: x + w * 0.08, y: y + h * 0.38),
            control1: CGPoint(x: x - w * 0.08, y: y + h * 0.62),
            control2: CGPoint(x: x - w * 0.08, y: y + h * 0.38)
        )
        path.addLine(to: CGPoint(x: x + w * 0.08, y: y + h * 0.20))
        path.addCurve(to: CGPoint(x: x + w * 0.18, y: y + h * 0.10), control1: CGPoint(x: x + w * 0.08, y: y + h * 0.14), control2: CGPoint(x: x + w * 0.12, y: y + h * 0.10))
        path.closeSubpath()
        return path
    }
}

private struct SemiCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PolygonShard: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + rect.width * first.x, y: rect.minY + rect.height * first.y))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + rect.width * point.x, y: rect.minY + rect.height * point.y))
        }
        path.closeSubpath()
        return path
    }
}

private struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.35))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.64, y: rect.minY + rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.35))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct LightningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.38))
        path.closeSubpath()
        return path
    }
}

private struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.28), control1: CGPoint(x: rect.minX, y: rect.maxY * 0.82), control2: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.midY), control2: CGPoint(x: rect.maxX, y: rect.maxY * 0.82))
        path.closeSubpath()
        return path
    }
}
