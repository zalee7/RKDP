import SwiftUI

struct StickDuelerAvatarView: View {
    var style: AvatarStyle
    var size: CGFloat = 56
    var initials: String? = nil

    private var lineWidth: CGFloat { max(2, size * 0.055) }
    private var scale: CGFloat { size / 100 }

    var body: some View {
        ZStack {
            auraView
            Circle()
                .fill(AppTheme.brandGradient.opacity(0.72))
                .overlay(Circle().stroke(Color.white.opacity(0.30), lineWidth: max(1, size * 0.024)))
            mascot
        }
        .frame(width: size, height: size)
        .shadow(color: auraColor.opacity(style.aura == "avatar_aura_none" ? 0.18 : 0.52), radius: size * 0.15)
        .accessibilityLabel("Puzzle piece avatar")
    }

    private var mascot: some View {
        ZStack {
            limbsBack
            puzzleBody
            face
            headwear
            limbsFront
            outfitAccent
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var auraView: some View {
        switch style.aura {
        case "avatar_aura_teal":
            Circle().fill(AppTheme.teal.opacity(0.25)).blur(radius: size * 0.12)
        case "avatar_aura_pink":
            Circle().fill(AppTheme.hotPink.opacity(0.28)).blur(radius: size * 0.12)
        case "avatar_aura_crown":
            Circle().fill(AppTheme.crownGold.opacity(0.26)).blur(radius: size * 0.14)
        case "avatar_aura_storm":
            Circle().stroke(AppTheme.royalBlue.opacity(0.85), lineWidth: max(2, size * 0.045)).rotationEffect(.degrees(-14))
                .overlay(Circle().stroke(AppTheme.hotPink.opacity(0.75), lineWidth: max(1, size * 0.025)).scaleEffect(0.82))
        default:
            Circle().fill(Color.white.opacity(0.04))
        }
    }

    private var puzzleBody: some View {
        PuzzlePieceShape()
            .fill(bodyFill)
            .frame(width: 56 * scale, height: 56 * scale)
            .overlay(
                PuzzlePieceShape()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                    .frame(width: 56 * scale, height: 56 * scale)
            )
            .overlay(
                PuzzlePieceShape()
                    .stroke(Color.white.opacity(0.34), lineWidth: max(1, lineWidth * 0.32))
                    .frame(width: 46 * scale, height: 46 * scale)
                    .offset(x: -2 * scale, y: -2 * scale)
            )
            .shadow(color: bodyColor.opacity(0.28), radius: size * 0.08, x: 0, y: size * 0.04)
            .offset(y: 4 * scale)
    }

    private var bodyFill: LinearGradient {
        LinearGradient(
            colors: [bodyHighlight, bodyColor, bodyShadow],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var face: some View {
        switch style.face {
        case "avatar_face_focused":
            faceEyes(left: "•", right: "•")
            mouthLine(width: 13, y: 55)
        case "avatar_face_wink":
            faceEyes(left: "•", right: "-", y: 45)
            faceText("⌣", y: 55, size: 14)
        case "avatar_face_shades":
            RoundedRectangle(cornerRadius: 3 * scale)
                .fill(Color.black.opacity(0.86))
                .frame(width: 28 * scale, height: 8 * scale)
                .overlay(Rectangle().fill(Color.white.opacity(0.55)).frame(width: 2 * scale, height: 8 * scale))
                .offset(y: -5 * scale)
            faceText("⌣", y: 56, size: 13)
        case "avatar_face_gem":
            HStack(spacing: 8 * scale) {
                Diamond().fill(AppTheme.hotPink).frame(width: 7 * scale, height: 10 * scale)
                Diamond().fill(AppTheme.hotPink).frame(width: 7 * scale, height: 10 * scale)
            }
            .offset(y: -5 * scale)
            faceText("⌣", y: 56, size: 13)
        default:
            faceEyes(left: "•", right: "•")
            faceText("⌣", y: 56, size: 14)
        }
    }

    @ViewBuilder
    private var headwear: some View {
        switch style.head {
        case "avatar_head_crown":
            CrownShape()
                .fill(AppTheme.crownGold)
                .frame(width: 35 * scale, height: 23 * scale)
                .offset(y: -33 * scale)
                .overlay(Diamond().fill(AppTheme.hotPink).frame(width: 6 * scale, height: 9 * scale).offset(y: -30 * scale))
        case "avatar_head_headphones":
            Circle()
                .trim(from: 0.54, to: 0.96)
                .stroke(AppTheme.teal, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: 48 * scale, height: 48 * scale)
                .offset(y: -3 * scale)
            HStack(spacing: 37 * scale) {
                Capsule().fill(AppTheme.teal).frame(width: 7 * scale, height: 18 * scale)
                Capsule().fill(AppTheme.teal).frame(width: 7 * scale, height: 18 * scale)
            }
            .offset(y: 3 * scale)
        case "avatar_head_wizard":
            Triangle()
                .fill(AppTheme.royalBlue)
                .frame(width: 37 * scale, height: 35 * scale)
                .offset(y: -38 * scale)
                .overlay(Circle().fill(AppTheme.crownGold).frame(width: 6 * scale, height: 6 * scale).offset(y: -51 * scale))
        case "avatar_head_lightning":
            LightningShape()
                .fill(AppTheme.crownGold)
                .frame(width: 27 * scale, height: 34 * scale)
                .offset(x: 18 * scale, y: -27 * scale)
        case "avatar_head_halo":
            Ellipse()
                .stroke(AppTheme.crownGold, lineWidth: lineWidth)
                .frame(width: 39 * scale, height: 12 * scale)
                .offset(y: -38 * scale)
        default:
            EmptyView()
        }
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
        Circle().fill(.white).frame(width: 6 * scale, height: 6 * scale).offset(x: (leftArmEnd.x - 50) * scale, y: (leftArmEnd.y - 50) * scale)
        Circle().fill(.white).frame(width: 6 * scale, height: 6 * scale).offset(x: (rightArmEnd.x - 50) * scale, y: (rightArmEnd.y - 50) * scale)
        Capsule().fill(.white).frame(width: 13 * scale, height: 5 * scale).rotationEffect(.degrees(-8)).offset(x: (leftLegEnd.x - 50) * scale, y: (leftLegEnd.y - 50) * scale)
        Capsule().fill(.white).frame(width: 13 * scale, height: 5 * scale).rotationEffect(.degrees(8)).offset(x: (rightLegEnd.x - 50) * scale, y: (rightLegEnd.y - 50) * scale)
    }

    @ViewBuilder
    private var outfitAccent: some View {
        switch style.outfit {
        case "avatar_outfit_cape":
            Triangle()
                .fill(AppTheme.hotPink.opacity(0.72))
                .frame(width: 56 * scale, height: 38 * scale)
                .offset(y: 23 * scale)
                .zIndex(-1)
        case "avatar_outfit_armor":
            ShieldShape()
                .fill(AppTheme.royalBlue.opacity(0.88))
                .frame(width: 19 * scale, height: 23 * scale)
                .offset(y: 17 * scale)
                .overlay(ShieldShape().stroke(Color.white.opacity(0.82), lineWidth: max(1, lineWidth * 0.45)).frame(width: 19 * scale, height: 23 * scale).offset(y: 17 * scale))
        case "avatar_outfit_neon":
            RoundedRectangle(cornerRadius: 3 * scale)
                .stroke(AppTheme.hotPink, lineWidth: max(1, lineWidth * 0.7))
                .frame(width: 30 * scale, height: 30 * scale)
                .offset(y: 4 * scale)
                .overlay(Rectangle().fill(AppTheme.teal).frame(width: 3 * scale, height: 28 * scale).offset(y: 4 * scale))
        case "avatar_outfit_royal":
            Diamond()
                .fill(AppTheme.hotPink)
                .frame(width: 11 * scale, height: 15 * scale)
                .offset(y: 12 * scale)
        default:
            EmptyView()
        }
    }

    private var leftArmEnd: (x: CGFloat, y: CGFloat) {
        switch style.pose {
        case "avatar_pose_victory": return (25, 19)
        case "avatar_pose_thinking": return (38, 42)
        case "avatar_pose_ready": return (22, 59)
        case "avatar_pose_flex": return (25, 38)
        default: return (24, 62)
        }
    }

    private var rightArmEnd: (x: CGFloat, y: CGFloat) {
        switch style.pose {
        case "avatar_pose_victory": return (75, 19)
        case "avatar_pose_thinking": return (76, 62)
        case "avatar_pose_ready": return (78, 59)
        case "avatar_pose_flex": return (75, 38)
        default: return (76, 62)
        }
    }

    private var leftLegEnd: (x: CGFloat, y: CGFloat) { style.pose == "avatar_pose_ready" ? (36, 88) : (40, 88) }
    private var rightLegEnd: (x: CGFloat, y: CGFloat) { style.pose == "avatar_pose_ready" ? (64, 88) : (60, 88) }

    private var bodyColor: Color {
        switch style.outfit {
        case "avatar_outfit_hoodie": return AppTheme.teal
        case "avatar_outfit_cape": return AppTheme.hotPink
        case "avatar_outfit_armor": return AppTheme.royalBlue
        case "avatar_outfit_neon": return Color(hex: "7B42FF")
        case "avatar_outfit_royal": return AppTheme.crownGold
        default: return AppTheme.hotPink
        }
    }

    private var bodyHighlight: Color {
        switch style.outfit {
        case "avatar_outfit_hoodie": return Color(hex: "7FFFE3")
        case "avatar_outfit_cape": return Color(hex: "FF8AC5")
        case "avatar_outfit_armor": return Color(hex: "71C8FF")
        case "avatar_outfit_neon": return Color(hex: "B794FF")
        case "avatar_outfit_royal": return Color(hex: "FFE887")
        default: return Color(hex: "FF7FB7")
        }
    }

    private var bodyShadow: Color {
        switch style.outfit {
        case "avatar_outfit_hoodie": return Color(hex: "078A76")
        case "avatar_outfit_cape": return Color(hex: "C21864")
        case "avatar_outfit_armor": return Color(hex: "1668D9")
        case "avatar_outfit_neon": return Color(hex: "3F1BC4")
        case "avatar_outfit_royal": return Color(hex: "D99500")
        default: return Color(hex: "C21F68")
        }
    }

    private var auraColor: Color {
        switch style.aura {
        case "avatar_aura_teal": return AppTheme.teal
        case "avatar_aura_pink": return AppTheme.hotPink
        case "avatar_aura_crown": return AppTheme.crownGold
        case "avatar_aura_storm": return AppTheme.royalBlue
        default: return AppTheme.accent
        }
    }

    private func point(x: CGFloat, y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }

    private func faceEyes(left: String, right: String, y: CGFloat = 44) -> some View {
        HStack(spacing: 11 * scale) {
            Text(left)
            Text(right)
        }
        .font(.system(size: max(7, 13 * scale), weight: .black, design: .rounded))
        .foregroundStyle(.white)
        .offset(y: (y - 50) * scale)
    }

    private func faceText(_ text: String, y: CGFloat, size fontSize: CGFloat) -> some View {
        Text(text)
            .font(.system(size: max(6, fontSize * scale), weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .offset(y: (y - 50) * scale)
    }

    private func mouthLine(width: CGFloat, y: CGFloat) -> some View {
        Capsule().fill(.white).frame(width: width * scale, height: max(1, 2 * scale)).offset(y: (y - 50) * scale)
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
        path.addLine(to: CGPoint(x: x + w * 0.42, y: y + h * 0.10))
        path.addCurve(
            to: CGPoint(x: x + w * 0.58, y: y + h * 0.10),
            control1: CGPoint(x: x + w * 0.42, y: y - h * 0.08),
            control2: CGPoint(x: x + w * 0.58, y: y - h * 0.08)
        )
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
